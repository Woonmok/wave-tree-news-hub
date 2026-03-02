#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="${WAVETREE_WORKSPACE_ROOT:-$(cd "$PROJECT_ROOT/.." && pwd)}"

BASE="$PROJECT_ROOT"
DEPLOY="${WAVETREE_DEPLOY_DIR:-$WORKSPACE_ROOT/woonmok.github.io}"
LOG_DIR="$BASE/logs"
STATE_DIR="$BASE/.state"
TODAY=$(date '+%Y-%m-%d')
NOW=$(date '+%Y-%m-%d %H:%M:%S')
OUT="$LOG_DIR/morning_status_${TODAY}.log"
STATUS_STATE_FILE="$STATE_DIR/morning_status_telegram_${TODAY}.state"

mkdir -p "$LOG_DIR" "$STATE_DIR"

read_env_value() {
  local key="$1"
  local file="$2"
  [ -f "$file" ] || return 1
  grep -E "^${key}=" "$file" | tail -n 1 | cut -d '=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

get_telegram_credentials() {
  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat_id="${TELEGRAM_CHAT_ID:-}"

  if [ -z "$token" ] || [ -z "$chat_id" ]; then
    token="${token:-$(read_env_value TELEGRAM_BOT_TOKEN "$BASE/.env" || true)}"
    chat_id="${chat_id:-$(read_env_value TELEGRAM_CHAT_ID "$BASE/.env" || true)}"
  fi

  if [ -z "$token" ] || [ -z "$chat_id" ]; then
    token="${token:-$(read_env_value TELEGRAM_BOT_TOKEN "$DEPLOY/.env" || true)}"
    chat_id="${chat_id:-$(read_env_value TELEGRAM_CHAT_ID "$DEPLOY/.env" || true)}"
  fi

  echo "$token|$chat_id"
}

send_telegram_status() {
  local done_file="$BASE/.state/morning_automation_${TODAY}.done"
  local bridge_json="$BASE/data/daily_bridge_${TODAY}.json"
  local bridge_log="$BASE/logs/dailybridge_${TODAY}.log"
  local dashboard_json="$DEPLOY/dashboard_data.json"

  local done_flag="❌"
  [ -s "$done_file" ] && done_flag="✅"

  local bridge_flag="❌"
  [ -s "$bridge_json" ] && bridge_flag="✅"

  local log_flag="❌"
  [ -s "$bridge_log" ] && log_flag="✅"

  local dash_flag="❌"
  [ -s "$dashboard_json" ] && dash_flag="✅"

  local anti_status="NOT RUNNING"
  if pgrep -af "python.*$DEPLOY/antigravity.py" >/dev/null 2>&1; then
    anti_status="RUNNING"
  fi

  local creds token chat_id
  creds=$(get_telegram_credentials)
  token="${creds%%|*}"
  chat_id="${creds##*|}"

  if [ -z "$token" ] || [ -z "$chat_id" ]; then
    echo "[$NOW] telegram: skip (missing TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID)" >> "$OUT"
    return 0
  fi

  local msg
  local is_problem=0
  if [ "$done_flag" = "❌" ] || [ "$bridge_flag" = "❌" ] || [ "$log_flag" = "❌" ] || [ "$dash_flag" = "❌" ]; then
    is_problem=1
  fi

  state_has_flag() {
    local key="$1"
    [ -f "$STATUS_STATE_FILE" ] || return 1
    grep -q "^${key}=1$" "$STATUS_STATE_FILE"
  }

  state_set_flag() {
    local key="$1"
    if ! state_has_flag "$key"; then
      echo "${key}=1" >> "$STATUS_STATE_FILE"
    fi
  }

  if [ "$is_problem" -eq 1 ] && state_has_flag "sent_alert"; then
    echo "[$NOW] telegram: skip (alert already sent today)" >> "$OUT"
    return 0
  fi

  if [ "$is_problem" -eq 0 ] && state_has_flag "sent_ok"; then
    echo "[$NOW] telegram: skip (daily ok already sent today)" >> "$OUT"
    return 0
  fi

  if [ "$is_problem" -eq 1 ]; then
    msg="🚨 Morning Automation Alert ${TODAY}
- Done marker: ${done_flag}
- Daily JSON: ${bridge_flag}
- Daily Log: ${log_flag}
- Dashboard: ${dash_flag}
- Antigravity: ${anti_status}
- Host: $(hostname)"
  else
    msg="✅ Morning Status ${TODAY}
- Done marker: ${done_flag}
- Daily JSON: ${bridge_flag}
- Daily Log: ${log_flag}
- Dashboard: ${dash_flag}
- Antigravity: ${anti_status}
- Host: $(hostname)"
  fi
  if curl -fsS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
      --data-urlencode "chat_id=${chat_id}" \
      --data-urlencode "text=${msg}" >/dev/null; then
    echo "[$NOW] telegram: sent" >> "$OUT"
    if [ "$is_problem" -eq 1 ]; then
      state_set_flag "sent_alert"
    else
      state_set_flag "sent_ok"
    fi
  else
    echo "[$NOW] telegram: failed" >> "$OUT"
  fi
}

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
  if pgrep -af "python.*$DEPLOY/antigravity.py" >/dev/null 2>&1; then
    pgrep -af "python.*$DEPLOY/antigravity.py"
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

send_telegram_status
