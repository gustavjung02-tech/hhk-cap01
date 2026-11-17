import {
  createHash, createPrivateKey, createPublicKey, randomBytes, randomUUID,
  sign, timingSafeEqual, verify, type KeyObject
} from 'node:crypto';
import { Pool, type PoolClient } from 'pg';

const maxLeaseMs = 7 * 24 * 60 * 60 * 1000;
const ed25519SpkiPrefix = Buffer.from('302a300506032b6570032100', 'hex');
const tokenPattern = /^qr_[A-Za-z0-9_-]{32}$/;
const licensePattern = /^lic_[A-Za-z0-9_-]{32}$/;
const codePattern = /^[A-Z0-9][A-Z0-9_-]{2,39}$/;
const noncePattern = /^[A-Za-z0-9_-]{16,64}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class ApiFault extends Error {
  constructor(public readonly status: 400 | 401 | 403 | 404 | 409 | 422 | 429 | 503,
              public readonly code: string) { super(code); }
}

export type LicenseConfig = {
  pool: Pool;
  adminKey: string;
  privateKey: KeyObject;
};

type Policy = { grades: number[]; maxDevices: number; validDays: number };
type ClaimRow = {
  id: string; status: string; campaign_code: string;
  active: boolean; policy_version: number; policy: Policy;
};
type LicenseRow = {
  id: string; status: string; entitled_grades: number[];
  valid_from: Date; valid_until: Date | null; max_devices: number;
};
type DeviceRow = { id: string; active: boolean };
type DeviceProof = {
  licenseKey: string;
  devicePublicKey: string;
  proof: string;
  nonce: string;
  signedAt: number;
};
const digest = (value: string) => createHash('sha256').update(value, 'utf8').digest();
const hexDigest = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const token = (prefix: string) => prefix + randomBytes(24).toString('base64url');

const validPolicy = (value: unknown): value is Policy => {
  if (typeof value !== 'object' || value === null) return false;
  const p = value as Record<string, unknown>;
  return Array.isArray(p.grades) && p.grades.length > 0 &&
    p.grades.length <= 5 && p.grades.every(x => Number.isInteger(x) && x >= 1 && x <= 5) &&
    new Set(p.grades).size === p.grades.length &&
    Number.isInteger(p.maxDevices) && (p.maxDevices as number) >= 1 &&
    (p.maxDevices as number) <= 10 &&
    Number.isInteger(p.validDays) && (p.validDays as number) >= 1 &&
    (p.validDays as number) <= 3650;
};

function parseDevice(value: unknown, action: 'activate' | 'verify' | 'transfer') {
  if (typeof value !== 'object' || value === null) throw new ApiFault(400, 'INVALID_DEVICE_PROOF');
  const p = value as Partial<DeviceProof>;
  if (typeof p.licenseKey !== 'string' || !licensePattern.test(p.licenseKey) ||
      typeof p.devicePublicKey !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(p.devicePublicKey) ||
      typeof p.proof !== 'string' || !/^[A-Za-z0-9_-]{86}$/.test(p.proof) ||
      typeof p.nonce !== 'string' || !noncePattern.test(p.nonce) ||
      typeof p.signedAt !== 'number' || !Number.isSafeInteger(p.signedAt) ||
      Math.abs(Date.now() - p.signedAt) > 5 * 60 * 1000) {
    throw new ApiFault(400, 'INVALID_DEVICE_PROOF');
  }
  const raw = Buffer.from(p.devicePublicKey, 'base64url');
  const sig = Buffer.from(p.proof, 'base64url');
  if (raw.length !== 32 || sig.length !== 64) throw new ApiFault(400, 'INVALID_DEVICE_PROOF');
  const publicKey = createPublicKey({
    key: Buffer.concat([ed25519SpkiPrefix, raw]), format: 'der', type: 'spki'
  });
  const data = proofMessage(action, p.licenseKey, p.devicePublicKey, p.nonce, p.signedAt);
  if (!verify(null, Buffer.from(data), publicKey, sig)) {
    throw new ApiFault(401, 'INVALID_DEVICE_SIGNATURE');
  }
  return { licenseHash: digest(p.licenseKey), deviceHash: digest(p.devicePublicKey),
           deviceHashHex: hexDigest(raw) };
}

