# Trạng thái HHK — 15/11/2026

**Repo chính:** https://github.com/gustavjung02-tech/hhk-cap01
**Repo nguồn:** https://github.com/gustavjung01/cap-01 — giữ nguyên.

## Có thật
- Flutter/Dart: chọn lớp 1–5, xem bài học, trắc nghiệm; SQLite Android/iOS và IndexedDB Web lưu lớp đã chọn và kết quả/XP tốt nhất theo bài học. Đã sửa chấm Đúng/Sai source true/false; vẫn chưa có hồ sơ học sinh đầy đủ.
- JSON nguồn: 9 môn, 1.247 bài, 4.988 thẻ, 19.043 ID câu hỏi; 1.600 câu hỏi cách ly cần duyệt.
- PWA đã deploy thủ công lên Vercel: https://hhk-cap01-pwa.vercel.app từ CI artifact được xác minh SHA256.
- Vercel Git integration không kết nối và cấu hình source `git.deploymentEnabled=false`. Không có workflow auto-deploy.
- Database schema QR/key được giữ ở `db-prisma/` để triển khai vào project Prisma hiện hữu khi có DB.

## Chưa có thật — KHÔNG tuyên bố đã hoạt động
- Project Prisma `gus-02` hiện chưa có Prisma Postgres database hoặc Prisma Compute app.
- Backend `backend-prisma/` chỉ là server fail-closed và hợp đồng API; chưa có DB, không được phép cấp key thật.
- Kết nối giấy phép với Flutter chưa hoàn tất; các bài offline/tiến độ và chống gian lận đang ở mức MVP.
- Kiểm thử iPhone Safari cài ra màn hình, offline trên thiết bị thật, kiểm kê audio R2 chưa hoàn tất.
- Chưa xuất Android APK thương mại/iOS IPA; chưa xác thực chính sách QR/key với kho ứng dụng.

## Thứ tự bắt buộc
1. Provision Postgres **trong project Prisma được chỉ định** và xác định hướng Compute, không tạo project khác tùy tiện.
2. Áp dụng migration sau khi có DB, viết/kiểm thử token QR và license ký số trên server.
3. Hoàn thiện local-only Flutter (hồ sơ, tiến độ, XP, âm thanh, bộ dữ liệu) và kiểm thử offline thật.
4. Phát hành lại PWA **thủ công** từ CI artifact xanh; không có auto-deploy.
