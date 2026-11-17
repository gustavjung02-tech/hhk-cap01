# HHK — Offline mini-games wave P1-A and signed entitlement gate

## Pinned legacy sources (read-only)
- `gustavjung01/cap-01@7ab83326db4ab3141e2d42aeefe2ea182f13452b`:
  `DailyChallengePage.tsx`, `TrueFalseBlitzPage.tsx`, `QuickMathRushPage.tsx`, `MiniGameHubPage.tsx`.
- Only the interaction model and offline algorithms were ported. No React, localStorage business logic, remote learner database or synthetic XP is imported.

## Implemented in Flutter source
- `LearningEntitlementGate` reads device-bound signed lease through `OfflineLicenseManager.gradeAllowed(grade)` and fail-closes any lesson/quiz/home content when invalid/missing. Child account entry, grade/profile switching and retry remain accessible; deep learning navigations recheck the lease. A revoked device that is currently offline may retain an already-issued unexpired signed lease — explicit policy caveat requiring device QA.
- `FunQuestionEngine.daily()` selects up to five genuine grade-pack questions strictly supported by the existing `QuizEvaluator`, after checking active lesson/question and excluding ambiguous item types; no stock/generated content. Picks are deterministic per learner profile, grade and local calendar date using a stable hash.
- `FunResultStore.completeDaily()` uses local transactional `update()` first-write-wins to prevent double completion or result overwrite; profile/grade/date isolation. No XP awarded; it is a standalone game score.
- `FunQuestionEngine.trueFalse()` uses only real valid true/false questions. If none exist the game shows an honest empty state; no fabricated true/false assertions.
- `FunQuestionEngine.quickMath()` builds ten local grade-appropriate, solvable arithmetic challenges with checked integer answers; no backend service.
- Mini-game high scores/plays are stored locally per profile, grade and mode; no leaderboards, account syncing or fake rewards.
- The native pastel HHK home and three-line drawer expose daily challenge and mini-game; the other legacy games remain explicitly unimplemented until reviewed and ported.

## Required verification
- Automated Flutter tests must cover permission boundary for no lease, corrupt lease, valid lease; deterministic valid quiz sampling; first-write-wins daily persistence across restart and isolation; mini-game grading; flow navigation; no fake XP.
- Physical iPhone Safari and Android need permission/cached SW/safe-area/background/resume/secure vault restart tests. Daily results use local device date; intentional local clock manipulation cannot grant license or XP, but may change displayed daily challenge.
- CI 5/5 on the exact SHA before production PWA deployment; backend and Prisma staging must not change for this Flutter-only release.
