# Plagiarism Integration Flow v2

```text
Local Grading Agent
  -> POST /api/integration/fingerprints (hoặc event fingerprint.created)
  -> Plagiarism Service lưu và so sánh
  -> event plagiarism.alert.created
  -> Central Workflow Service lưu cảnh báo
  -> event notification.requested
  -> Notification Service / SignalR
  -> Dashboard Khảo thí
```

## Ownership

| Thành phần | Trách nhiệm |
|---|---|
| Local Agent | Đọc source local, chuẩn hoá, tạo fingerprint |
| Plagiarism Service | Lưu fingerprint, so sánh, tạo cảnh báo |
| Central Service | Phân quyền, gắn cảnh báo vào ca thi/bài chấm |
| Notification Service | Chỉ chuyển notification event qua SignalR |
| Khảo thí | Xác minh và kết luận cảnh báo |

## Queue topology

```text
exchange: plagiarism.exchange (topic)
  fingerprint.created -> plagiarism-fingerprint-worker
  alert.created       -> central-plagiarism-alerts

exchange: notification.exchange (topic)
  notification.requested -> notification-signalr
```

Mỗi service có queue riêng. Notification Service không consume `grading-jobs`, `grading-results` hoặc queue thuộc service khác.

## Failure handling

- API/event nhận fingerprint trả về thành công khi đã lưu idempotently.
- Lỗi tạm thời retry tối đa theo cấu hình.
- Payload sai chuyển dead-letter queue và ghi correlation id.
- Plagiarism lỗi không đổi trạng thái kết quả chấm và không ngăn Khảo thí duyệt điểm.

