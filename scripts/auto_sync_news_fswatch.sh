#!/bin/bash
SRC_TXT="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/data/raw/perplexity.txt"
NORMALIZED_JSON="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/data/normalized/news.json"
DASHBOARD_JSON="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/news.json"

fswatch -0 "$SRC_TXT" | while read -d "" event
 do
  echo "[auto_sync_news] 감지: $event"
  cd "/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub"
  node scripts/normalize.js --in "$SRC_TXT" --out "$NORMALIZED_JSON"
  cp "$NORMALIZED_JSON" "$DASHBOARD_JSON"
  echo "[auto_sync_news] news.json 동기화 완료"
  # 중요 뉴스 2개 자동 반영
  python3 "/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/sync_top_news.py"
done
