## QR/key/device contract correction — 17/11/2026
- Owner clarified: no physical-product quantities or packaging policies in HHK. QR codes are opaque one-use claim tokens; authorized admin creates a batch with an explicit `quantityTokens` count and campaign rights (grades, validDays, maxDevices).
- Database migration `0005_generic_claim_batches.sql` renames historic issuance batch table to `claim_batches`, changes count to `token_count`, drops obsolete business column, and supports new license source `qr_claim`; previously issued records/audit remain unchanged.
- Public legacy raw-key/QR endpoints become **admin-only**, while accounts use authenticated endpoints. Owner-scoped device inventory and new-device signed transfer, plus Flutter Activate/Renew/Change device actions, live in source.
- Migration must run **staging only after exact SHA 5/5 green CI and off-database restorable backup**. No changes to production Prisma DB or `main`. Production Flutter URL remains `https://hhk-cap01-pwa.vercel.app`; backend data remains staging.
- Issue #8/#7/#9 real-device QA remains open; signed leases can remain effective offline until expiry despite server revocation.

## Release update — 16/11/2026 23:27 UTC+7 (authoritative)

**User direction: deploy Flutter PWA directly to production URL; do not use preview deployments as the acceptance/test destination.** The Vercel PWA project is public-facing production, but the account/license API and Prisma DB intentionally remain **staging** for test data until separate production-backend authorization. This override replaces previous text below that held the PWA alias pending manual device QA; **device/browser QA is still open and must never be marked PASS without evidence.**

