# HHK CAP-01 — ĐỐI CHIẾU TÍNH NĂNG APP CŨ VỚI FLUTTER

Checkpoint 16/11/2026. App gốc READ-ONLY: https://github.com/gustavjung01/cap-01 (src/routes/appRoutes.tsx và src/shared/components/Sidebar.tsx). Roadmap chính Issue #1, danh sách port Issue #14. Đây là kiểm kê, KHÔNG phải danh sách tính năng đã hoàn thành.

## Shell đã có trong bản PWA production URL cho user test
- Màn login/register Dopi + card trước khi vào app, session được lưu/khôi phục từ secure storage client; backend đăng nhập thật Prisma staging đã bật.
- Trên trái: hamburger mở menu theo bốn nhóm. Trên phải: icon account/quản lý key. Bottom bốn tab: Trang chủ, Môn học, Luyện tập, Cài đặt.
- Home hero ảnh nền landing-hero.jpg có overlay/CTA. Nội dung học, câu hỏi hỗ trợ chấm, hồ sơ, tiến độ, XP là local.
- Flutter CI 5/5 xanh ở commit 96fab7b9. Chưa xác nhận iPhone Safari real-device E2E, không gọi bản này GA.

## Chức năng cũ và trạng thái thực tế
| Nhóm | Chức năng | Trạng thái Flutter |
|---|---|---|
| Học tập | Bài học, môn học, giáo trình | PARTIAL: có danh sách nội dung và bài; nội dung/đáp án chưa kiểm định hết |
| Học tập | Luyện tập | PARTIAL: có bottom riêng, quiz có guard kiểu câu hỗ trợ, offline XP |
| Học tập | Ôn tập thông minh | PARTIAL: xem bài đến hạn từ StudyLedger local |
| Học tập | Phòng trí nhớ, sơ đồ tư duy | CHƯA PORT logic |
| Học tập | Trợ lý AI cũ | NGOÀI SCOPE Flutter, không dựng backdoor React/AI |
| Vui chơi | Thử thách hằng ngày, mini-game, vẽ/tô màu, thi đấu | CHƯA PORT logic; drawer hiển thị “Chưa chuyển” |
| Thành tích | Tiến bộ/phân tích | PARTIAL: thống kê dựa trên StudyLedger local |
| Thành tích | Huy hiệu, thành tựu, bảng xếp hạng, cửa hàng avatar | CHƯA PORT logic |
| Cài đặt | Hồ sơ học sinh | PARTIAL: chọn/thêm/chuyển nhiều hồ sơ local |
| Cài đặt | Phụ huynh | PARTIAL: XP theo hồ sơ; chức năng nâng cao chưa port |
| Cài đặt | Giọng đọc, audio offline R2, theme, dữ liệu, cập nhật offline | CHƯA PORT đủ; cần assets thật và QA |
| Account | Quét QR, quản lý key, activate license | PARTIAL: account + backend staging source chạy, camera/device E2E chưa |
| Account | Đổi pass, quên pass, email verify, phiên thiết bị | CHƯA CÓ; P0 Issue #15 |
| Admin/desktop | Billing, cửa hàng cũ, Windows updater | Không đưa vào menu học sinh. Quản trị/đơn hàng là phạm vi backend riêng |

## Thứ tự port để không làm “nút giả”
1. P0 #15 password recovery/account management và #10 real-device QA.
2. P0 #8/#7 QR/key/device E2E; #3/#4 tiến độ và chấm câu.
3. P1 #14 mini-games + daily challenge (logic thật từ app cũ), badge/achievement/avatar, vẽ/mind-map/memory, phụ huynh nâng cao.
4. P1 #5 audio/TTS assets R2 và offline player, export data, accessibility.
5. #11 phát hành APK có chữ ký và kiểm thử rollback.

Mỗi màn port phải có engine Dart hoặc logic local thực, unit/widget/E2E tương ứng, CI xanh exact SHA. Không được đánh dấu “đã chuyển” nếu chỉ có menu placeholder. 19.043 question IDs trong nguồn, 1.600 quarantined vẫn phải giữ và audit, không gán bài tùy tiện. Dữ liệu học tập trẻ em không được chuyển lên Prisma account.

Tài liệu canonical: [EXECUTION_TRACKER.md](./EXECUTION_TRACKER.md), [HHK_HANDOFF.md](./HHK_HANDOFF.md).
