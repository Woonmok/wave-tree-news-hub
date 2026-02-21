# Wave Tree News Hub

정규화된 뉴스 대시보드 (Listeria-Free, Cultured Meat, High-End Audio, Computer AI, Global Business)

## 🚀 빠른 시작

> 2026-02-21 기준 운영 모드: 외장 볼륨 경로 권한 이슈로 LaunchAgent 대신 cron 기반 자동화 사용

### 로컬 개발
```bash
# 웹 서버 시작 (포트 8000)
python3 -m http.server 8000

# 브라우저에서 열기
http://localhost:8000/wave-tree-news-hub.html
```

### 뉴스 데이터 업데이트
```bash
# Perplexity 출력을 data/raw/perplexity.txt에 붙여넣은 후
node scripts/normalize.js --in data/raw/perplexity.txt --out data/normalized/news.json
```

## 📁 프로젝트 구조

```
wave-tree-news-hub/
├── wave-tree-news-hub.html    # 메인 대시보드
├── app.js                      # 프론트엔드 로직
├── scripts/
│   └── normalize.js            # Perplexity 출력 → news.json 변환
├── data/
│   ├── raw/
│   │   ├── perplexity.txt      # 사용자가 입력하는 Perplexity 응답 (30분마다 자동 처리)
│   │   └── perplexity.sample.txt
│   └── normalized/
│       └── news.json           # 정규화된 뉴스 (자동 생성)
└── README.md
```

## 🔄 자동 업데이트 (cron 운영)

현재 자동화는 아래 순서로 동작합니다.

- `06:50` → `run_perplexity_auto.sh` (Perplexity 수집/정규화/Top2 동기화)
- `07:00` → `run_daily_bridge.sh` (Daily_Bridge 생성/대시보드 동기화/아카이브 생성)

**현재 cron 확인:**
```bash
crontab -l
```

**운영 로그 확인:**
```bash
tail -f /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/logs/cron_perplexity_auto.log
tail -f /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/logs/cron_daily_bridge.log
```

**수동 실행 테스트:**
```bash
/bin/bash /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/run_perplexity_auto.sh
/bin/bash /Volumes/AI_DATA_CENTRE/AI_WORKSPACE/wave-tree-news-hub/run_daily_bridge.sh
```

## 📊 뉴스 데이터 포맷

### 입력 포맷 (Perplexity 권장 템플릿)

```
[CATEGORY: listeria_free]
- 제목 | 출처 | https://url | 2026-01-31T08:00:00Z | score=0.86 | tags=tag1,tag2 | summary=한줄요약
- 제목2 | 출처2 | https://url2 | 2026-01-31T06:00:00Z | score=0.92 | tags=guidance

[CATEGORY: cultured_meat]
- 배양육 뉴스 | 출처 | https://url | 2026-01-30T12:00:00Z | score=0.74 | tags=market,forecast | summary=요약

[CATEGORY: high_end_audio]
- 오디오 뉴스 | 출처 | https://url | 2026-01-31T02:00:00Z | score=0.62 | tags=product

[CATEGORY: computer_ai]
- AI 뉴스 | 출처 | https://url | 2026-01-31T01:00:00Z | score=0.88 | tags=supply-chain

[CATEGORY: global_biz]
- 글로벌 뉴스 | 출처 | https://url | 2026-01-30T05:00:00Z | score=0.9 | tags=eu,regulation
```

**필드 설명:**
- `CATEGORY`: listeria_free, cultured_meat, high_end_audio, computer_ai, global_biz
- `제목`: 뉴스 제목
- `출처`: 뉴스 출처/언론사
- `URL`: https://... 형식
- `날짜`: ISO 8601 (YYYY-MM-DDTHH:mm:ssZ) 또는 YYYY-MM-DD
- `score`: 0~1 사이의 점수 (선택사항)
- `tags`: 쉼표로 구분된 태그들 (선택사항)
- `summary`: 한 줄 요약 (선택사항)

### 출력 포맷 (news.json)

```json
{
  "generated_at": "2026-01-31T22:30:45Z",
  "items": [
    {
      "id": "sha1-hash",
      "category": "listeria_free",
      "title": "미국 RTE 파스타 리스테리아...",
      "source": "CDC/FDA",
      "url": "https://example.com/listeria-rte",
      "published_at": "2026-01-31T08:00:00Z",
      "summary": "RTE 제품군에 대한 환경모니터링...",
      "highlights": [],
      "tags": ["regulation", "usa"],
      "score": 0.86
    }
  ]
}
```

## 🌐 배포

### GitHub Pages
```bash
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/Woonmok/wave-tree-news-hub.git
git push -u origin main

# GitHub 저장소 Settings → Pages → Main branch 선택
# 대시보드: https://woonmok.github.io/wave-tree-news-hub/wave-tree-news-hub.html
```

### Cloudflare Pages
1. GitHub 저장소를 Cloudflare Pages에 연결
2. Build settings: (빌드 불필요 - 정적 사이트)
3. Output directory: `/` (루트)

## 🔗 ngrok 공개 URL (임시)

```bash
ngrok http 8000
```

## 📝 라이선스

MIT

## 👤 작성자

- Woonmok (qw5354@gmail.com)
