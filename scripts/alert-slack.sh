#!/usr/bin/env bash
## Watchdog: monitor Prometheus alerts and send Slack notifications
## at the CORRECT timing (when alert actually fires / resolves).
##
## Usage:
##   bash scripts/alert-slack.sh              # watch and auto-notify
##   SLACK_WEBHOOK_URL=... bash scripts/alert-slack.sh
##
set -euo pipefail

SLACK_URL="${SLACK_WEBHOOK_URL:-$(grep ^SLACK_WEBHOOK_URL= .env | head -1 | cut -d= -f2)}"
ALERT_NAME="${1:-ServiceDown}"
POLL_INTERVAL=5
PREV_STATE=""

echo "Alert Slack Watchdog starting..."
echo "  Monitoring:  $ALERT_NAME"
echo "  Poll every:  ${POLL_INTERVAL}s"
echo ""

send_slack() {
    local state="$1"  # firing or resolved
    local emoji="🔥"
    local verb="FIRING"
    if [ "$state" = "resolved" ]; then
        emoji="✅"
        verb="RESOLVED"
    fi
    local msg="${emoji} ${verb}: ${ALERT_NAME} alert"
    msg="${msg}\n*Summary:* inference-api is down"
    msg="${msg}\n*Description:* Prometheus has been unable to scrape inference-api"
    msg="${msg}\n*Status:* $state"

    echo "Sending Slack ${state}..."
    curl -s -X POST "$SLACK_URL" \
        -H 'Content-Type: application/json' \
        -d "$(cat <<EOF
{"text":"${msg}"}
EOF
)" > /dev/null
    echo "  Done at $(date '+%H:%M:%S')"
}

while true; do
    # Get state of the alert from Prometheus API
    STATE=$(curl -s http://localhost:9090/api/v1/alerts 2>/dev/null | \
            python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for a in d.get('data',{}).get('alerts',[]):
        if a['labels'].get('alertname','') == '$ALERT_NAME':
            print(a['state'])
            break
except: pass
" 2>/dev/null || echo "unknown")

    if [ -z "$STATE" ]; then
        STATE="inactive"
    fi

    if [ "$STATE" != "$PREV_STATE" ] && [ -n "$PREV_STATE" ]; then
        echo "State change: ${PREV_STATE} → ${STATE} at $(date '+%H:%M:%S')"
        if [ "$STATE" = "firing" ]; then
            send_slack "firing"
        elif [ "$PREV_STATE" = "firing" ] && { [ "$STATE" = "inactive" ] || [ "$STATE" = "pending" ]; }; then
            send_slack "resolved"
        fi
    fi

    PREV_STATE="$STATE"
    sleep "$POLL_INTERVAL"
done