# HHK EXECUTION TRACKER
**Nguồn trạng thái chuẩn:** [EPIC #1](https://github.com/gustavjung02-tech/hhk-cap01/issues/1) và issue con #2–#11.

## Đã có / chưa có (as of 15/11/2026)

| Nền tảng | Đã xác nhận | Chưa hoàn tất |
|---|---|---|
| Repo/CI | Flutter-first + source grades 1–5, CI baseline xanh | E2E thiết bị thật, QA từng câu |
| Flutter | UI học/quiz cơ bản, lưu grade/XP tốt nhất local | Multi-profile, tiến độ bền, badge/ôn tập, phân loại câu hỏi |
| Content | 19.043 ID không mất, manifest SHA256 | 1.600 quarantine, nội dung và đáp án chưa duyệt |
| Audio | Manifest + một số assets | File R2 thực, player & offline coverage |
| Prisma | project gus-02, branches main/staging đã tạo | **Cả 2 DB chưa có, Compute app chưa có; API 503** |
| PWA | Vercel production READY, manual-only, HTTP assets test | E2E Safari offline thật, entitlement |
| Android | Flutter Android source + APK debug CI | Signing release, test phân phối |

## Các Wave (không gán % tự ước lượng)
**Wave A — app local:** #2 → #3 → #4, song song #5.
**Wave B — Prisma staging & key:** #6 → #7 và #8.
**Wave C — tích hợp và kiểm thử:** #9 → #10.
**Wave D — release có kiểm soát:** #11.

**Toàn bộ issue con:** 10. **Đã hoàn tất theo nghiệm thu:** 0. **Một phần:** 4. **Bị chặn:** 4. **Chưa bắt đầu:** 2.

## Gate bắt buộc
- Khởi động task: đọc issue và repo tương ứng, ghi nhận phụ thuộc.
- Code: nhánh `staging`, test cụ thể, PR vào `main`; **CI xanh** là điều kiện tối thiểu.
- Prisma: staging DB khác production DB, chạy migration staging trước; production cần quyền/duyệt riêng.
- Vercel: manual-only plugin từ artifact kiểm tra đúng commit, không Git-linked auto-deploy.
- Giao hàng: cập nhật issue checklist bằng link commit/CI, đóng issue chỉ khi DoD đạt; không nói xong khi scaffold còn 503.

Chi tiết triển khai và đoạn bàn giao cho chat khác: [HHK_HANDOFF.md](./HHK_HANDOFF.md).

## Checkpoint Wave A (15/11/2026)

- **#3 IN PROGRESS:** cấu trúc local v2 với hồ sơ độc lập, transaction và idempotent attempt ID, migration v1 không xóa dữ liệu gốc, thống kê/ôn tập local, UI chọn/thêm hồ sơ. Test unit đã bổ sung; chờ CI/thiết bị thật để nghiệm thu.
- **#4 IN PROGRESS:** chỉ chấm các kiểu có quy tắc chặt `true_false`, `single_choice`, `fill_number`; tạm ẩn các kiểu khác, không coi text/đa chọn là câu đúng mặc định. Chưa audit đủ 19.043 ID.
- **#6 BLOCKED:** Prisma gus-02 không có database/Compute; vẫn chỉ đọc, chưa migration.
- **Production:** không thay đổi; deployment manual-only, chưa phát hành đợt này.
