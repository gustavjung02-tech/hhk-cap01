import { test } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/app.js';

test('health is explicit about missing Prisma backend configuration', async () => {
  const r = await app.request('/api/v1/health');
  assert.equal(r.status, 200);
  assert.equal((await r.json()).status, 'configuration_required');
});

test('claim and license are never usable before a configured database', async () => {
  for (const route of ['/api/v1/claims/redeem','/api/v1/licenses/activate']) {
    const r = await app.request(route,{method:'POST'});
    assert.equal(r.status,503);
    assert.equal((await r.json()).code, 'NOT_CONFIGURED');
  }
});