type AccountDevice = {
  licenseId: string;
  deviceHash: Buffer;
  deviceHashHex: string;
};

// The signed message uses the license ID, not a raw bearer license key.
// Distinct action names prevent replaying v1 activate/verify/transfer proofs.
function parseAccountDevice(value: unknown, action: 'account-activate' | 'account-verify' | 'account-transfer'):
  AccountDevice {
  const p = value as Record<string, unknown> | null;
  if (!p || typeof p.licenseId !== 'string' || !uuidPattern.test(p.licenseId) ||
      typeof p.devicePublicKey !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(p.devicePublicKey) ||
      typeof p.nonce !== 'string' || !noncePattern.test(p.nonce) ||
      typeof p.proof !== 'string' || !/^[A-Za-z0-9_-]{86}$/.test(p.proof) ||
      typeof p.signedAt !== 'number' || !Number.isSafeInteger(p.signedAt) ||
      Math.abs(Date.now() - p.signedAt) > 5 * 60 * 1000) {
    throw new ApiFault(400, 'INVALID_DEVICE_PROOF');
  }
  const raw = Buffer.from(p.devicePublicKey, 'base64url');
  const sig = Buffer.from(p.proof, 'base64url');
  if (raw.length !== 32 || sig.length !== 64) {
    throw new ApiFault(400, 'INVALID_DEVICE_PROOF');
  }
  const key = createPublicKey({
    key: Buffer.concat([ed25519SpkiPrefix, raw]), format: 'der', type: 'spki'
  });
  const message = proofMessage(action, p.licenseId, p.devicePublicKey,
                               p.nonce, p.signedAt);
  if (!verify(null, Buffer.from(message), key, sig)) {
    throw new ApiFault(401, 'INVALID_DEVICE_SIGNATURE');
  }
  return {licenseId: p.licenseId, deviceHash: digest(p.devicePublicKey),
          deviceHashHex: hexDigest(raw)};
}

export function proofMessage(action: string, licenseKey: string, devicePublicKey: string,
                             nonce: string, signedAt: number) {
  return ['HHK-DEVICE-PROOF-v1', action, licenseKey, devicePublicKey, nonce,
          String(signedAt)].join('\n');
}

async function transaction<T>(pool: Pool, work: (c: PoolClient) => Promise<T>): Promise<T> {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    const result = await work(c);
    await c.query('COMMIT');
    return result;
  } catch (e) {
    await c.query('ROLLBACK');
    throw e;
  } finally { c.release(); }
}

export function isAdmin(header: string | undefined, expected: string): boolean {
  const supplied = header?.startsWith('Bearer ') ? header.slice(7) : '';
  if (!supplied || expected.length < 32) return false;
  return timingSafeEqual(digest(supplied), digest(expected));
}

export class LicenseService {
  constructor(private readonly config: LicenseConfig) {}

  get pool() { return this.config.pool; }

  authorized(header: string | undefined) {
    return isAdmin(header, this.config.adminKey);
  }

  async ping() {
    await this.config.pool.query('SELECT 1');
  }

  publicKey() {
    return createPublicKey(this.config.privateKey).export({type: 'spki', format: 'der'})
      .toString('base64url');
  }

  private lease(row: LicenseRow, deviceHashHex: string) {
    const now = Date.now();
    const end = Math.min(now + maxLeaseMs, row.valid_until?.getTime() ?? Infinity);
    if (end <= now) throw new ApiFault(403, 'LICENSE_EXPIRED');
    const payload = {
      kind: 'hhk-offline-license-v1',
      licenseId: row.id,
      deviceKeyHash: deviceHashHex,
      grades: row.entitled_grades,
      issuedAt: new Date(now).toISOString(),
      expiresAt: new Date(end).toISOString()
    };
    const encoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const signature = sign(null, Buffer.from(encoded), this.config.privateKey)
      .toString('base64url');
    return { lease: encoded + '.' + signature, expiresAt: payload.expiresAt,
             grades: payload.grades };
  }

