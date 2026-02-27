#!/bin/bash
# setup_daily_bridge_cron.sh
# macOS cron에 run_daily_bridge.sh를 안전하게 등록(중복 방지)하는 스크립트

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PUBLISH_SCRIPT_PATH="$SCRIPT_DIR/run_7am_publish.sh"
DAILY_SCRIPT_PATH="$SCRIPT_DIR/run_daily_bridge.sh"
HEALTHCHECK_SCRIPT_PATH="$SCRIPT_DIR/run_705_healthcheck.sh"
MISSED_GUARD_SCRIPT_PATH="$SCRIPT_DIR/run_missed_jobs_guard.sh"
ANTIGRAVITY_SCRIPT_PATH="/Volumes/AI_WORKSPACE/projects/woonmok.github.io/scripts/ensure_antigravity.sh"

PUBLISH_CRON_TIME="50 6 * * *"
DAILY_CRON_TIME="0 7 * * *"
HEALTHCHECK_CRON_TIME="5 7 * * *"
ANTIGRAVITY_CRON_TIME="*/2 * * * *"
MISSED_GUARD_CRON_TIME="*/10 * * * *"

PUBLISH_CRON_CMD="/bin/bash $PUBLISH_SCRIPT_PATH"
DAILY_CRON_CMD="/bin/bash $DAILY_SCRIPT_PATH"
HEALTHCHECK_CRON_CMD="/bin/bash $HEALTHCHECK_SCRIPT_PATH"
ANTIGRAVITY_CRON_CMD="/bin/zsh $ANTIGRAVITY_SCRIPT_PATH"
MISSED_GUARD_CRON_CMD="/bin/bash $MISSED_GUARD_SCRIPT_PATH"

PUBLISH_CRON_LINE="$PUBLISH_CRON_TIME $PUBLISH_CRON_CMD"
DAILY_CRON_LINE="$DAILY_CRON_TIME $DAILY_CRON_CMD"
HEALTHCHECK_CRON_LINE="$HEALTHCHECK_CRON_TIME $HEALTHCHECK_CRON_CMD"
ANTIGRAVITY_CRON_LINE="$ANTIGRAVITY_CRON_TIME $ANTIGRAVITY_CRON_CMD"
MISSED_GUARD_CRON_LINE="$MISSED_GUARD_CRON_TIME $MISSED_GUARD_CRON_CMD"

chmod +x "$PUBLISH_SCRIPT_PATH" "$DAILY_SCRIPT_PATH" "$HEALTHCHECK_SCRIPT_PATH" "$MISSED_GUARD_SCRIPT_PATH"
[ -f "$ANTIGRAVITY_SCRIPT_PATH" ] && chmod +x "$ANTIGRAVITY_SCRIPT_PATH"

CURRENT_CRON=$(crontab -l 2>/dev/null || true)
FILTERED=$(printf "%s\n" "$CURRENT_CRON" | grep -F -v "$PUBLISH_SCRIPT_PATH" | grep -F -v "$DAILY_SCRIPT_PATH" | grep -F -v "$HEALTHCHECK_SCRIPT_PATH" | grep -F -v "$MISSED_GUARD_SCRIPT_PATH" | grep -F -v "$ANTIGRAVITY_SCRIPT_PATH" || true)

{
  printf "%s\n" "$FILTERED" | sed '/^[[:space:]]*$/d'
  printf "%s\n" "$PUBLISH_CRON_LINE"
  printf "%s\n" "$DAILY_CRON_LINE"
  printf "%s\n" "$HEALTHCHECK_CRON_LINE"
  printf "%s\n" "$MISSED_GUARD_CRON_LINE"
  if [ -f "$ANTIGRAVITY_SCRIPT_PATH" ]; then
    printf "%s\n" "$ANTIGRAVITY_CRON_LINE"
  fi
} | crontab -

echo "✅ cron 등록 완료"
echo "- 스케줄: 매일 06:50 (publish), 07:00 (daily bridge), 07:05 (healthcheck), 10분 주기 (missed-jobs guard), 2분 주기 (antigravity watchdog)"
echo "- 명령1: $PUBLISH_CRON_CMD"
echo "- 명령2: $DAILY_CRON_CMD"
echo "- 명령3: $HEALTHCHECK_CRON_CMD"
echo "- 명령4: $MISSED_GUARD_CRON_CMD"
if [ -f "$ANTIGRAVITY_SCRIPT_PATH" ]; then
  echo "- 명령5: $ANTIGRAVITY_CRON_CMD"
else
  echo "- 명령5: (건너뜀) antigravity watchdog 스크립트 없음: $ANTIGRAVITY_SCRIPT_PATH"
fi
echo ""
echo "📋 현재 crontab"
crontab -l
