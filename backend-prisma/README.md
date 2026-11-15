# HHK license backend — staging

## Staging backend on Vercel (Issue #6; current deployment path, 2026-11-15)

**Decision:** retain the existing Prisma Postgres database `hhk-staging` in `gus-02`; deploy Hono as a separate Vercel project **hhk-cap01-license-staging**. No Composer bootstrap, no database recreation, and no production migration. The previous Composer deployment experiment is not the active release path.

- Vercel team: `gustavjung02-techs-projects`; framework: **hono**; root directory: `backend-prisma`; Node 24.x; function region: `sin1` (Singapore); Git auto-deploy disabled by `backend-prisma/vercel.json`. The source entry `src/app.ts` exports the native Hono fetch handler. `src/serve-node.ts` remains the standalone local Node process, deliberately **not** named `src/server.ts` to avoid ambiguous Vercel framework entry detection.
- Staging-only Vercel encrypted env: `DATABASE_URL` (the **direct PostgreSQL connection string** for database `db_l4ds0m8jnxux66bd3erlnvqe`), `ADMIN_API_KEY` (32+ random chars), `LEASE_SIGNING_PRIVATE_KEY_PEM_BASE64` (Ed25519 PKCS8 PEM encoded base64). Never expose these via Flutter, public routes, GitHub code, screenshots, or logs.
- Release process: commit to `staging` -> verify successful push CI for **exact SHA** -> **manual preview deployment** on the dedicated Vercel project -> check `/api/v1/health` status `ready` and `/api/v1/public-key` -> conduct E2E QR/license checks with controlled staging test records -> report URL in Issue #6. Do not auto-promote to the PWA production domain.
- A missing backend configuration now correctly returns **503** at health (instead of misleading `200 configuration_required`); all QR/license mutation routes also fail closed. A healthy `200 ready` requires a real successful PostgreSQL ping.
- The Prisma staging DB migration ledger is retained as-is; **do not run migrations during the Vercel deployment**. Compute-specific files are historical until Composer offers supported non-destructive resource adoption.


This Node 24 + Hono + pg service uses Prisma Postgres within project gus-02.
The source is implemented and tested against a disposable PostgreSQL CI database.
Do not mistake source-ready for production-deployed: a Prisma Compute app does not
yet exist, and public production license issuance must remain disabled.

## Required backend-only environment

- DATABASE_URL — direct PostgreSQL URL for hhk-staging. Do not place this in Flutter or public Vercel.
- Prisma Compute **staging** Composer uses `HHK_LICENSE_DATABASE_URL` instead of reserved `DATABASE_URL`. This is a branch-scoped secret and points to the same existing hhk-staging database.
- ADMIN_API_KEY — a random administrative token of at least 32 characters.
- LEASE_SIGNING_PRIVATE_KEY_PEM_BASE64 — base64 of an Ed25519 private-key PEM.
- PORT — optional, defaults to 3000.

Missing configuration returns HTTP 503 (NOT_CONFIGURED). Database failures also fail closed.

## Flow and endpoints

1. Admin POST /api/v1/admin/campaigns: {"campaignCode":"GRADE1","active":true,"policy":{"grades":[1],"maxDevices":1,"validDays":30}}. Requires Authorization: Bearer ADMIN_API_KEY.
2. Admin POST /api/v1/admin/batches: {"batchCode":"BATCH001","campaignCode":"GRADE1","quantityPacks":10}. Exactly one random qr_ token is issued per pack of 20 notebooks; returned only once.
3. Public POST /api/v1/claims/redeem: {"token":"qr_..."}. SQL row locks and UNIQUE token binding ensure only one lic_ license per QR, concurrent requests cannot create duplicates. A repeated claim receives 409, never a second license.
4. POST /api/v1/licenses/activate requires licenseKey, devicePublicKey, nonce, signedAt and proof of the device's Ed25519 private key. Concurrent activations lock the license row and enforce maxDevices.
5. POST /api/v1/licenses/verify refreshes a signed lease only for an active registered device. GET /api/v1/public-key exposes the Ed25519 verifier public key.
6. Admin POST /api/v1/licenses/transfer moves a single active slot to a new signed device; requires fromDevicePublicKey. Admin POST /api/v1/licenses/revoke with {"licenseId":"uuid"} disables all devices. Both require the admin Bearer token.
7. GET /api/v1/health reports ready only if the database responds.

Device proof message (UTF-8, joined by newlines):
HHK-DEVICE-PROOF-v1
activate OR verify OR transfer
licenseKey
devicePublicKey
nonce
signedAt

devicePublicKey: base64url of the 32 raw bytes of an Ed25519 public key.
nonce: base64url string 16–64 characters. signedAt: Unix milliseconds within 5 minutes.
proof: base64url 64-byte Ed25519 signature of the whole message.

Offline lease: base64url(JSON payload).base64url(Ed25519 signature over the encoded JSON).
Leases last at most seven days, limited by license expiry. Clients must check signature,
device public-key hash, grade entitlement, and expiry offline. Revocation only takes
effect on disconnected clients when their lease expires.

## Build and CI

cd backend-prisma
npm install
npm run typecheck
npm test
npm run build
npm start

GitHub Actions starts disposable postgres:16, applies the exact versioned
db-prisma/migrations/0001_license_only.sql and 0002_device_limit.sql migrations
and tests concurrent QR redemption, database quota bypass prevention,
signature checks, transfer and revocation.
No CI test writes to the real hhk-staging or production database.

## Deployment gate

- Repository root now has an npm workspace manifest pointing **only** to backend-prisma. This helps Prisma Console detect the package manager without converting Flutter to Node. Deploy the backend-prisma workspace explicitly through Prisma 8 Composer and an authenticated staging-only environment. Never deploy the Flutter app as a Node server.
- Prisma Compute app creation/artifact upload is not available via the
  current Prisma plugin; no fake live endpoint is claimed.
- When runtime exists, configure secrets only on Prisma staging branch,
  test its health/endpoints, install rate limits, and review signed-lease
  lifecycle before issuing real QR tokens.
- main/production migrations and Flutter license gating require separate
  release gates and review. Never auto-link Git to deploy production.
