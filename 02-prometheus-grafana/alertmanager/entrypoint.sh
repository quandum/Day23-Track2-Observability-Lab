#!/bin/sh
## Inject SLACK_WEBHOOK_URL from env into alertmanager.yml at runtime.
## This keeps the webhook URL OUT of git (use .env instead).

set -e

# Copy config from read-only mount to writable location
cp /etc/alertmanager/alertmanager.yml /tmp/alertmanager.yml

# Replace placeholder with actual env var value
sed -i "s|https://hooks.slack.com/services/REPLACE/ME|${SLACK_WEBHOOK_URL}|g" /tmp/alertmanager.yml

echo "Starting alertmanager with injected webhook URL..."
exec /bin/alertmanager --config.file=/tmp/alertmanager.yml --storage.path=/alertmanager --web.listen-address=:9093