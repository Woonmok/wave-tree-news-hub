#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
from datetime import datetime, timezone
from urllib.parse import urlparse

from perplexity import Perplexity
import requests

try:
    from dotenv import load_dotenv
except ImportError:
    def load_dotenv(*args, **kwargs):
        return False

TARGET_COUNTS = {
    "listeria_free": 4,
    "cultured_meat": 5,
    "high_end_audio": 5,
    "computer_ai": 5,
    "global_biz": 4,
}

MAX_AGE_DAYS = {
    "listeria_free": 21,
    "cultured_meat": 14,
    "high_end_audio": 14,
    "computer_ai": 10,
    "global_biz": 10,
}

SEARCH_HOSTS = {
    "google.com",
    "bing.com",
    "duckduckgo.com",
    "search.naver.com",
    "search.daum.net",
    "news.google.com",
}

PROMPTS = {
    "listeria_free": """최신순 우선으로 최근 21일 이내 리스테리아/식품안전 뉴스만 수집해. 가능하면 오늘/어제 기사를 우선.
주제: 리콜, FDA/CDC 경보, 발병 보고, 오염 조사.
반드시 실제 기사 원문 URL(https://...)만 사용.
JSON 배열만 출력:
[{"title":"", "source":"", "url":"https://...", "published_at":"YYYY-MM-DD", "tags":["",""], "summary":"한국어 1~2문장"}]""",
    "cultured_meat": """최신순 우선으로 최근 14일 이내 배양육/대체단백질 뉴스만 수집해. 가능하면 오늘/어제 기사를 우선.
주제: 투자, 규제, 상용화, 생산기술, 기업 동향.
반드시 실제 기사 원문 URL(https://...)만 사용.
JSON 배열만 출력:
[{"title":"", "source":"", "url":"https://...", "published_at":"YYYY-MM-DD", "tags":["",""], "summary":"한국어 1~2문장"}]""",
    "high_end_audio": """최신순 우선으로 최근 14일 이내 High-End Audio 뉴스만 수집해. 가능하면 오늘/어제 기사를 우선.
주제: DAC, 하이엔드 앰프, 하이파이 스트리밍, 오디오 쇼/전시회, 플래그십 신제품.
반드시 실제 기사 원문 URL(https://...)만 사용.
JSON 배열만 출력:
[{"title":"", "source":"", "url":"https://...", "published_at":"YYYY-MM-DD", "tags":["",""], "summary":"한국어 1~2문장"}]""",
    "computer_ai": """최신순 우선으로 최근 10일 이내 Computer & AI 뉴스만 수집해. 가능하면 오늘/어제 기사를 우선.
주제: GPU, AI 인프라, 데이터센터, 모델 릴리즈, 클라우드 단가/정책.
반드시 실제 기사 원문 URL(https://...)만 사용.
JSON 배열만 출력:
[{"title":"", "source":"", "url":"https://...", "published_at":"YYYY-MM-DD", "tags":["",""], "summary":"한국어 1~2문장"}]""",
    "global_biz": """최신순 우선으로 최근 10일 이내 글로벌 비즈니스/정책/무역/거시경제 뉴스만 수집해. 가능하면 오늘/어제 기사를 우선.
주제: 환율, 무역규제, 금리, 공급망, 글로벌 정책 변화.
반드시 실제 기사 원문 URL(https://...)만 사용.
JSON 배열만 출력:
[{"title":"", "source":"", "url":"https://...", "published_at":"YYYY-MM-DD", "tags":["",""], "summary":"한국어 1~2문장"}]""",
}


def make_id(category: str, title: str, url: str, source: str) -> str:
    s = f"{category}|{title}|{url}|{source}"
    return hashlib.sha1(s.encode("utf-8")).hexdigest()


def extract_json_array(text: str):
    m = re.search(r"\[.*\]", text, re.S)
    if m:
        return json.loads(m.group(0))
    m = re.search(r"\{.*\}", text, re.S)
    if m:
        obj = json.loads(m.group(0))
        if isinstance(obj, dict) and isinstance(obj.get("items"), list):
            return obj["items"]
    raise ValueError("No valid JSON array found in model response")


