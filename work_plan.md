# Kế Hoạch Thực Hiện Lab — Day 23 Observability Stack

**Học viên:** Trần Mạnh Chánh Quân  
**Mã số học viên:** 2A202600786  
**Chương trình:** VinUni AI2k_2 · Phase 2 · Track 2  
**Ngày thực hiện:** 2026-06-29  
**Cập nhật tiến độ:** 2026-06-30

---

## 📊 Tiến độ hiện tại (Progress Dashboard)

| Track | Mô tả | Trạng thái | Điểm |
|:------|:------|:----------:|:----:|
| 00 | Setup | ✅ Hoàn thành | 5/5 |
| 01 | Instrument FastAPI | ✅ Hoàn thành | 20/20 |
| 02 | Prometheus + Grafana + Alerts | ✅ Hoàn thành | 30/30 |
| 03 | Tracing & Logs | ✅ Hoàn thành | 20/20 |
| 04 | Drift Detection | ✅ Hoàn thành | 15/15 |
| 05 | Cross-Day Integration | ✅ Hoàn thành | 10/10 |
| Bonus | AgentOps | ✅ Hoàn thành | +10 |
| Bonus | eBPF / Langfuse | ⬜ Chưa làm | 0/20 |
| **Tổng** | | **6/7 tracks + 1 bonus** | **110/130** ✅ |

### Screenshots đã có trong submission/

| Screenshot | Trạng thái |
|:-----------|:----------:|
| `dashboard-overview.png` | ✅ |
| `slo-burn-rate.png` | ✅ |
| `cost-and-tokens.png` | ✅ |
| `alertmanager-firing.png` | ✅ |
| `slack-firing.png` | ✅ |
| `slack-resolved.png` | ✅ |
| `inference_active_gauge.png` | ✅ |
| `grafana-dashboards-api.json` | ✅ |
| `cross-day-dashboard.png` | ✅ |
| `jaeger-trace.png` | ✅ |
| `agentops-jaeger.png` | ✅ |

### ✅ Tất cả screenshots đã hoàn thành

### Công việc còn lại

1. ✔️ Chạy `make verify` kiểm tra lần cuối
2. 🎯 (Optional) Bonus tracks

---

## Mục lục

