#!/bin/bash
# setup_daily_bridge_cron.sh
# macOS cron에 run_daily_bridge.sh를 안전하게 등록(중복 방지)하는 스크립트

set -Eeuo pipefail

SCRIPT_PATH="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/run_daily_bridge.sh"
CRON_TIME="0 7 * * *"
CRON_CMD="/bin/bash $SCRIPT_PATH"
CRON_LINE="$CRON_TIME $CRON_CMD"

if [ ! -x "$SCRIPT_PATH" ]; then
  chmod +x "$SCRIPT_PATH"
fi

CURRENT_CRON=$(crontab -l 2>/dev/null || true)
FILTERED=$(printf "%s\n" "$CURRENT_CRON" | grep -F -v "$SCRIPT_PATH" || true)

{
  printf "%s\n" "$FILTERED" | sed '/^[[:space:]]*$/d'
  printf "%s\n" "$CRON_LINE"
} | crontab -

echo "✅ cron 등록 완료"
echo "- 스케줄: 매일 07:00"
echo "- 명령: $CRON_CMD"
echo ""
echo "📋 현재 crontab"
crontab -l
