# Quyết định kiến trúc HHK (15/11/2026)

## Nghiệp vụ

1. Mỗi **lốc 20 cuốn tập** có **một mã nhận quà** (QR/tem). QR không phải license; tránh để lộ token đổi quà trước khi mua.
2. Khách quét QR tới **website công ty** (website ngoài phạm vi repo app), website đổi token lấy **key**. Key đưa vào app Flutter để kích hoạt một lần khi có mạng.
3. Mỗi key có các quyền gắn với chiến dịch (ví dụ lớp được mở, ngày hết hạn, số thiết bị). **Chưa chốt phần thưởng, thời hạn, xác suất hay giá trị** nên tất cả đều cấu hình trên server.
4. Sau kích hoạt, học bài, chấm câu hỏi, thống kê tiến độ/XP đều diễn ra **trên điện thoại** khi offline. XP là động lực trong máy; không có giải đấu/bảng xếp hạng trực tuyến giả.
5. Không có Chat AI, chatbot Gemini, proxy AI, API key AI hoặc thanh toán trong app.
6. Đổi điện thoại: có thể kích hoạt lại theo chính sách chuyển máy; **tiến độ chỉ chuyển nếu có bản sao lưu**. Mặc định local-only, không tự động đồng bộ dữ liệu trẻ em lên server.

## Dữ liệu

- Bài học/câu hỏi/thẻ học: nguồn từ repo cũ, export thành JSON theo grade, giữ ID, câu hỏi, đáp án và lời giải.
- Mọi nhãn bộ sách gán vòng tròn trong source được đặt `textbook: null` ở JSON chuẩn cho tới khi biên tập xác minh. Không được tự gắn bộ sách sai.
- Âm thanh: nguồn source có **TTS manifest**; file thực tế ở R2 cần kiểm kê độc lập. Không nói có audio offline đầy đủ nếu chưa kiểm chứng.
- Không copy React/Vite/Electron/Service Worker cũ, Express/SQLite server cũ, AI cũ, build logs, generated reports, tiền mã hóa.
- Flutter app không biết Neon URL/DB password, không chấm bài trên Cloudflare.

## License & bảo mật

- Neon chứa `print_batches`, `claim_tokens`, `reward_campaigns`, `licenses`, `device_activations`, `license_audit`.
- Token QR/Key lưu **hash** ở DB; phát hành ngẫu nhiên đủ entropy và chống đoán; rate limit/IP abuse policy ở Worker.
- Cloudflare chỉ xác nhận quyền, trả **offline license có chữ ký số** (device-bound, hạn sử dụng, policy version). Chữ ký được Flutter xác thực bằng public key trước khi mở quyền. Không cho Flutter tự đặt Premium trong SQLite.
- Một token QR chỉ đổi quà một lần bằng transaction; phương án chống quét trước bán cần tem kín hoặc xác nhận mua hàng. Chuyển máy/thu hồi theo chính sách.
- API khi chưa cấu hình Neon/khóa ký phải trả lỗi đóng, tuyệt đối không giả vờ kích hoạt thành công.

## Phân phối

- Android: APK từ kênh trực tiếp có thể phù hợp, nhưng phải có cơ chế ký/phân phối và cập nhật an toàn.
- iOS: cơ chế phát hành và key ngoài app phải được xác minh tương thích chính sách Apple trước khi công bố.
- Flutter Web (nếu phát hành) dùng IndexedDB, ứng dụng native Android/iOS dùng SQLite; không được gọi IndexedDB trên Android.
