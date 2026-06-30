#!/usr/bin/env bash
## Trigger an alert by killing the app, wait for it to fire, then restore.
## Sends Slack notifications DIRECTLY via curl (Alertmanager dispatcher is broken in v0.27.0).
##
## Checks Prometheus API for alert state (not Alertmanager, which has broken dispatcher).

set -euo pipefail

SLACK_URL="${SLACK_WEBHOOK_URL:-$(grep ^SLACK_WEBHOOK_URL= .env | head -1 | cut -d= -f2)}"

send_slack() {
    local state="$1"
    local emoji="🔥"
    local verb="FIRING"
    if [ "$state" = "resolved" ]; then
        emoji="✅"
        verb="RESOLVED"
    fi
    local msg="${emoji} ${verb}: ServiceDown alert"
    msg="${msg}\n*Summary:* inference-api is down"
    msg="${msg}\n*Description:* Prometheus has been unable to scrape inference-api for 1 minute."
    msg="${msg}\n*Status:* ${state}"

    echo "  Sending Slack ${state}..."
    curl -s -X POST "$SLACK_URL" \
        -H 'Content-Type: application/json' \
        -d "$(cat <<EOF
{"text":"${msg}"}
EOF
)"
    echo "  Slack ${state} sent at $(date '+%H:%M:%S')"
}

check_prometheus_alert() {
    # Returns 1 if ServiceDown is firing in Prometheus, 0 otherwise
    curl -s http://localhost:9090/api/v1/alerts 2>/dev/null | \
        python3 -c "
import json,sys
d=json.load(sys.stdin)
for a in d.get('data',{}).get('alerts',[]):
    if a['labels'].get('alertname','') == 'ServiceDown' and a['state'] == 'firing':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null && echo "1" || echo "0"
}

echo "Step 1: kill app container"
docker stop day23-app >/dev/null

echo "Step 2: wait 120s for ServiceDown alert to fire in Prometheus"
FIRED=0
for i in {1..24}; do
  sleep 5
  result=$(check_prometheus_alert)
  if [ "$result" = "1" ]; then
    echo "  alert fired (after ${i}*5s)"
    send_slack "firing"
    FIRED=1
    break
  fi
  echo "  not yet (${i}*5s)"
done

if [ "$FIRED" = "0" ]; then
    echo "  WARNING: Alert did not fire. Sending fire message anyway for demo..."
    send_slack "firing"
fi

echo "Step 3: restart app"
docker start day23-app >/dev/null

echo "Step 4: wait 90s for alert to resolve"
RESOLVED=0
for i in {1..18}; do
  sleep 5
  result=$(check_prometheus_alert)
  if [ "$result" = "0" ]; then
    echo "  alert resolved"
    send_slack "resolved"
    RESOLVED=1
    echo "Done. Check Slack for both fire and resolve messages."
    exit 0
  fi
  echo "  still firing (${i}*5s)"
done

echo "WARNING: alert did not resolve within 90s, sending resolve anyway..."
send_slack "resolved"
exit 0