#!/usr/bin/env bash

set -euo pipefail

ROOT_A="${SYNC_ROOT_A:-/Volumes/AI_WORKSPACE/projects}"
ROOT_B="${SYNC_ROOT_B:-/Volumes/AI_DATA_CENTRE/AI_WORKSPACE}"

A_HUB="${ROOT_A}/wave-tree-news-hub"
A_SITE="${ROOT_A}/woonmok.github.io"
B_HUB="${ROOT_B}/wave-tree-news-hub"
B_SITE="${ROOT_B}/woonmok.github.io"

MODE="a2b"
APPLY=false
DELETE_MODE=false
TARGET="all"

usage() {
  cat <<'EOF'
Usage:
  sync_projects.sh [a2b|b2a|forward|reverse] [all|hub|site] [--apply] [--delete]

Options:
  a2b          ROOT_A -> ROOT_B (default)
  b2a          ROOT_B -> ROOT_A
  forward      alias of a2b (backward-compatible)
  reverse      alias of b2a (backward-compatible)
  all          sync both projects (default)
  hub          sync only wave-tree-news-hub
  site         sync only woonmok.github.io
  --apply      actually run sync (default is --dry-run)
  --delete     mirror delete (use carefully)

Environment:
  SYNC_ROOT_A  default: /Volumes/AI_WORKSPACE/projects
  SYNC_ROOT_B  default: /Volumes/AI_DATA_CENTRE/AI_WORKSPACE

Examples:
  sync_projects.sh
  sync_projects.sh a2b all --apply
  sync_projects.sh b2a hub --apply
  SYNC_ROOT_A=/path/src SYNC_ROOT_B=/path/dst sync_projects.sh a2b site --apply --delete
EOF
}

for arg in "$@"; do
  case "$arg" in
    a2b|b2a|forward|reverse)
      MODE="$arg"
      ;;
    all|hub|site)
      TARGET="$arg"
      ;;
    --apply)
      APPLY=true
      ;;
    --delete)
      DELETE_MODE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" == "forward" ]]; then
  MODE="a2b"
elif [[ "$MODE" == "reverse" ]]; then
  MODE="b2a"
fi

RSYNC_OPTS=(
  -avh
  --progress
  --itemize-changes
)

if ! $APPLY; then
  RSYNC_OPTS+=(--dry-run)
fi

if $DELETE_MODE; then
  RSYNC_OPTS+=(--delete)
fi

EXCLUDES=(
  --exclude=.git/
  --exclude=.env
  --exclude=.env.*
  --exclude=.venv/
  --exclude=.venv*/
  --exclude=venv/
  --exclude=venv*/
  --exclude=.state/
  --exclude=.locks/
  --exclude=__pycache__/
  --exclude=.pytest_cache/
  --exclude=.mypy_cache/
  --exclude=.DS_Store
  --exclude=logs/
  --exclude=*.log
  --exclude=node_modules/
  --exclude=dist/
  --exclude=build/
  --exclude=*.plist
)

sync_pair() {
  local src="$1"
  local dst="$2"
  local name="$3"

  if [[ ! -d "$src" ]]; then
    echo "[ERROR] Source not found: $src"
    exit 1
  fi

  mkdir -p "$dst"

  echo ""
  echo "=== Sync: ${name} ==="
  echo "From: $src"
  echo "To  : $dst"
  rsync "${RSYNC_OPTS[@]}" "${EXCLUDES[@]}" "$src/" "$dst/"
}

if [[ "$MODE" == "a2b" ]]; then
  HUB_SRC="$A_HUB"
  HUB_DST="$B_HUB"
  SITE_SRC="$A_SITE"
  SITE_DST="$B_SITE"
else
  HUB_SRC="$B_HUB"
  HUB_DST="$A_HUB"
  SITE_SRC="$B_SITE"
  SITE_DST="$A_SITE"
fi

echo "Mode   : $MODE"
echo "ROOT_A : $ROOT_A"
echo "ROOT_B : $ROOT_B"
echo "Target : $TARGET"
if $APPLY; then
  echo "Run    : apply"
else
  echo "Run    : dry-run"
fi
if $DELETE_MODE; then
  echo "Delete : enabled (--delete)"
else
  echo "Delete : disabled"
fi

case "$TARGET" in
  all)
    sync_pair "$HUB_SRC" "$HUB_DST" "wave-tree-news-hub"
    sync_pair "$SITE_SRC" "$SITE_DST" "woonmok.github.io"
    ;;
  hub)
    sync_pair "$HUB_SRC" "$HUB_DST" "wave-tree-news-hub"
    ;;
  site)
    sync_pair "$SITE_SRC" "$SITE_DST" "woonmok.github.io"
    ;;
esac

echo ""
echo "Done."
