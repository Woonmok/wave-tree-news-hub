#!/bin/bash
set -Eeuo pipefail

BASE="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub"
DEPLOY="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io"
LOG_DIR="$BASE/logs"
TODAY=$(date '+%Y-%m-%d')
NOW=$(date '+%Y-%m-%d %H:%M:%S')
OUT="$LOG_DIR/morning_deadline_${TODAY}.log"

DONE_FILE="$BASE/.state/morning_automation_${TODAY}.done"
DAILY_JSON="$BASE/data/daily_bridge_${TODAY}.json"
DAILY_LOG="$BASE/logs/dailybridge_${TODAY}.log"
DASHBOARD_JSON="$DEPLOY/dashboard_data.json"

mkdir -p "$LOG_DIR"

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

check_success() {
  [ -s "$DAILY_JSON" ] || return 1
  [ -s "$DAILY_LOG" ] || return 1
  [ -s "$DASHBOARD_JSON" ] || return 1
  if grep -q "완료" "$DAILY_LOG" || grep -q "분석 완료" "$DAILY_LOG"; then
    return 0
  fi
  return 1
}

send_telegram_alert() {
  local creds token chat_id
  creds=$(get_telegram_credentials)
  token="${creds%%|*}"
  chat_id="${creds##*|}"

  if [ -z "$token" ] || [ -z "$chat_id" ]; then
    echo "[$NOW] telegram: skip (missing TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID)" >> "$OUT"
    return 0
  fi

  local msg
  msg="🚨 07:20 Morning automation incomplete (${TODAY})
- done_file: $([ -s "$DONE_FILE" ] && echo OK || echo MISSING)
- daily_json: $([ -s "$DAILY_JSON" ] && echo OK || echo MISSING)
- daily_log: $([ -s "$DAILY_LOG" ] && echo OK || echo MISSING)
- dashboard: $([ -s "$DASHBOARD_JSON" ] && echo OK || echo MISSING)
- host: $(hostname)
- check_time: $NOW"

  if curl -fsS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
      --data-urlencode "chat_id=${chat_id}" \
      --data-urlencode "text=${msg}" >/dev/null; then
    echo "[$NOW] telegram: sent incomplete alert" >> "$OUT"
  else
    echo "[$NOW] telegram: failed" >> "$OUT"
  fi
}

echo "[$NOW] 07:20 deadline check start" >> "$OUT"

if check_success; then
  echo "[$NOW] status: complete (no alert)" >> "$OUT"
  exit 0
fi

echo "[$NOW] status: incomplete (alert)" >> "$OUT"
send_telegram_alert
exit 1
