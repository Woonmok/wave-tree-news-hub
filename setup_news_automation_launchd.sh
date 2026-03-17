#!/bin/bash
# setup_news_automation_launchd.sh
# 뉴스 핵심 자동화를 launchd(LaunchAgent) 기반으로 설정

set -Eeuo pipefail

ORIG_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_DIR="$ORIG_SCRIPT_DIR"
HOME_WORKSPACE_ROOT="${HOME}/AI_WORKSPACE"
HOME_SCRIPT_DIR="$HOME_WORKSPACE_ROOT/wave-tree-news-hub"

if [ -d "$HOME_SCRIPT_DIR" ]; then
  SCRIPT_DIR="$HOME_SCRIPT_DIR"
fi

# 홈 워크스페이스 우선 사용하되, 필요한 파일이 없으면 현재 경로로 안전하게 fallback
if [ ! -f "$SCRIPT_DIR/com.wavetree.news-publish.plist" ] || [ ! -f "$SCRIPT_DIR/com.wavetree.dailybridge.plist" ]; then
  SCRIPT_DIR="$ORIG_SCRIPT_DIR"
fi

LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PUBLISH_LABEL="com.wavetree.news-publish"
DAILY_LABEL="com.wavetree.dailybridge"
PUBLISH_PLIST_SRC="$SCRIPT_DIR/com.wavetree.news-publish.plist"
DAILY_PLIST_SRC="$SCRIPT_DIR/com.wavetree.dailybridge.plist"
PUBLISH_PLIST_DST="$LAUNCH_AGENTS_DIR/${PUBLISH_LABEL}.plist"
DAILY_PLIST_DST="$LAUNCH_AGENTS_DIR/${DAILY_LABEL}.plist"

mkdir -p "$LAUNCH_AGENTS_DIR"

for required in "$PUBLISH_PLIST_SRC" "$DAILY_PLIST_SRC" "$SCRIPT_DIR/run_7am_publish.sh" "$SCRIPT_DIR/run_daily_bridge.sh"; do
  if [ ! -f "$required" ]; then
    echo "❌ 필수 파일 없음: $required"
    exit 1
  fi
done

chmod +x "$SCRIPT_DIR/run_7am_publish.sh" "$SCRIPT_DIR/run_daily_bridge.sh"

echo "🧹 기존 LaunchAgent 해제(있으면)..."
launchctl bootout "gui/$(id -u)/$PUBLISH_LABEL" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$DAILY_LABEL" 2>/dev/null || true

cp "$PUBLISH_PLIST_SRC" "$PUBLISH_PLIST_DST"
cp "$DAILY_PLIST_SRC" "$DAILY_PLIST_DST"
chmod 644 "$PUBLISH_PLIST_DST" "$DAILY_PLIST_DST"

echo "✅ plist 설치 완료"

echo "🚀 LaunchAgent 로드..."
launchctl bootstrap "gui/$(id -u)" "$PUBLISH_PLIST_DST"
launchctl bootstrap "gui/$(id -u)" "$DAILY_PLIST_DST"

launchctl enable "gui/$(id -u)/$PUBLISH_LABEL"
launchctl enable "gui/$(id -u)/$DAILY_LABEL"

# 즉시 1회 실행 트리거(검증 목적)
launchctl kickstart -k "gui/$(id -u)/$PUBLISH_LABEL" || true
launchctl kickstart -k "gui/$(id -u)/$DAILY_LABEL" || true

echo ""
echo "✅ launchd 전환 완료"
echo "- publish: 06:50 (${PUBLISH_LABEL})"
echo "- daily  : 07:00 (${DAILY_LABEL})"
echo "- 로그(launchd): /tmp/wavetree-news-publish*.log, /tmp/wavetree-dailybridge*.log"
echo ""
echo "📋 상태 확인"
launchctl print "gui/$(id -u)/$PUBLISH_LABEL" | grep -E "state =|last exit code|path =" || true
launchctl print "gui/$(id -u)/$DAILY_LABEL" | grep -E "state =|last exit code|path =" || true
