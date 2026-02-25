#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC_TXT="$PROJECT_ROOT/data/raw/perplexity.txt"
NORMALIZED_JSON="$PROJECT_ROOT/data/normalized/news.json"
SYNC_SCRIPT="$PROJECT_ROOT/sync_top_news.py"
PYTHON_BIN="$PROJECT_ROOT/.venv/bin/python"

if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="python3"
fi

fswatch -0 "$SRC_TXT" | while read -d "" event
 do
  echo "[auto_sync_news] 감지: $event"
  cd "$PROJECT_ROOT"
  node scripts/normalize.js --in "$SRC_TXT" --out "$NORMALIZED_JSON"
  echo "[auto_sync_news] data/normalized/news.json 갱신 완료"
  "$PYTHON_BIN" "$SYNC_SCRIPT" 2>&1 || echo "[auto_sync_news] sync 건너뜀"
done
