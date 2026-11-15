import { test } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/app.js';

test('health is explicit about missing Prisma backend configuration', async () => {
  const r = await app.request('/api/v1/health');
  assert.equal(r.status, 503);
  assert.deepEqual(await r.json(), {ok: false, service: 'hhk-license', status: 'configuration_required'});
});

test('claim and license are never usable before a configured database', async () => {
  for (const route of ['/api/v1/claims/redeem','/api/v1/licenses/activate']) {
    const r = await app.request(route,{method:'POST'});
    assert.equal(r.status,503);
    assert.equal((await r.json()).code, 'NOT_CONFIGURED');
  }
});

test('the Hono default export provides the Vercel-compatible fetch handler', () => {
  assert.equal(typeof app.fetch, 'function');
});

test('account login and inventory fail closed when database configuration is missing', async () => {
  const login = await app.request('/api/v1/accounts/login', {
    method: 'POST', headers: {'content-type': 'application/json'},
    body: JSON.stringify({email: 'user@example.test', password: 'not-a-real-password'})
  });
  assert.equal(login.status,503);
  assert.equal((await login.json()).code,'NOT_CONFIGURED');
  assert.equal((await app.request('/api/v1/account/keys')).status,503);
});