  async createCampaign(value: unknown) {
    const p = value as Record<string, unknown> | null;
    if (!p || typeof p.campaignCode !== 'string' ||
        !codePattern.test(p.campaignCode) || !validPolicy(p.policy) ||
        p.active !== true) throw new ApiFault(400, 'INVALID_CAMPAIGN');
    const id = randomUUID();
    await this.config.pool.query(
      'INSERT INTO reward_campaigns (id,campaign_code,active,policy,policy_version) VALUES ($1,$2,true,$3::jsonb,1)',
      [id, p.campaignCode, JSON.stringify(p.policy)]
    );
    return { id, campaignCode: p.campaignCode, active: true };
  }

  async createBatch(value: unknown) {
    const p = value as Record<string, unknown> | null;
    if (!p || typeof p.batchCode !== 'string' || !codePattern.test(p.batchCode) ||
        typeof p.campaignCode !== 'string' || !codePattern.test(p.campaignCode) ||
        !Number.isInteger(p.quantityTokens) || (p.quantityTokens as number) < 1 ||
        (p.quantityTokens as number) > 1000) {
      throw new ApiFault(400, 'INVALID_BATCH');
    }
    return transaction(this.config.pool, async c => {
      const campaigns = await c.query<{id: string}>(
        'SELECT id FROM reward_campaigns WHERE campaign_code=$1 AND active=true AND policy_version=1',
        [p.campaignCode]
      );
      if (!campaigns.rows[0]) throw new ApiFault(409, 'CAMPAIGN_NOT_ACTIVE');
      const batchId = randomUUID();
      await c.query(
        'INSERT INTO claim_batches (id,batch_code,token_count) VALUES ($1,$2,$3)',
        [batchId, p.batchCode, p.quantityTokens]
      );
      const qrTokens: string[] = [];
      for (let i = 0; i < (p.quantityTokens as number); i++) {
        const raw = token('qr_');
        await c.query(
          'INSERT INTO claim_tokens (id,batch_id,token_hash,campaign_id) VALUES ($1,$2,$3,$4)',
          [randomUUID(), batchId, digest(raw), campaigns.rows[0].id]
        );
        qrTokens.push(raw);
      }
      return {batchId, batchCode: p.batchCode, qrTokens};
    });
  }

  async redeem(value: unknown, accountId?: string) {
    const p = value as Record<string, unknown> | null;
    if (!p || typeof p.token !== 'string' || !tokenPattern.test(p.token)) {
      throw new ApiFault(400, 'INVALID_TOKEN');
    }
    return transaction(this.config.pool, async c => {
      const result = await c.query<ClaimRow>(
        'SELECT t.id,t.status,c.campaign_code,c.active,c.policy_version,c.policy FROM claim_tokens t JOIN reward_campaigns c ON c.id=t.campaign_id WHERE t.token_hash=$1 FOR UPDATE OF t',
        [digest(p.token as string)]
      );
      const claim = result.rows[0];
      if (!claim) throw new ApiFault(404, 'TOKEN_NOT_FOUND');
      if (claim.status !== 'unclaimed') throw new ApiFault(409, 'TOKEN_ALREADY_USED');
      if (!claim.active || claim.policy_version !== 1 || !validPolicy(claim.policy)) {
        throw new ApiFault(409, 'CAMPAIGN_NOT_ACTIVE');
      }
      const licenseKey = token('lic_');
      const licenseId = randomUUID();
      const policy = claim.policy;
      const inserted = await c.query<{valid_until: Date}>(
        "INSERT INTO licenses (id,token_id,license_hash,source,entitled_grades,valid_until,max_devices,status,account_id) VALUES ($1,$2,$3,'qr_claim',$4::smallint[],now() + $5::integer * interval '1 day',$6,'issued',$7) RETURNING valid_until",
        [licenseId, claim.id, digest(licenseKey), policy.grades, policy.validDays,
         policy.maxDevices, accountId ?? null]
      );
      await c.query(
        "UPDATE claim_tokens SET status='redeemed',redeemed_at=now() WHERE id=$1",
        [claim.id]
      );
      await c.query(
        "INSERT INTO license_audit (license_id,claim_token_id,operation,outcome,metadata) VALUES ($1,$2,'redeem','success',$3::jsonb)",
        [licenseId, claim.id, JSON.stringify({campaign: claim.campaign_code, policyVersion: 1})]
      );
      return { licenseKey, licenseId, grades: policy.grades,
               maxDevices: policy.maxDevices, validUntil: inserted.rows[0].valid_until };
    });
  }

