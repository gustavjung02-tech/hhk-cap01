## [LATEST] 17/11/2026 — Mini-game P1-A2 production released

- **App:** https://hhk-cap01-pwa.vercel.app — `dpl_3w2skUp2rBonYA431rNEu4VkRX8R` target `production` READY, alias verified. Source `staging@3720cf3edcf66105964a9932bebbab3247e912c4`. [CI run 44035281373](https://github.com/gustavjung02-tech/hhk-cap01/actions/runs/44035281373) **5/5 green**: 47 Flutter tests, Web/PWA offline, Android debug, backend, IndexedDB and content.
- Added four real offline Flutter games from pinned legacy: **Ghép Cặp, Xếp Chữ, Tốc Độ (8 s/câu), Điền Từ**. User enters **Menu 3 gạch → Mini-Game**; game opens only after a fresh signed-device-lease check. Data are gradeable catalog questions only; best score stored offline per learner/grade/game and **not** credited as StudyLedger XP. Full source notes in `docs/OFFLINE_EXTRA_GAMES.md`.
- Production smoke HTTP 200 for `/`, `main.dart.js`, `manifest.json`, `hhk-sw.js`, Dopi and hero; service worker `f6df8fa78d864657892b`. Rollback PWA deployment `dpl_EB1b8fFhTBN3RL8NHYEKPqogwaCd`.
- **Backend & Prisma staging remain unchanged** (schema 0001–0005); no production DB migration, no merge `main`. Owner prefers direct production PWA after exact-source CI GREEN, never a preview URL for acceptance.
- **NEXT / OPEN:** (#10/#15/#8/#9) QA iPhone Safari/Android physical app, camera QR, session/email/password/reset E2E, signed offline lease expiry/restart/transfer. (#14) port drawing/coloring with offline persistence; then memory room, mind map, inventory/avatar and audio. These are not marked done without real device/manual QA evidence.

---

# Four legacy mini-games → Flutter, wave P1-A2

Source: `gustavjung01/cap-01@7ab83326db4ab3141e2d42aeefe2ea182f13452b`, pages `MatchGamePage.tsx`, `WordScramblePage.tsx`, `SpeedQuizPage.tsx`, `FillBlankPage.tsx`.

## Behavior
- Ghép Cặp: 3–5 actual question-and-answer pairs; flip two hidden cards, match, remember wrong pair, award first-attempt points only; no fake pairs to fill a round.
- Xếp Chữ: up to 8 unique words backed by valid single-choice answers; deterministic shuffled Unicode tiles, tap to construct word, undo last letter, reveal after submission. Source prompts are real lesson questions.
- Tốc Độ: up to 10 strictly gradeable single-choice questions, 8-second timer per question, timeout is scored incorrect, background resume cannot reset an expired deadline; options remain visible until submission.
- Điền Từ: up to 10 strictly gradeable `fill_number` and `single_choice`; no unreviewed free-form `fill_text` or generated/fabricated text answers. Number input uses the original strict QuizEvaluator.
- All games: local persisted personal best by profile/grade/mode, no XP or network; show honest empty state when fewer verified questions; private game score never leaks to other learner profiles. `OfflineMiniGameHubPage` rechecks the device-bound signed lease before each nested game navigation.

## QA
- Flutter test suite covers invalid/ambiguous content rejection, matching/scramble deterministic candidates, numeric validation, speed timeout, card reveal, hub entitlement, local best score isolation.
- iPhone/Android manual QA remains open: touch targets, low-end performance, keyboard/safe area, license expiry mid-session, offline storage persistence after app restart and PWA service worker update.
- The daily challenge and previously implemented two games remain unchanged.
- Release gate: only deploy PWA production from an exact-SHA green 5/5 CI; no preview testing URL, no production DB migration.
