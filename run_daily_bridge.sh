#!/bin/bash
# run_daily_bridge.sh
# 매일 아침 뉴스 수집 및 Daily_Bridge.md 자동 생성 스크립트

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

PYTHON_BIN="python3"
if [ -f "$SCRIPT_DIR/.venv312/bin/activate" ]; then
    source "$SCRIPT_DIR/.venv312/bin/activate"
    PYTHON_BIN="$SCRIPT_DIR/.venv312/bin/python"
elif [ -f "$SCRIPT_DIR/.venv/bin/activate" ]; then
    source "$SCRIPT_DIR/.venv/bin/activate"
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
fi

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

# Python 실행 (Gemini 기반 분석 활성화)
echo "🌅 $(date '+%Y-%m-%d %H:%M:%S') - Daily Bridge 자동 생성 시작..."
"$PYTHON_BIN" news_hub.py

# Daily Bridge Markdown -> JSON 변환
INGEST_SCRIPT="$SCRIPT_DIR/tools/ingest_daily_bridge.js"
if [ -f "$INGEST_SCRIPT" ]; then
    NODE_BIN="/Users/seunghoonoh/.gemini/antigravity/scratch/node-v20/bin/node"
    if [ ! -x "$NODE_BIN" ]; then
        NODE_BIN="node"
    fi
    BRIDGE_DATE=$(date '+%Y-%m-%d')
    OUT_JSON="$SCRIPT_DIR/data/daily_bridge_${BRIDGE_DATE}.json"
    "$NODE_BIN" "$INGEST_SCRIPT" --date "$BRIDGE_DATE" --out "$OUT_JSON" < "$SCRIPT_DIR/Daily_Bridge.md"
    echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - Daily Bridge JSON 생성 완료: $OUT_JSON"
else
    echo "⚠️ $(date '+%Y-%m-%d %H:%M:%S') - ingest_daily_bridge.js 없음. JSON 생성 건너뜀"
fi

# 처리 완료 후 perplexity.txt 비우기
> data/raw/perplexity.txt
echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - perplexity.txt 리셋 완료"

echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 완료!"
echo "📄 Daily_Bridge.md를 확인하고 Antigravity에 복사하세요."