def extract_items_from_markdown(text: str):
    rows = []
    for line in text.splitlines():
        t = line.strip()
        if not t.startswith("-"):
            continue
        parts = [x.strip() for x in re.split(r"\s*\|\s*", t.lstrip("- "))]
        if len(parts) < 4:
            continue
        title, source, url, published = parts[0], parts[1], parts[2], parts[3]
        if not re.match(r"^https?://", url):
            continue
        tags = []
        summary = ""
        for tail in parts[4:]:
            if tail.startswith("tags="):
                tags = [x.strip() for x in tail.replace("tags=", "", 1).split(",") if x.strip()]
            if tail.startswith("summary="):
                summary = tail.replace("summary=", "", 1).strip()
        rows.append(
            {
                "title": title,
                "source": source,
                "url": url,
                "published_at": published,
                "tags": tags,
                "summary": summary,
            }
        )
    return rows


def normalize_published_at(raw: str) -> str:
    raw = (raw or "").strip()
    if re.match(r"^\d{4}-\d{2}-\d{2}$", raw):
        return raw + "T00:00:00.000Z"
    if raw:
        return raw
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_published_at(raw: str):
    value = (raw or "").strip()
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        if re.match(r"^\d{4}-\d{2}-\d{2}$", value):
            try:
                return datetime.fromisoformat(value + "T00:00:00+00:00").astimezone(timezone.utc)
            except Exception:
                return None
    return None


def normalize_title_key(title: str) -> str:
    return re.sub(r"\s+", " ", (title or "").strip().lower())


def is_suspicious_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except Exception:
        return True

    if parsed.scheme not in {"http", "https"}:
        return True
    host = (parsed.netloc or "").lower()
    if not host:
        return True
    if host.startswith("www."):
        host = host[4:]

    if any(host == h or host.endswith(f".{h}") for h in SEARCH_HOSTS):
        return True
    if (parsed.path or "") in {"", "/"}:
        return True
    return False


