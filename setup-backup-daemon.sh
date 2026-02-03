#!/bin/bash
# setup-backup-daemon.sh - 스크랩북 백업 서버를 시스템 시작 시 자동 실행

PLIST_FILE="com.wavetree.scrapbook-backup.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# LaunchAgents 디렉토리 생성
mkdir -p "$LAUNCH_AGENTS_DIR"

# plist 파일 복사
cp "$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

echo "✅ LaunchAgent 설정 파일 복사 완료"

# 기존 서비스 언로드 (실행 중이면)
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_FILE" 2>/dev/null

# 서비스 로드
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_FILE"

echo "✅ 백업 서버 데몬 등록 완료"
echo "📌 백업 서버가 시스템 시작 시 자동으로 실행됩니다."
echo ""
echo "🔧 유용한 명령어:"
echo "  - 상태 확인: launchctl list | grep scrapbook-backup"
echo "  - 중지: launchctl unload ~/Library/LaunchAgents/$PLIST_FILE"
echo "  - 재시작: launchctl unload ~/Library/LaunchAgents/$PLIST_FILE && launchctl load ~/Library/LaunchAgents/$PLIST_FILE"
echo "  - 로그 확인: tail -f logs/backup-server.log"
