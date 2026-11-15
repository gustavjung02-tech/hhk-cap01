# Prisma Postgres — schema QR/key

Prisma target: [gus-02](https://console.prisma.io/ph998iyve9m9q7pz3cc2q3mu/t5ke1mdd3u72vvhw1ogmm5vn)
- Workspace: `ph998iyve9m9q7pz3cc2q3mu`
- Project: `t5ke1mdd3u72vvhw1ogmm5vn`
- Branch: `main` (production).
- **Trạng thái kiểm tra 15/11/2026: chưa có database ở workspace/project này.**

Migration `migrations/0001_license_only.sql` là PostgreSQL thuần, CHƯA CHẠY trên môi trường production.
Sau khi database được tạo **bên trong đúng project**, cần chạy trên preview/branch trước, đối chiếu schema, rồi mới đề nghị phê duyệt migration production.
Không commit DATABASE_URL, token QR thô, license key hay signing private key. Flutter/PWA không nhận database credentials.
