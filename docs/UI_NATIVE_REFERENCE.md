# HHK native learning UI — reference screenshot rollout
Date: 2026-11-16. Implemented on branch staging, no React/web page rewrite.
User-provided image: three-screen pastel mobile education app reference.

## Design contract
- UI is genuine Flutter composition, not an image or web iframe.
- Lilac phone-first scaffold, compact rounded panels and purple action buttons.
- Existing Dopi asset anchors greeting and subject/practice banners.
- Home: greeting, fast subjects, daily mission (3 distinct locally practised lessons today), actual most recently practised lesson, real navigation to practice and rewards.
- Subjects: mint Dopi header, grades 1–5 chip row, subject list with colorful subject icons; lesson details include All/Practised filters and actual stored best-correct progress.
- Practice: pink Dopi banner, lesson list with true local attempts/progress, tap launches original QuizEvaluator and StudyLedger flow.
- Achievements: separate native view with completed practice count, total attempts, XP and three milestone checks computed from real StudyLedger results. No fake streak counters or unimplemented buttons.
- Bottom: Home / Subjects / Practice / Settings, 60dp plus exactly one device system safe-area inset, account button top-right and legacy three-line drawer top-left retained.
- Backend and license API unchanged, offline content source unchanged, login gateway unchanged.
- Screenshot assets are design inspiration only; source uses existing HHK Dopi artwork.
- QA gates: flutter analyze, flutter test including native widget tests, Flutter Web & APK builds; iPhone/Android physical QA still needs owner report.
- Release: exact commit CI green then manual deploy to Vercel project **hhk-cap01-pwa production**, never offer preview as acceptance URL. Public frontend still connects to staging backend/Prisma for test data.