- Production app: https://hhk-cap01-pwa.vercel.app; Vercel deployment `dpl_ApjLHxf7RxZ3KDGmGNLBi9J5NU8B` READY, target `production`. Release artifact `hhk-flutter-web-pwa` from exact green SHA `ee864194ff4e6dab96ab0bc90eadd699ac1d2cc4`, [CI 5/5 green](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43847413897). SHA `d35589d9` through `ee864194` changed docs and CI only, not Flutter source.
- Production smoke: HTTP 200 index, `main.dart.js`, `manifest.json`, `hhk-sw.js` (no-store), Dopi avatar and hero image. Production alias resolved to `dpl_ApjLHxf7RxZ3KDGmGNLBi9J5NU8B` rather than old `dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE`.
- Backend **staging**: `dpl_9LYvrJwu9GWM6Ve6mjuXan33ECcf` READY from `ee864194`. Staging-only `HHK_PUBLIC_APP_URL=https://hhk-cap01-pwa.vercel.app`; CORS explicitly allows production host and removes the obsolete isolated preview host. Health HTTP 200 ready. Stage-only backup/migration 0004 remain as documented below.
- Production PWA deploy is approved by owner even though manual iPhone/Android and real email-link/session rotation E2E have not passed; keep [Issue #10](https://github.com/gustavjung02-tech/hhk-cap01/issues/10) and #15 open. No production Prisma DB migration and no `main` merge occurred.
- **Workflow from now on:** change source on `staging` → wait CI 5/5 green on exact source commit → build/retain Flutter Web CI artifact → manually deploy **production target** `hhk-cap01-pwa` → confirm `https://hhk-cap01-pwa.vercel.app` aliases correct deployment and smoke → record QA/defects and rollback. Do not present preview URL as the app link. Rollback PWA production deployment `dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE` if necessary.

---

# HHK CAP-01 — Canonical account, QR and license workflow
2026-11-16. Task #15 account management source is deployed **to staging backend**; Flutter PWA production alias now serves Issue #15 Flutter UI. Refer to [Issue #1](https://github.com/gustavjung02-tech/hhk-cap01/issues/1), [Issue #15](https://github.com/gustavjung02-tech/hhk-cap01/issues/15), and [tracker](./EXECUTION_TRACKER.md).

## Fixed business boundaries
- One user/parent account can own many keys. Each key has at most one owner.
- Each QR claim token may be redeemed **once** into an account-owned key; no product/package size or sales-rule assumption is encoded. Flutter scans/redeems only after account login. Raw license key is displayed only when issued.
- Backend retains only accounts, email proof, sessions, license/QR/campaign/registered device/audit. Student profiles, answers, progress, XP remain local SQLite/IndexedDB. Static PWA assets are not inherently confidential.
- Ed25519-signed, device-bound lease controls offline learning eligibility; issued leases can remain effective until expiry while a device is offline.

## Implemented live staging HTTP contract
| Route | Security semantics |
| --- | --- |
| POST /api/v1/accounts/register + /api/v1/accounts/login | scrypt 64-byte hash, random 16-byte salt, lockout after repeated bad logins, session bearer token hashed at rest |
| GET /api/v1/account/me | Valid bearer, current email/emailVerified |
| POST /api/v1/accounts/email/verification/request | Neutral response and limited delivery |
| POST /api/v1/accounts/email/verify | 20-minute, hashed, random single-use `act_` action token verifies current address |
| POST /api/v1/accounts/password/forgot | Neutral response for absent/unverified email; only verified owner gets HTTPS reset email |
| POST /api/v1/accounts/password/reset | Single-use reset token, hash/salt renewal and **revoke all sessions** |
| POST /api/v1/account/password/change | Bearer, currentPassword, newPassword: verifies old scrypt hash; fresh salt/hash and **rotate current session** while revoking every other session |
| GET /api/v1/account/sessions | Authenticated own sessions, device label, last-used, current marker |
| POST /api/v1/account/sessions/revoke | Revoke an owned **other** session; not the current session |
| POST /api/v1/account/logout-all | Revoke every session, client clears vault |
| POST /api/v1/account/email/change/request + POST /api/v1/accounts/email/change/confirm | Verify existing password and new email ownership before updating |
| Account key/QR/device lease routes | Ownership and signed lease logic remain from migration 0003 / previous CI |

Password ≥12 characters, ≤256 UTF-8 bytes. Recovery tokens are 256-bit random values; DB stores SHA-256 digests and 20-minute expiry. Security audit excludes passwords and raw tokens. Session token is persisted in Flutter secure vault and does not expire daily; logout/revoke/reset/storage eviction can end it. On change password Flutter must store rotated token before displaying success.

## Current release evidence and limitations
- Source SHA `d35589d9`, [5/5 CI](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43799028874). Backend staging deploy `dpl_2pM9i7fN4JEvYR1qMuvACh98pqJj` READY.
- hhk-staging migration 0004 applied transactionally; 0001–0004 present, 2 original accounts / 3 sessions / 1 license / 1 QR preserved. Provider-managed extension excluded **only from isolated generic PostgreSQL restore rehearsal**, not from live Prisma.
- Backup `hhk-staging-pre0004-20261116.dump` on separate Vercel Drive (iad1), SHA256 verified, restored to disposable PostgreSQL 18 with row counts matching.
- Resend domain `fbmn.vn` verified; sending-only key encrypted in preview `staging`, `HHK_MAIL_FROM` and `HHK_PUBLIC_APP_URL` set. Actual email verified as delivered **and received** in controlled test mailbox.
- Live verified-email token consumption/reset/rotation and physical iPhone/Android E2E are still pending. CI integration passed disposable-PostgreSQL expiry, replay, rotation, session scope tests. Backend HTTP health, key schema and authentication gate were checked live.
- Isolated PWA QA preview https://hhk-cap01-119on2jr8-gustavjung02-techs-projects.vercel.app READY from the exact CI Flutter artifact; static root/JS/manifest/SW/asset HTTP 200; backend staging `dpl_2pM9i7fN4JEvYR1qMuvACh98pqJj` allows exact origin via CORS (204). Stage-only `HHK_PUBLIC_APP_URL` now points to this preview for verification/reset links; live browser token flows not yet confirmed.
- PWA production test alias https://hhk-cap01-pwa.vercel.app deliberately remains pre-#15; do not promote before manual device QA. Do not touch `main` or Prisma production DB without explicit approval.

See [detailed backup and rollback runbook](./ACCOUNT_SECURITY_RELEASE_20261116.md).
