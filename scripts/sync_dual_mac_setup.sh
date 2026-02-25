#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="${WAVETREE_WORKSPACE_ROOT:-$(cd "$PROJECT_ROOT/.." && pwd)}"
NEWS_HUB="$WORKSPACE_ROOT/wave-tree-news-hub"
WOONMOK="$WORKSPACE_ROOT/woonmok.github.io"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_brew_pkg() {
  local pkg="$1"
  if brew list --versions "$pkg" >/dev/null 2>&1; then
    log "ok: $pkg already installed"
  else
    log "install: $pkg"
    brew install "$pkg"
  fi
}

setup_venv() {
  local repo="$1"
  local req="$2"

  log "venv: $repo"
  cd "$repo"
  rm -rf .venv
  python3 -m venv .venv
  .venv/bin/python -m pip install --upgrade pip setuptools wheel

  if [ -n "$req" ] && [ -f "$req" ]; then
    .venv/bin/pip install -r "$req"
  fi
}

log "start dual-mac setup"

if ! need_cmd brew; then
  log "error: Homebrew not found"
  exit 1
fi

install_brew_pkg git
install_brew_pkg node
install_brew_pkg python@3.14

if ! install_brew_pkg jq; then
  log "warn: jq install failed"
  log "run manually: sudo chown -R $(whoami) /usr/local/share/man/man8 && chmod u+w /usr/local/share/man/man8"
fi

setup_venv "$NEWS_HUB" "$NEWS_HUB/requirements.txt"

setup_venv "$WOONMOK" ""
cd "$WOONMOK"
.venv/bin/pip install python-dotenv requests

if [ -f "$NEWS_HUB/setup_daily_bridge_cron.sh" ]; then
  /bin/bash "$NEWS_HUB/setup_daily_bridge_cron.sh"
fi

log "versions"
python3 -V
node -v
npm -v
git --version
jq --version || true

log "crontab"
crontab -l || true

log "done"
