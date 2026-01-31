#!/bin/bash
# ngrok을 macOS 데몬으로 설정하는 스크립트
# 사용법: bash setup-ngrok-daemon.sh

# 1. ngrok 설치 확인
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok이 설치되지 않았습니다."
    echo "설치하려면: brew install ngrok"
    exit 1
fi

# 2. plist 파일을 LaunchAgents로 복사
PLIST_FILE="$HOME/Library/LaunchAgents/com.ngrok.plist"
SOURCE_PLIST="$(dirname "$0")/com.ngrok.plist"

# LaunchAgents 디렉토리가 없으면 생성
mkdir -p "$HOME/Library/LaunchAgents"

# plist 파일 복사
cp "$SOURCE_PLIST" "$PLIST_FILE"
echo "✅ plist 파일을 $PLIST_FILE에 복사했습니다"

# 3. 권한 설정
chmod 644 "$PLIST_FILE"

# 4. launchd에 로드
launchctl load "$PLIST_FILE"
echo "✅ ngrok 데몬을 시작했습니다"

# 5. 상태 확인
sleep 2
if launchctl list | grep -q "com.ngrok.tunnel"; then
    echo "✅ ngrok이 백그라운드에서 실행 중입니다"
    echo ""
    echo "📋 로그 확인:"
    echo "  tail -f /tmp/ngrok.log"
    echo "  tail -f /tmp/ngrok-error.log"
    echo ""
    echo "🛑 ngrok 중지:"
    echo "  launchctl unload ~/Library/LaunchAgents/com.ngrok.plist"
else
    echo "❌ ngrok 시작에 실패했습니다"
    exit 1
fi
