# Luồng tích hợp Plagiarism đang sử dụng

## Luồng thực tế

```text
FE giảng viên
  -> POST localhost:5174/api/local-grading/run-batch
Engine local
  -> match folder sinh viên
  -> chạy Band 0/1/2
  -> POST localhost:5175/api/Plagiarism/check (WorkspacePath chỉ tồn tại local)
Plagiarism Service
  -> lưu report/comparison ở schema plag
  -> publish plagiarism-alerts nếu có từ khóa cấm
Engine local
  -> GET report + comparisons
  -> POST Central /api/integration/grading-items/{id}/plagiarism
  -> POST Central /api/integration/grading-items/{id}/attempts
Central Service
  -> lưu trạng thái plagiarism trên GradingItem
  -> tạo notification bền vững cho ExamOfficer
  -> publish grading-results
Notification Service
  -> consume plagiarism-alerts/grading-results
  -> SignalR Clients.Group(examSessionId)
```

## Contract Engine gọi Plagiarism

`POST http://localhost:5175/api/Plagiarism/check`

```json
{
  "submissionId": "grading-item-uuid",
  "examId": "exam-session-uuid",
  "studentId": "SE180001",
  "workspacePath": "D:\\ExamSubmissions\\SE180001",
  "bannedKeywords": ["Process.Start", "Registry"]
}
```

Sau đó Engine đọc:

- `GET /api/Plagiarism/submissions/{submissionId}`
- `GET /api/Plagiarism/exams/{examId}/comparisons`

## Callback về Central

`POST /api/integration/grading-items/{id}/plagiarism` dùng execution token:

```json
{
  "status": "Completed",
  "violationCount": 1,
  "maxSimilarity": 0,
  "rawJsonReport": "{...}",
  "errorMessage": "",
  "checkedAtUtc": "2026-07-23T00:00:00Z"
}
```

Nếu Plagiarism không truy cập được, Engine callback `TechnicalError` cho nhánh plagiarism nhưng vẫn tiếp tục gửi attempt chấm. Lỗi quét không biến kết quả chấm hợp lệ thành lỗi kỹ thuật.

## RabbitMQ

- `grading-jobs`: Central publish khi phân công batch.
- `grading-results`: Central publish các thay đổi/cảnh báo nghiệp vụ.
- `plagiarism-alerts`: Plagiarism Service publish khi phát hiện từ khóa cấm.
- Notification Service consume cả ba queue và push SignalR theo `ExamId`.

RabbitMQ cấu hình qua `RabbitMQ:Enabled`, `HostName`, `Port`, `UserName`, `Password`. Mặc định local là `localhost:5672`, `guest/guest`.
