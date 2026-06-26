# Project & Function Plan — PRN232 PE Evaluation Tool

> Project Code: CP-2025-01 | Group: G-05
> Tài liệu này mô tả danh sách chức năng (functional requirements), phân chia theo actor, và kế hoạch triển khai theo từng giai đoạn (sprint). Đi kèm với `01-technical-architecture-plan.md`.

---

## 1. Actor & Vai trò

| Actor | Vai trò trong hệ thống |
|---|---|
| Sinh viên (Thí sinh) | Nộp bài thi qua Desktop client, xem kết quả chấm điểm |
| Giảng viên chấm thi (Examiner) | Upload đề thi, upload test case/rubric, theo dõi quá trình thi, công bố điểm |
| Admin hệ thống | Quản trị tài khoản, cấu hình hệ thống, quản lý Docker image/sandbox |

---

## 2. Danh sách chức năng (Function List)

### 2.1 Module quản lý đề thi (Admin/Giảng viên)

| Mã | Chức năng | Mô tả |
|---|---|---|
| F-01 | Upload đề thi | Giảng viên upload project mẫu/skeleton cho sinh viên |
| F-02 | Upload rubric chấm điểm | Upload file JSON định nghĩa band, section, weight (theo cấu trúc ở mục 4) |
| F-03 | Upload test project theo section | Upload các project test (CRUD, Auth, Validation...) dùng để chấm Band 2 |
| F-04 | Quản lý kỳ thi (Exam) | Tạo/sửa/xoá kỳ thi, gắn rubric + đề thi tương ứng |
| F-05 | Theo dõi tiến trình thi real-time | Xem danh sách sinh viên đã nộp/chưa nộp, trạng thái chấm |
| F-06 | Xem báo cáo chấm điểm chi tiết | Xem JSON report từng band/section của từng sinh viên |
| F-07 | Công bố điểm | Chuyển trạng thái điểm từ "draft" sang "published" |
| F-08 | Xem báo cáo nghi vấn gian lận | Danh sách các cặp bài nộp có độ tương đồng code cao |

### 2.2 Module nộp bài & xem kết quả (Sinh viên — Desktop client đã có)

| Mã | Chức năng | Mô tả | Trạng thái |
|---|---|---|---|
| F-09 | Tải đề thi | Sinh viên tải project skeleton xuống máy | Đã có |
| F-10 | Nộp bài (.zip) | Đóng gói và nộp bài lên server | Đã có |
| F-11 | Xem kết quả chấm | Hiển thị điểm theo band/section ngay khi có | Đã có |

> Module 2.2 đã được triển khai sẵn ở client — **không nằm trong phạm vi phát triển của plan này**, chỉ cần đảm bảo API trả đúng `GradingReportDto` theo contract đã định nghĩa ở Architecture Plan mục 3.

### 2.3 Module chấm điểm tự động (Grading Engine — trọng tâm phát triển)

| Mã | Chức năng | Band | Mô tả kỹ thuật |
|---|---|---|---|
| F-12 | Giải nén & validate file nộp | — | Kiểm tra file .zip hợp lệ, giới hạn kích thước, giải nén vào thư mục tạm cách ly |
| F-13 | Kiểm tra cấu trúc project tĩnh | Band 0 | Quét 3 project Business/API/Repository, kiểm tra naming convention |
| F-14 | Kiểm tra `appsettings.json` tồn tại & hợp lệ | Band 0 | Parse JSON, kiểm tra key `ConnectionStrings` tồn tại |
| F-15 | Phát hiện hardcode connection string trong DbContext | Band 0 | Dùng Roslyn quét `OnConfiguring`, phát hiện chuỗi `UseSqlServer("...")` literal |
| F-16 | Build solution trong sandbox | Band 1 | Chạy `dotnet build` trong Docker container, bắt lỗi compile |
| F-17 | Chạy test section CRUD | Band 2a | `dotnet test --filter Category=CRUD`, parse `.trx` |
| F-18 | Chạy test section Auth | Band 2b | Tương tự F-17, filter `Category=Auth` |
| F-19 | Chạy test section Validation | Band 2c | Tương tự F-17, filter `Category=Validation` |
| F-20 | Tổng hợp điểm theo weight | Band 3 | Domain logic tính tổng điểm từ kết quả các band/section |
| F-21 | Xuất JSON report chuẩn hoá | Band 3 | Sinh báo cáo theo cấu trúc đã thống nhất |
| F-22 | Phát hiện trùng lặp code (plagiarism) | Song song | Thuật toán Winnowing, chạy độc lập không chặn luồng chấm điểm chính |
| F-23 | Quản lý queue & worker pool | Hạ tầng | Đảm bảo C-03 (≤15s/bài) khi nhiều sinh viên nộp cùng lúc |

### 2.4 Module hạ tầng & vận hành

| Mã | Chức năng | Mô tả |
|---|---|---|
| F-24 | Quản lý Docker image chấm bài | Admin có thể cập nhật image khi đổi version .NET SDK |
| F-25 | Logging & audit trail | Ghi log toàn bộ quá trình chấm để truy vết khi có khiếu nại |
| F-26 | Cấu hình timeout/giới hạn tài nguyên container | Cho phép Admin điều chỉnh không cần sửa code |

---

## 3. Ánh xạ chức năng vào layer kiến trúc

