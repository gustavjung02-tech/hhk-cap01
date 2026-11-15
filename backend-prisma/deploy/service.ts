import { type } from 'arktype';
import { secretString } from '@prisma/composer/arktype';
import node from '@prisma/composer/node';
import { compute } from '@prisma/composer-prisma-cloud';

export default compute({
  name: 'hhk-license-api',
  deps: {},
  input: type({ databaseUrl: secretString(), adminKey: secretString(), signingKey: secretString() }),
  build: node({ module: import.meta.url, entry: './dist/compute-server.mjs' }),
});
