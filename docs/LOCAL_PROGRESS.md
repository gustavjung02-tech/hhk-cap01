# HHK CAP-01 — Dữ liệu học tập cục bộ

## Hiện trạng (15/11/2026)

- Android/iOS: SQLite `hhk_cap01.db`, table `settings`, schema database version 2.
- Flutter Web/PWA: IndexedDB `hhk_cap01_v1`, object store `settings`, version 2. **Giữ tên DB v1 để bảo toàn dữ liệu cũ**.
- Dữ liệu schema logic `study:state:v2`: danh sách hồ sơ, hồ sơ hiện hành, kết quả theo `profileId:grade:lessonId`, XP tốt nhất, lịch sử rút gọn, danh sách attempt IDs để chống ghi trùng.
- `progress:v1:<grade>:<lessonId>` và `selected_grade` vẫn còn trong storage; khi khởi động v2 ứng dụng chuyển toàn bộ record hợp lệ vào profile mặc định trong một cập nhật nguyên tử **không xóa nguồn**.
- Không gọi endpoint backend cho câu trả lời, tiến độ hoặc XP.

## Trách nhiệm của thiết bị

Xóa dữ liệu ứng dụng, gỡ app không giữ dữ liệu hoặc xóa dữ liệu website có thể làm mất toàn bộ tiến độ. Safari/iOS có chính sách tự dọn IndexedDB khi bị giới hạn dung lượng hoặc ít tương tác, vì vậy **không bảo đảm giữ dữ liệu vĩnh viễn trên trình duyệt**.

## Export/restore — trạng thái và quy trình dự kiến

**Chưa có UI export/import trong bản hiện tại. Không hứa đã có chức năng sao lưu.** Quy trình sẽ triển khai ở Issue #3:
1. Export file JSON định dạng `hhk-local-backup-v1` chứa schema version, danh sách hồ sơ/tiến độ và checksum SHA-256, không chứa token/license hay khóa ký.
2. Cho người dùng lưu file vào nơi họ tự quản lý; cảnh báo file có thể chứa tên học sinh. Không tải lên server và không tự gửi qua email.
3. Khi restore, đọc và kiểm tra checksum, version, định dạng, giới hạn dung lượng và profile IDs; **không ghi đè** dữ liệu đang học nếu file lỗi. Yêu cầu xác nhận trước khi thay toàn bộ dữ liệu.
4. Thử nghiệm restore từ Android sang PWA và ngược lại; kiểm tra giữ nguyên XP, history và chống ghi trùng qua restart.

Tạm thời, không chỉnh sửa SQLite/IndexedDB thủ công hoặc sao chép file cơ sở dữ liệu khi app còn đang ghi; chờ chức năng backup đã kiểm thử.
