# Central Service BE Handoff - Three Role Workflow

## Trạng thái hiện tại

- Roles: `Admin`, `ExamOfficer`, `Lecturer`.
- Sinh viên là master data, không phải account.
- Authentication: JWT Bearer + rotating refresh token.
- Database: PostgreSQL/Supabase, schema `exam`.
- Swagger: `/swagger`.
- Local path bài thi tuyệt đối không gửi hoặc lưu ở Central Service.

Tài khoản seed local/demo, mật khẩu `123456`:

- `admin`
- `examofficer1`
- `lecturer1`

Seed nghiệp vụ: `ROOM-1`, sinh viên `SE000001`, mã đề `PRN223-DEMO`, ca thi `PE-DEMO-2026`, batch `BATCH-DEMO-001`.

## Authentication

### `POST /api/auth/login`

```json
{ "userName": "lecturer1", "password": "123456" }
```

### `POST /api/auth/refresh`

```json
{ "refreshToken": "token từ login" }
```

Mọi API còn lại gửi `Authorization: Bearer <accessToken>`.

## Admin API

- `GET /api/users?role=Lecturer`
- `POST /api/users`
- `PUT /api/users/{id}`
- `DELETE /api/users/{id}`

```json
{
  "userName": "lecturer2",
  "password": "123456",
  "fullName": "Lecturer Two",
  "email": "lecturer2@local",
  "role": "Lecturer",
  "isActive": true
}
```

Admin bị trả `403` khi gọi API phòng, sinh viên, đề hoặc kết quả.

## ExamOfficer API

### Master data

- `GET/POST/PUT /api/students`
- `POST /api/students/import` nhận mảng cùng cấu trúc student.
- `GET/POST/PUT/DELETE /api/rooms`
- `GET /api/directory/lecturers` chỉ đọc danh sách giảng viên active.

Student body:

```json
{ "studentCode": "SE180001", "fullName": "Nguyen Van A", "email": "a@local", "className": "SE18A", "isActive": true }
```

Room body:

```json
{ "code": "ROOM-2", "name": "Lab 2", "location": "Building A", "isActive": true }
```

### Mã đề

- `GET/POST/PUT /api/exam-papers`

```json
{
  "code": "PRN223-A",
  "title": "PRN223 PE - A",
  "rubricVersion": "1.0",
  "maxScore": 10,
  "solutionPattern": "*.sln",
  "requireAppSettings": true,
  "forbidHardcodedConnectionString": true,
  "timeoutSeconds": 15,
  "plagiarismKeywords": [],
  "sections": [
    {
      "name": "CRUD API",
      "weight": 10,
      "testFilter": "",
      "apiProjectPath": "PRN223.API/PRN223.API.csproj",
      "testCasesJson": "[{\"name\":\"Get list\",\"method\":\"GET\",\"urlPath\":\"/api/items\",\"expectedStatusCode\":200}]"
    }
  ],
  "isActive": true
}
```

### Ca thi và candidates

- `GET/POST /api/exam-sessions`
- `POST /api/exam-sessions/{id}/candidates`
- `GET /api/exam-sessions/{id}/candidates`
- `POST /api/exam-sessions/{id}/ready`

Create session:

```json
{ "code": "PE-SU26-01", "title": "Ca 1", "roomId": "uuid", "examPaperId": "uuid", "scheduledAtUtc": "2026-07-21T08:00:00Z" }
```

Add candidates:

```json
{ "studentIds": ["uuid-1", "uuid-2"] }
```

### Phân công và review

- `GET /api/grading-batches`
- `POST /api/grading-batches`
- `GET /api/grading-batches/{id}`
- `GET /api/grading-batches/{id}/export-excel` xuất bảng điểm của batch.
- `POST /api/grading-items/{id}/return`
- `POST /api/grading-batches/{id}/accept`

Create batch; `examCandidateIds: []` nghĩa là lấy tất cả candidate chưa vắng trong ca:

```json
{ "code": "BATCH-001", "examSessionId": "uuid", "lecturerId": "uuid", "examCandidateIds": [] }
```

Return result:

```json
{ "reason": "Report thiếu section Unit Tests" }
```

## Lecturer/Local Agent API

- `GET /api/grading-batches/mine`
- `GET /api/grading-batches/{id}` trả danh sách sinh viên và cấu hình mã đề.
- `POST /api/grading-batches/{id}/start`
- `POST /api/grading-batches/{id}/execution-package` cấp snapshot đề + execution token 4 giờ.
- `GET /api/grading-batches/{id}/export-excel` tải bảng điểm `.xlsx`; giảng viên chỉ tải được batch của mình, khảo thí tải được mọi batch.
- `POST /api/grading-items/{id}/match`
- `POST /api/grading-items/{id}/attempts`
- `POST /api/grading-items/{id}/retry`
- `POST /api/grading-batches/{id}/submit`

Match chỉ báo tìm thấy hay không; không gửi local path:

```json
{ "found": true, "note": null }
```

Submit attempt:

```json
{
  "clientRequestId": "local-agent-guid",
  "totalScore": 8.5,
  "rawJsonReport": "{\"sectionResults\":[]}",
  "hasTechnicalError": false,
  "errorCode": "",
  "errorMessage": "",
  "rubricVersion": "1.0",
  "completedAtUtc": "2026-07-21T10:00:00Z"
}
```

