# HHK CAP-01 — EXECUTION TRACKER

Checkpoint 16/11/2026. Canonical plan: GitHub Issue #1. Work branch: staging. Source commit: 96fab7b901b24181896f42366a2b8fae16b6b135. CI run 43792138192 passed 5/5.

- App testing URL: https://hhk-cap01-pwa.vercel.app/ (Vercel deployment dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE). Public production URL, but app currently connects to Prisma staging backend.
- Backend staging: hhk-cap01-license-staging-gustavjung02-techs-projects.vercel.app, deployment dpl_E51phyPMRZSgWW6LA9VunrMEjGto. Auth registration, login, me, keys, logout verified by live API tests. Prisma hhk-staging migrations 0001, 0002 and 0003.
- Pre-migration database snapshot of seven tables exists in schema hhk_pre_account_20261116. Same-database snapshot is not an offsite backup.
- Current UI: Dopi login gate, persistent client session, user profile icon top right, hamburger menu top left, bottom tabs Home/Subjects/Practice/Settings, photo hero, local progress/review/parent basics.
- Account limitations: no change password, forgot password, verified email or session management screens. Task #15 is P0.
- Legacy feature inventory: Issue #14 and docs/LEGACY_APP_FEATURE_AUDIT.md. Many original app features remain not migrated. Real-device QA and question bank review still pending.

Work order: (1) Issue #15 account recovery and security; (2) Issue #10 plus #2 iPhone/Android QA and UI fixes; (3) Issue #8 plus #7 one-time QR and device license live E2E; (4) Issue #3 and #4 study progress and question correctness; (5) Issue #14 and #5 legacy port/audio; (6) Issue #11 signed APK and release gates.

Rules: modify original source on staging, add tests, require green CI on exact SHA, deploy manually, update issue. Main and production database unchanged unless separately approved. Learner profiles, answers, XP and learning progress stay offline. QR redemption happens in app, not a separate website.

See docs/HHK_HANDOFF.md and docs/ACCOUNT_LICENSE_WORKFLOW.md for the handoff and account specifications.

---
## Issue #15 source implementation checkpoint — 16/11/2026
- New staging source checkpoint a9334d57: backend account change-password, forgot/reset (hashed one-use 20-min email token after verification), sessions/revoke/logout-all, email change verification, throttles and audit. Change rotates current bearer while revoking others; reset revokes all. Flutter Dopi forgot/reset and account settings integrated with secure vault; new PostgreSQL integration and widget tests.
- New migration 0004_account_security.sql is **NOT** applied. Existing staging DB data preflight: 2 accounts, 3 sessions, 1 license, 1 QR; version ledger 0001,0002,0003. Source CI must pass all five jobs for final exact commit.
- Blocker for database deployment: Prisma backups list empty; prior in-DB snapshot cannot replace offsite/restore-capable backup. Backup/restore first, migration staging only second.
- Blocker for email E2E: Resend sender domain fbmn.vn verified, but staging Vercel env still missing RESEND_API_KEY, HHK_MAIL_FROM and HHK_PUBLIC_APP_URL. Configure backend-only secrets before live reset validation.
- PWA production test URL has NOT been updated to Issue #15 code; backend staging remains pre-0004. Do not change main or production DB. After gates: staging migration, staging backend deploy/smoke, iPhone/Android QA, then manual PWA alias update.
