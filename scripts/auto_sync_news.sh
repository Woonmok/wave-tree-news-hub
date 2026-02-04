#!/bin/bash
# Perplexity txt 업로드 시 자동 변환 및 대시보드 news.json 동기화

SRC_DIR="/Users/seunghoonoh/wave-tree-news-hub/data/raw"
SRC_TXT="$SRC_DIR/perplexity.txt"
NORMALIZED_JSON="/Users/seunghoonoh/wave-tree-news-hub/data/normalized/news.json"
DASHBOARD_JSON="/Users/seunghoonoh/woonmok.github.io/news.json"

inotifywait -m -e close_write "$SRC_TXT" | while read path action file; do
  echo "[auto_sync_news] 감지: $file ($action)"
  cd /Users/seunghoonoh/wave-tree-news-hub
  node scripts/normalize.js --in "$SRC_TXT" --out "$NORMALIZED_JSON"
  cp "$NORMALIZED_JSON" "$DASHBOARD_JSON"
  echo "[auto_sync_news] news.json 동기화 완료"
done
