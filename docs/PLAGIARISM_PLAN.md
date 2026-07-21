# Plagiarism Plan v2 - mô hình chấm bài trên máy giảng viên

## 1. Nguyên tắc

- Bài thi nằm trên máy giảng viên; Central Service không lưu và không nhận `WorkspacePath`.
- Plagiarism Service không được mở đường dẫn local của giảng viên.
- Plagiarism chạy sau khi một bài có kết quả chấm hợp lệ, không chặn việc gửi điểm.
- Dữ liệu trao đổi là fingerprint đã chuẩn hoá và metadata, không phải đường dẫn máy.
- Cảnh báo plagiarism chỉ dành cho Khảo thí; giảng viên chỉ thấy khi Khảo thí trả bài/yêu cầu kiểm tra.

## 2. Luồng đề xuất

1. Local Grading Agent đọc source trên máy giảng viên.
2. Agent loại bỏ file build/generated, comment, whitespace và literal không cần thiết.
3. Agent tạo Winnowing fingerprints và quét GUID project bất thường.
4. Agent gửi `SubmissionFingerprintCreated` lên API/Event Gateway.
5. Plagiarism Service lưu fingerprint theo `ExamSessionId`, `ExamPaperCode`, `StudentCode`, `GradingAttemptId`.
6. Service so sánh với các bài cùng ca thi/mã đề.
7. Khi vượt ngưỡng, service phát `PlagiarismAlertCreated` vào queue riêng.
8. Central Service lưu cảnh báo; Notification Service chỉ consume queue notification riêng và push SignalR cho Khảo thí.

## 3. Contract fingerprint

```json
{
  "eventId": "uuid",
  "examSessionId": "uuid",
  "examPaperCode": "PRN223-A",
  "gradingItemId": "uuid",
  "gradingAttemptId": "uuid",
  "studentCode": "SE180001",
  "algorithm": "winnowing-v1",
  "fingerprints": [123456789, 987654321],
  "projectGuids": ["{GUID}"],
  "sourceFileCount": 24,
  "createdAtUtc": "2026-07-21T10:00:00Z"
}
```

Không được thêm `WorkspacePath`, access token, source code đầy đủ hoặc connection string vào event.

## 4. Quy tắc so sánh

- Chỉ so sánh bài cùng `ExamSessionId`; mặc định ưu tiên cùng `ExamPaperCode`.
- Không tự kết luận gian lận. Kết quả chỉ là `Suspicious`, cần Khảo thí xác minh.
- Lưu cả score, số fingerprint trùng, GUID trùng và phiên bản thuật toán.
- Regrade cùng một bài tạo attempt mới nhưng so sánh theo fingerprint mới nhất.
- Event phải idempotent theo `eventId` và `gradingAttemptId`.

## 5. Trạng thái cảnh báo

`New -> UnderReview -> Confirmed | Dismissed`

Khảo thí là role duy nhất được đổi trạng thái. Admin không được xem; giảng viên không tự xác nhận.

## 6. Việc cần sửa trong Plagiarism Service

- Bỏ contract `SubmissionGradedEvent` chứa `WorkspacePath`.
- Thêm endpoint/event nhận fingerprint.
- Tạo unique index cho `GradingAttemptId`.
- Tách queue `plagiarism.fingerprint.created` và `plagiarism.alert.created`.
- Không dùng default exchange với queue dùng chung.
- Thêm retry có giới hạn và dead-letter queue; không requeue vô hạn message lỗi.

