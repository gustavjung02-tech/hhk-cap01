## P1-A2 — 4 mini-game còn thiếu (17/11/2026)
- Theo đúng legacy pinned `gustavjung01/cap-01@7ab83326`: `MatchGamePage`, `WordScramblePage`, `SpeedQuizPage`, `FillBlankPage`. Flutter mới không phụ thuộc React/backend.
- `FunQuestionEngine.selectTypes` dùng chung bộ `QuizEvaluator.canGrade`. Ghép Cặp chỉ nhận `single_choice` có câu/đáp án ngắn và duy nhất; Xếp Chữ dùng từ đúng một từ, có đáp án trong options, tách chữ Unicode; Tốc Độ chỉ dùng trắc nghiệm đơn có đáp án kiểm chứng và giới hạn 8 giây; Điền Từ chỉ dùng `fill_number`/trắc nghiệm có thể chấm chắc chắn, từ chối `fill_text` mơ hồ.
- Vào `Menu 3 gạch → Mini-Game`; hub kiểm tra lại lease ký số ngay lúc mở game, kể cả khi menu đã mở từ lâu. Điểm và kỷ lục local cách ly theo hồ sơ/lớp/chế độ; không cộng XP bài học giả. Không thay backend, QR, Prisma hay `main`.
- Flutter tests: lọc dữ liệu không hợp lệ, chống gán đáp án thiếu kiểm chứng, deterministic word/match, tương tác lật thẻ, xếp chữ, hết giờ, điền số, lưu best score và quyền học khi hết hạn. **Thiết bị vật lý iPhone/Android vẫn cần QA**, không coi CI là bằng chứng.
- Hợp đồng release: `staging` → exact SHA CI 5/5 xanh → artifact Flutter Web kiểm tra SHA-256 → deploy **PWA production** `https://hhk-cap01-pwa.vercel.app` → smoke 6 asset → cập nhật Issue #14/#1. CI và deployment sẽ được ghi riêng sau khi có kết quả.

## Kế hoạch release tiếp theo (17/11/2026)
- Phát hiện và sửa lỗi **không dùng lease kiểm tra quyền học trong màn hình**: bổ sung `LearningEntitlementGate`, fail-closed khi key chưa kích hoạt/lease hết hạn/lỗi đọc secure storage, chặn toàn bộ màn nội dung và kiểm tra lại khi điều hướng sâu. Trên màn khóa vẫn đổi lớp/hồ sơ và mở quản lý key.
- P1-A source: `DailyChallenge`, `TrueFalseBlitz`, `QuickMathRush` port sang Dart/Flutter từ pinned legacy commit `7ab83326`, chỉ dùng nội dung/thuật toán offline; điểm riêng không giả làm XP của `StudyLedger`.
- 5 câu hằng ngày chọn deterministic theo ngày local + lớp + hồ sơ, lọc `QuizEvaluator.canGrade`; kết quả idempotent một lần/ngày, lưu offline theo hồ sơ. Mini-game có điểm cao nhất và lượt chơi lưu riêng theo hồ sơ và lớp.
- Vẫn **còn P0 QA chưa đạt**: email link live, account multi-device thực, camera QR, license hết hạn, iPhone Safari/Android real device. Không đổi trạng thái Issue #10/#15 thành PASS nếu không có chứng cứ.
- Release gate: staging exact-SHA CI 5/5 green rồi deploy Flutter artifact `production` chính; backend/Prisma staging giữ nguyên, không thay `main`/DB sản xuất. Trạng thái bản code ở commit sẽ được ghi sau khi CI xác nhận.

## RELEASE CẬP NHẬT — QR/key/device (17/11/2026) — trạng thái mới nhất

