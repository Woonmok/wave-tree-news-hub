#!/bin/bash
# run_daily_bridge.sh
# 매일 아침 뉴스 수집 및 Daily_Bridge.md 자동 생성 스크립트

# 작업 디렉토리 이동
cd /Users/seunghoonoh/Desktop/wave-tree-news-hub

# 가상환경 활성화
source .venv/bin/activate

# Python 실행 (Gemini 기반 분석 활성화)
echo "🌅 $(date '+%Y-%m-%d %H:%M:%S') - Daily Bridge 자동 생성 시작..."
python3 news_hub.py

echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 완료!"
echo "📄 Daily_Bridge.md를 확인하고 Antigravity에 복사하세요."