  private checkLicense(license: LicenseRow) {
    if (license.status === 'revoked') throw new ApiFault(403, 'LICENSE_REVOKED');
    if (license.status === 'expired' || license.valid_from.getTime() > Date.now() ||
        (license.valid_until && license.valid_until.getTime() <= Date.now())) {
      throw new ApiFault(403, 'LICENSE_EXPIRED');
    }
    return license;
  }

  private async lookupAccountLicense(
    c: PoolClient, accountId: string, licenseId: string, locked: boolean
  ) {
    const result = await c.query<LicenseRow>(
      'SELECT id,status,entitled_grades,valid_from,valid_until,max_devices ' +
      'FROM licenses WHERE id=$1 AND account_id=$2' + (locked ? ' FOR UPDATE' : ''),
      [licenseId, accountId]
    );
    if (!result.rows[0]) throw new ApiFault(404, 'LICENSE_NOT_FOUND');
    return this.checkLicense(result.rows[0]);
  }

  private async lookupLicense(c: PoolClient, licenseHash: Buffer, locked: boolean) {
    const row = await c.query<LicenseRow>(
      'SELECT id,status,entitled_grades,valid_from,valid_until,max_devices FROM licenses WHERE license_hash=$1' +
        (locked ? ' FOR UPDATE' : ''), [licenseHash]
    );
    if (!row.rows[0]) throw new ApiFault(404, 'LICENSE_NOT_FOUND');
    return this.checkLicense(row.rows[0]);
  }

  private async activateKnownLicense(
    c: PoolClient, license: LicenseRow,
    device: {deviceHash: Buffer; deviceHashHex: string}
  ) {
    const existing = await c.query<DeviceRow>(
      'SELECT id,active FROM device_activations WHERE license_id=$1 AND device_public_key_hash=$2',
      [license.id, device.deviceHash]
    );
    if (existing.rows[0] && !existing.rows[0].active) {
      throw new ApiFault(403, 'DEVICE_REVOKED');
    }
    if (!existing.rows[0]) {
      const used = await c.query<{count: string}>(
        'SELECT count(*)::text AS count FROM device_activations WHERE license_id=$1 AND active=true',
        [license.id]
      );
      if (Number(used.rows[0].count) >= license.max_devices) {
        throw new ApiFault(409, 'DEVICE_LIMIT_REACHED');
      }
      await c.query(
        'INSERT INTO device_activations (id,license_id,device_public_key_hash) VALUES ($1,$2,$3)',
        [randomUUID(), license.id, device.deviceHash]
      );
      await c.query(
        "INSERT INTO license_audit (license_id,operation,outcome) VALUES ($1,'activate','success')",
        [license.id]
      );
    }
    if (license.status === 'issued') {
      await c.query("UPDATE licenses SET status='active' WHERE id=$1", [license.id]);
    }
    return this.lease(license, device.deviceHashHex);
  }

  private async verifyKnownLicense(
    c: PoolClient, license: LicenseRow,
    device: {deviceHash: Buffer; deviceHashHex: string}
  ) {
    if (license.status !== 'active') throw new ApiFault(403, 'NOT_ACTIVATED');
    const row = await c.query<DeviceRow>(
      'SELECT id,active FROM device_activations WHERE license_id=$1 AND device_public_key_hash=$2',
      [license.id, device.deviceHash]
    );
    if (!row.rows[0]?.active) throw new ApiFault(403, 'DEVICE_NOT_ACTIVE');
    return this.lease(license, device.deviceHashHex);
  }

