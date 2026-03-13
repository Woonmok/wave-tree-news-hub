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

get_github_token() {
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

  if [ -z "$token" ]; then
    token="$(read_env_value GITHUB_TOKEN "$SCRIPT_DIR/.env" || true)"
  fi
  if [ -z "$token" ]; then
    token="$(read_env_value GH_TOKEN "$SCRIPT_DIR/.env" || true)"
  fi
  if [ -z "$token" ]; then
    token="$(read_env_value GITHUB_TOKEN "$DEPLOY_DIR/.env" || true)"
  fi
  if [ -z "$token" ]; then
    token="$(read_env_value GH_TOKEN "$DEPLOY_DIR/.env" || true)"
  fi

  echo "$token"
}

get_github_keychain_credentials() {
  local helper=""
  local creds=""
  local username=""
  local password=""

  helper="$(command -v git-credential-osxkeychain || true)"
  [ -n "$helper" ] || return 1

  creds="$(printf 'protocol=https\nhost=github.com\n\n' | "$helper" get 2>/dev/null || true)"
  username="$(printf '%s\n' "$creds" | sed -n 's/^username=//p' | head -n 1)"
  password="$(printf '%s\n' "$creds" | sed -n 's/^password=//p' | head -n 1)"

  [ -n "$username" ] || return 1
  [ -n "$password" ] || return 1
  printf '%s|%s\n' "$username" "$password"
}

can_use_github_ssh() {
  local probe=""
  probe="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  printf '%s\n' "$probe" | grep -q "successfully authenticated"
}

build_github_ssh_url() {
  local remote_url="$1"
  local path_part=""

  case "$remote_url" in
    git@github.com:*)
      printf '%s\n' "$remote_url"
      return 0
      ;;
    ssh://git@github.com/*)
      path_part="${remote_url#ssh://git@github.com/}"
      printf 'git@github.com:%s\n' "$path_part"
      return 0
      ;;
    https://github.com/*)
      path_part="${remote_url#https://github.com/}"
      printf 'git@github.com:%s\n' "$path_part"
      return 0
      ;;
    http://github.com/*)
      path_part="${remote_url#http://github.com/}"
      printf 'git@github.com:%s\n' "$path_part"
      return 0
      ;;
  esac

  return 1
}

configure_origin_push_url() {
  local origin_url=""
  local current_push_url=""
  local ssh_url=""

  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  [ -n "$origin_url" ] || return 1

  ssh_url="$(build_github_ssh_url "$origin_url" || true)"
  [ -n "$ssh_url" ] || return 1

  if ! can_use_github_ssh; then
    return 1
  fi

  current_push_url="$(git remote get-url --push origin 2>/dev/null || true)"
  if [ "$current_push_url" != "$ssh_url" ]; then
    git remote set-url --push origin "$ssh_url"
  fi

  echo "✅ origin push URL configured for SSH: $ssh_url"
  return 0
}

push_with_token_fallback() {
  local token="$1"
  local askpass=""
  [ -n "$token" ] || return 1

  askpass=$(mktemp)
  cat > "$askpass" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) echo "x-access-token" ;;
  *Password*) echo "$GITHUB_TOKEN" ;;
  *) echo "" ;;
esac
EOF
  chmod 700 "$askpass"

  if GIT_TERMINAL_PROMPT=0 GIT_ASKPASS="$askpass" GITHUB_TOKEN="$token" git push origin main; then
    rm -f "$askpass"
    return 0
  fi

  rm -f "$askpass"
  return 1
}

push_with_keychain_fallback() {
  local creds="$1"
  local username="${creds%%|*}"
  local password="${creds#*|}"
  local askpass=""

  [ -n "$username" ] || return 1
  [ -n "$password" ] || return 1

  askpass=$(mktemp)
  cat > "$askpass" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) echo "$GITHUB_USERNAME" ;;
  *Password*) echo "$GITHUB_PASSWORD" ;;
  *) echo "" ;;
esac
EOF
  chmod 700 "$askpass"

  if GIT_TERMINAL_PROMPT=0 GIT_ASKPASS="$askpass" GITHUB_USERNAME="$username" GITHUB_PASSWORD="$password" git push origin main; then
    rm -f "$askpass"
    return 0
  fi

  rm -f "$askpass"
  return 1
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
  GIT_TOKEN="$(get_github_token)"
  GIT_KEYCHAIN_CREDS="$(get_github_keychain_credentials || true)"

  if ! configure_origin_push_url; then
    echo "ℹ️ SSH push URL 자동 구성 건너뜀 - HTTPS fallback 사용"
  fi

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
      echo "⚠️ reconcile push 실패 - token fallback 시도"
      if push_with_token_fallback "$GIT_TOKEN"; then
        echo "✅ reconcile push success (token fallback)"
      elif push_with_keychain_fallback "$GIT_KEYCHAIN_CREDS"; then
        echo "✅ reconcile push success (keychain fallback)"
      elif [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
        echo "⚠️ rebase 진행 중 감지 - pull/rebase 재시도 건너뜀"
        exit 1
      else
        echo "⚠️ reconcile push 실패 - remote 변경사항 rebase 후 재시도"
        git pull --rebase --autostash origin main
        git push origin main || push_with_token_fallback "$GIT_TOKEN" || push_with_keychain_fallback "$GIT_KEYCHAIN_CREDS"
      fi
    fi
  else
    echo "ℹ️ no changes to push"
  fi
)

echo "===== $(date '+%Y-%m-%d %H:%M:%S') reconcile end ====="
