# HHK CAP-01 — ACCOUNT, QR VÀ LICENSE (CANONICAL)

Checkpoint 16/11/2026. Roadmap chính: GitHub Issue #1. Task quản lý tài khoản: #15. Trạng thái khác nhau giữa code đã chạy và tính năng chưa làm phải được giữ rõ ràng.

## Nghiệp vụ đã chốt
- Một tài khoản người dùng/phụ huynh có thể sở hữu nhiều key. Mỗi key chỉ có một chủ tài khoản.
- Một lốc 20 cuốn tập có một QR claim dùng một lần. QR được quét TRONG app sau khi đăng nhập, không cần website đổi QR riêng. Key mới chỉ hiển thị raw một lần.
- Backend quản lý tài khoản, phiên, QR, campaign, key, thiết bị và thu hồi. Hồ sơ học sinh, bài làm, XP, tiến độ ở local; không đồng bộ câu trả lời lên PostgreSQL.
- Key trong tài khoản chưa tự cấp quyền học: chỉ lease Ed25519 ký từ server, ràng thiết bị, lớp và thời hạn mới xác nhận quyền offline. Nội dung PWA static vẫn có thể tải trực tiếp.

## Đã triển khai và kiểm chứng
- Backend Hono: register, login, me, logout, keys, link key, redeem QR vào account, activate/verify license theo device proof.
- Mật khẩu được lưu dưới dạng scrypt hash với salt riêng; tối thiểu 12 ký tự. Sau 5 lần sai khóa login 15 phút. Session token ngẫu nhiên chỉ lưu hash ở server.
- Phiên đăng nhập không tự hết hạn theo ngày (database expires_at để NULL), có thể thu hồi khi user đăng xuất hoặc cần bảo vệ tài khoản.
- Flutter: login/register Dopi trước khi vào app, secure storage khôi phục phiên qua API, avatar tài khoản góc phải, danh sách key/QR.
- Database staging chạy migration 0001/0002/0003; backend API account đã chạy E2E thực tế. PWA đã được phát hành tại https://hhk-cap01-pwa.vercel.app/ để thử UI, nhưng kết nối backend/database STAGING.
- Source 96fab7b9; CI https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43792138192 xanh 5/5.

## Còn thiếu: ĐỔI PASS / QUÊN PASS (Issue #15, P0)
Hiện chưa có API hoặc nút đổi mật khẩu, quên mật khẩu, xác minh email, xem/thu hồi phiên từng thiết bị.

**Đổi mật khẩu khi đăng nhập**
1. Avatar góc phải -> Tài khoản & bảo mật -> Đổi mật khẩu -> nhập mật khẩu hiện tại, mật khẩu mới, nhập lại.
2. Backend xác thực phiên và mật khẩu cũ, kiểm tra mật khẩu mới, tạo hash/salt mới, cập nhật transaction.
3. Thu hồi mọi phiên máy khác. Phiên máy đang dùng được cấp token mới và lưu an toàn để KHÔNG tự nhảy về màn login khi đổi thành công.
4. Không tác động chủ sở hữu key, QR đã đổi hoặc dữ liệu học tập local. Test mật khẩu sai, xung đột, phiên cũ, nhiều thiết bị.

**Quên mật khẩu khi chưa đăng nhập**
1. Màn Dopi có Quên mật khẩu? -> người dùng nhập email đã chứng minh quyền sở hữu.
2. Backend gửi link reset HTTPS một lần, hạn ngắn 15–30 phút; DB chỉ giữ hash của token, trả câu trả lời chung cho email có/không tồn tại.
3. Tại link xác minh token, người dùng đặt mật khẩu mới. Reset thành công thu hồi tất cả phiên cũ; người dùng đăng nhập lại. Không gửi mật khẩu qua email.
4. Phải bổ sung xác minh email khi đăng ký, gửi mail có rate-limit, chống replay/brute-force và kiểm thử recovery. Không được coi email tự khai hiện tại là đã verify.

**Quản lý phiên**
- Thêm màn xem các phiên thiết bị, đăng xuất máy khác, đăng xuất tất cả.
- Phiên chỉ kết thúc khi người dùng yêu cầu hoặc có lý do an ninh (server revoke/reset) hay browser xóa storage; không chủ động timeout hàng ngày. Safari có thể tự dọn dữ liệu nên không cam kết đăng nhập vĩnh viễn trên PWA.
- Đổi/reset mật khẩu không tự gỡ key khỏi tài khoản; offline lease đã phát có vòng đời riêng và không thể bị hủy tức thì khi máy mất mạng.

## Phải làm trước GA
- Xóa nội dung mô tả cũ trong màn AccountPage rằng phiên chỉ ở RAM; sửa UI đúng thực tế secure storage.
- Khóa luồng QR legacy anonymous trước bán thật, E2E quét camera iPhone/Android, renew/expire/revoke/transfer.
- Xác minh email, recover pass, chống abuse theo nhiều thiết bị/IP, bảo vệ dữ liệu; test restore/rollback staging, device QA và audit nội dung.
- Nghiệp vụ/thời hạn chương trình quà tặng chưa được quyết định thương mại; không suy đoán.

Roadmap kỹ thuật: docs/EXECUTION_TRACKER.md. Chi tiết task: https://github.com/gustavjung02-tech/hhk-cap01/issues/15

---
## Issue #15 implemented SOURCE contract — 16/11/2026, NOT YET LIVE
- Change password: POST /api/v1/account/password/change with Bearer, currentPassword and newPassword, 12+ chars and at most 256 UTF-8 bytes; checks old scrypt hash, generates fresh 16-byte salt / 64-byte hash, revokes other sessions and rotates current token. Flutter secure vault saves rotated credential before returning from screen.
- Verified email: POST /api/v1/accounts/email/verification/request then /api/v1/accounts/email/verify with single-use 20-minute act_ token; POST /api/v1/accounts/password/forgot gives neutral response regardless of existence or verification; /api/v1/accounts/password/reset requires verified owner, revokes every bearer session on success and consumes token. All action token storage uses SHA-256 digests, never raw tokens or passwords.
- Session list GET /api/v1/account/sessions; revoke another device POST /api/v1/account/sessions/revoke; POST /api/v1/account/logout-all revokes current and others. Login stores device label and last-used; separate email change request/confirm via verified new address.
- Additive database migration 0004_account_security.sql awaits recoverable backup and green CI; ledger remains 0001/0002/0003 on hhk-staging. Resend sending domain fbmn.vn verified, but backend-only RESEND_API_KEY and HHK_MAIL_FROM and HHK_PUBLIC_APP_URL must be configured. Test PWA and backend staging still run pre-#15 builds. No production DB migration or main modification.