  async activate(value: unknown) {
    const device = parseDevice(value, 'activate');
    return transaction(this.config.pool, async c =>
      this.activateKnownLicense(c, await this.lookupLicense(c, device.licenseHash, true), device)
    );
  }

  async verify(value: unknown) {
    const device = parseDevice(value, 'verify');
    const c = await this.config.pool.connect();
    try {
      return await this.verifyKnownLicense(c,
        await this.lookupLicense(c, device.licenseHash, false), device);
    } finally { c.release(); }
  }

  async activateAccount(accountId: string, value: unknown) {
    const device = parseAccountDevice(value, 'account-activate');
    return transaction(this.config.pool, async c =>
      this.activateKnownLicense(c,
        await this.lookupAccountLicense(c, accountId, device.licenseId, true),
        device)
    );
  }

  async verifyAccount(accountId: string, value: unknown) {
    const device = parseAccountDevice(value, 'account-verify');
    const c = await this.config.pool.connect();
    try {
      return await this.verifyKnownLicense(c,
        await this.lookupAccountLicense(c, accountId, device.licenseId, false),
        device);
    } finally { c.release(); }
  }


  // Account owner can list registered slots, without exposing raw license keys.
  async accountDevices(accountId: string, licenseId: string) {
    if (!uuidPattern.test(licenseId)) throw new ApiFault(400, 'INVALID_LICENSE_ID');
    const rows = await this.config.pool.query<{
      id: string; active: boolean; activated_at: Date; revoked_at: Date | null;
      fingerprint: string;
    }>(
      `SELECT d.id,d.active,d.activated_at,d.revoked_at,
         left(encode(d.device_public_key_hash,'hex'),12) AS fingerprint
       FROM device_activations d JOIN licenses l ON l.id=d.license_id
       WHERE d.license_id=$1 AND l.account_id=$2
       ORDER BY d.activated_at DESC`,
      [licenseId, accountId]
    );
    // Don't disclose account/license existence to another user.
    const own = await this.config.pool.query(
      'SELECT 1 FROM licenses WHERE id=$1 AND account_id=$2', [licenseId, accountId]);
    if (!own.rows.length) throw new ApiFault(404, 'LICENSE_NOT_FOUND');
    return {devices: rows.rows.map(row => ({
      id:row.id, active:row.active, fingerprint:row.fingerprint,
      activatedAt:row.activated_at, revokedAt:row.revoked_at
    }))};
  }

  // New device signs its own key; account auth and DB row lock authorize transfer.
  // The source device can be selected by id, without copying its private key.
  async transferAccount(accountId: string, value: unknown) {
    const device = parseAccountDevice(value, 'account-transfer');
    const p = value as Record<string, unknown>;
    if (typeof p.fromDeviceId !== 'string' || !uuidPattern.test(p.fromDeviceId)) {
      throw new ApiFault(400, 'INVALID_TRANSFER');
    }
    return transaction(this.config.pool, async c => {
      const license = await this.lookupAccountLicense(c, accountId, device.licenseId, true);
      const old = await c.query<DeviceRow>(
        'SELECT id,active FROM device_activations WHERE id=$1 AND license_id=$2 FOR UPDATE',
        [p.fromDeviceId, license.id]);
      if (!old.rows[0]?.active) throw new ApiFault(409, 'SOURCE_DEVICE_NOT_ACTIVE');
      const already = await c.query<DeviceRow>(
        'SELECT id,active FROM device_activations WHERE license_id=$1 AND device_public_key_hash=$2',
        [license.id,device.deviceHash]);
      if (already.rows.length) throw new ApiFault(409, 'TARGET_ALREADY_REGISTERED');
      await c.query(
        'UPDATE device_activations SET active=false,revoked_at=now() WHERE id=$1',
        [old.rows[0].id]);
      await c.query(
        'INSERT INTO device_activations (id,license_id,device_public_key_hash) VALUES ($1,$2,$3)',
        [randomUUID(),license.id,device.deviceHash]);
      await c.query(
        "INSERT INTO license_audit (license_id,operation,outcome) VALUES ($1,'transfer','success')",
        [license.id]);
      return this.lease(license, device.deviceHashHex);
    });
  }

