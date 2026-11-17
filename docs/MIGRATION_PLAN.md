# Kế hoạch chuyển CAP-01 vào repo chính sạch

## Thực trạng và phạm vi
Nguồn read-only: `gustavjung01/cap-01@7ab83326db4ab3141e2d42aeefe2ea182f13452b` (423 files trong snapshot khảo sát).
Repo đích: `gustavjung02-tech/hhk-cap01`. Các xóa bỏ chỉ áp dụng **repo đích**; tuyệt đối không delete/force-push repo nguồn.

### KEEP (đã chọn lọc)
- `src/data/seedData.ts` và 76 file `src/data/*`: **chỉ chạy trong checkout tạm của workflow**, xuất `subjects.json`, `lessons.json`, `lesson_cards.json`, `questions.json`; không commit nguồn TS vào repo mới.
- Định danh `lesson.id`, `question.id`, `lessonId`, `subjectCode` giữ nguyên; không sửa ID.
- Ảnh phục vụ app: `public/mascots/dopi-avatar.png`, `public/icon.png` và vài ảnh nền; kiểm tra giấy phép và size trước khi đưa vào app.
- `public/audio/tts/manifest.json` và một số catalog: giữ metadata. Audio nhị phân trên R2 **chưa** đồng bộ/kiểm chứng.

### DROP at root (loại tận gốc, không port UI/legacy code)
`src/modules/*`, `src/shared/*`, React, Tailwind, Vite, `electron/*`, `backend/*` Express, cũ `public/sw.js`, `node_modules`, `dist`, logs, desktop, Vercel/Netlify configs, web-chat AI, Gemini, localStorage auth/XP, leaderboard giả, các bản report khổng lồ.

### REBUILD
Flutter/Dart màn hình lớp 1–5, môn học, danh sách bài học, thẻ học, luyện tập, chấm offline, tiến độ & nhiều học sinh, audio từ asset manifest; chặn truy cập theo offline license có xác thực.
Prisma backend + Prisma Postgres: QR redemption, activation, device move, license administration; KHÔNG có AI, thanh toán hoặc tiến độ trực tuyến.

## Milestones và gates

| Giai đoạn | Đầu ra | Gate |
|---|---|---|
| M0 | Cây repo sạch + Flutter shell + Prisma API fail-closed + PostgreSQL schema | lint/CI, không legacy runtime |
| M1 | Export đủ dữ liệu thật từ source pinned; assets và catalog | unique ID, FK, manifest SHA256, grade/subject coverage |
| M2 | Flutter Native lessons/practice/quiz + SQLite | học offline, crash/restart không mất tiến độ, test |
| M3 | QR cấp quyền & license server | token dùng một lần, cấp theo số mã cấu hình, signed offline license, anti-replay, account isolation |
| M4 | Phát hành APK / iOS feasibility / update content | signed build, thiết bị thực, offline/license tests |
| M5 | Tùy chọn backup và marketing | bảo mật, chính sách dữ liệu trẻ em, user consent |

## Điều không được tuyên bố xong khi chưa kiểm chứng
Chưa có database Prisma/Compute app đang chạy, audio R2 chưa kiểm kê và chưa có domain website công ty thì chưa deploy/license production; chưa có Flutter SDK tại runner thì chưa tạo APK; TTS manifest không chứng minh audio R2 đủ; repo nguồn cung cấp dữ liệu nhưng chưa bảo đảm chính xác toàn bộ chương trình GDPT.

## Tiếp theo
1. Kiểm tra import content GitHub Actions và đối chiếu số lượng/id/checksum.
2. Làm Flutter UI nghiệp vụ thực với dữ liệu đã nhập; hoàn chỉnh storage iOS/Android và Web.
3. Hoàn thiện QR/keys trên Prisma Postgres và backend Node/Prisma Compute, cấu hình công ty/tem/chiến dịch khi quyết định chính sách.
4. Chỉ deploy sau CI xanh và kiểm thử nghiệp vụ/giấy phép.
