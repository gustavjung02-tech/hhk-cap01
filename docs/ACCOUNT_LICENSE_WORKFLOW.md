# HHK CAP-01 — Canonical account, QR and license workflow
2026-11-16. Task #15 account management source is deployed **to staging backend**; Flutter PWA test alias still has the old UI. Refer to [Issue #1](https://github.com/gustavjung02-tech/hhk-cap01/issues/1), [Issue #15](https://github.com/gustavjung02-tech/hhk-cap01/issues/15), and [tracker](./EXECUTION_TRACKER.md).

## Fixed business boundaries
- One user/parent account can own many keys. Each key has at most one owner.
- One printed pack of 20 notebooks has a QR claim usable exactly once. QR scan/redeem takes place inside Flutter after account login, not on a separate website; raw license key is displayed only when issued.
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
