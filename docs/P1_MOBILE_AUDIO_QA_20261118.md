# HHK P1 — Mobile UX and offline audio QA, 18/11/2026

## Scope
- P0 account/QR/auth and Prisma are unchanged.
- A new Flutter widget viewport matrix simulates iPhone SE 320x568, Android 360x740, top and bottom system insets, 1.25-1.3x text, account QR input, bottom navigation, memory cards, mind map, avatar, and drawing persistence.
- CI widget emulation is NOT physical iPhone Safari or Android-device QA. Issue #10 remains open until actual device testing.
- Drawing root fix: raw pointer listener on canvas plus dynamic parent scroll physics, permitting both vertical and horizontal strokes and regular page scrolling outside the drawing area.

## Audio source inventory
- Source: content/media/tts_drive_packs.json, vi-v1 lesson-card packs for pre-K and grades 1 through 5. Each row has source R2 URL/key, SHA-256, size and expected asset count.
- The binary ZIP archives are not present in Git and have not been independently verified. Connected Cloudflare accounts do not list an obvious corresponding original HHK TTS bucket; no claim is made that they are deleted or unavailable globally.
- tooling/check_tts_packs.py validates manifest metadata in CI, then returns MISSING_ASSETS when the expected archive binaries are absent, not VERIFIED_ALL.
- To verify genuine downloaded files locally: python3 tooling/check_tts_packs.py --zip-dir /path/to/real-archives --require-files
- Binary verification compares sizes, SHA-256 hashes, ZIP paths and symlinks, audio file counts and per-file CRC without unpacking. It refuses malformed/duplicate archive entries.
- Do not enable a pretend audio playback button; only after verified source binaries, playable entry/lesson-card mapping, distribution rights and offline cache QA. Issue #5 remains open.

## Remaining manual mobile test
- iPhone Safari normal and installed PWA: home indicator/safe area, scroll, font scaling, QR camera permission, keyboard open/close, 3 student profiles, persistence, airplane mode, restart and storage eviction.
- Android Chrome and installed app / debug APK: same matrix plus screen rotation, back navigation and hardware audio playback when real assets exist.
- Offline lease expiry/revocation/transfer and real QR activation belong to separate P0 issues; do not mark passed solely from widget or backend tests.

## Release contract
- Only staging source -> exact SHA full CI green -> verified Flutter Web artifact SHA-256 -> manual Vercel production deployment -> confirm canonical alias. Never send preview for owner acceptance.
- This is a test/source progress document, not physical-device QA sign-off. No production database migration or main merge.
