#!/bin/bash
# News Hub 실행 스크립트

# .env 파일에서 API 키 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

if [ -x "$SCRIPT_DIR/.venv312/bin/python" ]; then
    PYTHON="$SCRIPT_DIR/.venv312/bin/python"
elif [ -x "$SCRIPT_DIR/.venv/bin/python" ]; then
    PYTHON="$SCRIPT_DIR/.venv/bin/python"
else
    PYTHON="python3"
fi

"$PYTHON" news_hub.py
