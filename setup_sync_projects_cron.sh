#!/bin/bash
# setup_sync_projects_cron.sh
# 원본/대상 프로젝트 동기화를 cron에 안전하게 등록(중복 방지)하는 스크립트

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT_PATH="$SCRIPT_DIR/scripts/sync_projects.sh"
CRON_LOG_DIR="${HOME}/Library/Logs/wave-tree-news-hub-cron"

MODE="forward"
TARGET="all"
SCHEDULE="*/20 * * * *"
RUN_MODE="apply"
DELETE_FLAG=""
UNINSTALL=false

usage() {
  cat <<'EOF'
Usage:
  ./setup_sync_projects_cron.sh [options]

Options:
  --mode forward|reverse     Sync direction (default: forward)
  --target all|hub|site      Sync target (default: all)
  --schedule "CRON_EXPR"     Cron schedule (default: */20 * * * *)
  --dry-run                  Register as dry-run mode
  --apply                    Register as apply mode (default)
  --delete                   Add --delete to sync command
  --uninstall                Remove previously registered sync cron jobs
  -h, --help                 Show help

Examples:
  ./setup_sync_projects_cron.sh
  ./setup_sync_projects_cron.sh --mode forward --target all --schedule "*/10 * * * *"
  ./setup_sync_projects_cron.sh --dry-run --target hub
  ./setup_sync_projects_cron.sh --uninstall
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --schedule)
      SCHEDULE="${2:-}"
      shift 2
      ;;
    --dry-run)
      RUN_MODE="dry-run"
      shift
      ;;
    --apply)
      RUN_MODE="apply"
      shift
      ;;
    --delete)
      DELETE_FLAG=" --delete"
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "❌ 알 수 없는 옵션: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "forward" && "$MODE" != "reverse" ]]; then
  echo "❌ --mode는 forward 또는 reverse만 허용됩니다."
  exit 1
fi

if [[ "$TARGET" != "all" && "$TARGET" != "hub" && "$TARGET" != "site" ]]; then
  echo "❌ --target은 all|hub|site만 허용됩니다."
  exit 1
fi

if [[ ! -x "$SYNC_SCRIPT_PATH" ]]; then
  chmod +x "$SYNC_SCRIPT_PATH"
fi

mkdir -p "$CRON_LOG_DIR"

RUN_FLAG=""
LOG_NAME_SUFFIX="apply"
if [[ "$RUN_MODE" == "dry-run" ]]; then
  RUN_FLAG=""
  LOG_NAME_SUFFIX="dryrun"
else
  RUN_FLAG=" --apply"
fi

CRON_CMD="/bin/bash $SYNC_SCRIPT_PATH $MODE $TARGET${RUN_FLAG}${DELETE_FLAG} >> $CRON_LOG_DIR/cron_sync_projects_${MODE}_${TARGET}_${LOG_NAME_SUFFIX}.log 2>&1"
CRON_LINE="$SCHEDULE $CRON_CMD"

CURRENT_CRON=$(crontab -l 2>/dev/null || true)

FILTERED=$(printf "%s\n" "$CURRENT_CRON" \
  | grep -F -v "$SYNC_SCRIPT_PATH" \
  || true)

if $UNINSTALL; then
  printf "%s\n" "$FILTERED" | sed '/^[[:space:]]*$/d' | crontab -
  echo "✅ sync_projects cron 제거 완료"
  echo "- 제거 대상 스크립트: $SYNC_SCRIPT_PATH"
  echo ""
  echo "📋 현재 crontab"
  crontab -l
  exit 0
fi

{
  printf "%s\n" "$FILTERED" | sed '/^[[:space:]]*$/d'
  printf "%s\n" "$CRON_LINE"
} | crontab -

echo "✅ sync_projects cron 등록 완료"
echo "- 스케줄: $SCHEDULE"
echo "- 방향: $MODE"
echo "- 대상: $TARGET"
echo "- 실행모드: $RUN_MODE"
if [[ -n "$DELETE_FLAG" ]]; then
  echo "- 삭제미러링: enabled (--delete)"
else
  echo "- 삭제미러링: disabled"
fi
echo "- 명령: $CRON_CMD"
echo "- 로그: $CRON_LOG_DIR"
echo ""
echo "📋 현재 crontab"
crontab -l
