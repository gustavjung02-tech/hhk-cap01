## RELEASE CẬP NHẬT — QR/key/device (17/11/2026) — trạng thái mới nhất

- Quyết định: QR token và quyền học không phụ thuộc quy cách/số lượng sản phẩm. Admin tạo `quantityTokens` mã theo campaign policy; mỗi token cấp tối đa một key thuộc một tài khoản. Những mô tả trước đây về quy cách đóng gói chỉ là lịch sử, không còn là yêu cầu phần mềm.
- Source `da4a43baa2a705832de0f00aee03cccbe8483981`, CI **5/5 PASS** [43989404146](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43989404146). Flutter Web và Android debug build, PostgreSQL integration, IndexedDB, content và packaged PWA đều PASS.
- Database **hhk-staging**: migration `0005_generic_claim_batches.sql` áp dụng sau backup + restore + migration rehearsal thành công. Ledger 0001–0005. Bảng `claim_batches` với `token_count`, cột cũ bị bỏ; dữ liệu 2 accounts/3 sessions/1 license/1 claim/1 batch giữ nguyên. **Production database và `main` không đụng tới**.
- Backend staging mới `dpl_AFQWYWLKeFeUyihgg9kh3QsfydvQ` READY. Health 200; public signing key 200; các endpoint legacy không xác thực bị chặn 401; API chuyển quyền máy cũng yêu cầu session.
- PWA **production** [hhk-cap01-pwa.vercel.app](https://hhk-cap01-pwa.vercel.app) `dpl_Huj7oT9q8kzUsQqZShKMQqKdVxcY` READY. Index, Flutter JS, manifest, SW, Dopi, hero ảnh 200; SW `8ced2e0a43e1ac351434`. Bản PWA rollback: `dpl_2mqpUzo7Eof1RLWEPFbC9GwzE8FG`.
- Flutter account/key: nhận mã trong app, gắn key, kích hoạt offline, gia hạn lease và đổi thiết bị bằng chữ ký Ed25519; per-key trạng thái lease dựa trên secure storage; các trường hợp lỗi có thông báo.
- **Còn OPEN**: test admin phát hành/claim QR **trên live staging** (bị chặn bởi an toàn kết nối quản trị), camera QR trên điện thoại thật, Safari iPhone/Android APK, lease expiration/storage eviction và email/session E2E (#8/#7/#9/#10/#15). CI disposable PostgreSQL có test redeem một lần, 32 yêu cầu đồng thời, chủ sở hữu, quota và transfer thành công; không thay thế test máy thật.
- Backup và rollback chi tiết: [`docs/QR_TOKEN_RELEASE_20261117.md`](./QR_TOKEN_RELEASE_20261117.md). Không phát hành dữ liệu sản xuất; URL PWA production vẫn dùng backend/DB **staging**.

---
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
