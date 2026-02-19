#!/bin/bash
# run_perplexity_auto.sh
# Perplexity API로 뉴스 생성 -> 정규화 -> 대시보드 동기화

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

LOG_DIR="$SCRIPT_DIR/logs"
LOCK_DIR="$SCRIPT_DIR/.locks"
LOCK_FILE="$LOCK_DIR/run_perplexity_auto.lock"
RUN_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/perplexity_auto_${RUN_DATE}.log"
ERR_LOG_FILE="$LOG_DIR/perplexity_auto_error_${RUN_DATE}.log"

mkdir -p "$LOG_DIR" "$LOCK_DIR"

if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || true)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "⛔ $(date '+%Y-%m-%d %H:%M:%S') - 이미 실행 중(PID: $OLD_PID). 중복 실행 차단"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"
exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$ERR_LOG_FILE" >&2)

cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM

PYTHON_BIN="/usr/bin/python3"
"$PYTHON_BIN" "$SCRIPT_DIR/tools/perplexity_auto.py"

echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 완료!"
