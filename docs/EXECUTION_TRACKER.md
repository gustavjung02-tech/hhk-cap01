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
