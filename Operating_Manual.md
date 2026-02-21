# News Intelligence Hub & Wave Tree 운영 매뉴얼

이 파일은 **VS Code(눈)**와 **Antigravity(뇌/근육)**를 유기적으로 연결하여 '진안 오가닉 OS'를 돌리기 위한 지침서입니다.

## 🚀 시스템 자동화 설정

> 2026-02-21 기준: 외장 볼륨 경로 LaunchAgent 권한 이슈(`Operation not permitted`)로 핵심 자동화는 cron으로 운영

### 초기 설정 (최초 1회)
```bash
cd /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub

# 1. 로그 디렉토리 생성
mkdir -p logs

# 2. 실행 권한 부여
chmod +x run_daily_bridge.sh run_perplexity_auto.sh

# 3. cron 등록 확인
crontab -l

# 4. 수동 테스트
/bin/bash run_perplexity_auto.sh
/bin/bash run_daily_bridge.sh
```

### 매일 아침 자동으로 일어나는 일
- **06:50** - cron이 `run_perplexity_auto.sh` 자동 실행
- **07:00** - cron이 `run_daily_bridge.sh` 자동 실행
- **뉴스 수집** - news_hub.py가 최신 뉴스 가져오기
- **로컬 분석** - 규칙 기반으로 자동 필터링 및 분석
- **Daily_Bridge.md 생성** - TOP 3 핵심 정보만 정제
- **로그 기록** - logs/cron_perplexity_auto.log, logs/cron_daily_bridge.log 및 일자 로그

---

## 📋 운영 프로세스 (Day-by-Day)

### 아침 7시: 자동 실행 완료 ✅
- Daily_Bridge.md가 자동으로 생성됨
- 핵심 정보 TOP 3이 정제되어 저장됨

### 아침 9시: 운목님의 액션 (약 5분)

#### Step 1: Daily_Bridge.md 확인
VS Code에서 `Daily_Bridge.md` 파일을 열고 생성된 내용 확인

#### Step 2: Antigravity로 전달
1. Daily_Bridge.md 전체 내용 복사 (Ctrl+A → Ctrl+C)
2. Antigravity 창 오픈
3. 다음과 같이 말하며 내용 붙여넣기:

```
"오늘의 레이더 감지 결과야. (복사한 내용 붙여넣기)

이 데이터를 바탕으로 현재 Wave Tree Project Dashboard에서 
수정하거나 새로 추가해야 할 To-Do 카드 3개를 뽑아줘."
```

### 오전 10시: Antigravity의 전략 실행

**Antigravity가 제안한 3개 액션 검토**
- 예: "균사체 트렌드 변화에 따라 서버 C의 연산 비중을 Bio-R&D로 70% 전환해야 함."

**승인 및 실행**
대시보드에서 [승인] 버튼을 누르거나 다음과 같이 명령:

```
"좋아, 2번 액션 승인한다. 
지금 즉시 서버 C의 환경 설정을 변경하는 스크립트를 실행해줘."
```

---

## 📡 시스템 워크플로우 한눈에 보기

```
[06:50/07:00] cron 자동 수집/브릿지 생성
    ↓
[자동] 로컬 규칙 기반 필터링 + 분석
    ↓
[자동] Daily_Bridge.md 생성 (TOP 3)
    ↓
[09:00] 운목님이 Daily_Bridge.md 열람
    ↓
[복사/붙여넣기] → Antigravity 전달
    ↓
[Antigravity] 전략 수립 및 제안
    ↓
[10:00] 운목님 승인 및 실행 명령
    ↓
[Wave Tree Dashboard] 자동 업데이트
```

---

**언제**: 매일 아침 업무 시작 직후

**도구**: VS Code + Copilot

**데이터 수집**: news_hub.py를 실행하여 최신 뉴스를 가져옵니다.

**Copilot에게 질문하기**: VS Code 채팅창(Ctrl+Shift+I)에 아래 문장을 던져 뉴스를 정제합니다.

> "방금 수집된 뉴스들 중에서 진안 Farmerstree의 균사체 연구와 서버 인프라에 직접적인 영향을 줄 만한 핵심 정보 3개만 요약해줘. 특히 '실행 가능한 인사이트' 위주로 정리해줘."

**브릿지 파일 생성**: 정리된 내용을 Daily_Bridge.md에 저장합니다.

---

## 💡 운목님을 위한 핵심 팁

✅ **VS Code는 '정보를 깎고 다듬는 공장'으로만 쓰세요.** (자동화됨)
- 더 이상 수동으로 뉴스를 정제할 필요가 없습니다.
- 매일 아침 Daily_Bridge.md만 확인하면 됩니다.

✅ **Antigravity는 '명령을 내리는 사령탑'으로 쓰세요.** (무거운 판단)
- 전략 수립과 의사결정만 담당
- 실행은 자동 스크립트가 처리

✅ **두 세계가 연결되는 지점은 Daily_Bridge.md 하나입니다.**
- 이 파일만 제대로 옮겨주면 시스템은 유기적으로 돌아갑니다.

---

## 🔧 매뉴얼 유지보수

### 매일 확인 사항
- [ ] logs/cron_perplexity_auto.log 확인 (에러 없음?)
- [ ] logs/cron_daily_bridge.log 확인 (에러 없음?)
- [ ] Daily_Bridge.md 생성됨 (TOP 3 정제됨?)
- [ ] Antigravity와 연동 정상?

### 수정 필요시
**키워드 변경**: news_hub.py의 `KEYWORDS` 섹션 수정
**실행 시간 변경**: `crontab -e`에서 06:50/07:00 스케줄 수정
**분석 엔진 설정**: 로컬 규칙 기반(기본값) 사용

---

생성: 2026년 2월 1일
최종 업데이트: 2026년 2월 21일
