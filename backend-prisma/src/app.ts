import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import {
  ApiFault, LicenseService, postgresError, serviceFromEnv
} from './license.js';

type Body = Record<string, unknown>;

export function createApp(service?: LicenseService) {
  const app = new Hono();
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
  const privileged = new Set([
    '/api/v1/admin/campaigns', '/api/v1/admin/batches',
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