  async revoke(value: unknown) {
    const p = value as Record<string, unknown> | null;
    if (!p || typeof p.licenseId !== 'string' || !uuidPattern.test(p.licenseId)) {
      throw new ApiFault(400, 'INVALID_LICENSE_ID');
    }
    return transaction(this.config.pool, async c => {
      const found = await c.query<{status: string}>(
        'SELECT status FROM licenses WHERE id=$1 FOR UPDATE', [p.licenseId]
      );
      if (!found.rows[0]) throw new ApiFault(404, 'LICENSE_NOT_FOUND');
      if (found.rows[0].status !== 'revoked') {
        await c.query("UPDATE licenses SET status='revoked' WHERE id=$1", [p.licenseId]);
        await c.query(
          'UPDATE device_activations SET active=false,revoked_at=now() WHERE license_id=$1 AND active=true',
          [p.licenseId]
        );
        await c.query(
          "INSERT INTO license_audit (license_id,operation,outcome) VALUES ($1,'revoke','success')",
          [p.licenseId]
        );
      }
      return {licenseId: p.licenseId, status: 'revoked'};
    });
  }

  async transfer(value: unknown) {
    const p = value as Record<string, unknown> | null;
    if (!p || typeof p.fromDevicePublicKey !== 'string' ||
        !/^[A-Za-z0-9_-]{43}$/.test(p.fromDevicePublicKey)) {
      throw new ApiFault(400, 'INVALID_TRANSFER');
    }
    const device = parseDevice(value, 'transfer');
    const fromHash = digest(p.fromDevicePublicKey);
    if (timingSafeEqual(fromHash, device.deviceHash)) {
      throw new ApiFault(400, 'SAME_DEVICE');
    }
    return transaction(this.config.pool, async c => {
      const license = await this.lookupLicense(c, device.licenseHash, true);
      const old = await c.query<DeviceRow>(
        'SELECT id,active FROM device_activations WHERE license_id=$1 AND device_public_key_hash=$2',
        [license.id, fromHash]
      );
      if (!old.rows[0]?.active) throw new ApiFault(409, 'SOURCE_DEVICE_NOT_ACTIVE');
      const prev = await c.query<DeviceRow>(
        'SELECT id,active FROM device_activations WHERE license_id=$1 AND device_public_key_hash=$2',
        [license.id, device.deviceHash]
      );
      if (prev.rows[0]) throw new ApiFault(409, 'TARGET_ALREADY_REGISTERED');
      await c.query(
        'UPDATE device_activations SET active=false,revoked_at=now() WHERE id=$1',
        [old.rows[0].id]
      );
      await c.query(
        'INSERT INTO device_activations (id,license_id,device_public_key_hash) VALUES ($1,$2,$3)',
        [randomUUID(), license.id, device.deviceHash]
      );
      await c.query(
        "INSERT INTO license_audit (license_id,operation,outcome) VALUES ($1,'transfer','success')",
        [license.id]
      );
      return this.lease(license, device.deviceHashHex);
    });
  }
}

export function serviceFromEnv(): LicenseService | undefined {
  const url = process.env.DATABASE_URL;
  const adminKey = process.env.ADMIN_API_KEY;
  const pemBase64 = process.env.LEASE_SIGNING_PRIVATE_KEY_PEM_BASE64;
  if (!url || !adminKey || adminKey.length < 32 || !pemBase64) return undefined;
  try {
    const privateKey = createPrivateKey(Buffer.from(pemBase64, 'base64').toString('utf8'));
    if (privateKey.asymmetricKeyType !== 'ed25519') return undefined;
    return new LicenseService({
      pool: new Pool({connectionString: url, max: 8, connectionTimeoutMillis: 3000}),
      adminKey, privateKey
    });
  } catch {
    return undefined;
  }
}

export function postgresError(error: unknown): boolean {
  return typeof error === 'object' && error !== null &&
    'code' in error && (error as {code?: string}).code === '23505';
}
