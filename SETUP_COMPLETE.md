# 🎯 Wave Tree Daily Bridge 시스템 - 설정 완료!

## ✅ 현재 상태

### 1️⃣ 자동 뉴스 수집 & 로컬 분석
- `news_hub.py`가 뉴스 수집 후 키워드/점수 기반으로 분석합니다.
- 외부 AI API 키 없이 동작합니다.
- TOP 3 정제 결과를 생성합니다.

### 2️⃣ Daily_Bridge.md 자동 생성
- VS Code ↔ Antigravity 연결 파일로 매일 생성됩니다.
- 핵심 정보 TOP 3를 마크다운으로 저장합니다.

### 3️⃣ 매일 아침 자동 실행 스케줄러
- `run_daily_bridge.sh` 실행
- cron 등록으로 자동 실행
- 06:50 `run_perplexity_auto.sh`
- 07:00 `run_daily_bridge.sh`

---

## 🚀 사용 시작하기

### Step 1: 시스템 상태 확인
```bash
crontab -l
tail -f /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/logs/cron_daily_bridge.log
```

### Step 2: 매일 운영
1. 07:00 자동 생성 완료
2. 09:00 `Daily_Bridge.md` 확인
3. Antigravity로 전달 후 액션 실행

---

## 🎓 처리 흐름

```text
[cron 06:50/07:00]
  -> [run_perplexity_auto.sh]
  -> [run_daily_bridge.sh]
  -> [news_hub.py 로컬 분석]
  -> [Daily_Bridge.md 생성]
  -> [Dashboard 동기화]
```

---

## 📞 트러블슈팅

### 생성 실패 시
```bash
tail -100 /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/logs/cron_daily_bridge.log
cd /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub
python3 news_hub.py
```

### 설정 포인트
- 실행 시간: `crontab -e`
- 키워드: `news_hub.py`의 `KEYWORDS`

---

**생성**: 2026년 2월 1일  
**최종 업데이트**: 2026년 2월 21일  
**상태**: ✅ cron 기반 자동화로 운영 중
