# HHK — QR Admin Console (18/11/2026)

## Đích triển khai và an toàn
- Project Vercel mới: `hhk-cap01-admin` của team `gustavjung02-techs-projects`; code duy nhất trong `admin-web/` nhánh `staging`.
- Chặn auto deploy: không liên kết Git repository; `vercel.json` có `git.deploymentEnabled=false`; tắt preview deployment. Chỉ deploy thủ công **production** sau GitHub Actions toàn xanh đúng SHA.
- Bảo vệ truy cập qua Vercel Authentication cho **all deployments** (nếu plan hỗ trợ) và backend bắt buộc credential `HHK_ADMIN_PANEL_KEY` riêng, phạm vi chỉ cấp/xem QR. Khóa `ADMIN_API_KEY` cũ vẫn được giữ nguyên và không bị sao chép.
- Trang admin sử dụng **backend/Prisma staging**, không đụng vào production Prisma DB hoặc nguồn `main`.
- Không có mặc định nào liên quan quy cách, hàng hóa hoặc số lượng vật lý.

## Thao tác
1. Mở trang admin; đăng nhập Vercel/team nếu được yêu cầu.
2. Đăng nhập tài khoản Vercel trong team quản trị và bấm **Kiểm tra kết nối**. Credential riêng `HHK_ADMIN_PANEL_KEY` chỉ tồn tại trong server-side env của Vercel và backend staging; không nhập khóa vào trình duyệt.
3. Chọn lớp (1–5), số ngày (1–3650), số thiết bị (1–10), bấm **Tạo chương trình**.
4. Chọn chương trình, mã đợt và số mã QR (1–100 trên màn hình), bấm **Phát hành mã QR**.
5. Tải **ZIP SVG QR + CSV**, hoặc tải riêng CSV ngay. Mỗi token `qr_...` chỉ đổi được một lần, raw token **chỉ được hiển thị tại thời điểm phát hành**; DB chỉ lưu SHA256 nên không thể xem lại sau khi đóng trang.
6. Vào https://hhk-cap01-pwa.vercel.app → đăng nhập → biểu tượng **Tài khoản** → **Quét QR** / dán mã → **Đổi QR lấy key** → trong **Key của tôi** nhấn **Kích hoạt** để có signed offline lease trên máy.
7. Mục **Các đợt đã cấp** trả về tối đa 100 đợt gần đây, chỉ thống kê tổng/đã dùng/chưa dùng, không có raw token.

## Kỹ thuật
- Admin web là static HTML/CSS/JS + Vercel Node Functions; dependencies pin `qrcode@1.5.4`, `jszip@3.10.1` cho tạo SVG/ZIP bên server. Không dùng dịch vụ tạo QR bên ngoài.
- `/api/issue` forward bearer scoped server-side qua HTTPS đến **duy nhất** HHK backend staging; chỉ cho các hành động `campaign`, `batch`, `list`. Client không lưu token vào storage, không tự động đưa token vào URL, không có analytics.
- `/api/qr` và `/api/export` kiểm tra định dạng `qr_...`, giới hạn tối đa 100 token, trả dữ liệu trong bộ nhớ. Header no-store, CSP chặn external script/iframe, policy same-origin.
- Backend `GET /api/v1/admin/batches` yêu cầu admin bearer, trả metadata/usage; không có migration DB.
- Nếu đóng trang trước khi tải token: phát hành đợt mới. Không cho phép xem lại raw token từ server.
- Live admin issuance/redeem và iPhone/Android QA chưa được ghi PASS nếu chưa có bằng chứng E2E.

## Kiểm thử và phát hành
- Workflow `.github/workflows/quality.yml` bổ sung job `qr-admin` (check, Node tests, QR image/ZIP smoke). Backend PostgreSQL integration kiểm tra account/admin scope và không trả token gốc.
- Staging backend cần deploy commit CI xanh để bật GET list. Frontend admin deploy **production target** thủ công. Không có preview/autodeploy.
- Sau release: kiểm tra project Vercel có Git link = null, SSO all, latestDeployment READY, canonical domain đúng, lỗi runtime và thử cấp QR thật trên staging với admin key do người quản trị nhập.

## Phân quyền máy chủ
- Vercel Authentication yêu cầu thành viên team; `HHK_ADMIN_PANEL_KEY` nằm trong env **production** của admin project và **preview/staging** của backend, không có trong frontend, không lưu vào browser hay Git.
- Backend chỉ chấp nhận panelKey tại `GET /api/v1/admin/batches` và `POST /api/v1/admin/campaigns`, `POST /api/v1/admin/batches`. Các API `/api/v1/licenses/*` vẫn yêu cầu admin API key cũ; unit+DB test chống mở rộng quyền.
- Cần bộ biến môi trường đúng trước deploy backend và admin. Không thay đổi khóa `ADMIN_API_KEY` hiện có.
