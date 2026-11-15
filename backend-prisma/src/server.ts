import { serve } from '@hono/node-server';
import app from './app.js';
const port = Number.parseInt(process.env.PORT ?? '3000', 10);
if (!Number.isSafeInteger(port) || port < 1 || port > 65535) {
  throw new Error('Invalid PORT');
}
serve({fetch: app.fetch, hostname: '0.0.0.0', port});
console.log('HHK license backend listening');
