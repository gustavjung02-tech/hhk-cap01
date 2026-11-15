# HHK Flutter Web / iPhone PWA — manual-only Vercel release

## Nguyên tắc không tự deploy

**Project Vercel không liên kết Git repository**, không bật Git integration, và **không tạo bất kỳ workflow deploy tự động nào**. GitHub Actions chỉ build và xuất `hhk-flutter-web-pwa` artifact; không chứa Vercel token và không chạy lệnh deploy. Người quản trị kiểm tra CI **xanh**, chọn đúng commit, sau đó tự triển khai bằng plugin Vercel.

Đích: team `gustavjung02-techs-projects`, project `hhk-cap01-pwa` (đã tạo, không liên kết Git và đã deploy manual).

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

### Đã deploy thử nghiệm
- URL: https://hhk-cap01-pwa.vercel.app
- Deployment ID: `dpl_7h4WwptfCUkGCYhaXjZAMcg4x2uy` — READY; build logs xác nhận đúng checksum SHA-256 artifact `231dc43d3b785195a0838ccdda3e6acd5062d605e05c8e57067430a38798cf1f`.
- Tạo deployment qua plugin Vercel bằng gói Flutter Web đã build và xác minh checksum, không cần Git integration. Bản triển khai này lấy artifact từ URL ký tạm thời trong lúc build: **không thể redeploy nguồn build cũ sau khi URL hết hạn**; lần sau phải lấy artifact mới từ CI và deploy thủ công lại.
- Project protection: public, không yêu cầu login Vercel; phát hành thử nghiệm, QR/key chưa hoạt động.

### Chưa giải quyết

Bản Flutter hiện mới có các luồng học/quiz căn bản. Hệ thống key QR thực tế chưa hoàn thiện, không phát hành bản thương mại. Kiểm thử trực tiếp trên iPhone, Safari standalone, đổi mạng/offline, kiểm tra icon và lộ trình cập nhật trước khi cấp cho khách.
