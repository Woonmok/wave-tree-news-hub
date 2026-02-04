#!/bin/bash
SRC_TXT="/Users/seunghoonoh/wave-tree-news-hub/data/raw/perplexity.txt"
NORMALIZED_JSON="/Users/seunghoonoh/wave-tree-news-hub/data/normalized/news.json"
DASHBOARD_JSON="/Users/seunghoonoh/woonmok.github.io/news.json"

fswatch -0 "$SRC_TXT" | while read -d "" event
 do
  echo "[auto_sync_news] 감지: $event"
  cd /Users/seunghoonoh/wave-tree-news-hub
  node scripts/normalize.js --in "$SRC_TXT" --out "$NORMALIZED_JSON"
  cp "$NORMALIZED_JSON" "$DASHBOARD_JSON"
  echo "[auto_sync_news] news.json 동기화 완료"
  # 중요 뉴스 2개 자동 반영
  python3 /Users/seunghoonoh/wave-tree-news-hub/sync_top_news.py
done
