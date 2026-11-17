# HHK — QR/key/device staging release record (17/11/2026)

## Source and targets
- Git source: `staging@da4a43baa2a705832de0f00aee03cccbe8483981`.
- CI: https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43989404146 — 5/5 success.
- Production **frontend only**: https://hhk-cap01-pwa.vercel.app — Vercel `dpl_Huj7oT9q8kzUsQqZShKMQqKdVxcY`, READY. Revert target: `dpl_2mqpUzo7Eof1RLWEPFbC9GwzE8FG`.
- API **staging**: `dpl_AFQWYWLKeFeUyihgg9kh3QsfydvQ`, READY, staging Prisma `db_l4ds0m8jnxux66bd3erlnvqe`. No merge to `main` or production DB migration.

## Removed product assumptions
- QR is an opaque single-use claim token. The administrator specifies `quantityTokens` and separate campaign rights (`grades`, `maxDevices`, `validDays`). No physical products or quantities are modeled.
- Previous schema migrations are immutable history. Staging migration 0005 renames table `print_batches` to `claim_batches`, column `quantity_packs` to `token_count`, deletes the obsolete business column and adds new license source `qr_claim`. Legacy license rows remain intact for audit.
- The account-scoped claim API binds the new license to the authenticated user atomically. Legacy raw-key claim/activate/verify endpoints require admin token. No separate QR landing page.

## Verified off-database backup and restore BEFORE 0005
- Vercel Sandbox Drive `hhk-staging-db-backups` (iad1), persisted archive `/backups/hhk-staging-pre0005-20261117.dump` — PostgreSQL custom `pg_dump -Fc --no-owner --no-acl`, **41,403 bytes**. Companion `.sha256`, `.list`, `.restore-list` files retained.
- `sha256sum -c` verified. Isolated PostgreSQL 18 restore `hhk_pre0005_restore` succeeded using filtered list. The platform-managed `prisma_postgres` extension has no equivalent in standalone PostgreSQL and is excluded **only in the generic restore rehearsal**.
- Restored counts: 2 accounts, 3 sessions, 1 license, 1 QR claim, 1 issuance batch; ledger 0001–0004. On independent restored DB, applying the exact repo 0005 succeeded and yielded ledger 0001–0005, no obsolete column, same row counts.
- Actual staging migration 0005 then applied transactionally via Prisma. Live SQL confirmed ledger 0001–0005, `claim_batches.token_count`, zero obsolete columns and unchanged counts.

## HTTP and CI evidence
- Backend live smoke: `/api/v1/health` 200 ready; `/api/v1/public-key` 200 Ed25519; unauthorized legacy claim/activate 401; unauthorized account transfer 401.
- Production PWA smoke: `/`, `/main.dart.js`, `/manifest.json`, `/hhk-sw.js`, Dopi PNG and hero JPG all 200; service worker version `8ced2e0a43e1ac351434`.
- CI PostgreSQL tested 32 concurrent claims (one winner), account owner isolation, one active device limit, signed device transfer and verification of new/old device. Flutter analyze/widget and Android debug compile passed.
- Live admin issuance/redeem workflow was **not** executed because the connector security boundary blocked passing an administrative credential into the external test runner. Do not claim live end-to-end ownership/transfer or device manual QA passed.

## Rollback / follow-up
- Keep the staging DB backup. Restoring it over a running DB would erase later data: do it only after explicit incident authorization and preservation of post-backup writes.
- Backend revert alone is risky because the previous implementation uses old table names. Prefer a forward fix against 0005 or a coordinated backup restore in a fresh environment. No production DB touches.
- Frontend can be rolled back to `dpl_2mqpUzo7Eof1RLWEPFbC9GwzE8FG` if UI regression is found.
- Open requirements: actual iPhone Safari/Android camera permissions, one-use printed QR and duplicated token, offline signed lease after restart/expiry/transfer, account recovery session QA; Issues #8/#7/#9/#10/#15 remain open.
