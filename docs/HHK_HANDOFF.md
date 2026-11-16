# HHK CAP-01 — Handoff (16/11/2026, staging account security live)

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
