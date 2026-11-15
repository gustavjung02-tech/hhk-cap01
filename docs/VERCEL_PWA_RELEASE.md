# HHK Flutter Web / iPhone PWA — manual-only Vercel release

## Nguyên tắc không tự deploy

**Project Vercel không liên kết Git repository**, không bật Git integration, và **không tạo bất kỳ workflow deploy tự động nào**. GitHub Actions chỉ build và xuất `hhk-flutter-web-pwa` artifact; không chứa Vercel token và không chạy lệnh deploy. Người quản trị kiểm tra CI **xanh**, chọn đúng commit, sau đó tự triển khai bằng plugin Vercel.

Đích: team `gustavjung02-techs-projects`, project `hhk-cap01-pwa` (chưa tồn tại cho đến khi được tạo thành công bằng plugin).

## Build sản phẩm PWA

```sh
cd frontend-flutter
flutter pub get
flutter test
flutter build web --release --pwa-strategy=none --base-href=/
cd ..
node tooling/build-pwa.mjs
node tooling/verify-pwa.mjs
```

Bản phát hành là **toàn bộ nội dung** của `frontend-flutter/build/web/`, trong đó có `vercel.json`, `hhk-sw.js`, `manifest.json`, icons và `main.dart.js`. Project Vercel chỉ phân phối static files, không build Flutter bằng Node runtime.

### Offline & cập nhật

Một phiên bản build có service worker riêng, precache app shell + assets giáo trình. Không phải dùng Internet mỗi lần học sau khi app đã tải/cached đầy đủ. iOS Safari có thể tự dọn cache do thiếu dung lượng/không hoạt động lâu; không được đảm bảo offline vĩnh viễn. Khi có bản mới, người dùng cần mở app khi có mạng để nhận service worker mới; dữ liệu học tập lưu trên IndexedDB riêng không bị dọn theo quy trình update cache.

Apple: mở trang bằng **Safari** → Share → **Add to Home Screen** → Add. Đây là **PWA**, không phải IPA App Store; không có backend hay database chạy trên điện thoại ngoài phần lưu local.

### Chưa giải quyết

Bản Flutter hiện mới có các luồng học/quiz căn bản. Hệ thống key QR thực tế chưa hoàn thiện, không phát hành bản thương mại. Kiểm thử trực tiếp trên iPhone, Safari standalone, đổi mạng/offline, kiểm tra icon và lộ trình cập nhật trước khi cấp cho khách.
