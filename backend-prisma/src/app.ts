import { Hono, type Context } from 'hono';
import { cors } from 'hono/cors';
import { AccountService, type AccountIdentity } from './account.js';
import { AccountSecurityService, type AccountMailer } from './account_security.js';
import { bodyLimit } from 'hono/body-limit';
import {
  ApiFault, LicenseService, postgresError, serviceFromEnv
} from './license.js';

type Body = Record<string, unknown>;

export function createApp(service?: LicenseService, mailer?: AccountMailer) {
  const app = new Hono();
  const accounts = service ? new AccountService(service.pool) : undefined;
  const security = service ? new AccountSecurityService(service.pool, mailer) : undefined;
  const requestIp = (c: Context) => (c.req.header('x-vercel-forwarded-for') ??
    c.req.header('cf-connecting-ip') ?? c.req.header('x-forwarded-for') ?? 'unknown').split(',')[0].trim().slice(0,80);
  // Browser access is restricted to explicitly approved app origins.
  const trustedOrigins = new Set((process.env.HHK_ALLOWED_ORIGINS ?? '')
      .split(',').map(origin => origin.trim()).filter(Boolean));
  app.use('/api/v1/*', cors({
    origin: origin => trustedOrigins.has(origin) ? origin : '',
    allowHeaders: ['Content-Type', 'Authorization'],
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    maxAge: 600,
  }));
  app.use('/api/v1/*', bodyLimit({
    maxSize: 16384,
    onError: c => c.json({ok: false, code: 'BODY_TOO_LARGE'}, 413)
  }));

  app.get('/api/v1/health', async c => {
    if (!service) {
      return c.json({ok: false, service: 'hhk-license', status: 'configuration_required'}, 503);
    }
    try {
      await service.ping();
      return c.json({ok: true, service: 'hhk-license', status: 'ready'});
    } catch {
      return c.json({ok: false, service: 'hhk-license', status: 'database_unavailable'}, 503);
    }
  });

  const handlers: Record<string, (body: Body) => Promise<unknown>> = {
    '/api/v1/admin/campaigns': body => service!.createCampaign(body),
    '/api/v1/admin/batches': body => service!.createBatch(body),
    '/api/v1/claims/redeem': body => service!.redeem(body),
    '/api/v1/licenses/activate': body => service!.activate(body),
    '/api/v1/licenses/verify': body => service!.verify(body),
    '/api/v1/licenses/transfer': body => service!.transfer(body),
    '/api/v1/licenses/revoke': body => service!.revoke(body)
  };
  // Raw-key/anonymous legacy endpoints are admin-only; user flows require ownership.
  const privileged = new Set([
    '/api/v1/admin/campaigns', '/api/v1/admin/batches',
    '/api/v1/claims/redeem', '/api/v1/licenses/activate', '/api/v1/licenses/verify',
    '/api/v1/licenses/transfer', '/api/v1/licenses/revoke'
  ]);

  app.get('/api/v1/public-key', c => {
    if (!service) return c.json({ok: false, code: 'NOT_CONFIGURED'}, 503);
    return c.json({
      keyType: 'ed25519-spki-der-base64url',
      publicKey: service.publicKey(),
      leaseSchema: 'hhk-offline-license-v1'
    });
  });
  // Auth is always server-backed. No local-only account or client-side admin bypass.
  const accountError = (c: Context, error: unknown) => {
    if (error instanceof ApiFault) {
      return c.json({ok: false, code: error.code}, error.status);
    }
    return c.json({ok: false, code: 'SERVICE_UNAVAILABLE'}, 503);
  };
  const withAccount = async (
    c: Context,
    authenticated: boolean,
    work: (body: Body, identity?: AccountIdentity) => Promise<object>
  ) => {
    if (!accounts || !service) return c.json({ok: false, code: 'NOT_CONFIGURED'}, 503);
    try {
      const identity = authenticated
        ? await accounts.authenticate(c.req.header('authorization')) : undefined;
      let body: unknown;
      try { body = await c.req.json(); } catch {
        return c.json({ok: false, code: 'INVALID_BODY'}, 400);
      }
      if (!body || Array.isArray(body) || typeof body !== 'object' ||
          JSON.stringify(body).length > 16384) {
        return c.json({ok: false, code: 'INVALID_BODY'}, 400);
      }
      return c.json({ok: true, ...await work(body as Body, identity)});
    } catch (error) { return accountError(c, error); }
  };
  app.post('/api/v1/accounts/register',
    c => withAccount(c, false, body => accounts!.register(body)));
  app.post('/api/v1/accounts/login',
    c => withAccount(c, false, body => accounts!.login(body)));
  app.get('/api/v1/account/me', async c => {
    if (!accounts) return c.json({ok: false, code: 'NOT_CONFIGURED'}, 503);
    try {
      return c.json({ok: true, account: await accounts.authenticate(c.req.header('authorization'))});
    } catch (error) { return accountError(c, error); }
  });
  app.get('/api/v1/account/keys', async c => {
    if (!accounts) return c.json({ok: false, code: 'NOT_CONFIGURED'}, 503);
    try {
      const identity = await accounts.authenticate(c.req.header('authorization'));
      return c.json({ok: true, ...await accounts.keys(identity.id)});
    } catch (error) { return accountError(c, error); }
  });
  app.post('/api/v1/account/logout', async c => {
    if (!accounts) return c.json({ok: false, code: 'NOT_CONFIGURED'}, 503);
    try {
      const header = c.req.header('authorization');
      const identity = await accounts.authenticate(header);
      return c.json({ok: true, ...await accounts.logout(header, identity.id)});
    } catch (error) { return accountError(c, error); }
  });
  // Password recovery is intentionally separate from authenticated change.
  app.post('/api/v1/accounts/email/verification/request',
    c => withAccount(c, false, body => security!.requestVerification(body,requestIp(c))));
  app.post('/api/v1/accounts/email/verify',
    c => withAccount(c, false, body => security!.verifyEmail(body)));
  app.post('/api/v1/accounts/password/forgot',
    c => withAccount(c, false, body => security!.forgot(body,requestIp(c))));
  app.post('/api/v1/accounts/password/reset',
    c => withAccount(c, false, body => security!.reset(body)));
  app.post('/api/v1/account/password/change', c => withAccount(c, true,
    (body,identity) => security!.changePassword(identity!.id,c.req.header('authorization'),body)));
  app.post('/api/v1/account/email/change/request', c => withAccount(c,true,
    (body,identity) => security!.requestEmailChange(identity!.id,body)));
  app.post('/api/v1/accounts/email/change/confirm', c => withAccount(c,false,
    body => security!.confirmEmailChange(body)));
  app.get('/api/v1/account/sessions',async c => {
    if (!accounts || !security) return c.json({ok:false,code:'NOT_CONFIGURED'},503);
    try {
      const header=c.req.header('authorization');
      const identity=await accounts.authenticate(header);
      return c.json({ok:true,...await security.sessions(identity.id,header)});
    } catch(error) {return accountError(c,error);}
  });
  app.post('/api/v1/account/sessions/revoke',c => withAccount(c,true,
    (body,identity) => security!.revokeSession(identity!.id,c.req.header('authorization'),body)));
  app.post('/api/v1/account/logout-all',c => withAccount(c,true,
    (_body,identity) => security!.logoutAll(identity!.id)));
  app.post('/api/v1/account/keys/link', c => withAccount(c, true,
    (body, identity) => accounts!.linkKey(identity!.id, body)));
  app.post('/api/v1/account/keys/activate', c => withAccount(c, true,
    (body, identity) => service!.activateAccount(identity!.id, body)));
  app.post('/api/v1/account/keys/verify', c => withAccount(c, true,
    (body, identity) => service!.verifyAccount(identity!.id, body)));
  app.get('/api/v1/account/keys/:licenseId/devices', async c => {
    if (!accounts || !service) return c.json({ok:false,code:'NOT_CONFIGURED'},503);
    try {
      const identity = await accounts.authenticate(c.req.header('authorization'));
      return c.json({ok:true,...await service.accountDevices(identity.id,c.req.param('licenseId'))});
    } catch (error) {return accountError(c,error);}
  });
  app.post('/api/v1/account/keys/transfer', c => withAccount(c,true,
    (body,identity) => service!.transferAccount(identity!.id,body)));
  app.post('/api/v1/account/claims/redeem', c => withAccount(c, true,
    (body, identity) => service!.redeem(body, identity!.id)));
  for (const [path, handler] of Object.entries(handlers)) {
    app.post(path, async c => {
      if (!service) return c.json({ok: false, code: 'NOT_CONFIGURED'}, 503);
      if (privileged.has(path) &&
          !service.authorized(c.req.header('authorization'))) {
        return c.json({ok: false, code: 'UNAUTHORIZED'}, 401);
      }
      const contentLength = Number(c.req.header('content-length') ?? '0');
      if (!Number.isFinite(contentLength) || contentLength > 16384) {
        return c.json({ok: false, code: 'INVALID_BODY'}, 413);
      }
      if (!c.req.header('content-type')?.includes('application/json')) {
        return c.json({ok: false, code: 'INVALID_BODY'}, 415);
      }
      let parsed: unknown;
      try { parsed = await c.req.json(); } catch {
        return c.json({ok: false, code: 'INVALID_BODY'}, 400);
      }
      if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object' ||
          JSON.stringify(parsed).length > 16384) {
        return c.json({ok: false, code: 'INVALID_BODY'}, 400);
      }
      try {
        const result = await handler(parsed as Body);
        return c.json({ok: true, ...result as object}, 200);
      } catch (e) {
        if (e instanceof ApiFault) {
          return c.json({ok: false, code: e.code}, e.status as 400);
        }
        if (postgresError(e)) return c.json({ok: false, code: 'CONFLICT'}, 409);
        return c.json({ok: false, code: 'SERVICE_UNAVAILABLE'}, 503);
      }
    });
  }
  app.notFound(c => c.json({ok: false, code: 'NOT_FOUND'}, 404));
  return app;
}
export default createApp(serviceFromEnv());
