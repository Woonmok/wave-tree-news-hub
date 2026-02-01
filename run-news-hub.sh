#!/bin/bash
# News Hub 실행 스크립트

# .env 파일에서 API 키 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

cd /Users/seunghoonoh/Desktop/wave-tree-news-hub
/Users/seunghoonoh/Desktop/wave-tree-news-hub/.venv/bin/python news_hub.py
