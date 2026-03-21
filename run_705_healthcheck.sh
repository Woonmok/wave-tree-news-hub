#!/bin/bash
# run_705_healthcheck.sh
# 자동화 체인 상태를 점검하고 텔레그램으로 요약 전송

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

LOG_DIR="$SCRIPT_DIR/logs"
RUN_DATE=$(date '+%Y-%m-%d')
NOW_TS=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$LOG_DIR/automation_health_${RUN_DATE}.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

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

latest_log_or_empty() {
    local pattern="$1"
    local file
    file=$(ls -t $pattern 2>/dev/null | head -n 1 || true)
    echo "${file:-}"
}

latest_dated_log_or_empty() {
    local pattern="$1"
    local file
    local base_name
    local log_date

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        base_name=$(basename "$file")
        log_date=$(echo "$base_name" | sed -nE 's/.*_([0-9]{4}-[0-9]{2}-[0-9]{2})\.log$/\1/p')

        # 날짜가 파일명에 없거나 형식이 다르면 무시
        [ -n "$log_date" ] || continue

        # 미래 날짜 로그(모의 테스트 파일 등)는 헬스체크 판정에서 제외
        if [[ "$log_date" > "$RUN_DATE" ]]; then
            continue
        fi

        echo "$file"
        return 0
    done < <(ls -1t $pattern 2>/dev/null || true)

    echo ""
}

extract_recent_error_lines() {
    local file_path="$1"
    [ -f "$file_path" ] || return 0

    local lines
    lines=$(tail -n 80 "$file_path" | grep -E "❌|ERROR|Traceback|Exception|ModuleNotFoundError|CalledProcessError|실패|failed|FAIL" | tail -n 3 || true)
    if [ -z "$lines" ]; then
        lines=$(tail -n 3 "$file_path" || true)
    fi
    echo "$lines" | sed 's/^[[:space:]]*//'
}

ok_publish=0
ok_daily=0
ok_antigravity=0

publish_log=$(latest_dated_log_or_empty "$SCRIPT_DIR/logs/cron_publish_*.log")
if [ -n "$publish_log" ]; then
    publish_last_outcome=$(grep -E "⚠️ auto publish push 최종 실패|✅ auto publish pushed|ℹ️ no publish changes" "$publish_log" | tail -n 1 || true)
    if echo "$publish_last_outcome" | grep -qE "✅ auto publish pushed|ℹ️ no publish changes"; then
        ok_publish=1
    elif echo "$publish_last_outcome" | grep -q "⚠️ auto publish push 최종 실패"; then
        ok_publish=0
    fi
fi

daily_log=$(latest_dated_log_or_empty "$SCRIPT_DIR/logs/dailybridge_*.log")
if [ -n "$daily_log" ] && [ -f "$SCRIPT_DIR/data/daily_bridge_${RUN_DATE}.json" ]; then
    if grep -q "✅ .* - 완료!" "$daily_log"; then
        ok_daily=1
    fi
fi

if pgrep -af antigravity.py >/dev/null 2>&1; then
    ok_antigravity=1
fi

status_icon="✅"
if [ "$ok_publish" -ne 1 ] || [ "$ok_daily" -ne 1 ] || [ "$ok_antigravity" -ne 1 ]; then
    status_icon="⚠️"
fi

publish_status="FAIL"
daily_status="FAIL"
antigravity_status="FAIL"
[ "$ok_publish" -eq 1 ] && publish_status="OK"
[ "$ok_daily" -eq 1 ] && daily_status="OK"
[ "$ok_antigravity" -eq 1 ] && antigravity_status="OK"

failure_details=""
if [ "$status_icon" = "⚠️" ]; then
    if [ "$ok_publish" -ne 1 ] && [ -n "$publish_log" ]; then
        publish_err=$(extract_recent_error_lines "$publish_log")
        if [ -n "$publish_err" ]; then
            failure_details+="\n[publish]\n${publish_err}"
        fi
    fi

    daily_err_log=$(latest_dated_log_or_empty "$SCRIPT_DIR/logs/dailybridge_error_*.log")
    if [ "$ok_daily" -ne 1 ] && [ -n "$daily_err_log" ]; then
        daily_err=$(extract_recent_error_lines "$daily_err_log")
        if [ -n "$daily_err" ]; then
            failure_details+="\n[daily_bridge]\n${daily_err}"
        fi
    fi

    antigravity_err_log="$SCRIPT_DIR/../woonmok.github.io/logs/antigravity_error.log"
    if [ "$ok_antigravity" -ne 1 ] && [ -f "$antigravity_err_log" ]; then
        antigravity_err=$(extract_recent_error_lines "$antigravity_err_log")
        if [ -n "$antigravity_err" ]; then
            failure_details+="\n[antigravity]\n${antigravity_err}"
        fi
    fi
fi

echo "[$NOW_TS] healthcheck publish=$publish_status daily=$daily_status antigravity=$antigravity_status"

creds=$(get_telegram_credentials)
token="${creds%%|*}"
chat_id="${creds##*|}"

if [ -z "$token" ] || [ -z "$chat_id" ]; then
    echo "ℹ️ Telegram 자격 정보 없음: 전송 건너뜀"
    exit 0
fi

message="$status_icon WaveTree 자동화 헬스체크 (${RUN_DATE} 07:05 기준)\n- publish(06:50): ${publish_status}\n- daily_bridge(07:00): ${daily_status}\n- antigravity(watchdog): ${antigravity_status}\n- checked_at: ${NOW_TS}\n- host: $(hostname)"

if [ -n "$failure_details" ]; then
    message+="\n- recent_errors:${failure_details}"
fi

if curl -fsS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "text=${message}" >/dev/null; then
    echo "✅ 헬스체크 텔레그램 전송 완료"
else
    echo "⚠️ 헬스체크 텔레그램 전송 실패"
fi