Nếu Docker/engine lỗi, gửi `hasTechnicalError=true`, `errorCode` và `errorMessage`. Build/test fail của bài sinh viên vẫn gửi `hasTechnicalError=false` với điểm/report hợp lệ.

`clientRequestId` là idempotency key; gửi lại cùng key không tạo attempt trùng.

## Kết nối Local Engine

Sau khi gọi `start`, FE gọi `execution-package` bằng JWT giảng viên, rồi chuyển nguyên response cùng đường dẫn local sang Engine:

`POST http://localhost:5174/api/local-grading/run-batch`

```json
{
  "localRootPath": "D:\\ExamSubmissions\\PE-SU26-01",
  "executionPackage": { "...": "response từ Central" }
}
```

Engine tự match folder theo `studentCode`, chạy Band 0/1/2 và callback về:

- `POST /api/integration/grading-items/{id}/match`
- `POST /api/integration/grading-items/{id}/plagiarism`
- `POST /api/integration/grading-items/{id}/attempts`

Hai callback dùng execution token, không dùng JWT user và không nhận `WorkspacePath`.

Section của mã đề hỗ trợ thêm:

```json
{
  "name": "CRUD API",
  "weight": 4,
  "testFilter": "",
  "apiProjectPath": "PRN223.API/PRN223.API.csproj",
  "testCasesJson": "[{\"name\":\"Get list\",\"method\":\"GET\",\"urlPath\":\"/api/items\",\"expectedStatusCode\":200}]"
}
```

`testCasesJson` là một chuỗi chứa **JSON array**. Central trả `400` nếu JSON sai cú pháp hoặc root không phải array. Nếu array rỗng, Engine không có test case Band 2 để cấp điểm cho section đó.

### Cấu hình Engine trên máy giảng viên

Engine vẫn dùng database riêng để lưu rubric và submission trong quá trình chạy. Không commit mật khẩu Supabase thật vào `appsettings.json`; mỗi máy cấu hình bằng User Secrets hoặc biến môi trường:

```powershell
$env:ConnectionStrings__SupabaseConnection="Host=...;Database=...;Username=...;Password=..."
dotnet run --project PRN232.GradingEngine.Api
```

Engine gọi Plagiarism Service local tại `http://localhost:5175`, vì chỉ máy giảng viên có `WorkspacePath`. Engine chỉ callback báo cáo JSON, số vi phạm và độ tương đồng về Central; source và local path không được gửi về Central.

Central kết nối với Engine local bằng REST. RabbitMQ không vận chuyển source hoặc request chấm; RabbitMQ vận chuyển sự kiện realtime từ Central/Plagiarism tới Notification Service.

### Trạng thái plagiarism trong item

`GET /api/grading-batches/{id}` trả thêm trên mỗi item:

- `plagiarismStatus`: `Pending`, `Completed` hoặc `TechnicalError`.
- `plagiarismViolationCount`, `plagiarismMaxSimilarity`.
- `plagiarismReportJson`, `plagiarismErrorMessage`, `plagiarismCheckedAtUtc`.

Plagiarism lỗi không làm attempt chấm điểm thành lỗi. FE hiển thị cảnh báo riêng và vẫn cho phép khảo thí xử lý kết quả.

## Notification

- `GET /api/notifications`
- `POST /api/notifications/{id}/read`
- SignalR: `http://localhost:5176/gradingHub`, gọi `JoinExamGroup(examSessionId)`.
- Client methods: `UpdateProgress` và `PlagiarismAlert`.

## Trạng thái

- Batch: `Assigned`, `InProgress`, `SubmittedForReview`, `NeedsCorrection`, `Resubmitted`, `Accepted`.
- Item: `Assigned`, `LocalMatched`, `Grading`, `Graded`, `TechnicalError`, `MissingSubmission`, `Submitted`, `ReturnedForCorrection`, `Accepted`.

## Chạy và migration

```powershell
dotnet run --project PRN232.ExamAccount.Api
dotnet test PRN232.ExamAccount.sln
dotnet ef database update --project PRN232.ExamAccount.Infrastructure --startup-project PRN232.ExamAccount.Api
```

Nếu triển khai thủ công, chạy `engine-bridge-migration.sql` rồi `plagiarism-workflow-migration.sql`. Supabase hiện tại đã được áp dụng cả hai migration.

EF migration history của service nằm tại `exam.__EFMigrationsHistory`, không dùng bảng history chung ở schema `public`.

## Kiểm chứng gần nhất

- Exam Account tests: `5/5` pass.
- Grading Engine tests: `6/6` pass.
- Plagiarism tests: `5/5` pass.
- Notification build thành công nhưng project test hiện chưa có test case được discover.
- E2E thật đã chạy qua ExamOfficer → Lecturer → Engine → Plagiarism → Central → RabbitMQ → Notification/SignalR.
- E2E phát hiện đúng từ khóa cấm, Central lưu cảnh báo cho ExamOfficer và queue được consume hết.
- Dữ liệu và submission E2E tạm đã được xóa sau khi kiểm tra.
