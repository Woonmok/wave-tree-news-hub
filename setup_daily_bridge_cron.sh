#!/bin/bash
# setup_daily_bridge_cron.sh
# macOS cron에 run_daily_bridge.sh를 안전하게 등록(중복 방지)하는 스크립트

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PUBLISH_SCRIPT_PATH="$SCRIPT_DIR/run_7am_publish.sh"
DAILY_SCRIPT_PATH="$SCRIPT_DIR/run_daily_bridge.sh"

PUBLISH_CRON_TIME="50 6 * * *"
DAILY_CRON_TIME="0 7 * * *"

PUBLISH_CRON_CMD="/bin/bash $PUBLISH_SCRIPT_PATH"
DAILY_CRON_CMD="/bin/bash $DAILY_SCRIPT_PATH"

PUBLISH_CRON_LINE="$PUBLISH_CRON_TIME $PUBLISH_CRON_CMD"
DAILY_CRON_LINE="$DAILY_CRON_TIME $DAILY_CRON_CMD"

chmod +x "$PUBLISH_SCRIPT_PATH" "$DAILY_SCRIPT_PATH"

CURRENT_CRON=$(crontab -l 2>/dev/null || true)
FILTERED=$(printf "%s\n" "$CURRENT_CRON" | grep -F -v "$PUBLISH_SCRIPT_PATH" | grep -F -v "$DAILY_SCRIPT_PATH" || true)

{
  printf "%s\n" "$FILTERED" | sed '/^[[:space:]]*$/d'
  printf "%s\n" "$PUBLISH_CRON_LINE"
  printf "%s\n" "$DAILY_CRON_LINE"
} | crontab -

echo "✅ cron 등록 완료"
echo "- 스케줄: 매일 06:50 (publish), 07:00 (daily bridge)"
echo "- 명령1: $PUBLISH_CRON_CMD"
echo "- 명령2: $DAILY_CRON_CMD"
echo ""
echo "📋 현재 crontab"
crontab -l
