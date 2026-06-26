# Technical Architecture Plan — PRN232 PE Evaluation Tool (v2)

> Project Code: CP-2025-01 | Group: G-05
> v2 — cập nhật sau buổi thảo luận sâu, chốt 14 quyết định kỹ thuật cụ thể. Áp dụng **Clean Architecture** + **Domain-Driven Design (DDD)**, kiến trúc tổng thể gồm **2 service tách rời**: Grading Engine và Admin Portal.

---

## 1. Mục tiêu kiến trúc

Hệ thống phải đáp ứng các ràng buộc đã chốt trong Capstone Information Sheet:

- **C-01**: Hoạt động hoàn toàn trong mạng nội bộ (offline), không phụ thuộc Internet.
- **C-02**: Tương thích .NET 8 / .NET Core.
- **C-03**: Thời gian chấm 1 bài thi không vượt quá 15 giây.
- **C-04**: Thời gian phát triển giới hạn 1 học kỳ.

Nghiệp vụ chấm điểm có logic phức tạp và nhiều quy tắc thay đổi theo thời gian (band điểm, section test, trọng số) — đây là lý do chọn DDD: domain logic (luật chấm điểm) tách biệt hoàn toàn khỏi chi tiết kỹ thuật (Docker, EF Core, RabbitMQ), để khi rubric thay đổi, ta chỉ sửa Domain/Application, không đụng Infrastructure.

---

## 2. Bảng tổng hợp 14 quyết định kỹ thuật đã chốt

| # | Vấn đề | Quyết định | Lý do chính |
|---|---|---|---|
| 1 | Điều phối pipeline chấm điểm | Orchestrator + chạy song song Band 2 | Giảm thời gian chấm (đáp ứng C-03), cho phép re-grade từng band riêng |
| 2 | Quản lý container cho Band 2 | Container pool pre-warm, mỗi section vẫn tách container riêng | Vừa cách ly tốt, vừa giảm cold-start latency |
| 3 | Container sạch giữa các lần dùng | Tái sử dụng container instance, tự reset | Tiết kiệm tài nguyên hơn so với huỷ-tạo-mới liên tục |
| 4 | Cơ chế reset cụ thể | Read-only container + volume mount riêng theo job | Loại bỏ tận gốc rủi ro leak state, không cần "nhớ" dọn dẹp |
| 5 | NuGet cache khi offline | Named volume dùng chung, mount read-only lúc thi | Tách dữ liệu hạ tầng (cache) khỏi dữ liệu theo job, không cần rebuild image khi đổi package |
| 6 | Grading Engine vs Admin Portal | 2 service .NET tách rời hoàn toàn | Scale độc lập, cô lập lỗi, theo đúng lựa chọn của team |
| 7 | Giao tiếp giữa 2 service | RabbitMQ (Message Queue thật) | Tách rời thời gian xử lý, có buffer khi nhiều sinh viên nộp cùng lúc |
| 8 | Giảng viên review/chấm lại | Log chi tiết đầy đủ + container replay giữ lại có thời hạn | Vừa rẻ (log) vừa chính xác (replay đúng môi trường thật) |
| 9 | Nút "mở VS Code" cho giảng viên | Mở VS Code local qua network share (UNC path) | Đơn giản, không cần thêm hạ tầng code-server |
| 10 | Plagiarism detection | Chưa chốt — để mở, làm cùng AI trong giai đoạn còn lại | Cần thêm thời gian để quyết định Winnowing tự viết hay JPlag |
| 11 | Container runtime | Docker | Giữ nguyên, team đã quen |
| 12 | Real-time push cho Admin UI | SignalR | Chuẩn .NET, hỗ trợ 2 chiều, có fallback |
| 13 | API style | REST cho Grading Engine (machine-to-machine), GraphQL cho Admin UI | REST đơn giản cho service nội bộ, GraphQL linh hoạt cho UI cần nhiều dạng dữ liệu |
| 14 | Authentication | JWT Access token + Refresh token | Chuẩn phổ biến, đủ an toàn cho quy mô hệ thống |

---

