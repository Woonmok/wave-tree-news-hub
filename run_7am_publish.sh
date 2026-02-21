#!/bin/bash
set -Eeuo pipefail

BASE="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub"
DEPLOY="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io"
LOG_DIR="$BASE/logs"
RUN_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/cron_publish_${RUN_DATE}.log"

mkdir -p "$LOG_DIR"
exec >> "$LOG_FILE" 2>&1

echo "===== $(date '+%Y-%m-%d %H:%M:%S') publish start ====="

/bin/bash "$BASE/run_perplexity_auto.sh"

/usr/bin/python3 - <<'PY'
import json, sys
from collections import Counter
p='/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/data/normalized/news.json'
with open(p,'r',encoding='utf-8') as f:
  d=json.load(f)
items=d.get('items',[])
counts=Counter(i.get('category') for i in items)
target={'listeria_free':4,'cultured_meat':5,'high_end_audio':5,'computer_ai':5,'global_biz':4}
ok=(len(items)==23) and all(counts.get(k,0)==v for k,v in target.items())
if not ok:
  print('❌ quality gate failed:', len(items), dict(counts))
  sys.exit(2)
print('✅ quality gate passed:', len(items), dict(counts))
PY

cp "$BASE/data/normalized/news.json" "$DEPLOY/wave-tree-news-hub/data/normalized/news.json"
cp "$BASE/app.js" "$DEPLOY/wave-tree-news-hub/app.js"
cp "$BASE/index.html" "$DEPLOY/wave-tree-news-hub/index.html"

cd "$DEPLOY"

git add \
  wave-tree-news-hub/data/normalized/news.json \
  wave-tree-news-hub/app.js \
  wave-tree-news-hub/index.html \
  index.html \
  dashboard_data.json || true

if ! git diff --cached --quiet; then
  git commit -m "auto: 7am news publish $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo "✅ auto publish pushed"
else
  echo "ℹ️ no publish changes"
fi

echo "===== $(date '+%Y-%m-%d %H:%M:%S') publish end ====="
