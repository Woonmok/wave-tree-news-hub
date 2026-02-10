#!/bin/bash
SRC_TXT="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/data/raw/perplexity.txt"
NORMALIZED_JSON="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/data/news.json"

fswatch -0 "$SRC_TXT" | while read -d "" event
 do
  echo "[auto_sync_news] 감지: $event"
  cd "/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub"
  node scripts/normalize.js --in "$SRC_TXT" --out "$NORMALIZED_JSON"
  echo "[auto_sync_news] data/news.json 갱신 완료"
done