## 3. Kiến trúc tổng thể — 2 service tách rời

```
┌──────────────────────────┐         ┌──────────────────────────┐
│   ADMIN PORTAL SERVICE   │         │   GRADING ENGINE SERVICE │
│   (GraphQL + SignalR)    │         │   (REST API + Worker)    │
│                          │         │                          │
│  - Quản lý đề thi/rubric │         │  - Nhận job từ queue      │
│  - Theo dõi tiến trình   │◄───────►│  - Static check (Band 0)  │
│  - Xem báo cáo điểm      │ RabbitMQ│  - Build (Band 1)         │
│  - Công bố điểm          │         │  - Test sections (Band 2) │
│  - Quản lý tài khoản GV  │         │  - Aggregate score (Band 3)│
└───────────┬──────────────┘         └───────────┬──────────────┘
            │                                    │
            │         ┌──────────────┐           │
            └────────►│  SQL Server  │◄──────────┘
                      │  (dùng chung) │
                      └──────────────┘
                                                  │
                                       ┌──────────▼──────────┐
                                       │  Docker Sandbox Pool │
                                       │  (container reuse,   │
                                       │   read-only + volume)│
                                       └──────────────────────┘
```

**Luồng chính:**
1. Sinh viên nộp bài qua WPF Client (đã có sẵn) → gọi API của Grading Engine.
2. Grading Engine đẩy job vào RabbitMQ queue `grading-jobs`.
3. Admin Portal cũng đẩy lệnh (re-grade, cấu hình) vào cùng queue nếu cần.
4. Grading Engine Worker tiêu thụ job, chạy pipeline Band 0→1→2→3 qua Docker Sandbox Pool.
5. Kết quả ghi vào SQL Server dùng chung + đẩy message vào queue `grading-results`.
6. Admin Portal lắng nghe `grading-results`, cập nhật real-time cho giảng viên qua SignalR.

---

## 4. Clean Architecture trong từng service

Mỗi service (Grading Engine, Admin Portal) đều tuân theo 4 layer chuẩn, **dùng chung Domain và 1 phần Application** thông qua shared library (NuGet package nội bộ hoặc project reference qua Git submodule/source link).

```
shared/
├── PRN232.Domain/              (dùng chung bởi cả 2 service)
│   ├── Entities/
│   ├── ValueObjects/
│   ├── Aggregates/
│   ├── DomainEvents/
│   └── Interfaces/

grading-engine/
├── PRN232.GradingEngine.Application/
│   ├── UseCases/
│   │   ├── CheckStaticStructure/    (Band 0)
│   │   ├── BuildSolution/           (Band 1)
│   │   ├── RunTestSection/          (Band 2)
│   │   └── AggregateScore/          (Band 3)
│   └── Interfaces/
│       ├── ISandboxRunner.cs
│       ├── IStaticCodeAnalyzer.cs
│       ├── ITestResultParser.cs
│       └── IPlagiarismChecker.cs
├── PRN232.GradingEngine.Infrastructure/
│   ├── Sandbox/
│   │   ├── DockerSandboxPool.cs         // quyết định #2, #3, #4
│   │   ├── ContainerLifecycleManager.cs
│   │   └── NuGetVolumeConfig.cs         // quyết định #5
│   ├── StaticAnalysis/
│   │   └── RoslynStructureAnalyzer.cs
│   ├── TestExecution/
│   │   ├── DotnetTestRunner.cs
│   │   └── TrxResultParser.cs
│   ├── Messaging/
│   │   ├── RabbitMqJobConsumer.cs       // quyết định #7
│   │   └── RabbitMqResultPublisher.cs
│   └── Replay/
│       └── ReplayContainerManager.cs    // quyết định #8 (giữ container có thời hạn)
└── PRN232.GradingEngine.Api/
    ├── Controllers/   (REST — quyết định #13)
    ├── appsettings.json
    └── Program.cs

admin-portal/
├── PRN232.AdminPortal.Application/
│   ├── UseCases/
│   │   ├── ManageExam/
│   │   ├── ManageRubric/
│   │   └── ViewGradingReport/
│   └── Interfaces/
│       └── IGradingJobPublisher.cs
├── PRN232.AdminPortal.Infrastructure/
│   ├── Persistence/
│   │   └── ApplicationDbContext.cs      // không hardcode connection string
│   ├── Messaging/
│   │   ├── RabbitMqJobPublisher.cs
│   │   └── RabbitMqResultConsumer.cs
│   ├── Auth/
│   │   ├── JwtTokenGenerator.cs         // quyết định #14
│   │   └── RefreshTokenStore.cs
│   └── RealTime/
│       └── GradingHub.cs                // SignalR — quyết định #12
└── PRN232.AdminPortal.Api/
    ├── GraphQL/                          // quyết định #13
    │   ├── Queries/
    │   ├── Mutations/
    │   └── Subscriptions/
    ├── appsettings.json
    └── Program.cs
```

