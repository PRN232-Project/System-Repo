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
    { "name": "Unit Tests", "weight": 10, "testFilter": "FullyQualifiedName~Unit" }
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

## Notification

- `GET /api/notifications`
- `POST /api/notifications/{id}/read`

## Trạng thái

- Batch: `Assigned`, `InProgress`, `SubmittedForReview`, `NeedsCorrection`, `Resubmitted`, `Accepted`.
- Item: `Assigned`, `LocalMatched`, `Grading`, `Graded`, `TechnicalError`, `MissingSubmission`, `Submitted`, `ReturnedForCorrection`, `Accepted`.

## Chạy và migration

```powershell
dotnet run --project PRN232.ExamAccount.Api
dotnet test PRN232.ExamAccount.sln
dotnet ef database update --project PRN232.ExamAccount.Infrastructure --startup-project PRN232.ExamAccount.Api
```

EF migration history của service nằm tại `exam.__EFMigrationsHistory`, không dùng bảng history chung ở schema `public`.
