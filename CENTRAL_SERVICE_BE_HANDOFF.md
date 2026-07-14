# Central Service BE Handoff

## Scope da hoan thanh

- Service: `Exam-Account-Service`
- Huong hien tai: REST API + role permission + RabbitMQ consume/publish + gRPC goi sang `Notification-Service`
- Roles duoc ho tro:
  - `Admin`
  - `Lecturer`
  - `Student`

## Database va migration

- EF migration da tao: `Exam-Account-Service/PRN232.ExamAccount.Infrastructure/Persistence/Migrations/20260714150643_InitCentralService.cs`
- Da apply migration len Supabase thanh cong bang `dotnet ef database update`
- Seed mac dinh da duoc chay qua `Program.cs`
- Backup schema cu truoc khi reset:
  - `Exam-Account-Service/supabase-exam-backup-before-reset.sql`

## Trang thai Supabase hien tai

- Schema `exam` da duoc reset va tao lai theo migration moi
- Seed hien tai:
  - `admin / 123456`
  - `lecturer1 / 123456`
  - `student1 / 123456`
  - room mac dinh: `ROOM-1`

## Luu y van hanh

- Connection string Supabase dang nam trong:
  - [appsettings.json](/D:/Mon_hoc/Ky_8/PRN223/Assgment/Exam-Account-Service/PRN232.ExamAccount.Api/appsettings.json)
- Neu RabbitMQ chua bat, API van boot binh thuong.
- `GradingResultConsumer` da duoc doi sang retry nen khong lam sap API khi RabbitMQ offline.

## Auth/permission cho FE

Hien tai service dang dung header don gian de FE test nhanh, chua dung JWT:

- `X-User-Id: <guid>`
- `X-User-Role: Admin | Lecturer | Student`

FE flow de login:

1. Goi `POST /api/auth/login`
2. Luu `userId`, `role`
3. Gui 2 header tren cho cac request tiep theo

## API cho FE

Base URL mac dinh: `https://localhost:<port>`

### Auth

- `POST /api/auth/login`
  - body:
  ```json
  {
    "userName": "admin",
    "password": "123456"
  }
  ```

### Users

- `GET /api/users`
  - Admin only
  - query optional: `role`
- `GET /api/users/{userId}`
  - Admin only
- `POST /api/users`
  - Admin only
- `PUT /api/users/{userId}`
  - Admin only
- `DELETE /api/users/{userId}`
  - Admin only
  - se chan neu lecturer dang quan ly room hoac user da co submission

Body `POST/PUT /api/users`:

```json
{
  "userName": "student2",
  "password": "123456",
  "studentCode": "SE000002",
  "fullName": "Student Two",
  "email": "student2@local",
  "role": "Student",
  "isActive": true
}
```

### Rooms

- `GET /api/rooms`
  - Admin thay tat ca
  - Lecturer chi thay room minh quan ly
- `GET /api/rooms/{roomId}`
- `POST /api/rooms`
  - Admin only
- `PUT /api/rooms/{roomId}`
  - Admin only
- `DELETE /api/rooms/{roomId}`
  - Admin only
  - se chan neu room dang co exam

Body `POST/PUT /api/rooms`:

```json
{
  "code": "ROOM-2",
  "name": "Java Lab",
  "lecturerId": "LECTURER_GUID"
}
```

### Exams

- `GET /api/exams`
  - Admin/Lecturer/Student
  - Lecturer chi thay exam cua room minh
- `GET /api/exams/{examId}`
- `POST /api/exams`
  - Admin only
- `PUT /api/exams/{examId}`
  - Admin only
- `DELETE /api/exams/{examId}`
  - Admin only
  - se chan neu exam da co submission
- `GET /api/exams/{examId}/dashboard`
  - Admin/Lecturer
- `GET /api/exams/{examId}/submissions/{submissionId}`
  - Admin/Lecturer

Body `POST/PUT /api/exams`:

```json
{
  "roomId": "ROOM_GUID",
  "code": "EXAM-OOP-01",
  "title": "OOP Practical Exam",
  "maxScore": 10,
  "solutionPattern": "src/**/*.csproj",
  "requireAppSettings": true,
  "forbidHardcodedConnectionString": true,
  "timeoutSeconds": 15,
  "plagiarismKeywords": ["SqlConnection", "HardCode"]
}
```

### Exam Sections

- `GET /api/exam-sections?examId={examId}`
- `GET /api/exam-sections/{sectionId}`
- `POST /api/exam-sections`
  - Admin only
- `PUT /api/exam-sections/{sectionId}`
  - Admin only
