#!/bin/bash
# 데몬 중지 스크립트

echo "🛑 Wave Tree 데몬 중지..."

launchctl unload ~/Library/LaunchAgents/com.wavetree.httpserver.plist 2>/dev/null && echo "✅ HTTP 서버 중지"
launchctl unload ~/Library/LaunchAgents/com.ngrok.tunnel.plist 2>/dev/null && echo "✅ ngrok 중지"

echo ""
echo "남은 프로세스:"
launchctl list | grep -E "com.wavetree|com.ngrok" || echo "없음"