- [1. Tổng quan dự án](#1-tổng-quan-dự-án)
- [2. Kiểm tra môi trường & phần cứng](#2-kiểm-tra-môi-trường--phần-cứng)
- [3. Track 00 — Setup (15 phút, 5 điểm)](#3-track-00--setup-15-phút-5-điểm)
- [4. Track 01 — Instrument FastAPI (30 phút, 20 điểm)](#4-track-01--instrument-fastapi-30-phút-20-điểm)
- [5. Track 02 — Prometheus + Grafana + Alerts (45 phút, 30 điểm)](#5-track-02--prometheus--grafana--alerts-45-phút-30-điểm)
- [6. Track 03 — Tracing & Logs (30 phút, 20 điểm)](#6-track-03--tracing--logs-30-phút-20-điểm)
- [7. Track 04 — Drift Detection (20 phút, 15 điểm)](#7-track-04--drift-detection-20-phút-15-điểm)
- [8. Track 05 — Cross-Day Integration (20 phút, 10 điểm)](#8-track-05--cross-day-integration-20-phút-10-điểm)
- [9. Submission & Verify](#9-submission--verify)
- [10. Bonus Tracks (optional, +30 điểm)](#10-bonus-tracks-optional-30-điểm)
- [11. Timeline tổng thể](#11-timeline-tổng-thể)
- [12. Troubleshooting Checklist](#12-troubleshooting-checklist)
- [13. BONUS CHALLENGE — Observe thật (Ungraded)](#13-bonus-challenge--observe-một-thứ-thật-ungraded-4-8htrack)

---

## 1. Tổng quan dự án

### 1.1 Mục tiêu

Xây dựng **full open-source observability stack** cho một AI service (mock LLM inference) bao gồm:

- **7 Docker containers**: app (FastAPI), Prometheus, Grafana, Alertmanager, Loki, Jaeger, OpenTelemetry Collector
- **6 OpenTelemetry signals**: metrics, traces, logs, GPU gauges, token counters, quality scores
- **3 Grafana dashboards**: AI Service Overview, SLO Burn-Rate, Cost & Tokens
- **2 multi-window multi-burn-rate alerts** → Slack
- **Tail-sampling** trong OTel Collector
- **Drift detection** (PSI/KL/KS) với Evidently HTML report
- **Cross-day integration** từ các ngày trước (Days 16-22)

### 1.2 Thang điểm

| Loại | Số checkpoint | Tổng điểm |
|------|:-------------:|:----------:|
| Core | 22 checkpoints | 100 điểm |
| Bonus | 3 checkpoints | 30 điểm (additive) |
| **Tổng** | **25** | **130 điểm** |

### 1.3 Kiến trúc tổng thể

```
┌─────────────────────────────────────────────────────────┐
│                   Docker Network (obs)                    │
│                                                          │
│  ┌──────────┐    OTLP gRPC    ┌──────────────┐          │
│  │    App   │ ───────────────→│ OTel Collector│          │
│  │ FastAPI  │                 │ (tail-sample) │          │
│  │ :8000    │───┐             └──────┬───────┘          │
│  └──────────┘   │                    │                   │
│                 │              ┌─────┴──────┐           │
│                 │              │   Jaeger   │           │
│                 │              │  :16686    │           │
│                 │              └────────────┘           │
│                 │                                        │
│    /metrics ────┤         ┌──────────┐                  │
│                 ├────────→│Prometheus│←── scrape ──────│
│                 │         │  :9090   │                   │
│                 │         └─────┬────┘                   │
│                 │               │                        │
│                 │         ┌─────┴──────┐                 │
│                 │         │Alertmanager│──→ Slack        │
│                 │         │  :9093     │                 │
│                 │         └────────────┘                 │
│                 │                                        │
│                 │         ┌──────────┐                  │
│                 │         │  Grafana │←── Prometheus ──│
│                 │         │  :3000   │←── Loki ────────│
│                 │         │          │←── Jaeger ──────│
│                 │         └──────────┘                  │
│                 │                                        │
│                 │         ┌──────────┐                  │
│                 └────────→│   Loki   │                   │
│                           │  :3100   │                   │
│                           └──────────┘                   │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Kiểm tra môi trường & phần cứng

### 2.1 Yêu cầu tối thiểu (HARDWARE-GUIDE.md)

| Tài nguyên | Yêu cầu | Máy thực tế | Status |
|:-----------|:--------|:------------|:-------|
| RAM (free) | ≥ 4 GB | 11.68 GB | ✅ |
| Docker Desktop memory | ≥ 4 GB (recommend 6 GB) | 9.9 GB (WSL2) | ✅ |
| Disk space | ≥ 10 GB | 951 GB avail | ✅ |
| CPU cores | ≥ 4 | WSL2 (shared) | ✅ |

### 2.2 Tài nguyên steady-state

| Service | RAM | CPU |
|:--------|:---:|:---:|
| app (FastAPI) | 80 MB | <1% |
| prometheus | 200 MB | 1-3% |
| alertmanager | 60 MB | <1% |
| grafana | 250 MB | 1-2% |
| loki | 150 MB | 1% |
| jaeger | 200 MB | <1% |
| otel-collector | 100 MB | 1% |
| **Tổng steady-state** | **~1 GB** | **~5-10% 1 core** |

### 2.3 Pre-flight checklist

- [ ] Kiểm tra Docker installed: `docker --version`
- [ ] Kiểm tra Docker Compose: `docker compose version`
- [ ] Kiểm tra Docker running: `docker info`
- [ ] Kiểm tra RAM: `free -h`
- [ ] Kiểm tra disk: `df -h`
- [ ] Kiểm tra Python 3.12+: `python3 --version`

---

## 3. Track 00 — Setup (15 phút, 5 điểm)

### 3.1 Các bước thực hiện

| # | Bước | Command | Kỳ vọng | Ghi chú |
|:-:|:-----|:--------|:--------|:--------|
| 1 | Copy .env | `cp .env.example .env` | File `.env` được tạo | Cần chỉnh sửa sau |
| 2 | Cấu hình Slack webhook | Edit `.env`: `SLACK_WEBHOOK_URL` | URL hợp lệ | Test bằng curl nếu có |
| 3 | Pull images + verify | `make setup` | 6 images pulled, `verify-docker.py` pass | ~5-10 phút tùy network |
| 4 | Kiểm tra report | `ls 00-setup/setup-report.json` | File tồn tại | Checkpoint #1 |

### 3.2 Grading checkpoint

| # | Checkpoint | Điểm | How verified |
|:-:|:-----------|:----:|:-------------|
| 1 | `setup-report.json` committed | 5 | file exists |

---

## 4. Track 01 — Instrument FastAPI (30 phút, 20 điểm)

### 4.1 Code structure (`01-instrument-fastapi/app/`)

```
01-instrument-fastapi/app/
├── Dockerfile
├── inference.py       # Mock LLM inference logic
├── instrumentation.py # OTel instrumentation setup
├── main.py            # FastAPI app entry point
└── requirements.txt
```

### 4.2 6 Metric families cần expose

| Metric | Type | Labels | RED/USE/AI |
|:-------|:----:|:-------|:----------:|
| `inference_requests_total` | Counter | `model`, `status` | RED: Rate + Errors |
| `inference_latency_seconds_bucket` | Histogram | `model` | RED: Duration |
| `inference_active_gauge` | Gauge | — | USE: In-flight requests |
| `gpu_utilization_percent` | Gauge | — | USE: GPU util (simulated) |
| `inference_tokens_total` | Counter | `model`, `direction` | AI 4th pillar |
| `inference_quality_score` | Gauge | `model` | Eval-as-metric stub |

### 4.3 Các bước thực hiện

- [ ] Đọc code `main.py`, `inference.py`, `instrumentation.py`
- [ ] Kiểm tra OTel auto-instrumentation (FastAPI handler spans)
- [ ] Kiểm tra manual spans: `embed-text`, `vector-search`, `generate-tokens`
- [ ] Kiểm tra structured JSON logs với `structlog` → stdout
- [ ] Test metrics: `curl localhost:8000/metrics | grep -E "inference_(requests|latency|active|tokens|quality)"`
- [ ] Chụp screenshot `inference_active_gauge` rises during load → returns to 0

### 4.4 Grading checkpoints

| # | Checkpoint | Điểm | How verified |
|:-:|:-----------|:----:|:-------------|
| 2 | `/metrics` exposes `inference_requests_total` | 5 | curl + grep |
| 3 | `/metrics` exposes `inference_latency_seconds_bucket` | 5 | curl + grep |
| 4 | `inference_active_gauge` rises/returns to 0 | 5 | screenshot |
| 5 | `inference_quality_score` + `inference_tokens_total` | 5 | curl + grep |

---

## 5. Track 02 — Prometheus + Grafana + Alerts (45 phút, 30 điểm)

### 5.1 Kiến trúc track 02

```
            ┌──────────────────────────────────────┐
            │          Prometheus (:9090)           │
            │  ┌────────────────────────────────┐   │
            │  │  prometheus.yml                │   │
            │  │  - scrape app:8000/metrics     │   │
            │  │  - scrape self:9090/metrics    │   │
            │  └────────────────────────────────┘   │
            │  ┌────────────────────────────────┐   │
            │  │  Rules:                        │   │
            │  │  - ai-quality.yml              │   │
            │  │  - slo-burn-rate.yml           │   │
            │  └────────────────────────────────┘   │
            └──────────┬───────────────────────────┘
                       │ evaluation
              ┌────────┴────────┐
              │                 │
     ┌────────▼──────┐  ┌──────▼──────────┐
     │ Alertmanager   │  │    Grafana      │
     │ (:9093)        │  │ (:3000)         │
     │ → Slack        │  │ 3 dashboards    │
     └────────────────┘  └─────────────────┘
```

### 5.2 3 Grafana Dashboards

| Dashboard | Panels | Mục đích |
|:----------|:-------|:---------|
| **ai-service-overview** | 6 panels: RPS, P50-95-99 latency, error rate, GPU util, token throughput, cost/hr | Tổng quan service health |
| **slo-burn-rate** | Error budget remaining + multi-window burn rates | SLO monitoring (deck §6) |
| **cost-and-tokens** | Token throughput + estimated $/hr | AI FinOps (deck §11) |

### 5.3 Alert Rules

| Rule | File | Condition | Severity |
|:-----|:-----|:----------|:---------|
| `ServiceDown` | ai-quality.yml | `up{job="app"} == 0` for 1m | critical |
| `HighInferenceLatency` | ai-quality.yml | P99 latency > 500ms | warning |

### 5.4 Các bước thực hiện

- [ ] **Step 1**: `make up` — khởi động stack
- [ ] **Step 2**: `make smoke` — verify services (~30s sau up)
- [ ] **Step 3**: Mở Grafana `http://localhost:3000` — confirm 3 dashboards auto-loaded
- [ ] **Step 4**: `make load` — chạy Locust 10 users, 60s
- [ ] **Step 5**: Chụp ảnh Overview dashboard 6 panels có data
- [ ] **Step 6**: Chụp ảnh SLO burn-rate dashboard
- [ ] **Step 7**: Chụp ảnh Cost-and-tokens dashboard (non-zero $/hr)
- [ ] **Step 8**: `make alert` — kill app → đợi 90s → ServiceDown fire
- [ ] **Step 9**: Chụp ảnh Alertmanager `alertmanager-firing.png`
- [ ] **Step 10**: Chụp ảnh Slack fire message `slack-firing.png`
- [ ] **Step 11**: App tự restore → đợi ~60s → resolve
- [ ] **Step 12**: Chụp ảnh Slack resolve message `slack-resolved.png`

### 5.5 Grading checkpoints

| # | Checkpoint | Điểm | How verified |
|:-:|:-----------|:----:|:-------------|
| 6 | 3 Day-23 dashboards loaded automatically | 5 | Grafana API search |
| 7 | Overview dashboard 6 panels render with data | 5 | screenshot |
| 8 | SLO burn-rate dashboard populates burn rates | 5 | screenshot |
| 9 | Cost-and-tokens dashboard shows non-zero $/hr | 5 | screenshot |
| 10 | `make alert` triggers `ServiceDown` in Alertmanager | 5 | screenshot |
| 11 | Slack receives both fire AND resolve messages | 5 | screenshot |

---

## 6. Track 03 — Tracing & Logs (30 phút, 20 điểm)

### 6.1 Data flow

```
app (FastAPI)
│
│  OTLP gRPC (:4317)
│
▼
OTel Collector (tail-sampling)
│
├──→ Jaeger (:16686)    — traces
│
└──→ Loki (:3100)       — logs (via filelog receiver)
     │
     └── Grafana datasource: derived field trace_id → link to Jaeger
```

### 6.2 Tail-sampling policy

| Policy | Match condition | Keep rate |
|:-------|:----------------|:---------:|
| **errors** | `span.status.code == ERROR` | 100% |
| **slow** | `span.duration >= 2s` | 100% |
| **healthy** | random sampling | 1% |

**Buffer configuration:**
- Decision window: 30s
- Span memory: ~10K spans

### 6.3 Các bước thực hiện

- [x] **Step 1**: `make trace` — gọi `POST /predict` → nhận trace_id
- [x] **Step 2**: Mở Jaeger UI `http://localhost:16686`
- [x] **Step 3**: Search service `inference-api` → tìm trace cho `POST /predict`
- [x] **Step 4**: Chụp ảnh flame graph: `embed-text → vector-search → generate-tokens`
- [x] **Step 5**: Click span → chụp ảnh attributes panel (GenAI semantic conventions)
- [x] **Step 6**: Kiểm tra structured JSON log với trace_id trong Loki
- [x] **Step 7**: Verify click trace_id → jump to Jaeger trace
- [x] **Step 8**: Ghi log line + trace_id vào REFLECTION
- [x] **Step 9**: Tính toán tail-sampling math
  - Giả sử N traces/sec
  - Error rate = X%
  - Slow rate = Y%
  - Fraction kept = X% * 1.0 + Y% * 1.0 + (1 - X% - Y%) * 0.01

### 6.4 Grading checkpoints

| # | Checkpoint | Điểm | How verified |
|:-:|:-----------|:----:|:-------------|
| 12 | Jaeger trace `POST /predict` + 3 child spans | 5 | screenshot |
| 13 | Span attributes follow GenAI semantic conventions | 5 | screenshot |
| 14 | Tail-sampling math in REFLECTION | 5 | REFLECTION text |
| 15 | Structured JSON log with `trace_id` in REFLECTION | 5 | REFLECTION text |

---

## 7. Track 04 — Drift Detection (20 phút, 15 điểm)

### 7.1 Các phương pháp drift detection

| Method | Full name | Khi nào dùng | Threshold |
|:-------|:----------|:-------------|:---------:|
| **PSI** | Population Stability Index | Categorical features, score distributions | > 0.2 = drift |
| **KL** | Kullback-Leibler Divergence | Distribution shift, continuous prob. dist. | > 0.1 = significant |
| **KS** | Kolmogorov-Smirnov | Continuous numerical features | p < 0.05 |
| **MMD** | Maximum Mean Discrepancy | High-dimensional embeddings | Domain-specific |

### 7.2 Các bước thực hiện

- [x] **Option A (local)**: 
  ```bash
  cd 04-drift-detection
  pip install -r ../requirements-evidently.txt  # Python 3.12
  python3 scripts/drift_detect.py
  ```
- [ ] ~~Option B (Colab)~~: Đã dùng Option A local
- [x] Kiểm tra output:
  - `reports/drift-summary.json` — ✅ tồn tại, có 2 features `drift: yes` (`prompt_length`, `response_quality`)
  - `reports/drift-report.html` — ✅ Evidently HTML report (3 MB)
- [ ] Chụp ảnh Evidently report → ⚠️ Còn thiếu `drift-report.png`
- [x] Viết REFLECTION: feature nào dùng test nào (PSI/KL/KS/MMD)

### 7.3 Drift detection data flow

```
baseline.csv                     current.csv
  (reference)                     (production)
      │                              │
      └──────────┬───────────────────┘
                 │
                 ▼
        drift_detect.py
                 │
                 ├── PSI  (prompt_length, response_length)
                 ├── KL   (response_quality distribution)
                 ├── KS   (embedding_norm)
                 └── MMD  (embeddings high-dim)
                 │
                 ▼
         drift-summary.json + drift-report.html
```

### 7.4 Grading checkpoints

| # | Checkpoint | Điểm | How verified |
|:-:|:-----------|:----:|:-------------|
| 16 | `drift-summary.json` exists + ≥1 drift: yes | 5 | file content |
| 17 | Evidently HTML report renders | 5 | screenshot |
| 18 | REFLECTION explains test choice per feature | 5 | REFLECTION text |

---

## 8. Track 05 — Cross-Day Integration (20 phút, 10 điểm)

### 8.1 Prior-day metrics

| Source day | What | Integration target |
|:----------:|:-----|:-------------------|
| Day 16 | Cloud infra (EC2/EKS) | `node_exporter` |
| Day 17 | Data pipeline (Airflow) | Airflow DAG duration |
| Day 18 | Lakehouse (Spark/Delta) | Spark UI metrics |
| Day 19 | Vector store (Qdrant) | `host.docker.internal:6333/metrics` |
| Day 20 | Model serving (llama.cpp) | `host.docker.internal:8080/metrics` |
| Day 22 | Alignment (DPO model) | Custom gauge |

### 8.2 Integration scripts

| File | Purpose |
|:-----|:--------|
| `monitor-day19-vector-store.py` | Stub/metrics for Qdrant |
| `monitor-day20-llama-cpp.py` | Stub/metrics for llama.cpp |

### 8.3 Các bước thực hiện

- [x] Chạy integration scripts:
  ```bash
  python3 05-integration/monitor-day19-vector-store.py   # ✅ port 9101
  python3 05-integration/monitor-day20-llama-cpp.py      # ✅ port 9102
  ```
- [x] Import `05-integration/full-stack-dashboard.json` vào Grafana (copy vào provisioning)
- [x] Chụp ảnh cross-day dashboard với 6 panels
- [x] Viết REFLECTION: metric nào khó expose nhất (`day20_llamacpp_tokens_per_second`)

### 8.4 Grading checkpoints

| # | Checkpoint | Điểm | How verified |
|:-:|:-----------|:----:|:-------------|
| 19 | ≥1 prior-day source connected (real/stub) | 5 | screenshot |
| 20 | Cross-day dashboard 6 panels (data or "No Data") | 5 | screenshot |

---

## 9. Submission & Verify

### 9.1 File structure submission

```
submission/
├── REFLECTION.md                    # Bắt buộc, >500 chars
├── screenshots/
│   ├── dashboard-overview.png       # Rubric #7
│   ├── slo-burn-rate.png            # Rubric #8
│   ├── cost-and-tokens.png          # Rubric #9
│   ├── alertmanager-firing.png      # Rubric #10
│   ├── slack-firing.png             # Rubric #11
│   ├── slack-resolved.png           # Rubric #11
│   ├── jaeger-trace.png             # Rubric #12
│   ├── jaeger-attrs.png             # Rubric #13
│   ├── drift-report.png             # Rubric #17
│   └── cross-day-dashboard.png      # Rubric #19-20
```

### 9.2 REFLECTION.md sections

| Section | Nội dung | Điểm |
|:--------|:---------|:----:|
| 1 | Hardware + setup output | 5 |
| 2 | Dashboards & Alerts | 5 |
| 3 | Tracing & Logs | 5 |
| 4 | Drift Detection | 5 |
| 5 | Cross-Day Integration | 5 |
| 6 | "The single change that mattered most" | 10 |

### 9.3 Verify command

```bash
make verify    # python3 scripts/verify.py
# Expected: All checks pass → exit code 0
```

**verify.py checks:**
1. `00-setup/setup-report.json` exists
2. `app /healthz` reachable
3. `/metrics` exposes `inference_requests_total`
4. Prometheus reachable
5. Grafana reachable
6. Alertmanager reachable
7. 3 Day-23 dashboards loaded
8. Jaeger UI reachable
9. Loki ready
10. OTel Collector self-metrics reachable
11. `drift-summary.json` shows ≥1 drifted feature
12. `REFLECTION.md` exists + >500 chars

---

## 10. Bonus Tracks (optional, +30 điểm)

### 10.1 BONUS-ebpf-profiling (+10 điểm)

| Mục | Mô tả |
|:----|:------|
| Tool | Pyroscope (continuous profiling) |
| Requirement | Linux/WSL only |
| Output | Flame graph cho `day23-app` Python process |
| Thời gian | ~30 phút |

**Các bước:**
- [ ] Thêm Pyroscope service vào `docker-compose.yml`
- [ ] Instrument app với `pyroscope-io` client
- [ ] Chạy load → capture flame graph
- [ ] Chụp ảnh screenshot

### 10.2 BONUS-llm-native-obs (+10 điểm)

| Mục | Mô tả |
|:----|:------|
| Tool | Langfuse self-hosted |
| Output | LLM trace từ LangChain call |
| Thời gian | ~30 phút |

**Các bước:**
- [ ] Start Langfuse + Postgres containers
- [ ] Tích hợp LangChain callback vào app
- [ ] Gọi LLM → capture trace
- [ ] Chụp ảnh Langfuse trace

### 10.3 BONUS-agentops (+10 điểm)

| Mục | Mô tả |
|:----|:------|
| Tool | AgentOps (OTel agent spans + SLIs) |
| Deck reference | §14 (Harness, Loop & Self-Improvement Flywheel) + §19 (AgentOps Deepdive) |
| Output | `agentops-report.json` + Jaeger span tree (`day23-agent`) |
| Thời gian | ~30 phút |

**Các bước:**
- [ ] Chạy `python3 BONUS-agentops/agent_run.py`
- [ ] Kiểm tra `agentops-report.json`
- [ ] Mở Jaeger → tìm `day23-agent` spans
- [ ] Chụp ảnh span tree
- [ ] Ghi REFLECTION về pass^k vs pass@k

---

## 11. Timeline tổng thể

| Thời gian | Track | Hoạt động | Trạng thái |
|:---------:|:-----:|:----------|:----------:|
| T+00:00 | 00 | Setup: pull images, verify Docker | ✅ Done |
| T+00:15 | 01 | Instrument FastAPI: metrics, traces, logs | ✅ Done |
| T+00:45 | 02a | `make up`, `make smoke`, dashboards | ✅ Done |
| T+01:00 | 02b | `make load`, screenshots | ✅ Done |
| T+01:15 | 02c | `make alert`, Slack screenshots | ✅ Done |
| T+01:30 | 03a | Tracing: Jaeger trace + attributes | ✅ Done |
| T+01:45 | 03b | Logs: structured JSON with trace_id | ✅ Done |
| T+02:00 | 04 | Drift detection: PSI/KL/KS | ✅ Done |
| T+02:20 | 05 | Cross-day integration | ✅ Done |
| T+02:40 | Submit | Screenshots, REFLECTION, `make verify` | ✅ Done |
| T+03:10 | Bonus | eBPF / Langfuse / AgentOps | ⬜ Optional |

> **Ghi chú:** Timeline trên giả định mọi thứ suôn sẻ. Nên cộng thêm 30% buffer cho troubleshooting.

---

## 12. Troubleshooting Checklist

### 12.1 `make smoke` fails

| Symptom | Fix |
|:--------|:----|
| Grafana không reachable | Chờ 30s → retry (provisioning chưa xong) |
| App không start | Kiểm tra OTel collector đã start chưa |

### 12.2 `make alert` không fire

| Symptom | Fix |
|:--------|:----|
| Alert không fire sau 90s | Check rule `for: 1m` — có thể cần đợi lâu hơn |
| Slack không nhận | Test webhook: `curl -X POST $SLACK_WEBHOOK_URL -d '{"text":"test"}'` |

### 12.3 Out of memory

| Fix | Chi tiết |
|:----|:---------|
| Tăng Docker memory | Settings → Resources → Memory ≥ 6 GB |
| Skip bonus tracks | eBPF (+300 MB), Langfuse (+600 MB) |

### 12.4 Port conflicts

| Symptom | Fix |
|:--------|:----|
| Port 3000/9090 bị chiếm | `lsof -i :<port>` → kill process |

### 12.5 `make verify` non-zero

| Check | Fix |
|:------|:----|
| setup-report.json missing | Chạy lại `make setup` |
| 3 dashboards not found | Restart Grafana, đợi 30s |
| drift-summary.json missing | Chạy `make drift` |
| REFLECTION.md < 500 chars | Hoàn thiện các section |

---

## 13. BONUS CHALLENGE — Observe một thứ thật (UNGRADED, 4-8h/track)

> Tham khảo: [`BONUS-CHALLENGE.md`](BONUS-CHALLENGE.md)  
> Mục tiêu: Chĩa observability stack vào một thứ bạn thật sự quan tâm — portfolio piece thực, không phải lab tô màu.

### 13.1 Tổng quan 5 provocations

| # | Provocation | Effort | Output chính |
|:-:|:------------|:------:|:-------------|
| 1 | **Gắn telemetry vào lab cũ** (Day 18/19/20) | 4-6h | Dashboard JSON + 1 SLO alert + RUNBOOK.md |
| 2 | **Observe doanh nghiệp Việt dùng AI** | 6-8h | 2 dashboards, 2 alerts, webhook dịch alert → TV |
| 3 | **Drift detection trên dataset Việt thật** | 6-8h | Pipeline drift + dashboard + alert + reflection |
| 4 | **Cost observability model thật** | 4-6h | `$/request`, `$/day`, budget alert, top-3 cost endpoint |
| 5 | **Diễn tập postmortem (chaos)** | 6-8h | 3 chaos scripts + 3 postmortems + 1 dashboard change |

### 13.2 Provocation 1 — Gắn telemetry vào lab cũ ⭐ (Khuyến nghị)

**Lý do chọn:** Đã build 6 ngày lab trước, có sẵn code, chỉ cần thêm OTel instrumentation.

| Bước | Hành động | Thời gian |
|:----:|:----------|:---------:|
| 1.1 | Chọn 1 lab cũ (Day 19 Qdrant hoặc Day 20 llama.cpp) | 15min |
| 1.2 | Thêm OTel instrumentation (~30 dòng) | 1h |
| 1.3 | Tạo dashboard `dashboards/<tên-ngày>.json` | 1.5h |
| 1.4 | Define 1 SLO + 1 multi-burn-rate alert | 1h |
| 1.5 | Viết `RUNBOOK.md` (~150 từ) | 30min |
| 1.6 | Demo: trigger failure → alert fire < 5 phút | 1h |

**Deliverables:**
- `bonus/telemetry-<ngày>/` folder
- Dashboard JSON đã commit
- Alert rule trong `prometheus/rules/`
- `RUNBOOK.md`

**Câu hỏi brainstorm:**
- 3 metrics nào bạn xem đầu tiên khi có incident?
- Failure mode không hiển nhiên mà default alert không bắt?
- Có thể bắt failure sớm hơn 10 phút nếu đổi burn-rate window không?

---

### 13.3 Provocation 2 — Observe doanh nghiệp Việt dùng AI

| Bước | Hành động | Thời gian |
|:----:|:----------|:---------:|
| 2.1 | Chọn 1 business case cụ thể (chatbot, OCR, auto-reply...) | 30min |
| 2.2 | Viết `bonus/business-case.md` | 1h |
| 2.3 | Tạo 2 dashboards: 1 cho chủ shop (non-tech), 1 cho dev | 2h |
| 2.4 | 2 alert rules + webhook dịch alert → TV | 1.5h |
| 2.5 | Model card: 5 sample alerts hệ thống sẽ fire trong tuần | 1h |

**Deliverables:**
- `bonus/business-case.md`
- 2 `dashboards/*.json`
- Webhook-receiver script

---

### 13.4 Provocation 3 — Drift detection trên dataset Việt thật

| Bước | Hành động | Thời gian |
|:----:|:----------|:---------:|
| 3.1 | Chọn dataset (VnExpress headlines, Lazada reviews, weather...) | 30min |
| 3.2 | Viết `bonus/dataset-card.md` | 1h |
| 3.3 | Build `drift/pipeline.py`: fetch → detect → emit Prometheus metrics | 2h |
| 3.4 | Grafana dashboard + 1 alert rule | 1.5h |
| 3.5 | Reflection: PSI vs KL vs KS — cái nào surface shift sớm nhất? | 1h |

**Deliverables:**
- `bonus/dataset-card.md`
- `drift/pipeline.py`
- Dashboard + alert
- Reflection về PSI/KL/KS

---

### 13.5 Provocation 4 — Cost observability model thật

| Bước | Hành động | Thời gian |
|:----:|:----------|:---------:|
| 4.1 | Instrument client wrapper (OpenAI SDK / llama.cpp) | 1h |
| 4.2 | Dashboard `$/request`, `$/day`, `$/user` | 1.5h |
| 4.3 | 2 alerts: (a) burn-rate vs budget, (b) per-request anomaly | 1h |
| 4.4 | Tóm tắt 1 trang: 7 ngày cost data, top 3 endpoints | 1h |

**Deliverables:**
- Client wrapper đã instrument (`tokens_input`, `tokens_output`, `cost_usd`, `model`)
- Dashboard JSON
- Cost summary report

---

### 13.6 Provocation 5 — Diễn tập postmortem (Chaos Engineering)

| Bước | Hành động | Thời gian |
|:----:|:----------|:---------:|
| 5.1 | Chọn 3 failure modes (infra + data + dependency) | 30min |
| 5.2 | Viết 3 chaos scripts trong `bonus/chaos/` | 2h |
| 5.3 | Inject từng failure, đo time-to-detect + time-to-mitigate | 2h |
| 5.4 | Viết 3 postmortems (`bonus/postmortems/incident-NN.md`) | 2h |
| 5.5 | Implement ít nhất 1 action item (thay đổi dashboard/alert thật) | 1.5h |

**Postmortem template (deck §12):**
1. Timeline
2. Detection (thời điểm + signal)
3. Mitigation
4. Root Cause
5. Action Items (có ít nhất 1 item đã implement)

---

### 13.7 Bonus submission checklist

```
bonus/
├── REFLECTION.md          # 2 đoạn: bạn ngạc nhiên gì? thêm 8h bạn build gì?
├── <provocation-folder>/  # Deliverables của provocation đã chọn
└── screenshots/           # Dashboard, alert fire, postmortem timeline
```

### 13.8 Đo độ thành công (từ BONUS-CHALLENGE.md)

| # | Câu hỏi tự kiểm | Trả lời được? |
|:-:|:----------------|:-------------:|
| 1 | 3 metrics nào bạn thật sự xem đầu tiên khi có incident? Vì sao? | ⬜ |
| 2 | Failure mode không hiển nhiên mà default alert không bắt được? | ⬜ |
| 3 | PSI vs KL vs KS — cái nào surface shift sớm nhất trên dataset của bạn? | ⬜ |
| 4 | Leading indicator của runaway-cost là gì? | ⬜ |
| 5 | Time-to-detect lần inject thứ 2 có ngắn hơn lần 1 không? | ⬜ |
| 6 | Postmortem của bạn dẫn tới thay đổi thật gì trong system? | ⬜ |

> **Bonus này ungraded vì:** khoảnh khắc đặt điểm vào, bạn sẽ tối ưu cho điểm. Kỹ năng cần phát triển là **judgment** — cái gì đáng alert, cái gì không, đánh thức ai, khi nào, vì sao.

---

## Phụ lục

### A. Docker Compose services

```yaml
services:
  app:              FastAPI app (:8000)
  prometheus:       Prometheus v2.55.0 (:9090)
  alertmanager:     Alertmanager v0.27.0 (:9093)
  grafana:          Grafana 11.3.0 (:3000)
  loki:             Loki 3.3.0 (:3100)
  jaeger:           Jaeger all-in-one 1.62.0 (:16686)
  otel-collector:   OTel Collector Contrib 0.114.0 (:4317, :8888)
```

### B. Makefile commands

| Command | Mô tả |
|:--------|:------|
| `make setup` | One-time install: pull images, verify Docker |
| `make up` | Start the 7-service stack |
| `make smoke` | Health-check all services |
| `make load` | Run Locust (10 users, 60s) |
| `make alert` | Trigger alert (kill app → fire → restore → resolve) |
| `make trace` | Generate 1 traced request |
| `make drift` | Run drift detection |
| `make demo` | End-to-end: load → alert → trace → drift |
| `make verify` | Rubric gate — exit 0 = ready to submit |
| `make down` | Stop stack (preserve volumes) |
| `make clean` | Stop + remove volumes (DESTRUCTIVE) |

---

*Kế hoạch được soạn dựa trên phân tích: README.md, rubric.md, HARDWARE-GUIDE.md, Makefile, docker-compose.yml, và các README của 5 tracks.*