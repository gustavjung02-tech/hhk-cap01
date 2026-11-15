# BÀN GIAO HHK CAP-01 → CHAT MỚI

> **Checkpoint mới về tài khoản & offline lease:** Xem [ACCOUNT_LICENSE_WORKFLOW.md](./ACCOUNT_LICENSE_WORKFLOW.md). Đã có source đăng nhập, QR trong app, đăng ký key cho tài khoản và ký/xác minh lease Ed25519 gắn thiết bị. Chờ CI SHA mới và backup trước khi migration 0003 trên staging; chưa deploy PWA hoặc production. Các đoạn ghi 'không có tài khoản'/'chưa có DB' phía dưới chỉ là lịch sử.


> **Checkpoint cập nhật 15/11/2026 — #6:** Cơ sở dữ liệu `hhk-staging` hiện **READY**, đã chạy migrations 0001/0002; CI staging `11de041a` xanh. Prisma Compute bị chặn bởi `HostedStateBootstrapError` (existing unmanaged DB), không phải do thiếu database. Đã chọn backend Hono trên Vercel riêng, kết nối DB Prisma cũ; chỉ phát hành khi CI của commit mới xanh. Những dòng lịch sử phía dưới ghi "chưa có DB" là **đã lỗi thời**, không dùng làm trạng thái triển khai hiện hành. **Không thay đổi main/production.**

