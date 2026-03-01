#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="/Volumes/AI_DATA_CENTRE/AI_WORKSPACE"

ORIG_HUB="${BASE_DIR}/wave-tree-news-hub"
ORIG_SITE="${BASE_DIR}/woonmok.github.io"
PROJ_HUB="${BASE_DIR}/projects/wave-tree-news-hub"
PROJ_SITE="${BASE_DIR}/projects/woonmok.github.io"

MODE="forward"
APPLY=false
DELETE_MODE=false
TARGET="all"

usage() {
  cat <<'EOF'
Usage:
  sync_projects.sh [forward|reverse] [all|hub|site] [--apply] [--delete]

Options:
  forward      original -> projects (default)
  reverse      projects -> original
  all          sync both projects (default)
  hub          sync only wave-tree-news-hub
  site         sync only woonmok.github.io
  --apply      actually run sync (default is --dry-run)
  --delete     mirror delete (use carefully)

Examples:
  sync_projects.sh
  sync_projects.sh forward all --apply
  sync_projects.sh reverse hub --apply
  sync_projects.sh forward site --apply --delete
EOF
}

for arg in "$@"; do
  case "$arg" in
    forward|reverse)
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

if [[ "$MODE" == "forward" ]]; then
  HUB_SRC="$ORIG_HUB"
  HUB_DST="$PROJ_HUB"
  SITE_SRC="$ORIG_SITE"
  SITE_DST="$PROJ_SITE"
else
  HUB_SRC="$PROJ_HUB"
  HUB_DST="$ORIG_HUB"
  SITE_SRC="$PROJ_SITE"
  SITE_DST="$ORIG_SITE"
fi

echo "Mode   : $MODE"
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
