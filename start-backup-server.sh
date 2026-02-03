#!/bin/bash
# start-backup-server.sh - 스크랩북 백업 서버 시작 스크립트

cd "$(dirname "$0")"

echo "🚀 스크랩북 백업 서버 시작 중..."
node backup_server.js
