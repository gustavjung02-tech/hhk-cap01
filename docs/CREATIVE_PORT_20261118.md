# HHK creative Flutter port — 18/11/2026

Source of truth: legacy pinned read-only at gustavjung01/cap-01@7ab83326db4ab3141e2d42aeefe2ea182f13452b.
Implementation on HHK CAP-01 staging only. Issue #14.

## Scope delivered in source (CI and device QA must be checked separately)
- Drawing/coloring: native Flutter Canvas, star/house/sun/flower outlines and freehand mode, color/brush/undo/clear, automatic profile-and-grade-scoped LocalStore persistence. Changing template asks before discarding strokes. No photo upload or backend learner data.
- Memory Room: only active single-choice, true/false, and numeric questions that pass the existing strict QuizEvaluator; 20 cards per session, tap to reveal, self-rating hard/medium/easy, spaced intervals 1m through 7d stored in local database per profile/grade. Not scored XP.
- Mind map: choose a real lesson in the grade, display selected lesson root and actual edited summary/cards as expandable branches. The legacy MindMapPage was a *Coming soon* placeholder; this is the first functional Flutter implementation. Never fabricate branch content.
- Avatar shop: options from the pinned legacy; purchases and selected avatar saved per learner in LocalStore. The earned XP comes from StudyLedger. Spending tracks a separate local unlock budget instead of rewriting or subtracting actual learning XP. No payments or leaderboards.

## Pending
- Audio: source has content/media/tts_drive_packs.json metadata, but actual R2/Drive binary ZIP and contents have not yet been verified against checksum/IDs. No assertion of playable offline audio or adding fake playback. Issue #5 remains BLOCKED until asset inventory, checked download, player, offline cache QA.
- iPhone Safari PWA and Android physical-device QA, performance, memory limits, storage eviction, audio and license re-validation.
- Tests/CI: GitHub Actions must pass on exact source SHA before deploying a new PWA production artifact. No backend/Prisma DB changes. Do not merge main or migrate production DB as a consequence of this change.
