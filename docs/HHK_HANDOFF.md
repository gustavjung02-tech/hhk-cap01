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

# HHK CAP-01 — Handoff (historical staging checkpoint; see authoritative release update above)

Read canonical [Epic #1](https://github.com/gustavjung02-tech/hhk-cap01/issues/1), [Issue #15](https://github.com/gustavjung02-tech/hhk-cap01/issues/15), [tracker](./EXECUTION_TRACKER.md), [account/license workflow](./ACCOUNT_LICENSE_WORKFLOW.md), [recovery runbook](./ACCOUNT_SECURITY_RELEASE_20261116.md) and [legacy audit](./LEGACY_APP_FEATURE_AUDIT.md).

## Scope and baseline
- Only edit repo `gustavjung02-tech/hhk-cap01`, branch `staging`; do not change `main` or migrate production DB. Legacy `gustavjung01/cap-01` is read-only.
- Account-security source/deployed SHA: `d35589d9aa899ca6f1c8cec9af7042fd0dc75aea`. [CI 5/5 successful on exact SHA](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/43799028874). Baseline pre-#15 UI source `96fab7b9` was also CI-green.
- Prisma project `gus-02`: `proj_t5ke1mdd3u72vvhw1ogmm5vn`, DB **staging only** `hhk-staging` (`db_l4ds0m8jnxux66bd3erlnvqe`), **0001/0002/0003/0004 now applied**. Original data counts after QA cleanup: 2 accounts, 3 sessions, 1 license, 1 claim.
- Backend staging: https://hhk-cap01-license-staging-gustavjung02-techs-projects.vercel.app ; project `prj_F7zDPvMW9C8k8j2gw5Z8bSIfntPM`, **READY** deployment `dpl_2pM9i7fN4JEvYR1qMuvACh98pqJj` from tested SHA above. Rollback deployment: `dpl_E51phyPMRZSgWW6LA9VunrMEjGto`; beware backend rollback is not a DB rollback.
- #15 **isolated Flutter QA preview**: https://hhk-cap01-119on2jr8-gustavjung02-techs-projects.vercel.app (`dpl_BLccHZHiWg8PzjQAbD714aGUieAL`, READY). Exact 5/5 green Flutter artifact, 50 files. HTTP 200 for root/JS/manifest/service-worker/Dopi asset. Backend staging CORS 204 allows exact origin; staging email link target `HHK_PUBLIC_APP_URL` now points to preview. Real-device/browser QA still pending.
- Previous first #15 backend staging deployment `dpl_GVt4esjyVUec7KSjFxsZZE4hgEhr`; current deployment `dpl_2pM9i7fN4JEvYR1qMuvACh98pqJj` after preview env refresh.
- Existing public PWA test alias **still old release** https://hhk-cap01-pwa.vercel.app (project `prj_DSfBxmprioI98nq6gWCEuaVADlrC`, deployment `dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE`, fallback `dpl_GSobToSsy1tm4VkkKZskSA6nAQab`). The new #15 Flutter UI has **not** been published to that alias. PWA continues to call staging backend.
- Windows checkout preference `F:\\1_A_Disk_D\\fbmn\\HHK-01`; do Git/Vercel/Prisma operations through connected tools, do not ask user to paste source.

## Issue #15 — latest checkpoint
**Source, CI, backup, DB migration, backend staging deployment and basic live API/mail delivery completed; full E2E/device QA pending.**
- Backend implements old-password-confirmed change with fresh scrypt salt, token rotation preserving current machine, revoking other sessions; verified email one-use action tokens (20 minutes, SHA-256 hash stored); forgot response neutral; reset revokes ALL sessions; device session list/revoke/logout-all; email-change verification, throttling/audit.
- Flutter account settings, Dopi forgot password, verification-link action route, client-side secure storage token update and widget/API tests are in source but not yet in PWA public test build.
- Backup created on Vercel Sandbox Drive `hhk-staging-db-backups` in `iad1`, separate from Singapore DB. Archive `hhk-staging-pre0004-20261116.dump` (33,334 bytes), SHA256 manifest and archive list preserved. **Full restore to independent PostgreSQL 18 verified**, 2 accounts/3 sessions/1 license/1 claim and migration 0001–0003. Skip only provider-managed `prisma_postgres` extension during generic PostgreSQL rehearsal; see restore runbook.
- Migration `0004` applied only on staging, security tables and email_verified_at verified. After QA test-account cleanup original counts remained unchanged.
- Verified Resend sending domain `fbmn.vn`, stage-only Vercel env `RESEND_API_KEY` (sending-only, domain-restricted), `HHK_MAIL_FROM`, `HHK_PUBLIC_APP_URL`. Controlled verification email was actually sent, status `delivered`, and received via Resend inbox. API forgot returns identical 200 for unverified and absent email; no reset email was sent for either.
- **Not yet verified on live backend:** clicking/consuming the email action token, resetting password from inbox, same-device/new-token and other-device revocation via real browser. Connector security stopped moving the one-time email token between services. PostgreSQL integration tests cover expiration/replay/rotation. Do not label live E2E complete.
- **Real-device gate pending:** manual iPhone Safari PWA and Android APK tests of account/login/keyboard/safe-area, new reset UI, lease/QR/offline. No controlled iPhone/Android real hardware access here. **Do not update PWA production-test alias until manual device QA passes.**

## Product invariants and next tasks
Flutter/Dart Web/iOS/Android; Dopi login/register before app. Account icon top-right, menu left, bottom Home/Subjects/Practice/Settings, hero image. Persistent secure vault, no fixed daily logout; revoked tokens, password reset, user logout and browser storage eviction remain exceptions.

One parent account can own multiple license keys, one key belongs to a single account; one QR for one 20-notebook pack, claimed exactly once **inside the app**. Signed Ed25519 device lease (not a local flag) controls offline entitlement. Learner answers, grades, profiles, XP and progress stay local IndexedDB/SQLite. No React/Clerk/parallel AI backend.

**Next:** perform live email link + password-change/revoke E2E with controlled test inbox/browser and manual Safari/Android QA (#10); if green, promote CI-built Flutter PWA as a manually approved test release, verify service-worker cache and smoke. Then QR/device #8/#7/#9, local progress and question accuracy #3/#4, legacy port #14/#5, and production release gates #6/#11. No production DB migration without explicit approval.
