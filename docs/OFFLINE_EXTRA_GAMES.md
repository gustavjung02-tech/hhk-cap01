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
