import { Hono } from 'hono';
import { cors } from 'hono/cors';

interface Bindings {
  DATABASE_URL?: string;
  LICENSE_SIGNING_PRIVATE_KEY?: string;
  ALLOWED_ORIGINS?: string;
}

const app = new Hono<{Bindings:Bindings}>();
app.use('/api/*', cors({
  origin: (origin, context) => {
    const allowed = (context.env.ALLOWED_ORIGINS ?? '').split(',')
      .map((value: string)=>value.trim()).filter(Boolean);
    return allowed.includes(origin) ? origin : '';
  },
  allowMethods:['GET','POST','OPTIONS'],
  allowHeaders:['Content-Type','Authorization'],
}));
app.get('/api/v1/health',(c)=>c.json({ok:true,service:'hhk-license',stage:'scaffold'}));

// Deliberately fail-closed until atomic QR redemption,
// signed offline licenses, DB constraints and abuse controls are implemented.
for (const path of [
  '/api/v1/claims/redeem',
  '/api/v1/licenses/activate',
  '/api/v1/licenses/transfer',
  '/api/v1/licenses/revoke',
  '/api/v1/licenses/verify',
]) {
  app.post(path,(c)=>c.json({ok:false,code:'FEATURE_NOT_RELEASED'},501));
}
app.notFound(c=>c.json({ok:false,code:'NOT_FOUND'},404));
app.onError((error,c)=>{
  console.error('HHK Worker error:',error.name);
  return c.json({ok:false,code:'INTERNAL_ERROR'},500);
});
export default app;
