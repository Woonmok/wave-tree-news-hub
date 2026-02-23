# Process News Contract

## 목적
`news_hub.py`의 실행 흐름을 오케스트레이터 패턴으로 고정하고, 단계별 입출력/부작용/검증 기준을 명시한다.

현재 오케스트레이터는 아래 순서를 따른다.

1. `fetch_news()`
2. `filter_and_analyze(news_list)`
3. `persist(processed_news_data)`
4. `publish(processed_news_data, artifacts)`
5. `summary(processed_news_data, skipped_count, artifacts)`

---

## 1) fetch 단계
### 함수
- `fetch_news() -> list[str]`

### 입력
- 없음

### 출력 계약
- `list[str]` 반환
- 빈 리스트 허용
- 각 요소는 뉴스 원문 문자열

### 부작용
- 없음(권장)

### 검증 포인트
- 반환 타입이 리스트인지
- 리스트 요소가 모두 문자열인지

---

## 2) filter+analyze 단계
### 함수
- `filter_and_analyze(news_list, use_local_analysis=True) -> tuple[list[dict], int]`

### 입력
- `news_list: list[str]`
- `use_local_analysis: bool`

### 출력 계약
- `processed_news_data: list[dict]`
- `skipped_count: int`

각 `processed_news_data` 원소는 최소 키를 가진다.
- `text: str`
- `keywords: list[str]`
- `analysis: str | None`
- `category: str`

### 부작용
- 로깅 출력

### 검증 포인트
- `skipped_count >= 0`
- `len(processed_news_data) + skipped_count == len(news_list)`
- 각 원소에 위 4개 키 존재

---

## 3) persist 단계
### 함수
- `persist(processed_news_data) -> dict`

### 입력
- `processed_news_data: list[dict]`

### 출력 계약
반환 `artifacts`는 최소 아래 키를 가진다.
- `radar_saved: int`
- `json_saved: int`
- `bridge_path: str | None`
- `news_sync_ok: bool`

### 부작용
- `Project_Radar.md` append
- `detected_news.json` atomic 저장
- `Daily_Bridge.md` 생성
- `data/normalized/news.json` 동기화

### 검증 포인트
- `radar_saved <= len(processed_news_data)`
- `json_saved <= len(processed_news_data)`
- `bridge_path`가 존재하면 실제 파일 존재
- `news_sync_ok` 타입이 bool

---

## 4) publish 단계
### 함수
- `publish(processed_news_data, artifacts) -> None`

### 입력
- `processed_news_data: list[dict]`
- `artifacts: dict`

### 출력 계약
- 반환값 없음
- `artifacts`에 아래 키를 채운다.
  - `dashboard_ok: bool`
  - `html_ok: bool`

### 부작용
- `dashboard_data.json` 업데이트
- `sync_top_news.sync_to_html()` 실행

### 검증 포인트
- 실행 후 `artifacts`에 `dashboard_ok`, `html_ok` 존재
- 둘 다 bool

---

## 5) summary 단계
### 함수
- `summary(processed_news_data, skipped_count, artifacts) -> None`

### 입력
- `processed_news_data: list[dict]`
- `skipped_count: int`
- `artifacts: dict`

### 출력 계약
- 반환값 없음
- 최종 상태 로깅

### 부작용
- 로그 출력만 수행

### 검증 포인트
- 예외 없이 종료
- 핵심 상태값(`saved/skipped/dashboard/html/news_sync`) 로그에 포함

---

## 스키마 검증 관련 고정 규칙
`news.json`의 `items`는 아래 키를 반드시 가져야 한다.

```python
REQUIRED_KEYS = {"id", "category", "title", "summary"}
```

검증 함수 `validate_news_items_schema()`는:
- 필수 키 누락 항목을 제외
- 제외 건수와 원인을 로그에 남김
- 유효 항목만 후속 단계에 전달

---

## 운영 체크리스트 (수동)
- `python3 news_hub.py` 실행 시 예외 없이 종료
- 로그 레벨/포맷이 `logging.basicConfig(...)` 설정을 따름
- `process_news()` 본문에 세부 비즈니스 로직이 재유입되지 않았는지 확인
- JSON 저장은 atomic 경로(`atomic_write_json`)만 사용되는지 확인

## 계약 자동 점검
- 스크립트: `tools/check_process_contract.py`
- 실행: `python3 tools/check_process_contract.py`
- 실패 시 `❌ CONTRACT FAILED`와 함께 위반 항목을 출력한다.

## Git Hook 연동 (권장)
- 훅 파일: `.githooks/pre-commit`
- 기능:
  - `tools/check_process_contract.py` 실행
  - 핵심 자동화 스크립트 문법 스모크 체크
    - `news_hub.py`
    - `sync_top_news.py`
    - `../woonmok.github.io/antigravity.py` (텔레그램 자동 메시지)
    - `../woonmok.github.io/monitor_intelligence.py` (대시보드 업데이트)

설치(로컬 저장소 1회):

```bash
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

이 훅은 **커밋 시점에만** 동작하므로 런타임 자동화(대시보드 2개/텔레그램)에는 영향을 주지 않는다.
