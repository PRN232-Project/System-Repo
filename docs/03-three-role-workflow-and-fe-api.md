# Luồng ba role và hướng dẫn FE/API

## 1. Roles

- `Admin`: chỉ CRUD/khoá tài khoản và reset mật khẩu.
- `ExamOfficer`: quản lý sinh viên, phòng, mã đề, ca thi, phân công, duyệt/trả kết quả.
- `Lecturer`: nhận batch, đối chiếu bài local, chạy chấm, retry lỗi và gửi kết quả.

Sinh viên là master data, không có tài khoản đăng nhập.

## 2. Authentication

### Login

`POST /api/auth/login`

```json
{ "userName": "examofficer1", "password": "123456" }
```

Response trả `accessToken`, `refreshToken`, `expiresAtUtc` và thông tin user. FE gửi:

```http
Authorization: Bearer <accessToken>
```

Không tiếp tục gửi `X-User-Id` hoặc `X-User-Role`.

## 3. FE route map

| Route FE | Role | API chính |
|---|---|---|
| `/admin/accounts` | Admin | `/api/users` |
| `/exam-office/students` | ExamOfficer | `/api/students` |
| `/exam-office/rooms` | ExamOfficer | `/api/rooms` |
| `/exam-office/papers` | ExamOfficer | `/api/exam-papers` |
| `/exam-office/sessions` | ExamOfficer | `/api/exam-sessions` |
| `/exam-office/batches` | ExamOfficer | `/api/grading-batches` |
| `/lecturer/batches` | Lecturer | `/api/grading-batches/mine` |
| `/lecturer/batches/:id` | Lecturer | `/api/grading-batches/:id` |

## 4. Luồng Khảo thí

1. CRUD sinh viên, phòng và mã đề.
2. Tạo ca thi gắn phòng + mã đề.
3. Thêm/import candidates vào ca thi.
4. Lấy danh sách giảng viên qua `GET /api/directory/lecturers`.
5. Lấy candidate qua `GET /api/exam-sessions/{id}/candidates`.
6. Tạo và phân công trực tiếp qua `POST /api/grading-batches`.
7. Theo dõi item; khi lecturer submit thì duyệt hoặc trả từng item.

## 5. Luồng Giảng viên/Local Agent

1. `GET /api/grading-batches/mine` lấy batch được giao.
2. `POST /api/grading-batches/{id}/start` chuyển sang `InProgress`.
3. Agent tự chọn folder local; path không gửi lên server.
4. `POST /api/grading-items/{id}/match` báo đã match hoặc thiếu bài.
5. `POST /api/grading-items/{id}/attempts` gửi kết quả/lỗi kỹ thuật.
6. Khi mọi item ở trạng thái kết thúc, gọi `POST /api/grading-batches/{id}/submit`.
7. Item bị trả sẽ có `ReturnedForCorrection`; lecturer retry và submit lại.

## 6. Trạng thái FE phải xử lý

Batch: `Assigned`, `InProgress`, `SubmittedForReview`, `NeedsCorrection`, `Resubmitted`, `Accepted`.

Item: `Assigned`, `LocalMatched`, `Grading`, `Graded`, `TechnicalError`, `MissingSubmission`, `Submitted`, `ReturnedForCorrection`, `Accepted`.

`TechnicalError` là lỗi engine/hạ tầng. Build fail hoặc test fail của bài sinh viên vẫn là attempt hợp lệ và `Graded`.

## 7. Quy ước FE

- Dùng `id` UUID làm key; chỉ dùng code để hiển thị/tìm kiếm.
- Thời gian API là UTC ISO-8601; FE đổi sang giờ địa phương.
- Không suy luận quyền bằng cách ẩn nút; luôn xử lý HTTP 401/403.
- Sau mutation, dùng response từ server hoặc refetch; không tự đoán trạng thái.
- Hiển thị `errorCode` riêng với `errorMessage` để giảng viên biết lỗi có retry được hay không.
- Không gửi local path, source code hoặc secret lên Central Service.

## 8. HTTP conventions

- `200`: query/update thành công.
- `201`: tạo mới.
- `204`: xoá thành công.
- `400`: dữ liệu/quy tắc trạng thái không hợp lệ.
- `401`: chưa đăng nhập/token hết hạn.
- `403`: sai role hoặc không sở hữu batch.
- `404`: không tìm thấy resource trong phạm vi được phép.
- `409`: trùng code hoặc attempt đã tồn tại.

Swagger của Central Service là nguồn contract cuối cùng trong giai đoạn code: `/swagger`.
