#!/bin/bash
# setup_daily_bridge.sh
# Daily Bridge 자동 스케줄러 설정 가이드

echo "=========================================="
echo "Daily Bridge 자동 실행 설정"
echo "=========================================="
echo ""

# Step 1: 권한 확인
echo "✓ Step 1: 스크립트 권한 확인..."
if [ -x "/Users/seunghoonoh/Desktop/wave-tree-news-hub/run_daily_bridge.sh" ]; then
    echo "  ✅ 실행 권한 있음"
else
    echo "  ❌ 실행 권한 없음. 권한 부여 중..."
    chmod +x /Users/seunghoonoh/Desktop/wave-tree-news-hub/run_daily_bridge.sh
fi

# Step 2: LaunchAgent 복사
echo ""
echo "✓ Step 2: LaunchAgent 파일 복사..."
mkdir -p ~/Library/LaunchAgents
cp /Users/seunghoonoh/Desktop/wave-tree-news-hub/com.wavetree.dailybridge.plist ~/Library/LaunchAgents/
echo "  ✅ 파일 복사 완료"

# Step 3: LaunchAgent 로드
echo ""
echo "✓ Step 3: LaunchAgent 로드..."
launchctl unload ~/Library/LaunchAgents/com.wavetree.dailybridge.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.wavetree.dailybridge.plist
echo "  ✅ 로드 완료"

# Step 4: 확인
echo ""
echo "✓ Step 4: 설정 확인..."
if launchctl list | grep -q "com.wavetree.dailybridge"; then
    echo "  ✅ Daily Bridge가 성공적으로 등록되었습니다!"
    echo ""
    echo "📅 실행 일정: 매일 아침 07:00 (수정 가능)"
    echo "📁 로그 경로: /Users/seunghoonoh/Desktop/wave-tree-news-hub/logs/"
    echo ""
else
    echo "  ❌ 설정 실패. 아래 명령으로 수동 로드:"
    echo "  launchctl load ~/Library/LaunchAgents/com.wavetree.dailybridge.plist"
fi

echo ""
echo "=========================================="
echo "✅ 설정 완료!"
echo "=========================================="
