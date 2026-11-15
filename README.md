# HHK CAP-01 — Flutter native, học offline, tặng kèm lốc tập

**Repo chính:** https://github.com/gustavjung02-tech/hhk-cap01  
**Repo cũ chỉ đọc:** https://github.com/gustavjung01/cap-01 — không sửa, không xóa.

Ứng dụng học tập tiểu học lớp 1–5. **100% giao diện Flutter/Dart** cho Android/iOS, có thể xuất Flutter Web. Dữ liệu bài học, câu hỏi, ảnh và catalog âm thanh được bảo toàn từ repo cũ, chuẩn hóa thành JSON. Toàn bộ UI React/Electron/Express/AI cũ không được mang sang.

## Kiến trúc đã chốt

- **Flutter/Dart trên thiết bị:** xem bài học, làm câu hỏi, chấm bài, XP, huy hiệu, nhiều hồ sơ, lưu tiến độ offline. SQLite trên Android/iOS; IndexedDB trên Web.
- **Prisma backend + Prisma Postgres:** tối thiểu để đổi QR và kích hoạt / thu hồi key, không lưu mọi lần làm bài; không Chat AI.
- **Cloudflare R2:** ảnh/âm thanh và content pack nếu cần cập nhật sau.
- **Quà tặng:** 1 lốc **20 cuốn tập** có 1 mã nhận quà/QR. Khách quét vào website công ty lấy key, rồi kích hoạt trong app. Hình thức quà/thời hạn/ngẫu nhiên chưa chốt; không hardcode.
- **Sao lưu tiến độ:** tính năng tùy chọn trong giai đoạn sau; ứng dụng học được khi không có mạng.

## Cấu trúc

- `frontend-flutter/` — Flutter UI và nghiệp vụ học offline.
- `content/` — dữ liệu giáo trình, ID gốc, asset manifests có checksum.
- `backend-prisma/` — Node/Hono, lớp API giấy phép hướng về Prisma project hiện có; endpoint write chưa triển khai phải fail-closed.
- `db-prisma/` — PostgreSQL migrations QR, campaign, key, device (chưa áp dụng khi chưa có database Prisma).
- `tooling/` — script xuất nguồn JSON/audit và kiểm tra repo sạch.
- `docs/` — quyết định nghiệp vụ, plan, kiểm kê và phạm vi chưa hoàn thành.

## Nhập dữ liệu nguồn

Workflow `Import pinned legacy content` chạy tự động khi được bật: checkout `gustavjung01/cap-01` ở commit cố định, xuất **JSON, không copy code TSX/React**, copy riêng assets có ích. Đối chiếu `content/seed/v1/manifest.json` và chạy `node tooling/validate-export.mjs`.

**Trạng thái:** PWA Flutter Web bản kiểm thử đã được deploy thủ công tại https://hhk-cap01-pwa.vercel.app. Prisma project hiện chưa có Postgres hoặc Compute app; QR/key chưa hoạt động. APK thương mại chưa phát hành. Xem `docs/MIGRATION_PLAN.md`.
