# 🤖 Wave Tree 자동화 시스템 현황

**최종 업데이트**: 2026년 2월 21일

> ⚠️ **운영 모드 변경 (2026-02-21)**
> - 외장 볼륨 경로(`/Volumes/AI_DATA_CENTRE/...`)에서 macOS LaunchAgent가 `Operation not permitted`로 실패하는 이슈 확인
> - 핵심 자동화는 **LaunchAgent → cron**으로 전환 완료
> - 전환 대상: `dailybridge`, `perplexity-auto`, `antigravity`

---

## ✅ 정상 작동 중인 자동화

### 1️⃣ Daily Bridge (매일 07:00) ⭐ 핵심 시스템

**실행 방식**:
- cron: `0 7 * * *`
- 스크립트: `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/run_daily_bridge.sh`
- cron 로그: `logs/cron_daily_bridge.log`

**주요 역할**:
1. Perplexity 뉴스 자동 수집
2. Daily_Bridge.md 생성 (Antigravity 인사이트 브릿지)
3. dashboard_data.json 업데이트
4. woonmok.github.io Intelligence Hub 동기화

**생성 파일**:
- ✅ `Daily_Bridge.md` - Antigravity에 복사할 인사이트 브릿지
- ✅ `dashboard_data.json` - woonmok.github.io 대시보드 동기화
- ✅ `index.html Intelligence Hub` - 웹사이트 top 2 뉴스 자동 표시
- ✅ `detected_news.json` - API 연동 데이터
- ✅ `Project_Radar.md` - 전략 레이더
- ✅ `data/daily_bridge_YYYY-MM-DD.json` - JSON 아카이브

**안전장치** (5개):
1. `set -Eeuo pipefail` - 비정상 상태 즉시 실패 처리
2. `run_daily_bridge.lock` - 동시 실행 차단
3. Stale lock 자동 정리 (PID 생존 확인)
4. `trap` 기반 종료 정리 (락 해제 + 실패 알림)
5. 필수 명령어/경로 사전 검증 및 고정 PATH

**로그**:
- 표준: `logs/dailybridge_YYYY-MM-DD.log`
- 에러: `logs/dailybridge_error_YYYY-MM-DD.log`

**최근 실행**:
- 2026-02-20 03:48 - 자동 실행(기존 트리거)
- 2026-02-21 10:34 - 수동 복구 실행
- 2026-02-21 10:40 - cron 환경 시뮬레이션 테스트 성공

---

### 2️⃣ Antigravity Bot (상시 감시 복구) 🚀

**실행 방식**:
- cron watchdog: `*/2 * * * * /bin/zsh .../scripts/ensure_antigravity.sh`
- 스크립트: `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/antigravity.py`
- watchdog 로그: `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/logs/ensure_antigravity_cron.log`

**주요 기능**:
1. **매일 09:00 자동 브리핑**
   - 할일 목록
   - 최신 뉴스 (리스테리아, 배양육, 오디오, 컴퓨터)
   - 진안 날씨

2. **10분 간격 자동 업데이트**
   - 날씨 정보 갱신 → dashboard_data.json

3. **텔레그램 명령어**
   - `/할일` - 할일 목록 조회
   - `/브리핑` - 수동 브리핑 요청
   - `/날씨` - 현재 날씨 조회
   - 할일 추가/완료/삭제

**관리 파일**:
- `dashboard_data.json` - 대시보드 통합 데이터
- `todo_storage.json` - 할일 영구 저장소
- `daily_news.json` - 일일 뉴스 데이터
- `logs/antigravity.log` - 봇 활동 로그

**환경 변수** (.env):
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `OPENWEATHER_API_KEY`
- `ANTIGRAVITY_AUTO_BRIEFING=true`

---

### 3️⃣ Scrapbook Backup Server (상주)

**실행 방식**:
- LaunchAgent: `com.wavetree.scrapbook-backup.plist`
- KeepAlive: true
- 스크립트: `backup_server.js`

**역할**:
- 데이터 백업 서버 운영
- 스크랩북 데이터 자동 백업

**상태**: ⚠️ Exit Code 1 (재시작 대기 중)

**로그**:
- `~/Library/Logs/wave-tree-news-hub/backup-server.log`
- `~/Library/Logs/wave-tree-news-hub/backup-server.error.log`

---

### 4️⃣ Normalize Service (상주)

**실행 방식**:
- LaunchAgent: `com.wavetree.normalize.plist`

**역할**:
- 뉴스 데이터 정규화 처리

**상태**: ⚠️ Exit Code 78 (설정 오류)

---

### 5️⃣ HTTP Server (상주)

**실행 방식**:
- LaunchAgent: `com.wavetree.httpserver.plist`

**역할**:
- 로컬 HTTP 서버 운영
- 대시보드 서빙

---

## ❌ 비활성화된 자동화

### LaunchAgent 기반 외장볼륨 작업 (중단)

**중단 대상**:
- `com.wavetree.dailybridge`
- `com.wavetree.perplexity-auto`
- `com.wavetree.antigravity`

**중단 이유**:
- 외장 볼륨 경로 접근 시 LaunchAgent에서 `Operation not permitted` 발생
- 결과적으로 `EX_CONFIG(78)`로 즉시 종료되는 사례 다수 확인

**대체 방식**:
- 동일 스크립트를 cron으로 운영 전환

### update_news.py (매일 09:00)

**이전 설정**:
- cron: `00 09 * * *`
- 경로: `/Users/seunghoonoh/woonmok.github.io/update_news.py`

