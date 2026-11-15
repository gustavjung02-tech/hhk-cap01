# HHK tài khoản & quản lý key trong app — staging-first (Issue #2/#8/#9)

## Nghiệp vụ đã chốt theo yêu cầu mới (15/11/2026)

1. Người dùng/phụ huynh có **tài khoản online** (email + mật khẩu). Hồ sơ học sinh, bài làm, XP và nội dung offline tiếp tục lưu **trên thiết bị**, không chuyển sang PostgreSQL.
2. Trong tab **Tài khoản** của Flutter: đăng ký, đăng nhập, xem danh sách key, quét QR trực tiếp bằng camera Android/iOS/Web, hoặc dán QR URL/mã để đổi **một lần** vào chính tài khoản đã đăng nhập.
3. Key cũ đã nhận trước đó có thể nhập để liên kết tài khoản. Server lưu SHA-256 của key, **không có khả năng khôi phục và trả lại raw key** trong danh sách. Key mới chỉ hiển thị một lần ở màn hình đổi QR.
4. Một key thuộc tối đa một tài khoản; danh sách key chỉ được trả về với session hợp lệ thuộc chủ sở hữu. Mỗi QR đổi một lần bằng DB transaction và unique constraints.
5. Key được quản lý online, nhưng **chỉ sự hiện diện của key trong tài khoản KHÔNG cấp quyền học offline**. Quyền offline phải do Ed25519 lease ký từ backend, khóa vào device key và kiểm tra chữ ký, expiry và lớp học trong Flutter. Không cho phép client tự set `premium=true`.

## API mới / phân quyền

- `POST /api/v1/accounts/register`: email và mật khẩu tối thiểu 12 ký tự, scrypt + per-account random salt.
- `POST /api/v1/accounts/login`: session ngẫu nhiên, chỉ giữ SHA-256 ở DB, hết hạn sau 30 ngày; khóa tài khoản 15 phút sau 5 mật khẩu sai liên tiếp. Không lưu plain password.
- `GET /api/v1/account/me`, `POST /api/v1/account/logout`, `GET /api/v1/account/keys`: yêu cầu bearer session; list keys không chứa raw license key.
- `POST /api/v1/account/claims/redeem`: lấy QR dưới tài khoản đã đăng nhập, phát license gắn account atomically; replay 409.
- `POST /api/v1/account/keys/link`: gắn key chưa có owner vào account, idempotent nếu cùng owner, ngăn chiếm key đã gắn account khác.
- API QR legacy anonymous vẫn tồn tại trong backend để bảo toàn tính tương thích; **chưa được dùng làm luồng chính của Flutter** và phải khóa/xóa trước public production rollout để tránh claim ngoài tài khoản.
- CORS server dùng `HHK_ALLOWED_ORIGINS` danh sách origin đầy đủ, phân cách dấu phẩy. Browser PWA từ origin chưa được allow sẽ không gọi được account API. Không mặc định `*`.

## Thay đổi schema

`db-prisma/migrations/0003_accounts.sql` tạo bảng `app_accounts`, `account_sessions`, thêm `licenses.account_id` và indexes. **Chưa chạy trên `hhk-staging`**, chỉ chạy test PostgreSQL disposable trong CI. Migration không xóa bảng cũ hoặc dữ liệu hiện tại. Sau CI xanh và duyệt kế hoạch backup mới áp dụng riêng staging; không động vào main.

## Trạng thái thực thi và cổng trước phát hành

- Code Flutter, backend, test đang trên `staging`; app staging build không đồng nghĩa backend schema đã có. Chưa deploy bản Flutter có account.
- Session Flutter tạm thời **chỉ giữ RAM**, không lưu token vào SQLite/IndexedDB, vì đó không phải kho thông tin xác thực an toàn; khởi động lại app phải đăng nhập. Cần nghiên cứu kho token bảo mật đa nền tảng và logout mọi thiết bị trước GA.
- Chưa có email verification, password reset, server-wide IP rate limit, CSRF/cookie flow, đồng ý chính sách và kiểm thử recovery; **không mở public signup/đưa production** trước các bước này.
- Chưa có device proof v2 theo account/lease offline trong Flutter; UI không đánh lừa người dùng là đã mở khóa gói học.
- QR Web camera cần quyền camera và kết nối HTTPS; mobile_scanner Web tải bộ giải mã lần đầu (không hoạt động hoàn toàn offline); người dùng vẫn có thể nhập mã bằng tay.
- Trước deploy: CI xanh với SHA mới → sao lưu staging → migration 0003 staging-only → cấu hình CORS đúng origin staging PWA → manual deploy backend của SHA mới → E2E register/login/redeem/link/key isolation/QR duplicate/expiry → kiểm thử UI Android/PWA và signed-lease offline → mới xét release.

## Còn phải làm trong task tiếp

1. Dứt luồng activate/verify bằng device Ed25519 **không cần raw license key**, dựa trên session tài khoản + license id, ký proof vào account/thiết bị, bảo toàn lease offline.
2. Bổ sung signed-lease verification Flutter Android/iOS/PWA và persistence private device key trong secure storage phù hợp từng nền tảng; test tamper/expiry/đổi máy/revoke.
3. Auth hardening: email verification, reset password, anti-abuse, lưu session bảo mật, audit privacy. Thay thế redeem anonymous để tất cả QR thuộc tài khoản.
4. QA trình quét camera thiết bị thật (Android+iPhone+Safari), hành vi khi offline, và khi QR đã dùng.
