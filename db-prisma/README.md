# Prisma Postgres — QR/License staging

Project: [gus-02](https://console.prisma.io/ph998iyve9m9q7pz3cc2q3mu/t5ke1mdd3u72vvhw1ogmm5vn), workspace `ph998iyve9m9q7pz3cc2q3mu`.

## Verified on 2026-11-15

- `main`: Prisma production branch; **no production migration was run**.
- `staging`: Prisma preview branch `br_jaj4yknwox2kog9397s25rnw`.
- `hhk-staging`: Prisma Postgres `db_l4ds0m8jnxux66bd3erlnvqe`, region `ap-southeast-1`, status **ready**, belongs to project `gus-02`.
- Before migration: 0 user tables under schema `public`.
- Applied exactly `db-prisma/migrations/0001_license_only.sql` to **hhk-staging only**. Live database introspection confirms 6 tables: `print_batches`, `reward_campaigns`, `claim_tokens`, `licenses`, `device_activations`, `license_audit`.
- Catalog checks confirm foreign-key, uniqueness, check constraints and expected indexes (32 constraints and 15 indexes total).
- Source migration is additive, wraps operations in a transaction, and does not create student, XP or AI chat records.

## Not yet complete

- Backend remains fail-closed and has no live Prisma Compute app. Root repo is a Flutter/Node monorepo, and Prisma Composer Git bootstrap currently reports **no package manager detected**. This message does **not** indicate a database failure. Future backend deployment must target `backend-prisma/` with a supported package/app build and implement authenticated transactional QR/license endpoints.
- Constraint enforcement was inspected in the catalog; real transaction/concurrency/e2e tests, service integration and rollback drills remain required.
- `main` needs its **own isolated database**, provisioning and migration only after staging tests and explicit production approval.
- Keep `DATABASE_URL` and other credentials in backend secrets, never commit them or display them in frontend. Rotate the database connection credential exposed in the Prisma Console screenshot before real usage.

Do not use Prisma's `create_prisma_postgres_database` tool for this project: its API creates a **new project** rather than attaching a database to existing `gus-02`.
