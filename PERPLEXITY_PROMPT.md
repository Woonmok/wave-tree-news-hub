# Perplexity 프롬프트 템플릿

이 문서는 Perplexity에서 출력을 얻을 때 사용하는 고정 프롬프트 템플릿입니다.
**항상 이 형식으로 출력하도록 강제**하면 `normalize.js`가 자동 처리합니다.

---

## 🔧 프롬프트 템플릿 (복사해서 사용)

```
당신은 뉴스 큐레이터입니다. 다음 5개 카테고리에 대한 최신 뉴스를 수집하고,
**정확히 이 형식**으로만 출력해주세요:

[CATEGORY: listeria_free]
- 제목 | 출처 | https://URL | YYYY-MM-DDTHH:mm:ssZ | score=0.X | tags=tag1,tag2 | summary=한줄요약

[CATEGORY: cultured_meat]
- 제목 | 출처 | https://URL | YYYY-MM-DDTHH:mm:ssZ | score=0.X | tags=tag1,tag2 | summary=한줄요약

[CATEGORY: high_end_audio]
- 제목 | 출처 | https://URL | YYYY-MM-DDTHH:mm:ssZ | score=0.X | tags=tag1,tag2 | summary=한줄요약

[CATEGORY: computer_ai]
- 제목 | 출처 | https://URL | YYYY-MM-DDTHH:mm:ssZ | score=0.X | tags=tag1,tag2 | summary=한줄요약

[CATEGORY: global_biz]
- 제목 | 출처 | https://URL | YYYY-MM-DDTHH:mm:ssZ | score=0.X | tags=tag1,tag2 | summary=한줄요약

**규칙:**
1. 각 카테고리마다 최소 2-3개의 뉴스 항목을 포함해주세요.
2. 날짜는 ISO 8601 형식 (2026-01-31T08:00:00Z)이어야 합니다.
3. URL은 정확한 링크여야 합니다 (예: https://example.com/news-article).
4. score는 0~1 사이의 숫자입니다 (관련성/중요도).
5. tags는 쉼표로 구분하고 소문자만 사용합니다.
6. summary는 20-50자의 한줄 요약입니다.
7. 파이프(|) 문자로 필드를 구분하고, 각 필드 양쪽에 공백을 넣어주세요.
8. summary 다음에 마침표(.)를 붙이지 마세요.
9. 다른 설명이나 주석은 절대 포함하지 마세요. 위의 형식만 출력합니다.

이제 시작해주세요!
```

---

## 📋 예시 출력

```
[CATEGORY: listeria_free]
- 미국 RTE 파스타 리스테리아 사망 사고로 "제로 목표" 관리 강화 | CDC/FDA | https://example.com/listeria-rte | 2026-01-31T08:00:00Z | score=0.86 | tags=regulation,usa | summary=RTE 제품군에 대한 환경모니터링과 공정관리 강화 움직임
- FDA, RTE 제품 위생설비·환경모니터링 지침 업데이트 | FDA | https://example.com/fda-guidance | 2026-01-31T06:00:00Z | score=0.92 | tags=guidance,fsma | summary=신규 FSMA 규정에 따른 시설 점검 강화안 발표

[CATEGORY: cultured_meat]
- 배양육 시장 2034년 11억 달러 전망, 연평균 50.9% 성장 | Market Research | https://example.com/cultured-market | 2026-01-30T12:00:00Z | score=0.74 | tags=market,forecast | summary=북미 비중과 승인국 확대가 핵심
- Vow, 538kg 배양 메추라기 생산 성공 - 상업화 이정표 | Vow Food | https://example.com/vow-538kg | 2026-01-29T10:00:00Z | score=0.81 | tags=scaleup | summary=호주 배양육 기업이 단백질 규모 생산 증명

[CATEGORY: high_end_audio]
- REL Acoustics 홈시어터 전용 서브우퍼 2종 공개 | REL | https://example.com/rel-sub | 2026-01-31T02:00:00Z | score=0.62 | tags=product,home-theater | summary=Strata3과 Strata5 신제품 발표

[CATEGORY: computer_ai]
- OpenAI 첫 AI 하드웨어, 럭스셰어→폭스콘 단독 전환 | TrendForce | https://example.com/openai-foxconn | 2026-01-31T01:00:00Z | score=0.88 | tags=supply-chain,device | summary=생산 파트너 변경 이슈
- 아날로그 AI 칩·에너지 효율형 딥러닝 하드웨어 논의 | AI Hardware Summit | https://example.com/analog-ai | 2026-01-28T09:00:00Z | score=0.55 | tags=hardware,energy | summary=차세대 AI 컴퓨팅 아키텍처 구상

[CATEGORY: global_biz]
- 유럽 식품안전청, 배양육 규제 프레임워크 최종안 발표 | EFSA | https://example.com/efsa-framework | 2026-01-30T05:00:00Z | score=0.9 | tags=eu,regulation | summary=EU 배양육 승인 절차 표준화 고시
```

---

## 🎯 사용 방법

1. **Perplexity 접속**: https://www.perplexity.ai
2. **위의 프롬프트 템플릿을 복사**해서 입력창에 붙여넣기
3. **Perplexity 응답을 복사**
4. **`data/raw/perplexity.txt`에 붙여넣기**
5. **30분 이내에 자동으로 `data/normalized/news.json` 업데이트됨**

또는 수동으로 실행:
```bash
node scripts/normalize.js --in data/raw/perplexity.txt --out data/normalized/news.json
```

---

## ✅ 체크리스트

- [ ] 프롬프트를 Perplexity에 입력
- [ ] 출력이 정확한 형식인지 확인
- [ ] 출력을 `data/raw/perplexity.txt`에 붙여넣기
- [ ] 로그에서 정규화 확인: `tail -f ~/Library/Logs/wavetree-normalize.log`
- [ ] 브라우저에서 대시보드 새로고침

---

## 🐛 문제 해결

**출력이 처리되지 않으면:**
1. 파일 경로 확인: `ls -la ~/Desktop/wave-tree-news-hub/data/raw/perplexity.txt`
2. 형식 확인: 파이프(|)가 정확히 구분되어 있는지
3. 로그 확인: `tail ~/Library/Logs/wavetree-normalize-error.log`

**형식 검증:**
```bash
# 직접 실행해보기
node ~/Desktop/wave-tree-news-hub/scripts/normalize.js --in ~/Desktop/wave-tree-news-hub/data/raw/perplexity.txt --out ~/Desktop/wave-tree-news-hub/data/normalized/news.json
```

---

## 📝 카테고리 설명

- **listeria_free**: 식품 안전, 리스테리아 관련 뉴스
- **cultured_meat**: 배양육/세포육 기술 및 시장 뉴스
- **high_end_audio**: 고급 오디오 장비 및 기술 뉴스
- **computer_ai**: 컴퓨터/AI 하드웨어 및 기술 뉴스
- **global_biz**: 국제 비즈니스 및 규제 뉴스
