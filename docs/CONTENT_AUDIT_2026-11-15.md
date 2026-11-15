# Audit dữ liệu từ nguồn gốc, 15/11/2026

**Nguồn không chỉnh sửa:** `gustavjung01/cap-01@7ab83326db4ab3141e2d42aeefe2ea182f13452b`

Export đã chạy GitHub Actions và lưu data JSON trên repo mới:
- 9 môn học, 1.247 bài học, 4.988 thẻ nội dung;
- 19.043 ID câu hỏi được bảo toàn;
- 17.443 câu hỏi có grade/lesson/subject liên kết phù hợp trong tập seed hiện tại;
- 1.600 câu hỏi bị cách ly, trong đó **400 thiếu lesson**, **1.200 bị lệch lớp**.

Câu hỏi cách ly giữ nguyên nội dung và ID tại `content/seed/v1/quarantine/questions.json` và **không** đưa vào file học của Flutter cho đến khi biên tập xác minh liên kết chính xác. Không tự động gán bài/lớp hoặc xóa câu hỏi. Các file JSON đã có SHA-256 trong `content/seed/v1/manifest.json`.

**Rủi ro chưa xử lý:** dữ liệu source tự gán bộ sách theo vòng; trường textbook ở JSON mới được để NULL. Nội dung/đáp án chưa qua QA sư phạm; media manifest không đảm bảo âm thanh R2 đã tồn tại/chơi được. Không được tuyên bố đủ toàn bộ giáo trình production trước khi kiểm định.