**Cập nhật:** 15/11/2026, UTC+7. **Nguồn sự thật về task:** [EPIC #1](https://github.com/gustavjung02-tech/hhk-cap01/issues/1) + [Issues #2–#11](https://github.com/gustavjung02-tech/hhk-cap01/issues).

## Thông tin cố định, không hỏi lại
- **Repo chính:** https://github.com/gustavjung02-tech/hhk-cap01 (chỉ chỉnh repo này).
- **Repo nguồn bất biến:** https://github.com/gustavjung01/cap-01 — KHÔNG chỉnh/xóa/force-push, chỉ dùng tham chiếu dữ liệu (locked commit `7ab83326db4ab3141e2d42aeefe2ea182f13452b`).
- **GitHub branches:** `main` production, `staging` để phát triển/test. Thao tác code mới trên `staging`; tạo PR vào main sau CI xanh.
- **Local Windows dự định:** `F:\1_A_Disk_D\fbmn\HHK-01`; agent không tự động truy cập ổ F, user clone/pull ở máy mình. Câu lệnh: `git fetch origin && git switch staging && git pull --ff-only origin staging`; xây APK tại `frontend-flutter/`.
- **Prisma workspace/project:** [gus-02](https://console.prisma.io/ph998iyve9m9q7pz3cc2q3mu/t5ke1mdd3u72vvhw1ogmm5vn); Prisma `main` (production), `staging` (preview). **Chưa có PostgreSQL database hoặc Prisma Compute app** ở lần kiểm tra này. Plugin create DB hiện tạo kèm project mới và không nhận projectId — **không dùng** để tránh tạo sai project. Thử triển khai DB đúng trong existing gus-02 bằng Console/CLI. **Không tự chạy migration production**.
- **PWA Vercel:** https://hhk-cap01-pwa.vercel.app; project `hhk-cap01-pwa` team `gustavjung02-techs-projects`, deployment gần nhất `dpl_Nv7oZ7uzEdVbHLAAnJQLEUxCgfEX` (READY, kiểm tra HTTP 200). Auto-deploy Git **đã chặn**, manual deploy bằng plugin từ artifact Flutter CI xanh.
- **Frontend:** Flutter/Dart 100%, UI/quiz cơ bản; SQLite Android/iOS, IndexedDB web, local StudyLedger. **Không React/Electron/Chat AI**.
- **Nghiệp vụ:** một lốc **20 cuốn tập** có một QR → website công ty để đổi token lấy key → nhập key trong Flutter. Giá trị/thời hạn quà tặng chưa chốt, config qua campaign. **Không bán vé quay thưởng**.
- **Local first:** học/chấm điểm/XP/tiến độ/hồ sơ đều ở máy, không sync mỗi câu. Server Prisma chỉ QR/key/license/device/audit, không phải database bài học/điểm.
- **Data import:** 9 môn, 1.247 bài, 4.988 thẻ, 19.043 câu nguồn; 17.443 câu đã ghép được lesson; **1.600 quarantine** (400 thiếu lesson, 1.200 lệch lớp) phải giữ ID và rà soát, KHÔNG xóa hay gán bừa. Audio R2 thực chưa được verify.
- **Backend:** `backend-prisma/` Node/Hono fail-closed HTTP 503 cho endpoint QR/license, `db-prisma/migrations/0001_license_only.sql` CHƯA chạy. Không tưởng tượng có key activation thật.
- **Source hiện tại:** GitHub `main` SHA tại thời điểm bàn giao `97c55303a2418673ecc6993f86434a3a01c40f3a`; CI Flutter/content/backend đã thành công cho code `00ab1c39c8da5eb3efebc384945dbe2e472d0a5c`; commit phát sinh sau đó phải kiểm lại CI.

## Task rõ ràng theo issue
| Issue | Trạng thái tại bàn giao | Bắt đầu |
|---|---|---|
| [#2 UI Flutter & hồ sơ](https://github.com/gustavjung02-tech/hhk-cap01/issues/2) | PARTIAL | Wave A |
| [#3 Offline local progress/XP](https://github.com/gustavjung02-tech/hhk-cap01/issues/3) | PARTIAL | **BẮT ĐẦU NGAY** |
| [#4 Chấm bài & audit 19.043 câu](https://github.com/gustavjung02-tech/hhk-cap01/issues/4) | PARTIAL | **BẮT ĐẦU NGAY** |
| [#5 R2 audio/ảnh offline](https://github.com/gustavjung02-tech/hhk-cap01/issues/5) | BLOCKED inventory | Wave A |
| [#6 DB Prisma staging/prod](https://github.com/gustavjung02-tech/hhk-cap01/issues/6) | BLOCKED Postgres | Infra song song |
| [#7 QR/license backend](https://github.com/gustavjung02-tech/hhk-cap01/issues/7) | BLOCKED #6 | Wave B |
| [#8 QR website công ty](https://github.com/gustavjung02-tech/hhk-cap01/issues/8) | NOT_STARTED | Wave B |
| [#9 Flutter signed offline license](https://github.com/gustavjung02-tech/hhk-cap01/issues/9) | BLOCKED #7 | Wave C |
| [#10 QA staging/Android/iPhone](https://github.com/gustavjung02-tech/hhk-cap01/issues/10) | NOT_STARTED | Wave C |
| [#11 APK ký/PWA release](https://github.com/gustavjung02-tech/hhk-cap01/issues/11) | PARTIAL | Wave D |

**Tiến độ:** 0/10 issue con hoàn thành nghiệm thu/đóng; 4 partial, 4 blocked, 2 not started. Baseline đã có nhưng đừng đổi thành "100% ứng dụng hoàn chỉnh". Chi tiết checklist trong mỗi issue.

## Việc chat mới NÊN làm trước, theo đúng trình tự
1. Mở #3 + #4, đọc source thật `frontend-flutter/lib/data/study_ledger.dart`, `local_store_*.dart`, `features/study/quiz_evaluator.dart`, `practice_page.dart`, `content/seed/v1/manifest.json`. Không đoán loại câu hỏi.
2. Chọn phần nhỏ có thể nghiệm thu ngay trong #3 hoặc #4, sửa tận gốc trên GitHub `staging`; bổ sung unit/widget/integration test phù hợp. Không làm kiểu chắp vá.
3. Chạy/kiểm tra GitHub CI bằng PR vào main, không merge nếu fail. Cập nhật checkbox issue + link commit/test, đóng issue khi thật sự đạt DoD.
4. Song song xử lý blocker #6 để tạo DB staging **trong gus-02**, validate migration ở staging. Không đụng Prisma `main` cho đến khi test và chủ dự án chấp thuận.
5. Nếu cần phát hành PWA: chỉ dùng plugin Vercel **sau CI xanh**, gói artifact đúng SHA, manual deploy; không bật Git integration/auto-deploy. APK Android dùng Flutter local hoặc CI, ký release riêng.

## Rủi ro cần giữ rõ
- PWA static JSON/asset đã public có thể tải thẳng, **ẩn UI sau key không bảo vệ bí mật nội dung**. Có threat model ở #9.
- Không coi Swift/iOS App Store là đã được phát hành: hiện chỉ Flutter Web PWA cho iPhone và Android debug build trong CI.
- Không nói đã có audio offline nếu chưa đối chiếu R2.
- Nguồn bài học chưa được QA sư phạm hoặc xác minh bộ sách; questionType phức tạp cần đánh giá riêng.
- Không lưu credentials/QR raw token/private signing key trong GitHub, Vercel hoặc client.

## Tiêu chuẩn báo cáo cuối mỗi lượt
Báo ngắn: (a) issue #; (b) commit/PR, nội dung sửa; (c) test + CI và kết quả; (d) deployment/migration nếu có, link; (e) blocker + task tiếp. Dừng ở test đỏ, không deploy/migrate production.

## Checkpoint đang thực thi (15/11/2026)
- Trên staging: commit `c55e5e9` — transactional study ledger schema v2; `2021eca` — profile UI + strict quiz guard.
- #3 chưa nghiệm thu đủ: còn kiểm thử SQLite thiết bị, Safari IndexedDB/reload và export/restore thực tế.
- #4 chưa nghiệm thu đủ: cần kiểm kê 100% questionType và rà soát 1.600 bản ghi quarantine.
- #6 chưa được mở khóa: Prisma plugin xác nhận workspace gus-02 có 0 database và 0 Compute app; không dùng API tạo DB vì tạo project mới.
- Không tự động deploy hay chạy migration production. CI của commit mới phải xác minh qua PR trước khi merge.
