import { createPrivateKey } from 'node:crypto';
import { Pool } from 'pg';
import { createApp } from '../src/app.ts';
import { LicenseService } from '../src/license.ts';
import computeService from './service.ts';

// Prisma Compute passes secrets through typed Composer service input. Never
// bundle real database credentials, admin secrets, or private signing keys.
const input = computeService.input();
const privateKey = createPrivateKey(
  Buffer.from(input.signingKey.expose(), 'base64').toString('utf8')
);
if (privateKey.asymmetricKeyType !== 'ed25519') {
  throw new Error('LEASE_SIGNING_PRIVATE_KEY must be Ed25519');
}
const pool = new Pool({
  connectionString: input.databaseUrl.expose(),
  max: 4,
  idleTimeoutMillis: 15_000,
  connectionTimeoutMillis: 3_000,
});
const app = createApp(new LicenseService({
  pool,
  adminKey: input.adminKey.expose(),
  privateKey,
}));
Bun.serve({ port: computeService.port(), hostname: '0.0.0.0', fetch: app.fetch });
