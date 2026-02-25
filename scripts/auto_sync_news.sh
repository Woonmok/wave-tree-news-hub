#!/bin/bash
# Perplexity txt 업로드 시 자동 변환 및 대시보드 news.json 동기화

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC_DIR="$PROJECT_ROOT/data/raw"
SRC_TXT="$SRC_DIR/perplexity.txt"
NORMALIZED_JSON="$PROJECT_ROOT/data/normalized/news.json"
SYNC_SCRIPT="$PROJECT_ROOT/sync_top_news.py"
PYTHON_BIN="$PROJECT_ROOT/.venv/bin/python"

if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="python3"
fi

inotifywait -m -e close_write "$SRC_TXT" | while read path action file; do
  echo "[auto_sync_news] 감지: $file ($action)"
  cd "$PROJECT_ROOT"
  node scripts/normalize.js --in "$SRC_TXT" --out "$NORMALIZED_JSON"
  echo "[auto_sync_news] data/normalized/news.json 갱신 완료"
  "$PYTHON_BIN" "$SYNC_SCRIPT"
done
