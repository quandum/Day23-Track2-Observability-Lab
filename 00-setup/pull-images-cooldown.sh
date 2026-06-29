#!/usr/bin/env bash
## Pre-pull all Docker images with 5-minute cooling breaks between each.
set -euo pipefail

IMAGES=(
  "prom/prometheus:v2.55.0"
  "prom/alertmanager:v0.27.0"
  "grafana/grafana:11.3.0"
  "grafana/loki:3.3.0"
  "jaegertracing/all-in-one:1.62.0"
  "otel/opentelemetry-collector-contrib:0.114.0"
)

SLEEP_MINUTES=2
SLEEP_SECONDS=$((SLEEP_MINUTES * 60))

echo "Safe pull: ${#IMAGES[@]} images, ${SLEEP_MINUTES}min rest between each"
echo "Started at: $(date '+%H:%M:%S')"
echo ""

for i in "${!IMAGES[@]}"; do
  img="${IMAGES[$i]}"
  echo "=== [$(date '+%H:%M:%S')] Pulling image $((i+1))/${#IMAGES[@]}: $img ==="
  docker pull "$img"
  echo "=== Done: $img ==="
  
  if [ "$i" -lt $((${#IMAGES[@]} - 1)) ]; then
    echo "--- Cooling down for ${SLEEP_MINUTES} minutes (${SLEEP_SECONDS}s)... ---"
    sleep "$SLEEP_SECONDS"
  fi
done

echo ""
echo "=== All images cached at $(date '+%H:%M:%S') ==="