import { module } from '@prisma/composer';
import { envSecret } from '@prisma/composer-prisma-cloud';
import licenseApi from './service.ts';

// Name must match the already-created Prisma Console project gus-02.
// Staging is targeted exclusively by the deploy invocation/environment flag.
// No rawPostgres() declaration: the existing hhk-staging database is kept.
export default module('gus-02', ({ provision }) => {
  provision(licenseApi, {
    input: {
      databaseUrl: envSecret('HHK_LICENSE_DATABASE_URL'),
      adminKey: envSecret('ADMIN_API_KEY'),
      signingKey: envSecret('LEASE_SIGNING_PRIVATE_KEY_PEM_BASE64'),
    },
  });
});
