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
| PWA public test alias | `dpl_7BfqKgWGkZRgXbF4c39EEmU9CMoE` unchanged | HELD per gate |
| Production DB migration / main merge | Not authorized, never initiated | NOT DONE |

Read [handoff](./HHK_HANDOFF.md), [account contract](./ACCOUNT_LICENSE_WORKFLOW.md), and [staging security backup/release runbook](./ACCOUNT_SECURITY_RELEASE_20261116.md).

Next priority after #15 device QA: #10/#2 Safari, Android and UI; #8/#7/#9 QR/key/account device lease E2E; #3/#4 local progress and question audit (19,043 source items/1,600 quarantine); #14/#5 legacy daily challenges, games, art, badges/avatars, mind map, memory room, audio; #11/#6 production isolation, signed APK, restore rehearsal and release gates.

Security and data invariants: QR claimed in-app, one key per account, one parent many keys; only Ed25519 device lease is offline entitlement; student profiles, XP, answers and history remain local. Never treat CI green as proof of physical QA or commercial release.
