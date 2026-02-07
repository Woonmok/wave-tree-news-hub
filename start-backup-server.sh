#!/bin/bash
# start-backup-server.sh - 스크랩북 백업 서버 자동 실행/재시작 스크립트
# wave-tree-news-hub 폴더에서 실행

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Node.js 백업 서버 실행
if [ ! -f backup_server.js ]; then
  echo "backup_server.js 파일이 없습니다. 경로를 확인하세요."
  exit 1
fi

# 로그 파일 경로
LOGFILE="backup_server.log"

# 이미 실행 중이면 종료 후 재시작
RUNNING_PID=$(ps aux | grep node | grep backup_server.js | grep -v grep | awk '{print $2}')
if [ -n "$RUNNING_PID" ]; then
  echo "기존 백업 서버 프로세스($RUNNING_PID) 종료 중..."
  kill "$RUNNING_PID"
  sleep 1
fi

# 서버 실행 (백그라운드)
nohup node backup_server.js > "$LOGFILE" 2>&1 &

sleep 1
NEW_PID=$(ps aux | grep node | grep backup_server.js | grep -v grep | awk '{print $2}')
if [ -n "$NEW_PID" ]; then
  echo "백업 서버가 성공적으로 실행되었습니다. (PID: $NEW_PID)"
  echo "로그: $LOGFILE"
else
  echo "서버 실행에 실패했습니다. 로그를 확인하세요."
fi
