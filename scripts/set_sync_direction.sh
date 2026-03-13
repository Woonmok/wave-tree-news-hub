#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$ROOT_DIR/.state"
ACTIVE_FILE="$STATE_DIR/sync_direction.active"

normalize_mode() {
  local mode="$1"
  case "$mode" in
    a2b|forward)
      echo "a2b"
      ;;
    b2a|reverse)
      echo "b2a"
      ;;
    status)
      echo "status"
      ;;
    *)
      echo ""
      ;;
  esac
}

REQ_RAW="${1:-status}"
REQ_MODE="$(normalize_mode "$REQ_RAW")"

if [[ -z "$REQ_MODE" ]]; then
  echo "Usage: $(basename "$0") [a2b|b2a|status]"
  exit 1
fi

mkdir -p "$STATE_DIR"

CURRENT_MODE="a2b"
if [[ -f "$ACTIVE_FILE" ]]; then
  ACTIVE_CONTENT="$(tr -d '[:space:]' < "$ACTIVE_FILE" || true)"
  case "$ACTIVE_CONTENT" in
    a2b|b2a)
      CURRENT_MODE="$ACTIVE_CONTENT"
      ;;
  esac
fi

if [[ "$REQ_MODE" == "status" ]]; then
  echo "active_direction=$CURRENT_MODE"
  echo "file=$ACTIVE_FILE"
  exit 0
fi

printf '%s\n' "$REQ_MODE" > "$ACTIVE_FILE"
echo "active_direction=$REQ_MODE"
echo "file=$ACTIVE_FILE"
