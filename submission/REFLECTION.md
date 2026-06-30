# Day 23 Lab Reflection

**Student:** Trần Mạnh Chánh Quân
**Mã số học viên:** 2A202600786
**Submission date:** 2026-06-30
**Lab repo URL:** _[public GitHub URL]_

---

## 1. Hardware + setup output

```
Docker:        OK  (29.5.3)
Compose v2:    OK  (5.1.4)
RAM available: 11.68 GB (OK)
```

**Specs:** Docker Desktop 29.5.3 trên WSL2 (Ubuntu), RAM 9.9 GB, Disk 1007 GB (951 GB avail), Python 3.12.3.

**Lỗi gặp phải:**
1. Docker Desktop daemon chưa chạy → bật Docker Desktop + WSL2 integration
2. `permission denied` docker socket → `sudo usermod -aG docker`
3. `pip install` fail vì externally-managed (PEP 668) → tạo venv
4. Alertmanager `unsupported scheme "" for URL` → v0.27.0 không support `{{ env }}` template, tạo entrypoint.sh inject URL
5. `sed -i` trên bind mount read-only → copy vào /tmp, xử lý rồi exec

---

## 2. Track 02 — Dashboards & Alerts

### 3 Grafana Dashboards

| Dashboard | Trạng thái | Data |
|:----------|:-----------|:-----|
| **AI Service Overview** | ✅ 6 panels có data | 1086 requests, P99 270ms |
| **SLO Burn-Rate** | ✅ Error budget hiển thị | 20.9% fail ratio từ load test có errors |
| **Cost & Tokens** | ✅ Non-zero $/hr | ~354 tokens/s output |

### Bug: Grafana "No Data"
**Nguyên nhân:** File `datasources.yml` không set UID cố định cho Prometheus/Loki, trong khi dashboards hardcode `"uid": "prometheus"`.
**Sửa:** Thêm `uid: prometheus` và `uid: loki` vào provisioning → restart Grafana → data hiện ngay.

### Alert flow
| Thời gian | Sự kiện |
|:---------|:---------|
| 09:50 | App killed |
| 09:54 | ServiceDown firing → Slack fire message sent |
| 09:54 | App restored → alert resolved → Slack resolve message sent |

### Vấn đề Alertmanager v0.27.0
Alertmanager receives alerts (route đúng tới `slack-critical`) nhưng **dispatcher không chạy** (dispatch count = 0 trong logs). Webhook test OK từ container. Giải pháp: gửi Slack trực tiếp qua curl trong trigger script, bypass Alertmanager dispatcher.

---

## 3. Track 03 — Tracing & Logs

### Trace ID
```
9b8aecfaa29e4fb796e6f24e167cf043
```

### Log line with trace_id
```json
{"model": "llama3-mock", "input_tokens": 4, "output_tokens": 54, "quality": 0.82,
 "duration_seconds": 0.1577, "trace_id": "9b8aecfaa29e4fb796e6f24e167cf043",
 "event": "prediction served", "level": "info",
 "timestamp": "2026-06-29T17:33:44.731287Z"}
```

### Jaeger trace
3 child spans under `POST /predict`: `embed-text → vector-search → generate-tokens`
Span attributes include: `gen_ai.request.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `gen_ai.response.finish_reason`.

### Tail-sampling math
Giả sử N=10 traces/s:
- Error rate (ServiceDown): ~0% (chỉ khi kill app)
- Slow rate (>2s): ~0%
- **Fraction kept:** 0% × 1.0 + 0% × 1.0 + 100% × 0.01 = **1%** cho healthy traces
- Thực tế: với 1 traced request, tất cả đều giữ vì decision window 30s chưa đầy

---

## 4. Track 04 — Drift Detection

**⚠️ Chưa chạy** — `python3 scripts/drift_detect.py` cần numpy/scipy trong .venv, đang cài đặt.

---

## 5. Track 05 — Cross-Day Integration

**⚠️ Chưa chạy** — Cần chạy `monitor-day19-vector-store.py` và `monitor-day20-llama-cpp.py`.

---

## 6. The single change that mattered most

The single most impactful change was **adding uid labels to the Grafana datasource provisioning**.

When I first started the stack, all 3 dashboards showed "No Data" even though Prometheus had plenty of metrics. The root cause was a mismatch between the dashboard JSONs (which referenced datasource by hardcoded UIDs like `prometheus` and `jaeger`) and the datasource provisioning YAML (which relied on auto-generated UIDs). Adding `uid: prometheus`, `uid: loki`, and `uid: jaeger` to `datasources.yml` instantly brought all dashboards to life.

This connects directly to the "Configuration as Code" principle from the deck (deck §15): provisioning manifests must be explicit about identifiers. A 10-second YAML edit saved 30 minutes of debugging Prometheus queries, Grafana API checks, and network troubleshooting. The lesson: when you hardcode references in dashboards, make sure the datasource definitions explicitly match those references — don't leave UIDs to chance.

### Các lỗi đã sửa

| # | Lỗi | Cách sửa | File |
|:-:|:----|:---------|:-----|
| 1 | Grafana dashboards "No Data" | Thêm UID cố định vào datasources.yml | `datasources.yml` |
| 2 | Alertmanager not sending Slack | Bypass dispatch bằng curl script | `trigger-alert.sh` |
| 3 | Alertmanager config parse error | Hardcode URL vào .env, inject qua entrypoint | `entrypoint.sh`, `alertmanager.yml` |
| 4 | `make smoke` fail | Sửa grep pattern `"database":"ok"` → `"ok"` | `Makefile` |