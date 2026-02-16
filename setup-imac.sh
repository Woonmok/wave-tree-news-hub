#!/bin/bash
# setup-imac.sh - iMac에서 전체 환경을 한 번에 설정

set -e  # 오류 시 중단

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Wave Tree News Hub - iMac 환경 설정 시작"
echo "📁 작업 디렉토리: $SCRIPT_DIR"
echo ""

# 1. 디렉토리 생성
echo "1️⃣  필요한 디렉토리 생성..."
mkdir -p logs
mkdir -p data/raw/backups
mkdir -p data/normalized
mkdir -p data/scrapbook
echo "   ✅ 디렉토리 생성 완료"
echo ""

# 2. 실행 권한 부여
echo "2️⃣  스크립트 실행 권한 설정..."
chmod +x run_daily_bridge.sh
chmod +x run-news-hub.sh
chmod +x setup_daily_bridge.sh
chmod +x setup-daemon.sh
chmod +x setup-ngrok-daemon.sh
chmod +x start-http-server.sh
chmod +x stop-daemon.sh
chmod +x start-backup-server.sh
chmod +x setup-backup-daemon.sh
echo "   ✅ 실행 권한 설정 완료"
echo ""

# 3. Python 환경 확인
echo "3️⃣  Python 환경 확인..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ Python 설치됨: $PYTHON_VERSION"
    
    # 필요한 패키지 설치
    echo "   📦 필요한 Python 패키지 확인 중..."
    if ! python3 -c "import dotenv" 2>/dev/null; then
        echo "   ⏳ python-dotenv 설치 중..."
        pip3 install python-dotenv
    fi
else
    echo "   ⚠️  Python3가 설치되어 있지 않습니다."
    echo "   🔗 https://www.python.org/downloads/ 에서 설치해주세요."
fi
echo ""

# 4. Node.js 환경 확인
echo "4️⃣  Node.js 환경 확인..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo "   ✅ Node.js 설치됨: $NODE_VERSION"
else
    echo "   ⚠️  Node.js가 설치되어 있지 않습니다."
    echo "   🔗 https://nodejs.org/ 에서 설치해주세요."
fi
echo ""

# 5. 백업 서버 데몬 등록
echo "5️⃣  백업 서버 데몬 등록..."
if [ -f "setup-backup-daemon.sh" ]; then
    ./setup-backup-daemon.sh
else
    echo "   ⚠️  setup-backup-daemon.sh 파일이 없습니다."
fi
echo ""

# 6. HTTP 서버 확인
echo "6️⃣  HTTP 서버 설정..."
if [ -f "start-http-server.sh" ]; then
    echo "   ✅ HTTP 서버 스크립트 준비됨"
    echo "   💡 실행: ./start-http-server.sh"
else
    echo "   ⚠️  start-http-server.sh 파일이 없습니다."
fi
echo ""

# 7. 기존 데몬 확인
echo "7️⃣  기존 데몬 서비스 확인..."
echo "   백업 서버:"
launchctl list | grep scrapbook-backup || echo "     (없음)"
echo "   HTTP 서버:"
launchctl list | grep httpserver || echo "     (없음)"
echo "   Ngrok:"
launchctl list | grep ngrok || echo "     (없음)"
echo ""

# 8. 환경 변수 확인
echo "8️⃣  환경 변수 확인..."
echo "   ℹ️  외부 AI API 키는 더 이상 필요하지 않습니다."
echo "   ✅ 로컬 규칙 기반 분석 모드 사용"
echo ""

# 완료 메시지
echo "=========================================="
echo "✅ iMac 환경 설정 완료!"
echo "=========================================="
echo ""
echo "📋 다음 단계:"
echo ""
echo "1️⃣  백업 서버 상태 확인:"
echo "   launchctl list | grep scrapbook-backup"
echo ""
echo "2️⃣  HTTP 서버 실행 (뉴스 허브 접속용):"
echo "   ./start-http-server.sh"
echo ""
echo "3️⃣  뉴스 수집 테스트:"
echo "   python3 news_hub.py"
echo ""
echo "4️⃣  브라우저에서 접속:"
echo "   http://localhost:8000"
echo ""
echo "5️⃣  백업 로그 확인:"
echo "   tail -f logs/backup-server.log"
echo ""
echo "=========================================="
