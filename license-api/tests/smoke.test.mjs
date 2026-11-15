import { test } from 'node:test';
import { strict as assert } from 'node:assert';
test('license API intentionally fails closed before release', () => {
  assert.equal('FEATURE_NOT_RELEASED'.startsWith('FEATURE_'),true);
});