def probe_http_alive(url: str, timeout: int = 8) -> bool:
    headers = {"User-Agent": "WaveTreeNewsBot/1.0 (+backfill)"}
    try:
        resp = requests.head(url, timeout=timeout, allow_redirects=True, headers=headers)
        status = int(getattr(resp, "status_code", 0) or 0)
        return 200 <= status < 400
    except Exception:
        try:
            resp = requests.get(url, timeout=timeout, allow_redirects=True, headers=headers)
            status = int(getattr(resp, "status_code", 0) or 0)
            return 200 <= status < 400
        except Exception:
            return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True, help="Target normalized news.json")
    args = parser.parse_args()

    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    load_dotenv(os.path.join(base_dir, ".env"))

    api_key = os.getenv("PERPLEXITY_API_KEY", "").strip()
    model = os.getenv("PERPLEXITY_MODEL", "sonar-pro").strip() or "sonar-pro"
    if not api_key:
        raise RuntimeError("PERPLEXITY_API_KEY not set")

    with open(args.file, "r", encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", []) if isinstance(data, dict) else []
    if not isinstance(items, list):
        items = []

    # 1) 카테고리 내부 URL 중복 제거: 같은 섹션에서 같은 링크 반복 방지
    cleaned = []
    seen_by_category = {k: set() for k in TARGET_COUNTS}
    for item in items:
        if not isinstance(item, dict):
            continue
        category = item.get("category")
        url = str(item.get("url") or "").strip()
        if category not in TARGET_COUNTS:
            continue
        if not re.match(r"^https?://", url):
            continue
        if url in seen_by_category[category]:
            continue
        seen_by_category[category].add(url)
        cleaned.append(item)
    items = cleaned

    by_cat = {cat: [] for cat in TARGET_COUNTS}
    for item in items:
        cat = item.get("category")
        if cat in by_cat:
            by_cat[cat].append(item)

    existing_ids = {it.get("id") for it in items if isinstance(it, dict)}
    existing_urls = {it.get("url") for it in items if isinstance(it, dict) and it.get("url")}
    existing_title_keys = {
        normalize_title_key(str(it.get("title") or ""))
        for it in items
        if isinstance(it, dict) and it.get("title")
    }

    client = Perplexity(api_key=api_key)

    added = 0
    for cat in ("listeria_free", "cultured_meat", "high_end_audio", "computer_ai", "global_biz"):
        need = TARGET_COUNTS[cat]
        have = len(by_cat.get(cat, []))
        if have >= need:
            continue

        # 최대 4회 재시도하면서 누락 슬롯 채우기
        for attempt in range(1, 7):
            if len(by_cat[cat]) >= need:
                break

            excluded_urls = [u for u in existing_urls if isinstance(u, str)]
            excluded_urls = [u for u in excluded_urls if isinstance(u, str)][:20]
            user_prompt = PROMPTS[cat] + "\n" + (
                "이미 수집된 URL(재사용 금지):\n" + "\n".join(f"- {u}" for u in excluded_urls)
                if excluded_urls
                else ""
            )

            resp = client.chat.completions.create(
                model=model,
                messages=[
                    {
                        "role": "system",
                        "content": "너는 사실 기반 뉴스 큐레이터다. URL은 실제 기사 원문만 사용하고, 중복 URL/홈페이지/검색결과 링크를 절대 내지 마라.",
                    },
                    {"role": "user", "content": user_prompt},
                ],
            )
            text = (resp.choices[0].message.content or "").strip()

            try:
                arr = extract_json_array(text)
            except Exception:
                arr = extract_items_from_markdown(text)

            for x in arr:
                if len(by_cat[cat]) >= need:
                    break

                title = str(x.get("title", "")).strip()
                source = str(x.get("source", "")).strip() or "Web"
                url = str(x.get("url", "")).strip()
                if not title or not re.match(r"^https?://", url):
                    continue
                if is_suspicious_url(url):
                    continue
                if not probe_http_alive(url):
                    continue
                if url in existing_urls:
                    continue
                title_key = normalize_title_key(title)
                if title_key in existing_title_keys:
                    continue

                published_raw = str(x.get("published_at", "")).strip()
                published_dt = parse_published_at(published_raw)
                if published_dt is None:
                    published_dt = datetime.now(timezone.utc)

                max_age_days = MAX_AGE_DAYS.get(cat, 14)
                age_days = (datetime.now(timezone.utc) - published_dt).days
                if age_days > max_age_days:
                    continue

                item = {
                    "id": make_id(cat, title, url, source),
                    "category": cat,
                    "title": title,
                    "source": source,
                    "url": url,
                    "published_at": normalize_published_at(published_raw),
                    "summary": str(x.get("summary", "")).strip(),
                    "highlights": [],
                    "tags": [str(t) for t in (x.get("tags") or [])][:5] if isinstance(x.get("tags"), list) else [],
                    "score": None,
                }
                if item["id"] in existing_ids:
                    continue

                items.append(item)
                by_cat[cat].append(item)
                existing_ids.add(item["id"])
                existing_urls.add(url)
                existing_title_keys.add(title_key)
                added += 1

    # Rebuild ordered output with fixed per-category caps
    ordered = []
    for cat in ("listeria_free", "cultured_meat", "high_end_audio", "computer_ai", "global_biz"):
        cat_items = [it for it in items if isinstance(it, dict) and it.get("category") == cat]
        cat_items.sort(key=lambda z: str(z.get("published_at") or ""), reverse=True)
        ordered.extend(cat_items[: TARGET_COUNTS[cat]])

    out = {
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "items": ordered,
    }

    with open(args.file, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    counts = {cat: len([it for it in ordered if it.get("category") == cat]) for cat in TARGET_COUNTS}
    print(f"added={added}")
    print(counts)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
