#!/bin/bash
# run_perplexity_auto.sh
# Perplexity API로 뉴스 생성 -> 정규화 -> 대시보드 동기화

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

LOG_DIR="$SCRIPT_DIR/logs"
LOCK_DIR="$SCRIPT_DIR/.locks"
STATE_DIR="$SCRIPT_DIR/.state"
LOCK_FILE="$LOCK_DIR/run_perplexity_auto.lock"
RUN_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/perplexity_auto_${RUN_DATE}.log"
ERR_LOG_FILE="$LOG_DIR/perplexity_auto_error_${RUN_DATE}.log"
RUN_TMP_FILE="$LOG_DIR/perplexity_auto_run_${RUN_DATE}.tmp"
ZERO_ADDED_ALERT_SENT="$STATE_DIR/perplexity_zero_added_${RUN_DATE}.sent"

mkdir -p "$LOG_DIR" "$LOCK_DIR" "$STATE_DIR"

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
    rm -f "$RUN_TMP_FILE"
}
trap cleanup EXIT INT TERM

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
        token="${token:-$(read_env_value TELEGRAM_BOT_TOKEN "$SCRIPT_DIR/.env" || true)}"
        chat_id="${chat_id:-$(read_env_value TELEGRAM_CHAT_ID "$SCRIPT_DIR/.env" || true)}"
    fi

    if [ -z "$token" ] || [ -z "$chat_id" ]; then
        token="${token:-$(read_env_value TELEGRAM_BOT_TOKEN "$SCRIPT_DIR/../woonmok.github.io/.env" || true)}"
        chat_id="${chat_id:-$(read_env_value TELEGRAM_CHAT_ID "$SCRIPT_DIR/../woonmok.github.io/.env" || true)}"
    fi

    echo "$token|$chat_id"
}

send_zero_added_alert_once() {
    local reason="$1"

    if [ -f "$ZERO_ADDED_ALERT_SENT" ]; then
        echo "ℹ️ $(date '+%Y-%m-%d %H:%M:%S') - added=0 알림은 이미 오늘 발송됨"
        return 0
    fi

    local creds token chat_id
    creds=$(get_telegram_credentials)
    token="${creds%%|*}"
    chat_id="${creds##*|}"

    if [ -z "$token" ] || [ -z "$chat_id" ]; then
        echo "ℹ️ $(date '+%Y-%m-%d %H:%M:%S') - Telegram 알림 건너뜀: TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID 없음"
        return 0
    fi

    local msg
    msg="⚠️ Perplexity 신규 뉴스 0건 감지 (${RUN_DATE})%0A- reason: ${reason}%0A- host: $(hostname)%0A- script: run_perplexity_auto.sh"
    if curl -fsS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${msg}" >/dev/null; then
        touch "$ZERO_ADDED_ALERT_SENT"
        echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - added=0 텔레그램 알림 발송 완료"
    else
        echo "⚠️ $(date '+%Y-%m-%d %H:%M:%S') - added=0 텔레그램 알림 발송 실패"
    fi
}

# Python 실행 환경 선택 (.venv-1 우선, 실행 가능 여부 검증)
PYTHON_BIN="python3"
for candidate in \
    "$SCRIPT_DIR/.venv-1/bin/python" \
    "$SCRIPT_DIR/.venv312/bin/python" \
    "$SCRIPT_DIR/.venv/bin/python" \
    "python3"
do
    if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
        if "$candidate" --version >/dev/null 2>&1; then
            PYTHON_BIN="$candidate"
            break
        else
            echo "⚠️ $(date '+%Y-%m-%d %H:%M:%S') - Python 후보 실행 실패, 건너뜀: $candidate"
        fi
    fi
done
echo "🐍 $(date '+%Y-%m-%d %H:%M:%S') - Python 인터프리터: $PYTHON_BIN"

PERPLEXITY_MODEL="${PERPLEXITY_MODEL:-$(read_env_value PERPLEXITY_MODEL "$SCRIPT_DIR/.env" || true)}"
PERPLEXITY_MODEL="${PERPLEXITY_MODEL:-sonar}"
export PERPLEXITY_MODEL
echo "🧠 $(date '+%Y-%m-%d %H:%M:%S') - Perplexity 모델: $PERPLEXITY_MODEL"

"$PYTHON_BIN" "$SCRIPT_DIR/tools/perplexity_auto.py" | tee "$RUN_TMP_FILE"

if grep -Eq "^added=0$" "$RUN_TMP_FILE"; then
    if grep -q "data already fresh, Perplexity API call skipped" "$RUN_TMP_FILE"; then
        echo "ℹ️ $(date '+%Y-%m-%d %H:%M:%S') - added=0 (today fresh data, API skip)"
    else
        echo "⚠️ $(date '+%Y-%m-%d %H:%M:%S') - added=0 (new content 없음)"
        send_zero_added_alert_once "no_new_items_after_run"
    fi
else
    rm -f "$ZERO_ADDED_ALERT_SENT"
fi

echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 완료!"
