#!/bin/bash
# run_missed_jobs_guard.sh
# 절전/로그인 지연 등으로 놓친 아침 자동화 작업을 보정 실행

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

LOG_DIR="$SCRIPT_DIR/logs"
STATE_DIR="$SCRIPT_DIR/.state"
RUN_DATE=$(date '+%Y-%m-%d')
NOW_HM=$(date '+%H%M')
NOW_HM_DEC=$((10#$NOW_HM))
GUARD_LOG="$LOG_DIR/missed_jobs_guard_${RUN_DATE}.log"

mkdir -p "$LOG_DIR" "$STATE_DIR"
exec >> "$GUARD_LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] guard tick start"

publish_done_file="$STATE_DIR/publish_done_${RUN_DATE}.stamp"
publish_attempt_file="$STATE_DIR/publish_attempted_${RUN_DATE}.stamp"
daily_done_file="$STATE_DIR/daily_done_${RUN_DATE}.stamp"
health_done_file="$STATE_DIR/health_done_${RUN_DATE}.stamp"

publish_ok() {
  local f="$LOG_DIR/cron_publish_${RUN_DATE}.log"
  [ -f "$f" ] || return 1
  grep -qE "✅ auto publish pushed|ℹ️ no publish changes|===== .* publish end =====" "$f"
}

daily_ok() {
  local f="$LOG_DIR/dailybridge_${RUN_DATE}.log"
  [ -f "$SCRIPT_DIR/data/daily_bridge_${RUN_DATE}.json" ] || return 1
  [ -f "$f" ] || return 1
  grep -q "✅ .* - 완료!" "$f"
}

health_ok() {
  local f="$LOG_DIR/automation_health_${RUN_DATE}.log"
  [ -f "$f" ] || return 1
  grep -q "healthcheck publish=.* daily=.* antigravity=.*" "$f"
}

if (( NOW_HM_DEC >= 700 )) && [ ! -f "$publish_done_file" ] && [ ! -f "$publish_attempt_file" ]; then
  if publish_ok; then
    touch "$publish_done_file"
    touch "$publish_attempt_file"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] publish already done"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] publish missed -> run_7am_publish.sh"
    touch "$publish_attempt_file"
    if /bin/bash "$SCRIPT_DIR/run_7am_publish.sh"; then
      if publish_ok; then
        touch "$publish_done_file"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] publish recovery success"
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] publish recovery ran but verification failed"
      fi
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] publish recovery failed"
    fi
  fi
fi

if (( NOW_HM_DEC >= 710 )) && [ ! -f "$daily_done_file" ]; then
  if daily_ok; then
    touch "$daily_done_file"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] daily already done"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] daily missed -> run_daily_bridge.sh"
    if /bin/bash "$SCRIPT_DIR/run_daily_bridge.sh"; then
      if daily_ok; then
        touch "$daily_done_file"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] daily recovery success"
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] daily recovery ran but verification failed"
      fi
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] daily recovery failed"
    fi
  fi
fi

if (( NOW_HM_DEC >= 705 )) && [ ! -f "$health_done_file" ]; then
  if health_ok; then
    touch "$health_done_file"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] healthcheck already done"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] healthcheck missed -> run_705_healthcheck.sh"
    if /bin/bash "$SCRIPT_DIR/run_705_healthcheck.sh"; then
      if health_ok; then
        touch "$health_done_file"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] healthcheck recovery success"
      else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] healthcheck recovery ran but verification failed"
      fi
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] healthcheck recovery failed"
    fi
  fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] guard tick end"