---

## 5. Domain Layer chi tiết

Domain layer là phần dùng chung, không phụ thuộc bất kỳ công nghệ nào (không Docker, không RabbitMQ, không EF Core attribute).

### 5.1 Value Objects (bất biến)

```csharp
namespace PRN232.Domain.ValueObjects;

public sealed class Score : IEquatable<Score>
{
    public decimal Value { get; }
    public decimal MaxValue { get; }

    private Score(decimal value, decimal maxValue)
    {
        Value = value;
        MaxValue = maxValue;
    }

    public static Score Create(decimal value, decimal maxValue)
    {
        if (value < 0)
            throw new InvalidGradingStateException("Score không thể âm.");
        if (value > maxValue)
            throw new InvalidGradingStateException("Score vượt quá điểm tối đa.");

        return new Score(value, maxValue);
    }

    public static Score Zero(decimal maxValue) => new(0, maxValue);

    public Score Add(Score other)
    {
        var newMax = MaxValue + other.MaxValue;
        return Create(Value + other.Value, newMax);
    }

    public bool Equals(Score? other) =>
        other is not null && Value == other.Value && MaxValue == other.MaxValue;

    public override bool Equals(object? obj) => Equals(obj as Score);
    public override int GetHashCode() => HashCode.Combine(Value, MaxValue);
}
```

```csharp
public sealed class GradingBand : IEquatable<GradingBand>
{
    public int BandLevel { get; }
    public string Name { get; }
    public bool IsBlocking { get; }  // true = fail thì dừng pipeline (band 0, 1)

    private GradingBand(int bandLevel, string name, bool isBlocking)
    {
        BandLevel = bandLevel;
        Name = name;
        IsBlocking = isBlocking;
    }

    public static readonly GradingBand StaticStructure = new(0, "Static Structure", isBlocking: true);
    public static readonly GradingBand Build = new(1, "Build", isBlocking: true);
    public static readonly GradingBand TestSection = new(2, "Test Section", isBlocking: false);

    public bool Equals(GradingBand? other) => other is not null && BandLevel == other.BandLevel;
    public override bool Equals(object? obj) => Equals(obj as GradingBand);
    public override int GetHashCode() => BandLevel.GetHashCode();
}
```

### 5.2 Aggregate Root — nơi enforce rule fail-fast

