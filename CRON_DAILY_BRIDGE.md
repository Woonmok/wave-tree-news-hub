# Daily Bridge cron 운영 가이드 (Mac mini)

## 1) 1회 설정

```bash
cd /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub
chmod +x run_daily_bridge.sh setup_daily_bridge_cron.sh
./setup_daily_bridge_cron.sh
```

기본 등록 스케줄: `매일 07:00`

---

## 2) 실패 시 텔레그램 알림 설정

`run_daily_bridge.sh`는 아래 순서로 토큰/채팅ID를 찾습니다.

1. 현재 셸 환경변수
2. `wave-tree-news-hub/.env`
3. `woonmok.github.io/.env`

필수 키:

```env
TELEGRAM_BOT_TOKEN=123456:ABCDEF...
TELEGRAM_CHAT_ID=123456789
```

---

## 3) 안전장치 5개 (적용됨)

1. `set -Eeuo pipefail`로 비정상 상태 즉시 실패 처리
2. `run_daily_bridge.lock` 파일로 동시 실행 차단
3. stale lock 자동 정리(PID 생존 확인)
4. `trap` 기반 종료 정리(락 해제 + 실패 알림)
5. 필수 명령어/경로 사전 검증 및 고정 PATH

동일 스크립트를 cron/VS Code 수동 실행이 함께 쓰므로 락이 공통 적용됩니다.

---

## 4) 로그 자동 생성

- 표준 로그: `logs/dailybridge_YYYY-MM-DD.log`
- 에러 로그: `logs/dailybridge_error_YYYY-MM-DD.log`

실행 시 자동 생성되며, 별도 로그 파일 생성 작업이 필요 없습니다.

---

## 5) 운영 점검 명령

```bash
# 현재 cron 확인
crontab -l

# 수동 실행(락 동일 적용)
/bin/bash /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/run_daily_bridge.sh

# 최근 로그 확인
tail -n 100 /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/logs/dailybridge_$(date +%Y-%m-%d).log
```
