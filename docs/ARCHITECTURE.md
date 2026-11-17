# Quyết định kiến trúc HHK (cập nhật 17/11/2026)

## Nghiệp vụ

1. **QR là mã nhận quyền độc lập với sản phẩm vật lý**. Không cố định số lượng hay cách phân phối sản phẩm trong phần mềm. Mỗi token có thể đổi tối đa một lần; việc phát hành token phải được quản trị cho phép.
2. Người dùng đã đăng nhập quét/nhập QR **trong app Flutter** → backend phát hành key vào đúng tài khoản → chủ tài khoản kích hoạt quyền học trên thiết bị bằng chữ ký Ed25519.
3. Mỗi key có chính sách cấu hình từ backend: lớp được mở, thời hạn quyền học, giới hạn thiết bị. Không mô hình hóa quy cách kinh doanh trong schema QR.
4. Sau kích hoạt, học bài, chấm câu hỏi, thống kê tiến độ/XP đều diễn ra **trên điện thoại** khi offline. XP là động lực trong máy; không có giải đấu/bảng xếp hạng trực tuyến giả.
5. Không có Chat AI, chatbot Gemini, proxy AI, API key AI hoặc thanh toán trong app.
6. Đổi điện thoại: có thể kích hoạt lại theo chính sách chuyển máy; **tiến độ chỉ chuyển nếu có bản sao lưu**. Mặc định local-only, không tự động đồng bộ dữ liệu trẻ em lên server.

## Dữ liệu

- Bài học/câu hỏi/thẻ học: nguồn từ repo cũ, export thành JSON theo grade, giữ ID, câu hỏi, đáp án và lời giải.
- Mọi nhãn bộ sách gán vòng tròn trong source được đặt `textbook: null` ở JSON chuẩn cho tới khi biên tập xác minh. Không được tự gắn bộ sách sai.
- Âm thanh: nguồn source có **TTS manifest**; file thực tế ở R2 cần kiểm kê độc lập. Không nói có audio offline đầy đủ nếu chưa kiểm chứng.
- Không copy React/Vite/Electron/Service Worker cũ, Express/SQLite server cũ, AI cũ, build logs, generated reports, tiền mã hóa.
- Flutter app không biết Prisma Postgres URL/DB password, không gọi server để chấm từng bài.

## License & bảo mật

- Prisma Postgres chứa `claim_batches`, `claim_tokens`, `reward_campaigns`, `licenses`, `device_activations`, `license_audit`.
- Token QR/Key lưu **hash** ở DB; phát hành ngẫu nhiên đủ entropy và chống đoán; rate limit/IP abuse policy ở backend Prisma.
- Backend Prisma chỉ xác nhận quyền, trả **offline license có chữ ký số** (device-bound, hạn sử dụng, policy version). Chữ ký được Flutter xác thực bằng public key trước khi mở quyền. Không cho Flutter tự đặt Premium trong SQLite.
- Một token QR chỉ nhận quyền một lần bằng transaction; endpoint không có tài khoản chỉ dành cho quản trị. Phương thức phân phối mã ở bên ngoài app, không áp đặt bởi phần mềm. Chuyển thiết bị đòi chữ ký máy mới và quyền sở hữu key.
- API khi chưa cấu hình Prisma Postgres/khóa ký phải trả lỗi đóng, tuyệt đối không giả vờ kích hoạt thành công.

## Phân phối

- Android: APK từ kênh trực tiếp có thể phù hợp, nhưng phải có cơ chế ký/phân phối và cập nhật an toàn.
- iOS: cơ chế phát hành và key ngoài app phải được xác minh tương thích chính sách Apple trước khi công bố.
- Flutter Web (nếu phát hành) dùng IndexedDB, ứng dụng native Android/iOS dùng SQLite; không được gọi IndexedDB trên Android.
