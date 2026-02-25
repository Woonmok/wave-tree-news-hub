#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE="$SCRIPT_DIR"
DEPLOY="$(cd "$SCRIPT_DIR/../woonmok.github.io" && pwd)"
LOG_DIR="$BASE/logs"
RUN_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/cron_publish_${RUN_DATE}.log"

mkdir -p "$LOG_DIR"
exec >> "$LOG_FILE" 2>&1

echo "===== $(date '+%Y-%m-%d %H:%M:%S') publish start ====="

if /bin/bash "$BASE/run_perplexity_auto.sh"; then
  echo "✅ run_perplexity_auto.sh 완료"
else
  echo "⚠️ run_perplexity_auto.sh 실패 - 기존 normalized/news.json 기준으로 계속 진행"
fi

BASE_DIR="$BASE" /usr/bin/python3 - <<'PY'
import json, sys
import os
from collections import Counter
p=os.path.join(os.environ['BASE_DIR'],'data','normalized','news.json')
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
cp "$BASE/data/normalized/news.json" "$DEPLOY/news.json"
cp "$BASE/app.js" "$DEPLOY/wave-tree-news-hub/app.js"
cp "$BASE/index.html" "$DEPLOY/wave-tree-news-hub/index.html"

cd "$DEPLOY"

git add \
  wave-tree-news-hub/data/normalized/news.json \
  news.json \
  wave-tree-news-hub/app.js \
  wave-tree-news-hub/index.html \
  index.html \
  dashboard_data.json || true

if ! git diff --cached --quiet; then
  git commit -m "auto: 7am news publish $(date '+%Y-%m-%d %H:%M')"
  if git push origin main; then
    echo "✅ auto publish pushed"
  else
    echo "⚠️ git push 실패 - remote 변경사항 rebase 후 재시도"
    if git pull --rebase origin main && git push origin main; then
      echo "✅ auto publish pushed (rebase)"
    else
      echo "⚠️ auto publish push 최종 실패 - 로컬 커밋만 유지"
    fi
  fi
else
  echo "ℹ️ no publish changes"
fi

echo "===== $(date '+%Y-%m-%d %H:%M:%S') publish end ====="
