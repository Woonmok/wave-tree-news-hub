#!/bin/bash
# run_daily_bridge.sh
# 매일 아침 뉴스 수집 및 Daily_Bridge.md 자동 생성 스크립트

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

LOG_DIR="$SCRIPT_DIR/logs"
LOCK_DIR="$SCRIPT_DIR/.locks"
LOCK_FILE="$LOCK_DIR/run_daily_bridge.lock"
RUN_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/dailybridge_${RUN_DATE}.log"
ERR_LOG_FILE="$LOG_DIR/dailybridge_error_${RUN_DATE}.log"

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

SUCCESS=0

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

send_telegram_failure() {
    local reason="$1"
    local creds
    creds=$(get_telegram_credentials)
    local token="${creds%%|*}"
    local chat_id="${creds##*|}"

    if [ -z "$token" ] || [ -z "$chat_id" ]; then
        echo "ℹ️ $(date '+%Y-%m-%d %H:%M:%S') - Telegram 알림 건너뜀: TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID 없음"
        return 0
    fi

    local text
    text="❌ Daily Bridge 실패%0A- 시각: $(date '+%Y-%m-%d %H:%M:%S')%0A- 호스트: $(hostname)%0A- 원인: ${reason}%0A- 로그: ${LOG_FILE}"
    curl -fsS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${text}" >/dev/null || true
}

cleanup() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ] || [ "$SUCCESS" -ne 1 ]; then
        echo "❌ $(date '+%Y-%m-%d %H:%M:%S') - 비정상 종료 (exit: $exit_code)"
        send_telegram_failure "exit_code_${exit_code}"
    fi
    rm -f "$LOCK_FILE"
}

trap cleanup EXIT INT TERM

for cmd in cp mkdir date tee; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ $(date '+%Y-%m-%d %H:%M:%S') - 필수 명령어 누락: $cmd"
        exit 1
    fi
done

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

# 백업: perplexity.txt를 날짜별로 저장
BACKUP_DIR="data/raw/backups"
BACKUP_FILE="$BACKUP_DIR/perplexity_$(date '+%Y-%m-%d').txt"

# backups 디렉토리 생성
mkdir -p "$BACKUP_DIR"

# 현재 perplexity.txt가 존재하고 비어있지 않으면 백업
if [ -f "data/raw/perplexity.txt" ] && [ -s "data/raw/perplexity.txt" ]; then
    cp "data/raw/perplexity.txt" "$BACKUP_FILE"
    echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 백업 완료: $BACKUP_FILE"
fi

# Python 실행 (로컬 규칙 기반 분석)
echo "🌅 $(date '+%Y-%m-%d %H:%M:%S') - Daily Bridge 자동 생성 시작..."
"$PYTHON_BIN" news_hub.py

# Claude 의사결정 인사이트 보강 (news.json 유지 업데이트)
if [ -f "$SCRIPT_DIR/tools/enrich_with_claude.py" ] && [ -f "$SCRIPT_DIR/data/normalized/news.json" ]; then
    echo "🧠 $(date '+%Y-%m-%d %H:%M:%S') - Claude 인사이트 보강 실행..."
    "$PYTHON_BIN" "$SCRIPT_DIR/tools/enrich_with_claude.py" \
        --in "$SCRIPT_DIR/data/normalized/news.json" \
        --out "$SCRIPT_DIR/data/normalized/news.json" \
        --max-enrich "${CLAUDE_ENRICH_MAX_ITEMS:-20}" || true
fi

# 대시보드 동기화 보강: 최신 news.json -> dashboard_data.json 반영
echo "🔄 $(date '+%Y-%m-%d %H:%M:%S') - dashboard 동기화 실행..."
"$PYTHON_BIN" sync_top_news.py

# Daily Bridge Markdown -> JSON 변환
INGEST_SCRIPT="$SCRIPT_DIR/tools/ingest_daily_bridge.js"
if [ -f "$INGEST_SCRIPT" ]; then
    NODE_BIN="node"
    if ! command -v "$NODE_BIN" >/dev/null 2>&1; then
        # cron 환경에서는 nvm 경로가 빠질 수 있어 fallback 탐색
        NVM_NODE=$(ls -1 "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | tail -n 1 || true)
        if [ -n "$NVM_NODE" ] && [ -x "$NVM_NODE" ]; then
            NODE_BIN="$NVM_NODE"
            echo "ℹ️ $(date '+%Y-%m-%d %H:%M:%S') - nvm node fallback 사용: $NODE_BIN"
        else
            echo "⚠️ $(date '+%Y-%m-%d %H:%M:%S') - node 실행 파일을 찾을 수 없어 JSON 생성을 건너뜁니다"
            exit 0
        fi
    fi
    BRIDGE_DATE=$(date '+%Y-%m-%d')
    OUT_JSON="$SCRIPT_DIR/data/daily_bridge_${BRIDGE_DATE}.json"
    "$NODE_BIN" "$INGEST_SCRIPT" --date "$BRIDGE_DATE" --out "$OUT_JSON" < "$SCRIPT_DIR/Daily_Bridge.md"
    echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - Daily Bridge JSON 생성 완료: $OUT_JSON"
else
    echo "⚠️ $(date '+%Y-%m-%d %H:%M:%S') - ingest_daily_bridge.js 없음. JSON 생성 건너뜀"
fi

# GitHub Pages 경로(woonmok.github.io/wave-tree-news-hub)로 정적 파일 동기화
PAGES_DIR="$SCRIPT_DIR/../woonmok.github.io/wave-tree-news-hub"
mkdir -p "$PAGES_DIR/data/normalized"

cp "$SCRIPT_DIR/index.html" "$PAGES_DIR/index.html"
cp "$SCRIPT_DIR/app.js" "$PAGES_DIR/app.js"
cp "$SCRIPT_DIR/data/normalized/news.json" "$PAGES_DIR/data/normalized/news.json"

if [ -f "$SCRIPT_DIR/data/daily_bridge_${BRIDGE_DATE}.json" ]; then
    cp "$SCRIPT_DIR/data/daily_bridge_${BRIDGE_DATE}.json" "$PAGES_DIR/data/daily_bridge_${BRIDGE_DATE}.json"
fi

echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - GitHub Pages 경로 동기화 완료: $PAGES_DIR"

# 처리 완료 후 perplexity.txt 비우기
> data/raw/perplexity.txt
echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - perplexity.txt 리셋 완료"

SUCCESS=1
echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 완료!"
echo "📄 Daily_Bridge.md를 확인하고 Antigravity에 복사하세요."
