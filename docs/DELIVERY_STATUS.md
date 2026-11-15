# Trạng thái giao hàng – không đánh đồng scaffold với bản hoàn thành

Repo đích: `gustavjung02-tech/hhk-cap01`.
Nguồn `gustavjung01/cap-01` **không bị chỉnh sửa**.

## Có trong repo
- Flutter UI cho chọn lớp, môn học, đọc thẻ bài, làm bài trắc nghiệm và lựa chọn đáp án, giao diện quản lý nội dung chưa có dữ liệu thật.
- Flutter layer SQLite trên Android/iOS, IndexedDB trên web.
- Neon migration QR theo lốc 20 cuốn, campaigns/key/thiết bị.
- Workers API fail-closed đối với activation; chưa phát hành key thật.
- Import và validate curriculum cần chạy GitHub Actions trên pinned source để tạo JSON thật.

## Chưa đạt
- Không có đủ dữ liệu cho Flutter cho đến khi job import commit thành công; không có build artifact thực tế khi CI chưa xanh.
- Chưa có signed offline license, tem QR bí mật, trang web công ty, quyền quản trị hay xác minh gacha.
- Chưa QA toàn bộ câu hỏi/đáp án; hình ảnh âm thanh R2 chưa được kiểm thử thực tế.
- Không triển khai production Neon/Cloudflare hoặc phát hành APK khi chưa được kiểm định.
