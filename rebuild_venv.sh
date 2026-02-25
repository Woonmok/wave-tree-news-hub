#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN=""
for candidate in python3.14 python3.13 python3.12 python3.11 python3.10 python3 /usr/bin/python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        PYTHON_BIN="$(command -v "$candidate")"
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo "❌ python3 실행 파일을 찾지 못했습니다."
    exit 1
fi

echo "🧹 기존 .venv 제거"
rm -rf .venv

echo "🐍 Python 선택: $PYTHON_BIN"
"$PYTHON_BIN" -m venv .venv

echo "📦 기본 툴 업그레이드"
.venv/bin/python -m pip install --upgrade pip setuptools wheel

if [ -f requirements.txt ]; then
    echo "📚 requirements.txt 설치"
    .venv/bin/pip install -r requirements.txt
else
    echo "ℹ️ requirements.txt가 없어 의존성 자동 설치를 건너뜁니다."
fi

echo "✅ 완료: $SCRIPT_DIR/.venv/bin/python"
echo "👉 VS Code에서 인터프리터를 .venv/bin/python으로 선택하세요."
