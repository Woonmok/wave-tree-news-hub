#!/bin/bash
# run_daily_bridge.sh
# 매일 아침 뉴스 수집 및 Daily_Bridge.md 자동 생성 스크립트

# 작업 디렉토리 이동
cd /Users/seunghoonoh/Desktop/wave-tree-news-hub

# 가상환경 활성화
source .venv/bin/activate

# 백업: perplexity.txt를 날짜별로 저장
BACKUP_DIR="data/raw/backups"
BACKUP_FILE="$BACKUP_DIR/perplexity_$(date '+%Y-%m-%d').txt"

# backups 디렉토리 생성
mkdir -p "$BACKUP_DIR"

# 현재 perplexity.txt가 존재하고 비어있지 않으면 백업
if [ -f "data/raw/perplexity.txt" ] && [ -s "data/raw/perplexity.txt" ]; then
    cp "data/raw/perplexity.txt" "$BACKUP_FILE"
    echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 백업 완료: $BACKUP_FILE"
fi

# Python 실행 (Gemini 기반 분석 활성화)
echo "🌅 $(date '+%Y-%m-%d %H:%M:%S') - Daily Bridge 자동 생성 시작..."
python3 news_hub.py

# 처리 완료 후 perplexity.txt 비우기
> data/raw/perplexity.txt
echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - perplexity.txt 리셋 완료"

echo "✅ $(date '+%Y-%m-%d %H:%M:%S') - 완료!"
echo "📄 Daily_Bridge.md를 확인하고 Antigravity에 복사하세요."
