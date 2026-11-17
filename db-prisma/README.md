# Prisma Postgres — QR/License staging

Project: [gus-02](https://console.prisma.io/ph998iyve9m9q7pz3cc2q3mu/t5ke1mdd3u72vvhw1ogmm5vn), workspace `ph998iyve9m9q7pz3cc2q3mu`.

## Verified on 2026-11-15

- `main`: Prisma production branch; **no production migration was run**.
- `staging`: Prisma preview branch `br_jaj4yknwox2kog9397s25rnw`.
- `hhk-staging`: Prisma Postgres `db_l4ds0m8jnxux66bd3erlnvqe`, region `ap-southeast-1`, status **ready**, belongs to project `gus-02`.
- Before migration: 0 user tables under schema `public`.
- Lịch sử: migration `0001` từng tạo bảng `print_batches` cùng thông số kinh doanh không còn hợp lệ. Migration `0005_generic_claim_batches.sql` chuyển tên thành **`claim_batches`**, đổi số lượng thành `token_count` và bỏ cột quy cách; FK token được PostgreSQL giữ khi đổi tên.
- Catalog checks confirm foreign-key, uniqueness, check constraints and expected indexes (32 constraints and 15 indexes for 0001).
- Applied **0002_device_limit.sql** after [CI green](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43716503565) on staging only. Live queries confirm version ledger hhk_schema_migrations contains 0001/0002; triggers trg_hhk_device_limit and trg_hhk_license_limit exist on the intended tables.
- Staging has zero batches, QR tokens, licenses or device activations after the migrations.
- Both migrations are transactional and contain no student, XP or AI chat records.

## Not yet complete

- Backend QR/license endpoints are implemented in backend-prisma and exercised with disposable PostgreSQL 16 in CI, but no live Prisma Compute app exists. Root package.json now declares an npm workspace for backend-prisma, while Flutter continues to build independently. Prisma Compute still needs backend-targeted Composer deployment plus service/environment configuration; no production auto-deploy.
- Transaction, concurrency, bad-signature, device-quota, transfer and revoke tests passed on CI PostgreSQL. Deployed service E2E tests, rate limits, release rollback, and production isolation checks remain required.
- `main` needs its **own isolated database**, provisioning and migration only after staging tests and explicit production approval.
- Keep `DATABASE_URL` and other credentials in backend secrets, never commit them or display them in frontend. Rotate the database connection credential exposed in the Prisma Console screenshot before real usage.

Do not use Prisma's `create_prisma_postgres_database` tool for this project: its API creates a **new project** rather than attaching a database to existing `gus-02`.
