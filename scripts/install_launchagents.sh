#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEWS_HUB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="${WAVETREE_WORKSPACE_ROOT:-$(cd "$NEWS_HUB_DIR/.." && pwd)}"
WOONMOK_DIR="${WAVETREE_WOONMOK_DIR:-$WORKSPACE_ROOT/woonmok.github.io}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

mkdir -p "$LAUNCH_AGENTS_DIR"

# launchd 환경변수에 워크스페이스 루트 주입 (선택값이지만 이식성에 도움)
launchctl setenv WAVETREE_WORKSPACE_ROOT "$WORKSPACE_ROOT" || true
launchctl setenv WAVETREE_NEWS_HUB_DIR "$NEWS_HUB_DIR" || true
launchctl setenv WAVETREE_WOONMOK_DIR "$WOONMOK_DIR" || true

PLISTS=(
  "$NEWS_HUB_DIR/com.ngrok.plist"
  "$NEWS_HUB_DIR/com.wavetree.backup-server.plist"
  "$NEWS_HUB_DIR/com.wavetree.dailybridge.plist"
  "$NEWS_HUB_DIR/com.wavetree.fswatch.plist"
  "$NEWS_HUB_DIR/com.wavetree.httpserver.plist"
  "$NEWS_HUB_DIR/com.wavetree.perplexity-auto.plist"
  "$NEWS_HUB_DIR/com.wavetree.scrapbook-backup.plist"
  "$WOONMOK_DIR/com.wavetree.antigravity.plist"
  "$WOONMOK_DIR/com.wavetree.news-sync.plist"
  "$WOONMOK_DIR/com.wavetree.news-sync-loop.plist"
)

echo "[install_launchagents] workspace: $WORKSPACE_ROOT"
echo "[install_launchagents] news-hub:  $NEWS_HUB_DIR"
echo "[install_launchagents] woonmok:   $WOONMOK_DIR"

action_load() {
  local plist_dest="$1"
  launchctl load "$plist_dest" >/dev/null 2>&1 || true
}

for plist_src in "${PLISTS[@]}"; do
  if [[ ! -f "$plist_src" ]]; then
    echo "[skip] not found: $plist_src"
    continue
  fi

  plist_name="$(basename "$plist_src")"
  plist_dest="$LAUNCH_AGENTS_DIR/$plist_name"
  label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist_src" 2>/dev/null || true)"

  cp "$plist_src" "$plist_dest"
  action_load "$plist_dest"

  if [[ -n "$label" ]] && launchctl list | grep -q "$label"; then
    echo "[ok] loaded: $plist_name ($label)"
  else
    echo "[warn] not active yet: $plist_name${label:+ ($label)}"
  fi
done

echo ""
echo "[install_launchagents] loaded labels"
launchctl list | grep -E 'com\.wavetree|com\.ngrok' || true

echo ""
echo "[done] LaunchAgents reinstalled with portable paths."