```csharp
namespace PRN232.Domain.Aggregates;

// MỌI thay đổi liên quan đến 1 bài nộp phải đi qua đây.
// Rule "không chấm Band sau khi Band trước fail" được enforce NGAY TRONG aggregate,
// không phải ở Application Handler — đảm bảo không thể có state sai dù code gọi sai thứ tự.
public class SubmissionAggregate
{
    public Guid Id { get; private set; }
    public Guid StudentId { get; private set; }
    public Guid ExamId { get; private set; }

    private bool _band0Passed;
    private bool _band1Passed;
    private readonly List<TestSectionResult> _sectionResults = new();
    public IReadOnlyList<TestSectionResult> SectionResults => _sectionResults.AsReadOnly();

    private readonly List<object> _domainEvents = new();
    public IReadOnlyList<object> DomainEvents => _domainEvents.AsReadOnly();

    private SubmissionAggregate() { }

    public static SubmissionAggregate Create(Guid studentId, Guid examId) => new()
    {
        Id = Guid.NewGuid(),
        StudentId = studentId,
        ExamId = examId
    };

    public void RecordBand0Result(bool passed, IReadOnlyList<string> violations)
    {
        _band0Passed = passed;
        if (!passed)
            _domainEvents.Add(new BandFailedEvent(Id, GradingBand.StaticStructure, violations));
    }

    public void RecordBand1Result(bool passed, IReadOnlyList<string> buildErrors)
    {
        if (!_band0Passed)
            throw new InvalidGradingStateException("Không thể chấm Band 1 khi Band 0 chưa pass.");

        _band1Passed = passed;
        if (!passed)
            _domainEvents.Add(new BandFailedEvent(Id, GradingBand.Build, buildErrors));
    }

    public void AddSectionResult(TestSectionResult result)
    {
        if (!_band0Passed || !_band1Passed)
            throw new InvalidGradingStateException("Không thể chấm Test Section khi Band 0/1 chưa pass.");

        _sectionResults.Add(result);
    }

    public Score CalculateTotalScore()
    {
        if (!_band0Passed || !_band1Passed)
            return Score.Zero(100);

        var total = _sectionResults
            .Select(r => r.CalculateScore())
            .Aggregate(Score.Zero(0), (acc, s) => acc.Add(s));

        _domainEvents.Add(new SubmissionGradedEvent(Id, total.Value));
        return total;
    }
}
```

---

## 6. Application Layer — Orchestrator pipeline (quyết định #1)

```csharp
namespace PRN232.GradingEngine.Application;

public class GradingPipelineOrchestrator
{
    private readonly IMediator _mediator;

    public async Task<Result<GradingReportDto>> ExecuteAsync(Guid submissionId, RubricConfig rubric)
    {
        // Band 0 — static structure check, dừng ngay nếu fail
        var band0 = await _mediator.Send(new CheckStaticStructureCommand(submissionId, rubric.StructureRules));
        if (band0.IsFailed)
            return Result.Fail<GradingReportDto>(MapToZeroScoreReport(band0));

        // Band 1 — build, dừng ngay nếu fail
        var band1 = await _mediator.Send(new BuildSolutionCommand(submissionId));
        if (band1.IsFailed)
            return Result.Fail<GradingReportDto>(MapToZeroScoreReport(band1));

        // Band 2 — chạy SONG SONG các section (quyết định #1, #2)
        var sectionTasks = rubric.Sections.Select(section =>
            _mediator.Send(new RunTestSectionCommand(submissionId, section)));
        var sectionResults = await Task.WhenAll(sectionTasks);

        // Band 3 — tổng hợp điểm (Domain logic)
        var finalReport = await _mediator.Send(new AggregateScoreCommand(submissionId, sectionResults));

        return Result.Ok(finalReport);
    }
}
```