- `DELETE /api/exam-sections/{sectionId}`
  - Admin only

Body `POST/PUT /api/exam-sections`:

```json
{
  "examId": "EXAM_GUID",
  "name": "Unit Test",
  "weight": 4,
  "testFilter": "FullyQualifiedName~Unit"
}
```

### Submissions

- `POST /api/Submissions`
  - Student only
  - student chi duoc nop cho chinh minh
- `GET /api/Submissions`
  - Student chi thay bai minh
  - Lecturer chi thay bai trong room minh quan ly
- `GET /api/Submissions/{submissionId}`
- `POST /api/Submissions/{submissionId}/regrade`
  - Admin/Lecturer
- `DELETE /api/Submissions/{submissionId}`
  - Admin/Lecturer

Body `POST /api/Submissions`:

```json
{
  "examId": "EXAM_GUID",
  "studentId": "STUDENT_GUID",
  "workspacePath": "D:/grading/submissions/se000001"
}
```

### Notifications

- `GET /api/notifications?userId={userId}`
- `GET /api/notifications/{notificationId}`
- `POST /api/notifications/{notificationId}/read`
- `DELETE /api/notifications/{notificationId}`

## Luong grading hien tai

1. Student submit bai qua `POST /api/Submissions`
2. `Exam-Account-Service` publish job len RabbitMQ
3. `Engine-Service` consume job va cham bai
4. `Engine-Service` publish ket qua ve queue result
5. `Exam-Account-Service` consume result
6. Neu thanh cong:
   - update diem
   - update section results
7. Neu loi:
   - set `Submission.Status = Failed`
   - luu `ErrorMessage`
   - tao `NotificationRecord`
   - goi gRPC sang `Notification-Service` de bao lecturer

## Contract Engine can follow

File contract:

- [SubmissionGradedEvent.cs](/D:/Mon_hoc/Ky_8/PRN223/Assgment/Exam-Account-Service/PRN232.ExamAccount.Application/Messaging/SubmissionGradedEvent.cs)

Payload Engine can publish ve RabbitMQ:

```json
{
  "submissionId": "SUBMISSION_GUID",
  "examId": "EXAM_GUID",
  "studentCode": "SE000001",
  "totalScore": 8.5,
  "rawJsonReport": "{\"sectionResults\":[{\"name\":\"Unit Test\",\"score\":4,\"maxScore\":4,\"status\":\"Passed\",\"feedback\":\"OK\"}]}",
  "hasErrors": false,
  "errorMessage": "",
  "completedAtUtc": "2026-07-14T15:30:00Z"
}
```

Neu cham bai loi, Engine phai gui:

- `hasErrors = true`
- `errorMessage` co noi dung ro rang
- `rawJsonReport` co the rong

Vi du:

```json
{
  "submissionId": "SUBMISSION_GUID",
  "examId": "EXAM_GUID",
  "studentCode": "SE000001",
  "totalScore": 0,
  "rawJsonReport": "",
  "hasErrors": true,
  "errorMessage": "Docker container timeout after 15 seconds",
  "completedAtUtc": "2026-07-14T15:35:00Z"
}
```

## Contract Notification gRPC

`Exam-Account-Service` se goi sang `Notification-Service` khi grading loi.

Proto dang dung:

- `Notification-Service/PRN232.Notification.Api/Protos/notification.proto`

Thong tin duoc gui:

- `LecturerId`
- `RoomId`
- `ExamId`
- `SubmissionId`
- `Type`
- `Title`
- `Message`

## Viec dong nghiep Engine can lam tiep

- Consume dung queue grading job tu exchange `grading.exchange`
- Publish ket qua ve queue result dung schema `SubmissionGradedEvent`
- Dam bao `rawJsonReport.sectionResults[]` dung format ma `Exam-Account-Service` dang parse
- Neu loi grading, phai gui `hasErrors=true` de trigger thong bao lecturer
- Neu can them section-level metadata, thong nhat truoc khi doi contract

## Lenh chay nhanh

### Tao migration moi sau nay

```powershell
dotnet ef migrations add <MigrationName> --project PRN232.ExamAccount.Infrastructure --startup-project PRN232.ExamAccount.Api --output-dir Persistence/Migrations
```

### Apply migration

```powershell
dotnet ef database update --project PRN232.ExamAccount.Infrastructure --startup-project PRN232.ExamAccount.Api
```

### Run API

```powershell
dotnet run --project PRN232.ExamAccount.Api
```

### Test

```powershell
dotnet test PRN232.ExamAccount.sln
```
