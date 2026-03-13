#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync_projects.sh"
STATE_DIR="$ROOT_DIR/.state"
LOCKS_DIR="$ROOT_DIR/.locks"
ACTIVE_FILE="$STATE_DIR/sync_direction.active"
LOCK_DIR="$LOCKS_DIR/sync_projects_guard.lock"

normalize_mode() {
  local mode="$1"
  case "$mode" in
    a2b|forward)
      echo "a2b"
      ;;
    b2a|reverse)
      echo "b2a"
      ;;
    *)
      echo ""
      ;;
  esac
}

EXPECTED_RAW="${1:-}"
if [[ -z "$EXPECTED_RAW" ]]; then
  echo "Usage: $(basename "$0") <a2b|b2a> [sync_projects args...]"
  exit 1
fi
shift

EXPECTED_MODE="$(normalize_mode "$EXPECTED_RAW")"
if [[ -z "$EXPECTED_MODE" ]]; then
  echo "[ERROR] Invalid expected mode: $EXPECTED_RAW"
  exit 1
fi

mkdir -p "$STATE_DIR" "$LOCKS_DIR"

ACTIVE_MODE="a2b"
if [[ -f "$ACTIVE_FILE" ]]; then
  ACTIVE_CONTENT="$(tr -d '[:space:]' < "$ACTIVE_FILE" || true)"
  NORMALIZED_ACTIVE="$(normalize_mode "$ACTIVE_CONTENT")"
  if [[ -n "$NORMALIZED_ACTIVE" ]]; then
    ACTIVE_MODE="$NORMALIZED_ACTIVE"
  fi
fi

if [[ "$ACTIVE_MODE" != "$EXPECTED_MODE" ]]; then
  echo "[SKIP] expected=$EXPECTED_MODE active=$ACTIVE_MODE"
  exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "[SKIP] another sync is in progress"
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

echo "[RUN ] mode=$EXPECTED_MODE args=$*"
exec "$SYNC_SCRIPT" "$EXPECTED_MODE" "$@"
