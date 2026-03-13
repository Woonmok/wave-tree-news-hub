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

read_env_value() {
  local key="$1"
  local file="$2"
  [ -f "$file" ] || return 1
  grep -E "^${key}=" "$file" | tail -n 1 | cut -d '=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

get_github_token() {
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  if [ -z "$token" ]; then
    token="$(read_env_value GITHUB_TOKEN "$BASE/.env" || true)"
  fi
  if [ -z "$token" ]; then
    token="$(read_env_value GH_TOKEN "$BASE/.env" || true)"
  fi
  if [ -z "$token" ]; then
    token="$(read_env_value GITHUB_TOKEN "$DEPLOY/.env" || true)"
  fi
  if [ -z "$token" ]; then
    token="$(read_env_value GH_TOKEN "$DEPLOY/.env" || true)"
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

# GitHub Pages source가 docs/로 바뀌어도 반영되도록 mirror 유지
mkdir -p "$DEPLOY/docs"
cp "$DEPLOY/index.html" "$DEPLOY/docs/index.html"
cp "$DEPLOY/dashboard_data.json" "$DEPLOY/docs/dashboard_data.json"
cp "$DEPLOY/news.json" "$DEPLOY/docs/news.json"

cd "$DEPLOY"

GIT_TOKEN="$(get_github_token)"
GIT_KEYCHAIN_CREDS="$(get_github_keychain_credentials || true)"

if ! configure_origin_push_url; then
  echo "ℹ️ SSH push URL 자동 구성 건너뜀 - HTTPS fallback 사용"
fi

git add \
  wave-tree-news-hub/data/normalized/news.json \
  news.json \
  docs/news.json \
  wave-tree-news-hub/app.js \
  wave-tree-news-hub/index.html \
  index.html \
  docs/index.html \
  dashboard_data.json \
  docs/dashboard_data.json || true

if ! git diff --cached --quiet; then
  git commit -m "auto: 7am news publish $(date '+%Y-%m-%d %H:%M')"
  if git push origin main; then
    echo "✅ auto publish pushed"
  else
    echo "⚠️ git push 실패 - token fallback 시도"
    if push_with_token_fallback "$GIT_TOKEN"; then
      echo "✅ auto publish pushed (token fallback)"
    elif push_with_keychain_fallback "$GIT_KEYCHAIN_CREDS"; then
      echo "✅ auto publish pushed (keychain fallback)"
    elif [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
      echo "⚠️ rebase 진행 중 감지 - pull/rebase 재시도 건너뜀"
      echo "⚠️ auto publish push 최종 실패 - 로컬 커밋만 유지"
    elif git pull --rebase --autostash origin main && git push origin main; then
      echo "✅ auto publish pushed (rebase)"
    elif push_with_token_fallback "$GIT_TOKEN"; then
      echo "✅ auto publish pushed (rebase+token fallback)"
    elif push_with_keychain_fallback "$GIT_KEYCHAIN_CREDS"; then
      echo "✅ auto publish pushed (rebase+keychain fallback)"
    else
      echo "⚠️ auto publish push 최종 실패 - 로컬 커밋만 유지"
    fi
  fi
else
  echo "ℹ️ no publish changes"
fi

echo "===== $(date '+%Y-%m-%d %H:%M:%S') publish end ====="
