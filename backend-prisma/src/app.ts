import { Hono } from 'hono';

/**
 * Deliberately fails closed until Prisma Postgres and secure QR/license
 * implementation are provisioned inside the user's specified Prisma project.
 * NEVER accept user-provided "premium", "grade", or "device" claims as truth.
 */
const app = new Hono();
app.get('/api/v1/health', c => c.json({ok:true,service:'hhk-license',status:'configuration_required'}));
for (const path of [
  '/api/v1/claims/redeem',
  '/api/v1/licenses/activate',
  '/api/v1/licenses/transfer',
  '/api/v1/licenses/revoke',
  '/api/v1/licenses/verify',
]) {
  app.post(path, c => c.json({ok:false,code:'NOT_CONFIGURED'},503));
}
app.notFound(c => c.json({ok:false,code:'NOT_FOUND'},404));
export default app;
