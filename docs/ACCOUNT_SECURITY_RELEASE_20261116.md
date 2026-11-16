# Issue #15 — Staging backup, migration and release record
Date: 2026-11-16 UTC+7. **Staging only.** Backup and migration were authorized for `hhk-staging`. Production database and `main` were not modified.

## Git/CI/deployment provenance
- Source SHA: `d35589d9aa899ca6f1c8cec9af7042fd0dc75aea`, CI [43799028874](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43799028874) success 5/5.
- Applied exact repo `db-prisma/migrations/0004_account_security.sql` (blob SHA `4f817cad449a4cf9ad1bf1c99c7e61a86497be6e`) to Prisma staging DB `db_l4ds0m8jnxux66bd3erlnvqe`.
- Backend Vercel project `prj_F7zDPvMW9C8k8j2gw5Z8bSIfntPM`, staging deployment `dpl_GVt4esjyVUec7KSjFxsZZE4hgEhr`, READY.
- Health: 200 ready. Public key: `hhk-offline-license-v1` Ed25519. Unauthorized GET sessions: HTTP 401. Mail: verified Resend sender, controlled email delivered and received.

## Off-database backup and tested restore
- Stored in **persistent Vercel Sandbox Drive** `hhk-staging-db-backups`, storage region **iad1**; Prisma staging DB located in Singapore. This is an off-database copy, **not** Prisma automated backup or a full provider-independent export.
- Archive path when mounting drive at `/backups`: `/backups/hhk-staging-pre0004-20261116.dump` (PostgreSQL `pg_dump -Fc --no-owner --no-acl`, **33,334 bytes**). Companions: `.list`, `.restore-list` and `.sha256` files with corresponding basename. `sha256sum -c` returned OK.
- Restore rehearsal: PostgreSQL 18 fresh local DB `hhk_restore_probe2` inside isolated Vercel Sandbox `hhk-db-backup-20261116`. Command: `pg_restore --exit-on-error --no-owner --no-acl -L <restore-list> -d hhk_restore_probe2 <dump>`.
- Prisma platform-specific `prisma_postgres` extension was unavailable in ordinary PostgreSQL. The restore list excludes only its EXTENSION and COMMENT entries; the live Prisma database was untouched. **Restore succeeded** with 2 accounts, 3 account sessions, 1 license, 1 claim, migration ledger 0001,0002,0003.
- To recover in a new **Prisma** environment, use the complete custom archive; the managed extension will already be available if supported. For ordinary PostgreSQL use the filtered restore list; confirm installed extensions and constraints, then reapply migration 0004 only if needed. Do not restore over the existing live staging DB without explicit incident authorization: it would discard writes after the backup.

## Staging schema checks after 0004
```sql
SELECT version FROM hhk_schema_migrations ORDER BY version;
-- 0001, 0002, 0003, 0004
SELECT count(*) FROM app_accounts; -- 2 after QA cleanup
SELECT count(*) FROM account_sessions; -- 3 after QA cleanup
```
Tables `account_action_tokens`, `account_action_throttle`, `account_security_audit` exist; `app_accounts.email_verified_at` exists. License and claim counts still 1 each.

## Mail configuration and QA
- Resend verified sending and receiving domain: `fbmn.vn`.
- Vercel backend environment scoped to `preview`, branch `staging`: `RESEND_API_KEY` (restricted to send-only/domain), `HHK_MAIL_FROM`, `HHK_PUBLIC_APP_URL`; never commit raw secrets or expose them in frontend.
- Controlled QA account registered; verification request HTTP 200; Resend status **delivered** and inbound receipt confirmed. Forgot response for unverified and absent email: identical HTTP 200 `requested:true`, no reset email. QA account deleted afterwards; original account counts preserved.
- One-time email token consumption across connector boundaries was blocked by security handling, so live reset/replay/change-session integration is **not** marked done. Disposable PostgreSQL integration/Flutter tests cover those routes.
- Do not publish #15 Flutter PWA onto production-test alias before manual Safari iPhone and Android QA. The current public PWA test alias remains pre-#15.

## Rollback / follow-up
- Previous backend staging deployment: `dpl_E51phyPMRZSgWW6LA9VunrMEjGto`. Backend rollback alone must be checked for compatibility with additive 0004; do not drop 0004 in a hot incident.
- New backend staging deployment: `dpl_GVt4esjyVUec7KSjFxsZZE4hgEhr`.
- Previous public PWA test deployment: `dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE`, rollback fallback `dpl_GSobToSsy1tm4VkkKZskSA6nAQab`.
- Next exact gates: controlled live browser action-token/rotation/revoke E2E → manual iPhone Safari and Android device QA → manual release of tested PWA artifact to public test alias → HTTP/service-worker/offline regression → next Issue #8/#7/#9, then legacy #14.
