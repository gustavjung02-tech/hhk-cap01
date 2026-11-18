# HHK Offline Audio — verified original Drive packs

## Verified on 18 November 2026
Six original ZIPs found through connected Google Drive. Pre-K ZIP also exists but Flutter CAP-01 currently supports grades 1–5 only. For 1–5, the files contain **4,200 actual MP3 lesson-card tracks**, matched against **4,200 active card IDs** in current Flutter grade packs. **140 cards per grade have no track** in the original ZIP. Do not show a playback control for those cards.

The original R2 metadata in `content/media/tts_drive_packs.json` is from a DIFFERENT binary revision (all six size/SHA256 pairs disagree with Drive copies). Never silently substitute those old R2 checksums for Drive. The new source of truth is `frontend-flutter/assets/content/audio/catalog.json` (exact Drive SHA256, bytes, counts, IDs). Both catalogs are preserved for provenance.

## UX and offline storage
- In a licensed lesson, each card with source audio has **Nghe thẻ này** and **Tạm dừng/Tiếp tục**. Once finished, tapping play starts from the beginning.
- **Tải âm thanh bài này** downloads only existing MP3s for the current lesson to local SQLite/IndexedDB. Subsequent plays use cached bytes and **work without network** while a valid signed offline lease remains available.
- Audio cache never contains the learner's email, username or license/key. It is shared between local profiles of the same grade; playback/download checks active grade entitlement. Each MP3 is constrained to 500 KB, checked for MIME/MP3 framing, stored with a SHA256 integrity record, checked on read. Downloads of invalid/missing responses fail closed.
- Audio not present in the verified catalog has **no play button**. No synthetic or browser-generated TTS is used.
- The app must not depend on Google Drive being online when playing; the origin of MP3 bytes is the same PWA domain.

## Source integrity / repeatable release
All original Drive ZIPs were downloaded via authorized connector, inspected, SHA256 computed, internal manifests mapped, and individual MP3 IDs cross-checked with the Flutter lessons. ZIPs contain Windows-style backslashes; the publisher normalizes them while enforcing a safe path, no duplicate IDs or symlinks, entry CRC and MP3 headers.

1. Work on GitHub `staging`, run the **full CI 6/6 green** at one exact SHA (Flutter analyzer/tests/web/Android debug, Chrome IndexedDB, backend, qr-admin and content/audio checks).
2. Retrieve the exact CI Flutter web artifact (short-lived signed URL, SHA256) and each original **Drive ZIP** through the connected Google Drive connector. Signed URLs and audio ZIP bytes are never committed.
3. Use `tooling/release_audio_pwa.mjs` with server-side env `HHK_PWA_ARTIFACT_URL`, `HHK_PWA_SHA256`, `HHK_AUDIO_URLS_JSON` (five rows: grade, fileName, downloadUrl), and `tooling/publish_verified_tts.py`. These scripts verify *both* PWA artifact and every source ZIP before publishing static `/audio/tts/2026-04-27-v1/grade-N/lesson-card-ID.mp3` for grades 1–5.
4. Deploy **Vercel target production only**, from CI-green source. No Git auto-deployment, no preview for user acceptance, no backend migration.
5. Confirm Vercel READY, build transcript has `VERIFIED_ALL` and `4200` files, and canonical PWA domain matches deployed SHA. Do not claim real iPhone/Android audible playback until human device QA.

## Remaining QA
- On iPhone Safari PWA and Android Chrome: tap **Nghe**, pause/resume, restart, airplane mode, interrupted download, storage full/eviction, signed lease expiration, and different profiles.
- Verify 140 new cards per grade without TTS do not display fake controls.
- Native Android release APK with audio plugin compatibility remains a separate signed-build task.


## Whole-grade download UX (19 November 2026 source update)
- User request: do **not** make learners enter each lesson to download audio. On the **Bài học** curriculum tab, right below grade choice, show **Tải trọn bộ âm thanh lớp N**.
- One button opens the grade download manager: **Tải toàn bộ âm thanh lớp N**, progress **Đã lưu x/y đoạn**, estimated download size, stop and **Tải tiếp phần còn thiếu**.
- Existing recorded cards are reused across lessons and local profiles. Up to four simultaneous verified MP3 requests; every completed file is written to IndexedDB/SQLite immediately. If offline, browser closes or storage fills, files already saved remain and the next user-initiated download resumes only missing/corrupt records.
- Lesson pages now link to **whole-grade download** rather than showing a repeated **Tải âm thanh bài này** action on every lesson. **Nghe thẻ này** still plays the chosen card, including an individual network fetch if that audio has not yet been cached.
- The bulk download still checks a signed grade lease before starting; missing/unlicensed grades never unlock audio. The 140 cards per grade without MP3 remain excluded.
- Bulk download currently uses bounded concurrent per-card requests to already verified same-origin assets; it is **one user action**, not a single ZIP network transfer. Do not promise instant downloads. The reported source archive size is an approximate network budget; local base64/IndexedDB storage may be larger.
- Tests: grade download retry after failed response; stop+resume; no duplicate fetch for verified cached files; grade-download phone UI; entitlement gate; regression ensuring per-lesson download action was removed.
- Physical iPhone/Android offline audio and storage-quota QA remain open and require owner/device testing.