**Lưu ý quan trọng**: `Task.WhenAll` ở Band 2 chỉ hợp lệ vì mỗi `RunTestSectionCommand` sẽ lấy 1 container riêng từ pool (quyết định #2) — không có tranh chấp tài nguyên giữa các Task chạy song song.

---

## 7. Infrastructure — Sandbox Runner chi tiết (quyết định #2, #3, #4, #5)

### 7.1 Container Pool với reset read-only

```csharp
namespace PRN232.GradingEngine.Infrastructure.Sandbox;

public class DockerSandboxPool : ISandboxRunner
{
    private readonly ConcurrentQueue<ContainerHandle> _idlePool = new();
    private readonly SemaphoreSlim _poolLock = new(initialCount: PoolSize);

    public async Task<SandboxResult> RunInSandboxAsync(string submissionWorkspacePath, string command, CancellationToken ct)
    {
        await _poolLock.WaitAsync(ct);
        try
        {
            var container = await AcquireContainerAsync();

            // Mount riêng theo job — container chính bản thân là read-only (quyết định #4)
            // /workspace là volume riêng cho submission này, /tmp là tmpfs tự xoá
            var runOptions = new ContainerRunOptions
            {
                ReadOnlyRootFs = true,
                Mounts = new[]
                {
                    new Mount("/workspace", submissionWorkspacePath, MountType.Bind, ReadOnly: false),
                    new Mount("/tmp", null, MountType.Tmpfs, ReadOnly: false, SizeMb: 100),
                    new Mount("/root/.nuget/packages", "nuget-shared-cache", MountType.Volume, ReadOnly: true) // quyết định #5
                },
                TimeoutSeconds = 15 // đáp ứng C-03
            };

            var result = await container.ExecAsync(command, runOptions, ct);

            // Vì /workspace và /tmp là 2 nơi DUY NHẤT có thể viết, và cả 2 đều ephemeral theo job,
            // container có thể trả về pool NGAY mà không cần script dọn dẹp riêng (quyết định #3+#4 kết hợp)
            ReleaseContainerToPool(container);

            return result;
        }
        finally
        {
            _poolLock.Release();
        }
    }
}
```

### 7.2 NuGet volume setup (quyết định #5) — vận hành 1 lần/kỳ thi

```bash
# Bước 1 (lúc có mạng, trước kỳ thi): tạo và populate volume
docker volume create nuget-shared-cache
docker run --rm -v nuget-shared-cache:/root/.nuget/packages \
  -v ./sample-project:/src -w /src \
  mcr.microsoft.com/dotnet/sdk:8.0 dotnet restore

# Bước 2 (lúc thi, offline): mount read-only cho mọi container job
docker run --rm \
  -v nuget-shared-cache:/root/.nuget/packages:ro \
  -v /tmp/submission-{id}:/workspace:rw \
  --read-only \
  --tmpfs /tmp:rw,size=100m \
  grading-image dotnet build /workspace
```

---

## 8. Messaging giữa 2 service (quyết định #7 — RabbitMQ)

### 8.1 Lý do chọn RabbitMQ thay vì DB-as-queue

Sau khi đã tách Grading Engine và Admin Portal thành 2 service độc lập (quyết định #6), việc giao tiếp đồng bộ hoặc qua DB polling sẽ tạo coupling ngầm và khó scale. RabbitMQ cho phép:
- Admin Portal đẩy job mà không cần biết Grading Engine có đang online hay không.
- Buffer tự nhiên khi nhiều sinh viên nộp cùng lúc (đáp ứng C-03 ở mức hệ thống, không chỉ ở mức 1 bài).
- Routing linh hoạt (ví dụ ưu tiên job re-grade lên trước job thường, qua priority queue).

### 8.2 Cấu trúc queue

```
Exchange: grading.exchange (type: direct)
├── Queue: grading-jobs           (Admin Portal/WPF → Grading Engine)
│     routing key: "job.new"
├── Queue: grading-jobs.regrade   (ưu tiên cao hơn — re-grade theo yêu cầu giảng viên)
│     routing key: "job.regrade"
└── Queue: grading-results        (Grading Engine → Admin Portal)
      routing key: "result.done"
```

### 8.3 Publisher (Admin Portal)

```csharp
public class RabbitMqJobPublisher : IGradingJobPublisher
{
    public Task PublishAsync(GradingJobMessage message, bool isRegrade)
    {
        var routingKey = isRegrade ? "job.regrade" : "job.new";
        _channel.BasicPublish(
            exchange: "grading.exchange",
            routingKey: routingKey,
            body: JsonSerializer.SerializeToUtf8Bytes(message));
        return Task.CompletedTask;
    }
}
```

### 8.4 Consumer (Grading Engine)

```csharp
public class RabbitMqJobConsumer : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.Received += async (sender, ea) =>
        {
            var message = JsonSerializer.Deserialize<GradingJobMessage>(ea.Body.ToArray());
            await _orchestrator.ExecuteAsync(message.SubmissionId, message.Rubric);
            _channel.BasicAck(ea.DeliveryTag, multiple: false);
        };
        _channel.BasicConsume(queue: "grading-jobs", autoAck: false, consumer: consumer);
        await Task.Delay(Timeout.Infinite, ct);
    }
}
```

> **Ghi chú vận hành quan trọng (đáp ứng C-01)**: RabbitMQ phải được **tự host trong mạng nội bộ** (RabbitMQ Docker image hoặc Windows service), không dùng dịch vụ cloud (CloudAMQP...). Cần thêm bước cài đặt RabbitMQ vào tài liệu vận hành/triển khai trước kỳ thi.

---

## 9. Giảng viên review & chấm lại (quyết định #8, #9)

### 9.1 Log chi tiết (luôn có, mọi lần chấm)

Mỗi lần chấm, Grading Engine ghi lại đầy đủ:
```json
{
  "submissionId": "...",
  "band0": { "checkedRules": [...], "violations": [...] },
  "band1": { "buildOutput": "full stdout/stderr của dotnet build", "exitCode": 0 },
  "band2": {
    "CRUD": { "trxRawOutput": "...", "durationMs": 4231 },
    "Auth": { "trxRawOutput": "...", "durationMs": 2104 }
  },
  "timestamps": { "startedAt": "...", "finishedAt": "..." }
}
```
Giảng viên đọc log này trong Admin Portal trước, đa số trường hợp khiếu nại được giải quyết ở đây mà không cần chạy lại.

### 9.2 Container replay (khi log không đủ, cần chạy lại thật)

```csharp
public class ReplayContainerManager
{
    private readonly TimeSpan _replayTtl = TimeSpan.FromMinutes(30);

    public async Task<ReplaySession> CreateReplayAsync(Guid submissionId)
    {
        // Tái tạo đúng môi trường: cùng image, cùng NuGet volume, cùng workspace đã build
        var container = await _dockerClient.RunAsync(new ContainerRunOptions
        {
            Image = "grading-image",
            Mounts = GetSameMountsAsOriginalJob(submissionId),
            AutoRemove = false // KHÔNG tự xoá ngay — khác với job chấm bình thường
        });

        ScheduleAutoCleanup(container.Id, _replayTtl);

        return new ReplaySession(container.Id, ExpiresAt: DateTime.UtcNow.Add(_replayTtl));
    }
}
```

### 9.3 Nút "Mở VS Code" (quyết định #9)

Vì thư mục submission (`/workspace` mount) thực tế nằm trên ổ đĩa máy chủ chấm bài, expose qua network share nội bộ:

```csharp
// Admin Portal — sinh link UNC, KHÔNG mở trực tiếp được từ browser nên dùng custom URI scheme
public string BuildVsCodeUri(Guid submissionId)
{
    var uncPath = $@"\\grading-server\submissions\{submissionId}";
    return $"vscode://file/{uncPath}";
}
```
```html
<!-- Admin UI: nút mở, click sẽ trigger VS Code local của giảng viên (cần VS Code đã cài + có quyền truy cập network share) -->
<a href="vscode://file/\\grading-server\submissions\{id}">Mở bằng VS Code</a>
```

> Giới hạn cần ghi rõ cho người dùng: cách này cho giảng viên thấy **code đã build xong** (kết quả tĩnh), không phải môi trường runtime đang chạy như container replay — phù hợp cho việc đọc code, không phù hợp để debug runtime behavior. Nếu cần debug sâu, dùng kết hợp với 9.2.

---

## 10. API style (quyết định #13)

| Service | Style | Lý do |
|---|---|---|
| Grading Engine | REST (ASP.NET Core Web API) | Giao tiếp machine-to-machine (WPF client, internal call) — REST đơn giản, dễ versioning, dễ test bằng Postman/curl |
| Admin Portal | GraphQL (HotChocolate) | UI Admin cần truy vấn linh hoạt (lọc theo nhiều điều kiện, lấy nested data — ví dụ "exam → submissions → section results" trong 1 query), tránh over-fetching/under-fetching so với REST thuần |

Ví dụ GraphQL query điển hình cho Admin UI:
```graphql
query GetExamDashboard($examId: ID!) {
  exam(id: $examId) {
    name
    submissions(status: GRADED) {
      studentName
      totalScore
      sectionResults { name passed total }
    }
  }
}
```

---

## 11. Authentication (quyết định #14)

```csharp
// JWT Access token (ngắn hạn, 15 phút) + Refresh token (dài hạn, 7 ngày, lưu trong DB)
public class JwtTokenGenerator
{
    public TokenPair GenerateTokenPair(User user)
    {
        var accessToken = GenerateJwt(user, expiry: TimeSpan.FromMinutes(15));
        var refreshToken = GenerateSecureRandomToken();

        _refreshTokenStore.Save(new RefreshTokenEntity
        {
            Token = HashToken(refreshToken),  // không lưu plain text
            UserId = user.Id,
            ExpiresAt = DateTime.UtcNow.AddDays(7)
        });

        return new TokenPair(accessToken, refreshToken);
    }
}
```
- Access token dùng cho mọi request tới cả 2 service (cùng 1 signing key hoặc trust qua JWKS nội bộ).
- Refresh token lưu DB, cho phép revoke (xoá record) khi giảng viên logout hoặc bị khoá tài khoản.

---

## 12. CI/CD (cho chính dự án)

```
.github/workflows/
├── ci-grading-engine.yml
├── ci-admin-portal.yml
└── ci-domain-shared.yml      # test Domain layer dùng chung trước tiên
```

```yaml
# ci-domain-shared.yml — chạy nhanh nhất, không cần Docker/RabbitMQ
name: CI - Domain
on: [pull_request, push]
jobs:
  test-domain:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '8.0.x' }
      - run: dotnet test shared/PRN232.Domain.Tests --no-restore
```

Mỗi service có pipeline CI riêng (build + test layer Application với mock, không cần Docker/RabbitMQ thật trong CI thường — chỉ chạy integration test đầy đủ ở pipeline nightly riêng).

---

## 13. Testing Strategy

| Layer | Loại test | Công cụ | Cần hạ tầng ngoài? |
|---|---|---|---|
| Domain (shared) | Unit test | xUnit + FluentAssertions | Không |
| Application (mỗi service) | Unit test, mock interface | xUnit + Moq | Không |
| Infrastructure — Sandbox | Integration test | Testcontainers | Cần Docker |
| Infrastructure — Messaging | Integration test | Testcontainers (RabbitMQ image) | Cần Docker |
| API (mỗi service) | Integration test | WebApplicationFactory | Cần DB test (SQLite/in-memory) |

---

## 14. Rủi ro kỹ thuật & giảm thiểu (cập nhật)

| Rủi ro | Mức độ | Giảm thiểu |
|---|---|---|
| RabbitMQ phải tự host nội bộ, thêm 1 hệ thống phải vận hành (C-01) | Cao | Viết tài liệu cài đặt RabbitMQ chi tiết, test kỹ trước kỳ thi thật, có kế hoạch fallback (Channel<T> in-memory) nếu RabbitMQ lỗi |
| 2 service tách rời tăng độ phức tạp deploy/debug | Trung bình | Dùng docker-compose để chạy cả 2 service + RabbitMQ + SQL Server cùng lúc trong môi trường dev, giảm friction |
| Container pool tái sử dụng vẫn có lỗ hổng nếu có tiến trình viết ra ngoài /workspace, /tmp mà không bị chặn | Trung bình | Test kỹ với `--read-only` thật, viết test case cố tình cho code sinh viên ghi ra ngoài để xác nhận bị chặn |
| Container replay giữ lại 30 phút có thể bị lạm dụng (tốn tài nguyên nếu nhiều giảng viên mở cùng lúc) | Trung bình | Giới hạn số replay session đồng thời, tự động đóng sớm nếu không hoạt động |
| Plagiarism detection chưa chốt công nghệ, làm cùng AI trong thời gian ngắn còn lại | Cao | Ưu tiên giải pháp đơn giản nhất chạy được trước (có thể là so khớp token thô), nâng cấp sau nếu còn thời gian |
| NuGet volume thiếu package mới khi đổi rubric giữa kỳ | Trung bình | Checklist vận hành: luôn restore lại volume trước mỗi kỳ thi khi rubric/đề thi thay đổi dependency |
