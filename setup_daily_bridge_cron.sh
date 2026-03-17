#!/bin/bash
# setup_daily_bridge_cron.sh
# macOS cron에 run_daily_bridge.sh를 안전하게 등록(중복 방지)하는 스크립트

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
HOME_WORKSPACE_ROOT="${HOME}/AI_WORKSPACE"

# Prefer the home workspace path for cron to avoid external-volume permission issues.
if [ -d "$HOME_WORKSPACE_ROOT/wave-tree-news-hub" ]; then
  SCRIPT_DIR="$HOME_WORKSPACE_ROOT/wave-tree-news-hub"
fi

WOONMOK_DIR="$SCRIPT_DIR/../woonmok.github.io"
if [ -d "$HOME_WORKSPACE_ROOT/woonmok.github.io" ]; then
  WOONMOK_DIR="$HOME_WORKSPACE_ROOT/woonmok.github.io"
fi

CRON_LOG_DIR="${HOME}/Library/Logs/wave-tree-news-hub-cron"
PUBLISH_SCRIPT_PATH="$SCRIPT_DIR/run_7am_publish.sh"
DAILY_SCRIPT_PATH="$SCRIPT_DIR/run_daily_bridge.sh"
HEALTHCHECK_SCRIPT_PATH="$SCRIPT_DIR/run_705_healthcheck.sh"
RECONCILE_SCRIPT_PATH="$SCRIPT_DIR/run_710_reconcile.sh"
MISSED_GUARD_SCRIPT_PATH="$SCRIPT_DIR/run_missed_jobs_guard.sh"
MORNING_STATUS_SCRIPT_PATH="$SCRIPT_DIR/scripts/report_morning_status.sh"
ANTIGRAVITY_SCRIPT_PATH="$WOONMOK_DIR/scripts/ensure_antigravity.sh"

PUBLISH_CRON_TIME="50 6 * * *"
DAILY_CRON_TIME="0 7 * * *"
HEALTHCHECK_CRON_TIME="5 7 * * *"
RECONCILE_CRON_TIME="10 7 * * *"
ANTIGRAVITY_CRON_TIME="*/2 * * * *"
MISSED_GUARD_CRON_TIME="*/10 * * * *"
MISSED_GUARD_REBOOT_TIME="@reboot"
MORNING_STATUS_0905_CRON_TIME="5 9 * * *"

mkdir -p "$CRON_LOG_DIR"

PUBLISH_CRON_CMD="/bin/bash $PUBLISH_SCRIPT_PATH >> $CRON_LOG_DIR/cron_publish.log 2>&1"
DAILY_CRON_CMD="/bin/bash $DAILY_SCRIPT_PATH >> $CRON_LOG_DIR/cron_daily_bridge.log 2>&1"
HEALTHCHECK_CRON_CMD="/bin/bash $HEALTHCHECK_SCRIPT_PATH >> $CRON_LOG_DIR/cron_healthcheck.log 2>&1"
RECONCILE_CRON_CMD="/bin/bash $RECONCILE_SCRIPT_PATH >> $CRON_LOG_DIR/cron_reconcile.log 2>&1"
ANTIGRAVITY_CRON_CMD="/bin/zsh $ANTIGRAVITY_SCRIPT_PATH >> $CRON_LOG_DIR/ensure_antigravity_cron.log 2>&1"
MISSED_GUARD_CRON_CMD="/bin/bash $MISSED_GUARD_SCRIPT_PATH >> $CRON_LOG_DIR/cron_missed_guard.log 2>&1"
MISSED_GUARD_REBOOT_CMD="/bin/bash $MISSED_GUARD_SCRIPT_PATH >> $CRON_LOG_DIR/cron_missed_guard.log 2>&1"
MORNING_STATUS_0905_CRON_CMD="/bin/bash $MORNING_STATUS_SCRIPT_PATH >> $CRON_LOG_DIR/report_morning_status_0905_cron.log 2>&1"

