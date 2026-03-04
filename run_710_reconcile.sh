#!/bin/bash
# run_710_reconcile.sh
# 07:10 품질 재보강: 뉴스 23개/카테고리 분포 보정 + Top2 동기화 + 배포 반영

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

LOG_DIR="$SCRIPT_DIR/logs"
RUN_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOG_DIR/reconcile_${RUN_DATE}.log"

mkdir -p "$LOG_DIR"
exec >> "$LOG_FILE" 2>&1

echo "===== $(date '+%Y-%m-%d %H:%M:%S') reconcile start ====="

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

send_failure_alert() {
  local reason="$1"
  local creds token chat_id now_ts tail_log message

  creds=$(get_telegram_credentials)
  token="${creds%%|*}"
  chat_id="${creds##*|}"
  now_ts=$(date '+%Y-%m-%d %H:%M:%S')

  if [ -z "$token" ] || [ -z "$chat_id" ]; then
    echo "ℹ️ Telegram 자격 정보 없음: 실패 알림 전송 건너뜀"
    return 0
  fi

  tail_log=$(tail -n 20 "$LOG_FILE" 2>/dev/null || true)
  message="🚨 WaveTree 07:10 reconcile 실패\n- date: ${RUN_DATE}\n- time: ${now_ts}\n- reason: ${reason}\n- host: $(hostname)\n- log: ${LOG_FILE}\n- tail:\n${tail_log}"

  if curl -fsS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "text=${message}" >/dev/null; then
    echo "✅ reconcile 실패 알림 전송 완료"
  else
    echo "⚠️ reconcile 실패 알림 전송 실패"
  fi
}

on_error() {
  local line_no="$1"
  send_failure_alert "스크립트 실행 오류(line ${line_no})"
  exit 1
}

trap 'on_error $LINENO' ERR

PYTHON_BIN="python3"
if [ -x "$SCRIPT_DIR/.venv-1/bin/python" ]; then
  PYTHON_BIN="$SCRIPT_DIR/.venv-1/bin/python"
elif [ -x "$SCRIPT_DIR/.venv/bin/python" ]; then
  PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
fi

NEWS_JSON="$SCRIPT_DIR/data/normalized/news.json"
DEPLOY_DIR="$SCRIPT_DIR/../woonmok.github.io"

counts_ok() {
  NEWS_JSON_PATH="$NEWS_JSON" "$PYTHON_BIN" - <<'PY'
import json, os, collections, sys
p=os.environ['NEWS_JSON_PATH']
d=json.load(open(p,encoding='utf-8'))
items=d.get('items',[])
c=collections.Counter(i.get('category') for i in items)
target={'listeria_free':4,'cultured_meat':5,'high_end_audio':5,'computer_ai':5,'global_biz':4}
ok=(len(items)==23) and all(c.get(k,0)==v for k,v in target.items())
print('items=',len(items),'counts=',dict(c),'ok=',ok)
sys.exit(0 if ok else 1)
PY
}

if counts_ok; then
  echo "✅ already healthy: 23 items"
else
  echo "⚠️ not healthy: start backfill loop"
  for i in 1 2 3 4 5; do
    echo "-- backfill attempt $i"
    "$PYTHON_BIN" "$SCRIPT_DIR/tools/backfill_missing_categories.py" --file "$NEWS_JSON" || true
    "$PYTHON_BIN" "$SCRIPT_DIR/tools/validate_news_urls.py" --file "$NEWS_JSON" || true
    if counts_ok; then
      echo "✅ recovered on attempt $i"
      break
    fi
  done
fi

if ! counts_ok; then
  echo "❌ reconcile failed: 23개/카테고리 목표 미충족"
  send_failure_alert "23개/카테고리 목표 미충족"
  exit 1
fi

echo "🔄 sync top2"
"$PYTHON_BIN" "$SCRIPT_DIR/sync_top_news.py"

echo "🔄 mirror to deploy repo"
cp "$SCRIPT_DIR/data/normalized/news.json" "$DEPLOY_DIR/wave-tree-news-hub/data/normalized/news.json"
cp "$SCRIPT_DIR/data/normalized/news.json" "$DEPLOY_DIR/news.json"
cp "$SCRIPT_DIR/index.html" "$DEPLOY_DIR/wave-tree-news-hub/index.html"
cp "$SCRIPT_DIR/app.js" "$DEPLOY_DIR/wave-tree-news-hub/app.js"
mkdir -p "$DEPLOY_DIR/docs"
cp "$DEPLOY_DIR/index.html" "$DEPLOY_DIR/docs/index.html"
cp "$DEPLOY_DIR/dashboard_data.json" "$DEPLOY_DIR/docs/dashboard_data.json"
cp "$DEPLOY_DIR/news.json" "$DEPLOY_DIR/docs/news.json"

echo "🔄 git push attempt"
(
  cd "$DEPLOY_DIR"
  git add \
    wave-tree-news-hub/data/normalized/news.json \
    news.json \
    wave-tree-news-hub/index.html \
    wave-tree-news-hub/app.js \
    dashboard_data.json \
    index.html \
    docs/news.json \
    docs/dashboard_data.json \
    docs/index.html

  if ! git diff --cached --quiet; then
    git commit -m "auto: 7:10 reconcile $(date '+%Y-%m-%d %H:%M')"
    if git push origin main; then
      echo "✅ reconcile push success"
    else
      echo "⚠️ reconcile push 실패 - remote 변경사항 rebase 후 재시도"
      git pull --rebase --autostash origin main
      git push origin main
    fi
  else
    echo "ℹ️ no changes to push"
  fi
)

echo "===== $(date '+%Y-%m-%d %H:%M:%S') reconcile end ====="
