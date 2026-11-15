import { z } from 'zod';
import { secretString } from '@prisma/composer/zod';
import node from '@prisma/composer/node';
import { compute } from '@prisma/composer-prisma-cloud';

export default compute({
  name: 'hhk-license-api',
  deps: {},
  input: z.object({
    databaseUrl: secretString(),
    adminKey: secretString(),
    signingKey: secretString(),
  }),
  build: node({ module: import.meta.url, entry: './dist/compute-server.mjs' }),
});