**비활성화 이유**:
- 2026-02-12 비활성화
- antigravity.py로 기능 통합
- 이전 봇 토큰 폐기됨

**현재 상태**: 스크립트 내부에서 실행 거부 메시지 출력

---

## 📊 오늘의 자동화 실적 (2026-02-21)

| 시각 | 작업 | 상태 |
|------|------|------|
| 06:50 | Perplexity Auto (cron 등록) | ✅ 설정 완료 |
| 07:00 | Daily Bridge (cron 등록) | ✅ 설정 완료 |
| 10:34 | Daily Bridge 수동 복구 실행 | ✅ 성공 |
| 10:40 | cron 환경 시뮬레이션 실행 | ✅ 성공 |
| */2분 | Antigravity watchdog (cron) | ✅ 동작 중 |

**주요 성과**:
- Daily_Bridge.md 생성 완료
- Intelligence Hub에 top 2 뉴스 표시:
  1. Daily Bridge 2026-02-18
  2. 2026년 배양육 업계, "환상은 줄고 현실적인 재정·규제 전략으로 전환"
- 텔레그램 알림 발송 완료

---

## 🎯 자동화를 통해 이뤄놓은 것들

### 매일 자동으로 수행되는 작업
1. ✅ **최신 뉴스 자동 수집** (Perplexity → Daily_Bridge.md)
2. ✅ **woonmok.github.io Intelligence Hub 자동 업데이트** (Top 2 뉴스)
3. ✅ **텔레그램 자동 브리핑** (매일 09:00)
4. ✅ **날씨 정보 10분마다 자동 갱신**
5. ✅ **실패 시 텔레그램 즉시 알림** (안전장치)
6. ✅ **로그 자동 기록** (디버깅 및 감사)

### 수동 작업 제거
- ❌ 매일 아침 뉴스 수집 -> ✅ 자동화
- ❌ 대시보드 수동 업데이트 -> ✅ 자동 동기화
- ❌ Intelligence Hub 수동 업데이트 -> ✅ 자동 동기화
- ❌ 텔레그램 수동 브리핑 -> ✅ 자동 발송

---

## 🔧 운영 점검 명령어

### Daily Bridge 관리
```bash
# 현재 cron 확인
crontab -l

# 수동 실행 (락 동일 적용)
/bin/bash /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/run_daily_bridge.sh

# 최근 로그 확인
tail -n 100 /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/logs/dailybridge_$(date +%Y-%m-%d).log

# 에러 로그 확인
tail -n 50 /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/logs/dailybridge_error_$(date +%Y-%m-%d).log
```

### cron/프로세스 관리
```bash
# cron 설정 확인
crontab -l

# Antigravity 수동 복구 실행
/bin/zsh /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/scripts/ensure_antigravity.sh

# Antigravity 프로세스 확인
pgrep -af antigravity.py

# watchdog 로그
tail -f /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/logs/ensure_antigravity_cron.log
```

### 시스템 상태 확인
```bash
# 설치된 LaunchAgents
ls -1 ~/Library/LaunchAgents/com.wavetree.*

# Intelligence Hub 동기화 확인
jq -r '.intelligence | length, (.[] | .title)' /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/dashboard_data.json

# 오늘 생성된 파일들
ls -lh /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/data/daily_bridge_$(date +%Y-%m-%d).json
```

---

## 📝 환경 변수 설정

### 필수 .env 파일 (wave-tree-news-hub/.env)
```env
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
PERPLEXITY_API_KEY=your_perplexity_key
```

### 필수 .env 파일 (woonmok.github.io/.env)
```env
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
OPENWEATHER_API_KEY=your_openweather_key
ANTIGRAVITY_AUTO_BRIEFING=true
```

---

## 🚨 트러블슈팅

### Daily Bridge가 실행되지 않을 때
1. cron 등록 확인: `crontab -l`
2. 락 파일 확인: `ls -l /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/.locks/`
3. 로그 확인: `tail -50 logs/dailybridge_error_$(date +%Y-%m-%d).log`
4. 수동 실행 테스트: `./run_daily_bridge.sh`

### Antigravity 봇이 응답하지 않을 때
1. 실행 상태 확인: `pgrep -af antigravity.py`
2. watchdog 로그 확인: `tail -50 /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/logs/ensure_antigravity_cron.log`
3. 수동 복구: `/bin/zsh /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/scripts/ensure_antigravity.sh`
4. 에러 로그 확인: `tail -50 /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/logs/antigravity_error.log`
5. 환경 변수 확인: `.env` 파일 토큰 유효성 검증

### Intelligence Hub에 뉴스가 표시되지 않을 때
1. dashboard_data.json 확인: `jq .intelligence dashboard_data.json`
2. 수동 동기화: `python3 sync_top_news.py`
3. news.json 확인: `jq '.items | length' data/normalized/news.json`

---

## 📌 중요 파일 경로

### 실행 스크립트
- `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/run_daily_bridge.sh`
- `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/sync_top_news.py`
- `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/antigravity.py`

### 데이터 파일
- `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/dashboard_data.json`
- `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/data/normalized/news.json`
- `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/Daily_Bridge.md`

### 웹사이트
- `/Volumes/AI_DATA_CENTRE/AI_WORKSPACE/woonmok.github.io/index.html`

---

**마지막 점검**: 2026-02-21 ✅ cron 기반 핵심 자동화 정상 작동 중
