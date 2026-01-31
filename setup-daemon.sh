#!/bin/bash
# 웹 서버와 ngrok을 백그라운드 데몬으로 설정하는 스크립트

echo "🚀 Wave Tree 데몬 설정 시작..."

# 1. 기존 프로세스 중지
echo "🛑 기존 프로세스 중지..."
launchctl unload ~/Library/LaunchAgents/com.wavetree.httpserver.plist 2>/dev/null
launchctl unload ~/Library/LaunchAgents/com.ngrok.tunnel.plist 2>/dev/null

# 2. LaunchAgents 디렉토리 생성
mkdir -p ~/Library/LaunchAgents

# 3. Python HTTP 서버 설정
echo "⚙️  Python HTTP 서버 설정 중..."
cp com.wavetree.httpserver.plist ~/Library/LaunchAgents/
chmod 644 ~/Library/LaunchAgents/com.wavetree.httpserver.plist
launchctl load ~/Library/LaunchAgents/com.wavetree.httpserver.plist

# 4. ngrok 설정
echo "⚙️  ngrok 설정 중..."
cp com.ngrok.plist ~/Library/LaunchAgents/com.ngrok.tunnel.plist
chmod 644 ~/Library/LaunchAgents/com.ngrok.tunnel.plist
launchctl load ~/Library/LaunchAgents/com.ngrok.tunnel.plist

# 5. 시작 확인
sleep 3
echo ""
echo "✅ 서비스 상태:"
launchctl list | grep -E "com.wavetree|com.ngrok"

echo ""
echo "📋 로그 확인:"
echo "  HTTP 서버: tail -f /tmp/wavetree-http.log"
echo "  ngrok:     tail -f /tmp/wavetree-http-error.log"
echo ""
echo "🌐 ngrok URL 확인:"
curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' || echo "  (ngrok 시작 대기 중...)"
