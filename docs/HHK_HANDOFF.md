# HHK CAP-01 — BÀN GIAO CHAT MỚI (16/11/2026)

ĐỌC TRƯỚC: [GitHub EPIC #1](https://github.com/gustavjung02-tech/hhk-cap01/issues/1), [EXECUTION_TRACKER.md](./EXECUTION_TRACKER.md), [ACCOUNT_LICENSE_WORKFLOW.md](./ACCOUNT_LICENSE_WORKFLOW.md), [LEGACY_APP_FEATURE_AUDIT.md](./LEGACY_APP_FEATURE_AUDIT.md). Các ghi chú issue con năm 2026 trước checkpoint này có thể là lịch sử, không thay thế trạng thái mới nhất.

## Context không hỏi lại
- Repo sửa DUY NHẤT: https://github.com/gustavjung02-tech/hhk-cap01. Branch làm việc: staging; HEAD baseline đã test: 96fab7b901b24181896f42366a2b8fae16b6b135. Main riêng (không merge tùy tiện).
- Repo app cũ gustavjung01/cap-01 chỉ dùng đối chiếu tính năng, KHÔNG sửa.
- Prisma workspace/project gus-02: https://console.prisma.io/ph998iyve9m9q7pz3cc2q3mu/t5ke1mdd3u72vvhw1ogmm5vn ; staging database hhk-staging ID db_l4ds0m8jnxux66bd3erlnvqe; schema 0001/0002/0003 đã apply. Snapshot 7 bảng trước 0003: schema hhk_pre_account_20261116 (cùng database, không thay offsite backup).
- PWA URL production ĐỂ TEST: https://hhk-cap01-pwa.vercel.app ; Vercel project hhk-cap01-pwa ID prj_DSfBxmprioI98nq6gWCEuaVADlrC; live deployment dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE, build f7fd9a6f74eade9c3c33.
- Backend cho app đang dùng là STAGING (không phải production DB): https://hhk-cap01-license-staging-gustavjung02-techs-projects.vercel.app ; Vercel project hhk-cap01-license-staging ID prj_F7zDPvMW9C8k8j2gw5Z8bSIfntPM; READY dpl_E51phyPMRZSgWW6LA9VunrMEjGto. API health / public-key / register / login / me / keys / logout và CORS đã kiểm chứng live.
- CI kiểm chứng bản PWA: https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43792138192 -> SUCCESS 5/5, đúng commit 96fab7b9.
- Local Windows user dự định F:\1_A_Disk_D\fbmn\HHK-01; agent làm trực tiếp qua GitHub/Vercel/Prisma plugin, không đòi user copy code thủ công.
- Bản cũ rollback PWA dpl_GSobToSsy1tm4VkkKZskSA6nAQab, chuyển alias hhk-cap01-pwa.vercel.app trở lại bằng Vercel nếu app mới lỗi nghiêm trọng.

## Nghiệp vụ/Bố cục đã chốt
- Flutter/Dart Android/iOS/Web; trước vào app bắt login/register trên màn có ảnh Dopi + card; phiên login lưu, không tự hết hạn theo ngày (ngoại lệ bảo mật).
- App shell: góc trái trên menu 3 gạch; góc phải trên icon account; bottom Trang chủ – Môn học – Luyện tập – Cài đặt; hero trang chủ là ảnh nền. Đã implement nhưng cần QA iPhone/Android thật.
- Một account phụ huynh quản lý nhiều key; một lốc 20 cuốn = một QR claim dùng một lần, QR quét trong app để gắn key vào account; không xây claim website riêng. Key cần signed offline Ed25519 lease ràng thiết bị.
- Bài học, hồ sơ học sinh, XP, chấm điểm và tiến độ chỉ local SQLite/IndexedDB, không gửi vào backend. 19.043 câu nguồn, 1.600 quarantine chưa audit xong. Audio R2 và nhiều tính năng gốc chưa port.

## Task tiếp theo theo kế hoạch chính
1. **P0 #15**: hoàn thiện cơ chế tài khoản. Avatar -> Tài khoản & bảo mật -> Đổi mật khẩu (current/new/confirm, scrypt + salt, revoke phiên khác và giữ phiên máy hiện tại bằng token rotation); màn Dopi -> Quên mật khẩu (verify email trước, link reset one-use, rate limit, reset thì revoke mọi phiên). Trang xem/revoke các phiên khác; sửa label lỗi “session chỉ lưu RAM”. Hiện các tính năng này CHƯA CÓ; phải làm backend, migration additive, Flutter UI và test, không làm menu giả.
2. **P0 #10/#2**: người dùng test production PWA trên iPhone Safari: login, auth restore, bàn phím, menu, bottom safearea, hero, thao tác cài app, lỗi thực; Android APK debug; ghi bằng chứng và sửa tận nguồn.
3. **P0 #8/#7/#9**: QR claim trong app -> key sở hữu tài khoản -> activate/renew signed device lease -> offline; test trùng QR, linked key, hết hạn, chuyển máy, revoked, concurrency; chặn legacy anonymous redeem trước thương mại.
4. **P0 #3/#4**: offline study local durability và chấm bài đúng loại câu; rà soát 1.600 quarantine.
5. **P1 #14/#5**: port tính năng gốc còn thiếu theo nhóm: thử thách, mini-game, vẽ, phòng trí nhớ, sơ đồ tư duy, huy hiệu, avatar, TTS/audio; không gắn nhãn đã xong nếu chỉ có drawer “Chưa chuyển”.
6. **#11/#6 gate**: QA máy thật, backup/restore ngoài DB, tách production DB, APK release ký, public release chỉ sau nghiệm thu.

## Quy trình BẮT BUỘC
Đọc source & issue đúng task -> code tận gốc trên staging -> test unit/widget/PostgreSQL -> CI xanh exact SHA -> backup trước migration nếu cần -> deploy staging -> E2E -> khi user đã cho phép thì manual production deploy -> kiểm tra HTTP/API/logs -> cập nhật tracker/issue/rollback. Không dùng patch tạm, không phá production đang test, không yêu cầu lại repo URL/quyền sẵn có.

## Prompt mở chat tiếp theo
Tiếp tục HHK CAP-01. Đọc GitHub Issue #1, #15, #9, #14 và docs/EXECUTION_TRACKER.md, docs/HHK_HANDOFF.md, docs/ACCOUNT_LICENSE_WORKFLOW.md trên staging. Baseline CI xanh commit 96fab7b9, PWA production URL dùng backend Prisma staging migration 0003. Thực hiện P0 #15: đổi mật khẩu, quên mật khẩu qua email xác minh, quản lý phiên máy, UI/account và regression tests; có migration additive và backup nếu cần. Giữ phiên máy đang dùng khi đổi pass, revoke các phiên khác; reset pass revoke mọi phiên. CI xanh rồi mới deploy; cập nhật Issue #1/#15 và bàn giao ngắn. Không hỏi lại thông tin đã có.