| Chức năng | Domain | Application | Infrastructure | Presentation |
|---|---|---|---|---|
| F-13, F-14, F-15 | `GradingBand`, rule pass/fail | `CheckStaticStructureHandler` | `RoslynStructureAnalyzer` | — |
| F-16 | `BuildResult` entity | `BuildSolutionHandler` | `DockerSandboxRunner` | — |
| F-17, F-18, F-19 | `TestSectionResult` | `RunTestSectionHandler` | `DotnetTestRunner`, `TrxResultParser` | — |
| F-20, F-21 | `SubmissionAggregate.CalculateTotalScore()` | `AggregateScoreHandler` | — | — |
| F-22 | — | `CheckPlagiarismHandler` | `WinnowingPlagiarismChecker` | — |
| F-01–F-08 | `Exam`, `Rubric` entities | Các Command/Query tương ứng | `ExamRepository` | `ExamController` |
| F-23 | — | — | `GradingQueueService` (Hosted Service) | — |

---

## 4. Cấu trúc Rubric JSON (Input cho F-02, dùng xuyên suốt F-13 → F-21)

```json
{
  "examId": "PRN232-PE-2026-SU1",
  "structureRules": {
    "requiredProjects": ["*.API", "*.Business", "*.Repository"],
    "requireAppSettings": true,
    "forbidHardcodedConnectionString": true
  },
  "sections": [
    { "name": "CRUD", "weight": 30, "testFilter": "Category=CRUD" },
    { "name": "Auth", "weight": 25, "testFilter": "Category=Auth" },
    { "name": "Validation", "weight": 20, "testFilter": "Category=Validation" }
  ],
  "timeoutSeconds": 15
}
```

Rubric này được Admin/Giảng viên upload qua F-02, lưu trong DB, và Application layer đọc ra để điều phối — **không hardcode trong code**, đúng nguyên tắc mà chính hệ thống phải tuân thủ.

---

## 5. Kế hoạch triển khai theo Sprint (4 tháng, ước lượng 2 sprint/tháng, mỗi sprint 2 tuần)

### Sprint 1–2 (Tháng 1): Nền tảng & Domain
- Setup solution structure theo Architecture Plan.
- Định nghĩa toàn bộ Domain entities, Value Objects, Aggregate (`SubmissionAggregate`).
- Định nghĩa toàn bộ interface ở Application layer (`ISandboxRunner`, `IStaticCodeAnalyzer`, `ITestResultParser`, `IPlagiarismChecker`).
- Viết unit test cho Domain (tính điểm, band rule) — chạy được mà chưa cần Infrastructure.
- Setup CI pipeline cơ bản (build + test Domain/Application).

### Sprint 3–4 (Tháng 2): Band 0 & Band 1
- Triển khai `RoslynStructureAnalyzer` (F-13, F-14, F-15).
- Triển khai `DockerSandboxRunner` cơ bản — build container, chạy `dotnet build` (F-16).
- Benchmark thời gian khởi động container, tối ưu để đáp ứng C-03.
- API endpoint nhận bài nộp + trigger Band 0/1 (F-12).

### Sprint 5–6 (Tháng 3): Band 2 & Tổng hợp điểm
- Triển khai `DotnetTestRunner` + `TrxResultParser` (F-17, F-18, F-19).
- Triển khai `AggregateScoreHandler` (F-20, F-21).
- Triển khai queue/worker pool đảm bảo xử lý song song (F-23).
- Module Admin: upload đề thi, upload rubric, theo dõi tiến trình (F-01–F-05).

### Sprint 7–8 (Tháng 4): Plagiarism, hoàn thiện & kiểm thử
- Triển khai `WinnowingPlagiarismChecker` (F-22).
- Module xem báo cáo, công bố điểm (F-06, F-07, F-08).
- Integration test toàn luồng (API → Sandbox → DB).
- Load test: giả lập nhiều sinh viên nộp bài đồng thời, đo lại C-03.
- Viết tài liệu vận hành, chuẩn bị demo/báo cáo capstone.

---

## 6. Phân chia công việc gợi ý (4 thành viên)

| Thành viên | Phụ trách chính | Chức năng liên quan |
|---|---|---|
| Pham Tan Loc | Domain + Application core, tổng hợp điểm | F-20, F-21, toàn bộ Domain/Aggregate |
| Tran Duc Linh | Static Analysis (Roslyn) + Band 0 | F-13, F-14, F-15 |
| Tran Anh Duy | Sandbox/Docker + Band 1, Band 2 | F-16, F-17, F-18, F-19, F-23 |
| Tran Thai Thinh | Module Admin/API + Plagiarism | F-01–F-08, F-22 |

> Phân chia này tận dụng được tính tách biệt của Clean Architecture: 2 người làm Infrastructure (Docker, Roslyn) có thể làm song song với người làm Domain/Application, vì giao tiếp qua interface đã định nghĩa sẵn từ Sprint 1.

---

## 7. Định nghĩa "Hoàn thành" (Definition of Done) cho mỗi chức năng

Một chức năng được coi là hoàn thành khi:
1. Code tuân thủ đúng layer trong Architecture Plan (không vi phạm Dependency Rule).
2. Có unit test cho Domain/Application liên quan, coverage ≥ 80% cho phần Domain.
3. Build pass trên CI (GitHub Actions).
4. Đã review bởi ít nhất 1 thành viên khác trong team qua Pull Request.
5. Không hardcode giá trị cấu hình (connection string, timeout, weight...) — phải đọc từ `appsettings.json` hoặc rubric JSON.
