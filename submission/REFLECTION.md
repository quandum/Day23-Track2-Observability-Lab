# Day 23 Lab Reflection

> Fill in each section. Grader reads the "What I'd change" paragraph closest.

**Student:** Trần Mạnh Chánh Quân
**Mã số học viên:** 2A202600786
**Submission date:** 2026-06-29
**Lab repo URL:** _[public GitHub URL]_

---

## 1. Hardware + setup output

Paste output of `python3 00-setup/verify-docker.py`:

```
Docker:        OK  (29.5.3)
Compose v2:    OK  (5.1.4)
RAM available: 11.68 GB (OK)
Ports free:    BOUND: [8000, 9090, 9093, 3000, 3100, 16686, 4317, 4318, 8888] — stack đang chạy
Report written: /mnt/c/Users/quand/OneDrive/Documents/VinUni-AI2k_2/Day23-Track2-Lab/00-setup/setup-report.json
```

**Pre-flight checks:** Docker Desktop 29.5.3 trên WSL2 (Ubuntu), RAM 11 GB (free 4.4 GB), Disk 1007 GB (951 GB avail), Python 3.12.3.

**Lỗi gặp phải khi setup:**
1. Docker Desktop daemon chưa chạy → bật Docker Desktop + WSL2 integration
2. `permission denied` docker socket → `sudo usermod -aG docker`
3. `pip install` fail vì externally-managed → tạo `venv/` với `python3-venv`
4. Alertmanager v0.27.0 không support `{{ env }}` template → tạo entrypoint.sh inject webhook URL
5. Load test fail vì `zope.event` missing → dùng venv riêng

---

## 2. Track 02 — Dashboards & Alerts

### 6 essential panels (screenshot)

Drop `submission/screenshots/dashboard-overview.png`.

### Burn-rate panel

Drop `submission/screenshots/slo-burn-rate.png`.

### Alert fire + resolve

| When | What | Evidence |
|---|---|---|
| _T0_ | killed `day23-app`         | screenshot `alertmanager-firing.png` |
| _T0+90s_ | `ServiceDown` fired   | screenshot `slack-firing.png` |
| _T1_ | restored app              | — |
| _T1+60s_ | alert resolved        | screenshot `slack-resolved.png` |

### One thing surprised me about Prometheus / Grafana

_(2-3 sentences)_

**Load test results:** Locust 10 users × 60s → **977 requests, 0 failures**, avg latency 178ms, P50 170ms, P99 270ms, throughput ~17.4 req/s.

---

## 3. Track 03 — Tracing & Logs

### One trace screenshot from Jaeger

Drop `submission/screenshots/jaeger-trace.png` showing `embed-text → vector-search → generate-tokens` spans.

### Log line correlated to trace

Paste the log line and the trace_id it links to:

```
... paste here ...
```

### Tail-sampling math

If your service produced N traces/sec, what fraction did the policy keep? Show the calculation.

---

## 4. Track 04 — Drift Detection

### PSI scores

Paste `04-drift-detection/reports/drift-summary.json`:

```json
... paste here ...
```

### Which test fits which feature?

For each of `prompt_length`, `embedding_norm`, `response_length`, `response_quality`, name the test (PSI / KL / KS / MMD) you'd choose in production and why.

---

## 5. Track 05 — Cross-Day Integration

### Which prior-day metric was hardest to expose? Why?

_(2-3 sentences. If you didn't have prior days running, write about which one would be hardest based on the integration scripts.)_

---

## 6. The single change that mattered most

> **Grader reads this closest.** What one thing about your stack design — a metric you added, a label you dropped, a panel you reorganized, an alert threshold you tuned — made the biggest difference between "works" and "useful"? Write 1-2 paragraphs. Connect it to a concept from the deck.

### Các lỗi đã sửa trong quá trình lab

| # | Lỗi | Nguyên nhân | Cách sửa |
|:-:|:-----|:------------|:---------|
| 1 | Docker daemon không reachable | Docker Desktop chưa chạy, WSL2 integration chưa bật | Bật Docker Desktop → Settings → Resources → WSL Integration |
| 2 | `permission denied` docker socket | User chưa trong docker group | `sudo usermod -aG docker $USER` + newgrp |
| 3 | `pip install` fail | Python 3.12 externally-managed (PEP 668) | `python3 -m venv venv` → activate → install |
| 4 | Alertmanager `unsupported scheme "" for URL` | v0.27.0 không support `{{ env "VAR" }}` template | Tạo `entrypoint.sh` copy config từ /tmp → /etc, sed inject URL |
| 5 | `sed -i` can't move: Device or resource busy | Bind mount read-only | Mount vào `/tmp/alertmanager.yml:ro`, cp vào writable location trong entrypoint |
| 6 | `make smoke` fail despite all services healthy | `grep -q '"database":"ok"'` sai pattern (JSON multi-line) | Đổi thành `grep -q '"ok"'` |

**Issues ghi nhận:** Alertmanager v0.27.0 dropped `slack_api_url_file` support và cần URL trực tiếp, không dùng env template được. Load test cần Locust ≥ 2.32 trong venv riêng.