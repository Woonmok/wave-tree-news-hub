#!/bin/bash
set -Eeuo pipefail

BASE="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub"
DEPLOY="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io"
LOG_DIR="$BASE/logs"
TODAY=$(date '+%Y-%m-%d')
NOW=$(date '+%Y-%m-%d %H:%M:%S')
OUT="$LOG_DIR/morning_status_${TODAY}.log"

mkdir -p "$LOG_DIR"

{
  echo "============================================================"
  echo "[${NOW}] Morning Automation Status"
  echo "============================================================"

  echo "[1] Core artifacts"
  for f in \
    "$BASE/data/daily_bridge_${TODAY}.json" \
    "$BASE/logs/dailybridge_${TODAY}.log" \
    "$BASE/.state/morning_automation_${TODAY}.done" \
    "$DEPLOY/dashboard_data.json"; do
    if [ -e "$f" ]; then
      ls -lT "$f"
    else
      echo "MISSING: $f"
    fi
  done

  echo
  echo "[2] Process status"
  if pgrep -af '/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/antigravity.py' >/dev/null 2>&1; then
    pgrep -af '/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/antigravity.py'
  else
    echo "antigravity: NOT RUNNING"
  fi

  echo
  echo "[3] Recent guard logs"
  tail -n 20 "$BASE/logs/ensure_morning_automation.log" 2>/dev/null || echo "no ensure_morning_automation.log"

  echo
  echo "[4] Recent cron bridge logs"
  tail -n 20 "$BASE/logs/cron_daily_bridge.log" 2>/dev/null || echo "no cron_daily_bridge.log"

  echo "============================================================"
  echo
} >> "$OUT" 2>&1
