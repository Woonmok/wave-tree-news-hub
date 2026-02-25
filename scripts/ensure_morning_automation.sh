#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY="$(cd "$BASE/../woonmok.github.io" && pwd)"
LOG_DIR="$BASE/logs"
STATE_DIR="$BASE/.state"
LOCK_FILE="$STATE_DIR/ensure_morning_automation.lock"
RUN_LOG="$LOG_DIR/ensure_morning_automation.log"
TODAY=$(date '+%Y-%m-%d')
DONE_FILE="$STATE_DIR/morning_automation_${TODAY}.done"

mkdir -p "$LOG_DIR" "$STATE_DIR"
exec >> "$RUN_LOG" 2>&1

ts() { date '+%Y-%m-%d %H:%M:%S'; }

check_success() {
    local daily_log="$BASE/logs/dailybridge_${TODAY}.log"
    local daily_json="$BASE/data/daily_bridge_${TODAY}.json"
    local dashboard_json="$DEPLOY/dashboard_data.json"

    [ -s "$daily_log" ] || return 1
    [ -s "$daily_json" ] || return 1
    [ -s "$dashboard_json" ] || return 1

    if grep -q "완료" "$daily_log" || grep -q "분석 완료" "$daily_log"; then
        return 0
    fi

    return 1
}

if [ "$(date '+%H')" -lt 7 ]; then
    echo "[$(ts)] skip: before 07:00"
    exit 0
fi

if [ -f "$DONE_FILE" ] && check_success; then
    echo "[$(ts)] skip: already completed today"
    exit 0
fi

if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || true)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[$(ts)] skip: guard already running (PID: $OLD_PID)"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM

if pgrep -f "[r]un_7am_publish.sh|[r]un_daily_bridge.sh" >/dev/null 2>&1; then
    echo "[$(ts)] skip: morning jobs currently running"
    exit 0
fi

if check_success; then
    touch "$DONE_FILE"
    echo "[$(ts)] done: artifacts already present"
    exit 0
fi

echo "[$(ts)] missing morning artifacts, starting recovery run"

PUBLISH_OK=0
BRIDGE_OK=0

if /bin/bash "$BASE/run_7am_publish.sh"; then
    PUBLISH_OK=1
else
    echo "[$(ts)] warn: run_7am_publish.sh failed"
fi

if /bin/bash "$BASE/run_daily_bridge.sh"; then
    BRIDGE_OK=1
else
    echo "[$(ts)] warn: run_daily_bridge.sh failed"
fi

if check_success; then
    touch "$DONE_FILE"
    echo "[$(ts)] recovery success (publish=$PUBLISH_OK, bridge=$BRIDGE_OK)"
    exit 0
fi

echo "[$(ts)] recovery failed (publish=$PUBLISH_OK, bridge=$BRIDGE_OK)"
exit 1
