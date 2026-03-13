#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync_projects.sh"
SET_DIR_SCRIPT="$SCRIPT_DIR/set_sync_direction.sh"

MODE="${1:-a2b}"
TARGET="${2:-all}"
DRY_RUN=false

if [[ "$MODE" != "a2b" && "$MODE" != "b2a" && "$MODE" != "forward" && "$MODE" != "reverse" ]]; then
  echo "Usage: $(basename "$0") [a2b|b2a] [all|hub|site] [--dry-run]"
  exit 1
fi

if [[ "$MODE" == "forward" ]]; then
  MODE="a2b"
elif [[ "$MODE" == "reverse" ]]; then
  MODE="b2a"
fi

if [[ "$TARGET" != "all" && "$TARGET" != "hub" && "$TARGET" != "site" ]]; then
  echo "Usage: $(basename "$0") [a2b|b2a] [all|hub|site] [--dry-run]"
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
  esac
done

if $DRY_RUN; then
  "$SET_DIR_SCRIPT" "$MODE" >/dev/null
  exec "$SYNC_SCRIPT" "$MODE" "$TARGET" --delete
else
  "$SET_DIR_SCRIPT" "$MODE" >/dev/null
  exec "$SYNC_SCRIPT" "$MODE" "$TARGET" --apply --delete
fi
