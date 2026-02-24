#!/usr/bin/env python3
import os
import sys
import subprocess
import json
from datetime import date, datetime, timedelta, timezone
from dotenv import load_dotenv
from perplexity import Perplexity

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ENV_PATH = os.path.join(BASE_DIR, ".env")

load_dotenv(ENV_PATH)

API_KEY = os.environ.get("PERPLEXITY_API_KEY", "").strip()
if not API_KEY:
    raise RuntimeError("PERPLEXITY_API_KEY 환경 변수가 설정되어 있지 않습니다.")

MODEL = os.environ.get("PERPLEXITY_MODEL", "sonar-pro").strip()
OUT_PATH = os.environ.get(
    "PERPLEXITY_OUTPUT_PATH",
    os.path.join(BASE_DIR, "data", "raw", "perplexity.txt"),
).strip()

PROMPT_TEMPLATE = """
오늘자 뉴스 업데이트해줘. 반드시 중복은 피하고 꼭 가장 최근 기준으로.

파일 형식은 반드시 Markdown(.md) 으로 해줘.
아래 구조와 포맷을 그대로 지켜서 출력해.

요구사항:
- 카테고리와 개수는 고정:
  - 🦠 Listeria Free 4개
  - 🥩 Cultured Meat 5개
  - 🎵 High-End Audio 5개
  - 🤖 Computer & AI 5개
  - 🌍 Global Biz 4개
- 각 항목은 한 줄에 "제목 | 매체/기관 | URL | 날짜(YYYY-MM-DD) | tags=… | summary=…" 형식으로.
- URL은 반드시 실제 기사 원문 `https://...` 전체 주소를 넣어야 함.
- `(링크 없음)`, `N/A`, 검색 링크, 홈페이지만 넣는 것 금지.
- 전체 결과는 Markdown 문서 하나로 출력.
- 맨 위에는 오늘 날짜를 제목으로 넣어줘.

출력 형식 예시 (이 구조를 그대로 지켜):

# Perplexity 데일리 뉴스 – {today}

## 🦠 Listeria Free (4)

- 제목 | 매체/기관 | URL | {today} | tags=태그1,태그2 | summary=한글 2~3문장 요약
- 제목 | 매체/기관 | URL | {today} | tags=... | summary=...

## 🥩 Cultured Meat (5)

- ...
"""


def run_pipeline(output_path: str) -> None:
    normalized_path = os.path.join(BASE_DIR, "data", "normalized", "news.json")

    normalize = [
        "node",
        os.path.join(BASE_DIR, "scripts", "normalize.js"),
        "--in",
        output_path,
        "--out",
        normalized_path,
    ]
    subprocess.run(normalize, cwd=BASE_DIR, check=True)

    backfill = [
        sys.executable,
        os.path.join(BASE_DIR, "tools", "backfill_missing_categories.py"),
        "--file",
        normalized_path,
    ]
    subprocess.run(backfill, cwd=BASE_DIR, check=True)

    enrich = [
        sys.executable,
        os.path.join(BASE_DIR, "tools", "enrich_with_claude.py"),
        "--in",
        normalized_path,
        "--out",
        normalized_path,
        "--max-enrich",
        str(os.getenv("CLAUDE_ENRICH_MAX_ITEMS", "100")),
    ]
    subprocess.run(enrich, cwd=BASE_DIR, check=True)

    sync = [sys.executable, os.path.join(BASE_DIR, "sync_top_news.py")]
    subprocess.run(sync, cwd=BASE_DIR, check=True)


def load_json_safe(path: str):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def parse_iso_to_kst_date(value: str):
    if not value:
        return None
    text = str(value).strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except Exception:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    kst = timezone(timedelta(hours=9))
    return dt.astimezone(kst).date()


def extract_ids(news_data):
    if not isinstance(news_data, dict):
        return set()
    items = news_data.get("items", [])
    if not isinstance(items, list):
        return set()
    ids = set()
    for item in items:
        if isinstance(item, dict) and item.get("id"):
            ids.add(str(item.get("id")))
    return ids


def is_fresh_for_today(news_data, today_str: str, min_fresh_items: int = 5) -> bool:
    if not isinstance(news_data, dict):
        return False

    today = date.fromisoformat(today_str)

    generated_at = parse_iso_to_kst_date(news_data.get("generated_at"))
    if generated_at != today:
        return False

    items = news_data.get("items", [])
    if not isinstance(items, list):
        return False

    fresh_count = 0
    for item in items:
        if not isinstance(item, dict):
            continue
        item_date = parse_iso_to_kst_date(item.get("decision_generated_at"))
        if item_date == today:
            fresh_count += 1

    return fresh_count >= min_fresh_items


def main() -> int:
    today = date.today().strftime("%Y-%m-%d")
    normalized_path = os.path.join(BASE_DIR, "data", "normalized", "news.json")
    before_data = load_json_safe(normalized_path)
    before_ids = extract_ids(before_data)

    force_refresh = os.getenv("PERPLEXITY_FORCE_REFRESH", "").strip().lower() in {"1", "true", "yes", "on"}
    if not force_refresh and is_fresh_for_today(before_data, today):
        print(f"ℹ️ skip: today({today}) data already fresh, Perplexity API call skipped")
        print("added=0")
        return 0

    prompt = PROMPT_TEMPLATE.format(today=today)

    client = Perplexity(api_key=API_KEY)
    completion = client.chat.completions.create(
        model=MODEL,
        messages=[
            {
                "role": "system",
                "content": "너는 최신 뉴스를 웹에서 검색해 한국어로 마크다운 뉴스 브리핑을 만드는 에디터다.",
            },
            {"role": "user", "content": prompt},
        ],
    )

    md_text = (completion.choices[0].message.content or "").strip()
    if not md_text:
        raise RuntimeError("Perplexity 응답이 비어 있습니다.")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(md_text)

    run_pipeline(OUT_PATH)
    after_data = load_json_safe(normalized_path)
    after_ids = extract_ids(after_data)
    added_count = len(after_ids - before_ids)

    print(f"added={added_count}")
    if added_count == 0:
        print("⚠️ warning: Perplexity run finished but no new IDs were added")

    print(f"✅ Saved: {OUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