- Quyết định: QR token và quyền học không phụ thuộc quy cách/số lượng sản phẩm. Admin tạo `quantityTokens` mã theo campaign policy; mỗi token cấp tối đa một key thuộc một tài khoản. Những mô tả trước đây về quy cách đóng gói chỉ là lịch sử, không còn là yêu cầu phần mềm.
- Source `da4a43baa2a705832de0f00aee03cccbe8483981`, CI **5/5 PASS** [43989404146](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43989404146). Flutter Web và Android debug build, PostgreSQL integration, IndexedDB, content và packaged PWA đều PASS.
- Database **hhk-staging**: migration `0005_generic_claim_batches.sql` áp dụng sau backup + restore + migration rehearsal thành công. Ledger 0001–0005. Bảng `claim_batches` với `token_count`, cột cũ bị bỏ; dữ liệu 2 accounts/3 sessions/1 license/1 claim/1 batch giữ nguyên. **Production database và `main` không đụng tới**.
- Backend staging mới `dpl_AFQWYWLKeFeUyihgg9kh3QsfydvQ` READY. Health 200; public signing key 200; các endpoint legacy không xác thực bị chặn 401; API chuyển quyền máy cũng yêu cầu session.
- PWA **production** [hhk-cap01-pwa.vercel.app](https://hhk-cap01-pwa.vercel.app) `dpl_Huj7oT9q8kzUsQqZShKMQqKdVxcY` READY. Index, Flutter JS, manifest, SW, Dopi, hero ảnh 200; SW `8ced2e0a43e1ac351434`. Bản PWA rollback: `dpl_2mqpUzo7Eof1RLWEPFbC9GwzE8FG`.
- Flutter account/key: nhận mã trong app, gắn key, kích hoạt offline, gia hạn lease và đổi thiết bị bằng chữ ký Ed25519; per-key trạng thái lease dựa trên secure storage; các trường hợp lỗi có thông báo.
- **Còn OPEN**: test admin phát hành/claim QR **trên live staging** (bị chặn bởi an toàn kết nối quản trị), camera QR trên điện thoại thật, Safari iPhone/Android APK, lease expiration/storage eviction và email/session E2E (#8/#7/#9/#10/#15). CI disposable PostgreSQL có test redeem một lần, 32 yêu cầu đồng thời, chủ sở hữu, quota và transfer thành công; không thay thế test máy thật.
- Backup và rollback chi tiết: [`docs/QR_TOKEN_RELEASE_20261117.md`](./QR_TOKEN_RELEASE_20261117.md). Không phát hành dữ liệu sản xuất; URL PWA production vẫn dùng backend/DB **staging**.

---
## QR/key/device contract correction — 17/11/2026
- Owner clarified: no physical-product quantities or packaging policies in HHK. QR codes are opaque one-use claim tokens; authorized admin creates a batch with an explicit `quantityTokens` count and campaign rights (grades, validDays, maxDevices).
- Database migration `0005_generic_claim_batches.sql` renames historic issuance batch table to `claim_batches`, changes count to `token_count`, drops obsolete business column, and supports new license source `qr_claim`; previously issued records/audit remain unchanged.
- Public legacy raw-key/QR endpoints become **admin-only**, while accounts use authenticated endpoints. Owner-scoped device inventory and new-device signed transfer, plus Flutter Activate/Renew/Change device actions, live in source.
- Migration must run **staging only after exact SHA 5/5 green CI and off-database restorable backup**. No changes to production Prisma DB or `main`. Production Flutter URL remains `https://hhk-cap01-pwa.vercel.app`; backend data remains staging.
- Issue #8/#7/#9 real-device QA remains open; signed leases can remain effective offline until expiry despite server revocation.

## Release update — 16/11/2026 23:27 UTC+7 (authoritative)

**User direction: deploy Flutter PWA directly to production URL; do not use preview deployments as the acceptance/test destination.** The Vercel PWA project is public-facing production, but the account/license API and Prisma DB intentionally remain **staging** for test data until separate production-backend authorization. This override replaces previous text below that held the PWA alias pending manual device QA; **device/browser QA is still open and must never be marked PASS without evidence.**

- Production app: https://hhk-cap01-pwa.vercel.app; Vercel deployment `dpl_ApjLHxf7RxZ3KDGmGNLBi9J5NU8B` READY, target `production`. Release artifact `hhk-flutter-web-pwa` from exact green SHA `ee864194ff4e6dab96ab0bc90eadd699ac1d2cc4`, [CI 5/5 green](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43847413897). SHA `d35589d9` through `ee864194` changed docs and CI only, not Flutter source.
- Production smoke: HTTP 200 index, `main.dart.js`, `manifest.json`, `hhk-sw.js` (no-store), Dopi avatar and hero image. Production alias resolved to `dpl_ApjLHxf7RxZ3KDGmGNLBi9J5NU8B` rather than old `dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE`.
- Backend **staging**: `dpl_9LYvrJwu9GWM6Ve6mjuXan33ECcf` READY from `ee864194`. Staging-only `HHK_PUBLIC_APP_URL=https://hhk-cap01-pwa.vercel.app`; CORS explicitly allows production host and removes the obsolete isolated preview host. Health HTTP 200 ready. Stage-only backup/migration 0004 remain as documented below.
- Production PWA deploy is approved by owner even though manual iPhone/Android and real email-link/session rotation E2E have not passed; keep [Issue #10](https://github.com/gustavjung02-tech/hhk-cap01/issues/10) and #15 open. No production Prisma DB migration and no `main` merge occurred.
- **Workflow from now on:** change source on `staging` → wait CI 5/5 green on exact source commit → build/retain Flutter Web CI artifact → manually deploy **production target** `hhk-cap01-pwa` → confirm `https://hhk-cap01-pwa.vercel.app` aliases correct deployment and smoke → record QA/defects and rollback. Do not present preview URL as the app link. Rollback PWA production deployment `dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE` if necessary.

---

# HHK CAP-01 — Execution tracker
Canonical plan: GitHub Issue #1. Checkpoint: 16/11/2026 UTC+7. Branch: `staging`. Production database and `main` untouched.

| Phase | Evidence | Result |
| --- | --- | --- |
| #15 backend/Flutter source | `d35589d9aa899ca6f1c8cec9af7042fd0dc75aea` | Source implemented |
| 5-job exact-SHA CI | [run 43799028874](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43799028874) | PASS |
| Staging DB restore-capable backup | Vercel Drive `hhk-staging-db-backups` (iad1), `hhk-staging-pre0004-20261116.dump`, SHA256 verified; isolated PostgreSQL 18 restore counts matched | PASS |
| SQL migration 0004 | hhk-staging only, ledger 0001–0004, 3 security tables and email verification column | PASS |
| Backend staging release | `dpl_2pM9i7fN4JEvYR1qMuvACh98pqJj` `READY`; health ready / public-key valid / unauthorized sessions 401 | PASS |
| Recovery mail sender | Resend `fbmn.vn`, Vercel staging env sending-only domain-scoped key and sender; QA verify email delivered and received | PASS |
| Forgot privacy regression | Unknown and unverified addresses same 200 neutral; no reset mail for either | PASS |
| Live verified-link reset & session rotation | Token handoff between mailbox and backend blocked by connector security; CI PostgreSQL tests pass, no live proof | PENDING |
| iPhone Safari / Android physical QA | No real device test evidence | PENDING (#10) |
| #15 PWA isolated preview | [Preview](https://hhk-cap01-119on2jr8-gustavjung02-techs-projects.vercel.app) READY `dpl_BLccHZHiWg8PzjQAbD714aGUieAL`; CI artifact 50 files; root, JS, manifest, SW, Dopi asset GET 200; backend OPTIONS origin 204 exact allow-origin | PASS (preview smoke only) |
| Production Flutter PWA | https://hhk-cap01-pwa.vercel.app — dpl_ApjLHxf7RxZ3KDGmGNLBi9J5NU8B READY, CI ee864194 5/5; HTTP 200 index/JS/manifest/SW/brand/hero | DEPLOYED, mobile QA pending |
| Production DB migration / main merge | Not authorized, never initiated | NOT DONE |

Read [handoff](./HHK_HANDOFF.md), [account contract](./ACCOUNT_LICENSE_WORKFLOW.md), and [staging security backup/release runbook](./ACCOUNT_SECURITY_RELEASE_20261116.md).

Next priority after #15 device QA: #10/#2 Safari, Android and UI; #8/#7/#9 QR/key/account device lease E2E; #3/#4 local progress and question audit (19,043 source items/1,600 quarantine); #14/#5 legacy daily challenges, games, art, badges/avatars, mind map, memory room, audio; #11/#6 production isolation, signed APK, restore rehearsal and release gates.

Security and data invariants: QR claimed in-app, one key per account, one parent many keys; only Ed25519 device lease is offline entitlement; student profiles, XP, answers and history remain local. Never treat CI green as proof of physical QA or commercial release.