PUBLISH_CRON_LINE="$PUBLISH_CRON_TIME $PUBLISH_CRON_CMD"
DAILY_CRON_LINE="$DAILY_CRON_TIME $DAILY_CRON_CMD"
HEALTHCHECK_CRON_LINE="$HEALTHCHECK_CRON_TIME $HEALTHCHECK_CRON_CMD"
RECONCILE_CRON_LINE="$RECONCILE_CRON_TIME $RECONCILE_CRON_CMD"
ANTIGRAVITY_CRON_LINE="$ANTIGRAVITY_CRON_TIME $ANTIGRAVITY_CRON_CMD"
MISSED_GUARD_CRON_LINE="$MISSED_GUARD_CRON_TIME $MISSED_GUARD_CRON_CMD"
MISSED_GUARD_REBOOT_LINE="$MISSED_GUARD_REBOOT_TIME $MISSED_GUARD_REBOOT_CMD"
MORNING_STATUS_0905_CRON_LINE="$MORNING_STATUS_0905_CRON_TIME $MORNING_STATUS_0905_CRON_CMD"

chmod +x "$PUBLISH_SCRIPT_PATH" "$DAILY_SCRIPT_PATH" "$HEALTHCHECK_SCRIPT_PATH" "$RECONCILE_SCRIPT_PATH" "$MISSED_GUARD_SCRIPT_PATH" "$MORNING_STATUS_SCRIPT_PATH"
[ -f "$ANTIGRAVITY_SCRIPT_PATH" ] && chmod +x "$ANTIGRAVITY_SCRIPT_PATH"

CURRENT_CRON=$(crontab -l 2>/dev/null || true)
FILTERED=$(printf "%s\n" "$CURRENT_CRON" \
  | grep -E -v '/run_7am_publish\.sh' \
  | grep -E -v '/run_daily_bridge\.sh' \
  | grep -E -v '/run_705_healthcheck\.sh' \
  | grep -E -v '/run_710_reconcile\.sh' \
  | grep -E -v '/run_missed_jobs_guard\.sh' \
  | grep -E -v '^@reboot[[:space:]]+/bin/bash.*/run_missed_jobs_guard\.sh' \
  | grep -E -v '/report_morning_status\.sh' \
  | grep -E -v 'ensure_antigravity\.sh' \
  || true)

{
  printf "%s\n" "$FILTERED" | sed '/^[[:space:]]*$/d'
  printf "%s\n" "$PUBLISH_CRON_LINE"
  printf "%s\n" "$DAILY_CRON_LINE"
  printf "%s\n" "$HEALTHCHECK_CRON_LINE"
  printf "%s\n" "$RECONCILE_CRON_LINE"
  printf "%s\n" "$MISSED_GUARD_CRON_LINE"
  printf "%s\n" "$MISSED_GUARD_REBOOT_LINE"
  printf "%s\n" "$MORNING_STATUS_0905_CRON_LINE"
  if [ -f "$ANTIGRAVITY_SCRIPT_PATH" ]; then
    printf "%s\n" "$ANTIGRAVITY_CRON_LINE"
  fi
} | crontab -

echo "✅ cron 등록 완료"
echo "- 스케줄: 매일 06:50 (publish), 07:00 (daily bridge), 07:05 (healthcheck), 07:10 (reconcile), 10분 주기 + @reboot (missed-jobs guard), 2분 주기 (antigravity watchdog)"
echo "- cron 로그 경로: $CRON_LOG_DIR"
echo "- 명령1: $PUBLISH_CRON_CMD"
echo "- 명령2: $DAILY_CRON_CMD"
echo "- 명령3: $HEALTHCHECK_CRON_CMD"
echo "- 명령4: $RECONCILE_CRON_CMD"
echo "- 명령5: $MISSED_GUARD_CRON_CMD"
echo "- 명령6: $MISSED_GUARD_REBOOT_CMD (@reboot)"
echo "- 명령7: $MORNING_STATUS_0905_CRON_CMD"
if [ -f "$ANTIGRAVITY_SCRIPT_PATH" ]; then
  echo "- 명령8: $ANTIGRAVITY_CRON_CMD"
else
  echo "- 명령8: (건너뜀) antigravity watchdog 스크립트 없음: $ANTIGRAVITY_SCRIPT_PATH"
fi
echo ""
echo "📋 현재 crontab"
crontab -l
