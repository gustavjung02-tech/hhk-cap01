# HHK CAP-01 — kiểm kê chức năng app gốc → Flutter

**Nguồn được đọc trực tiếp:** repo `gustavjung01/cap-01`, branch `main`, tại `src/routes/appRoutes.tsx`, `src/shared/components/Sidebar.tsx`, `src/shared/components/AppAuthGate.tsx`, `src/modules/student/pages/HomePage.tsx` và `PracticePage.tsx`. App gốc chỉ để tham khảo, **không ghi/sửa**. Các mục thiếu bên dưới là **chưa chuyển**, không phải tính năng đã hoàn thành.

## Yêu cầu bố cục mới (16/11/2026)

- Trước khi mở app phải có **màn đăng ký/đăng nhập**. Background dùng hình hiện có `assets/brand/landing-hero.jpg` và Dopi `dopi-avatar.png`, card nhập email/mật khẩu. Đăng nhập qua API thật, không bypass local, không có chế độ "vào app mà không login".
- Sau login mới vào Flutter shell. **Tài khoản góc trên phải**, ba gạch trái trên mở Drawer. Bottom **Trang chủ / Môn học / Luyện tập / Cài đặt** với SafeArea iOS chuẩn (60dp content).
- Session bearer lưu riêng bằng `flutter_secure_storage` và thử khôi phục/đối chiếu server khi mở app; offline dùng lại phiên đã được xác thực để xem bài và tiến độ cục bộ, nhưng không cấp quyền trả phí nếu không có lease Ed25519 hợp lệ. Phiên **không tự hết hạn theo ngày**; chỉ đăng xuất chủ động hoặc khi server thu hồi / vô hiệu hóa vì bảo mật. Đăng xuất yêu cầu server xác nhận revoke trước khi xóa token cục bộ.
- Hero trang chủ có ảnh gốc `landing-hero.jpg` + gradient và CTA học; tránh chữ trên nền khó đọc.
- **Không** chuyển sang React, không sử dụng Clerk bridge / Web backend của app cũ làm backend thứ hai. Server account tiếp tục Hono/Prisma staging.

## Đối chiếu chức năng từ app gốc

| Nhóm trên Sidebar cũ | Chức năng gốc | Flutter sau commit thiết kế | Ưu tiên nghiệp vụ |
|---|---|---|---|
| Học tập | Bài học, Môn học, Giáo trình | Bài học + danh sách môn/giáo trình với dữ liệu đã nhập | P0: kiểm nội dung thực |
| Học tập | Quiz / Luyện tập | **Bottom Luyện tập** chọn bài và mở bộ câu hỏi có quy tắc chấm offline | P0: QA chấm nhiều dạng |
| Học tập | Ôn tập thông minh | Trang mới đọc `StudyLedger.dueForReview` theo hồ sơ/lớp, vào bài thật | P0: E2E |
| Học tập | Phòng trí nhớ, Mind-map | Có trong Drawer, **chưa chuyển nghiệp vụ** | P1 |
| Học tập | Trợ lý học tập AI | Có trong kiểm kê, **không triển khai AI/chat** vì giới hạn dự án | Ngoài scope |
| Vui chơi | Thử thách hằng ngày, Mini-Game, Vẽ & tô màu, Thi đấu | Trong Drawer, có trạng thái **Chưa chuyển**, không game giả | P1 |
| Thành tích | Tiến bộ, Phân tích | Trang mới đọc thống kê thực từ ledger; nhiều hồ sơ tách riêng | P0/P1 |
| Thành tích | Huy hiệu, Thành tựu, Bảng xếp hạng, Cửa hàng avatar | Trong Drawer, chưa chuyển; leaderboard cloud cần quyết định privacy | P1/P2 |
| Cài đặt | Hồ sơ học sinh | Drawer → chọn/chuyển/thêm hồ sơ local thực | P0 |
| Cài đặt | Phụ huynh | Trang mới hiển thị XP theo từng hồ sơ local; chưa đồng bộ cloud | P0/P1 |
| Cài đặt | Giọng đọc, Audio offline, Cập nhật PWA, Giao diện, Dữ liệu | Trong Drawer, chưa chuyển logic cũ | P1/P2 |
| Cài đặt | Gói dịch vụ / license | Góc phải trên → màn quản lý key/QR/kích hoạt đã có source | P0; cần backend migrate |
| Nội bộ | Admin, billing, desktop-only Windows updater | Không đưa vào menu học sinh; quản trị backend không phải student UI | Riêng |

## Các chỗ chưa thể coi là hoàn thiện

1. **Login chưa hoạt động online** trên backend staging trước migration `0003_accounts.sql` và deploy Hono auth mới. Bản PWA có auth gate sẽ yêu cầu login thật; nếu server chưa nâng cấp thì chưa vào được. Không phát hành production trong tình trạng đó.
2. Phiên persist dùng local encrypted vault native; trên Web cần kiểm thử plugin secure storage và Safari Private Browsing/storage eviction. Không thể cam kết giữ session sau khi người dùng xóa app/storage hoặc server chủ động revoke vì an toàn.
3. Audio, mini-game, daily challenge, huy hiệu, sơ đồ tư duy, trò chơi, đề luyện chưa được port; drawer hiển thị minh bạch, **không đánh dấu done**.
4. Bảo vệ nội dung static PWA: JSON nội dung công khai không thể khóa bằng ẩn UI; entitlement phải tách.
5. Core StudyLedger lưu local; tiến độ offline vẫn không gửi sang backend đăng nhập.
6. QA screenshot iPhone/Safari/PWA và Android, navbar, bàn phím, quét QR, data loss, phiên offline/online; CI xanh chưa bằng chứng test máy thật.

## Hướng thực thi

- **Wave UI/Auth:** CI Dart analyzer, widget tests: login required, restore, explicit logout; menu đúng nhóm, bottom 4 tab, hero load assets.
- **Wave Backend staging:** backup database hiện hữu, migration 0003, CORS staging origin, deploy commit CI xanh, live E2E register/login/restart/revoke/redeem.
- **Wave chức năng legacy:** lần lượt Mini-Game/Thử thách → thành tựu/huy hiệu → âm thanh/đọc → phụ huynh nâng cao; mỗi chức năng port engine gốc sang Dart, viết test riêng, không gọi server lưu điểm.
- **Go-live:** chỉ sau QA iPhone/Android thật và các gate privacy, license, storage.
