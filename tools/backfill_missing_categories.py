#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
from datetime import datetime, timezone

from dotenv import load_dotenv
from perplexity import Perplexity

TARGET_COUNTS = {
    "listeria_free": 4,
    "cultured_meat": 5,
    "high_end_audio": 5,
    "computer_ai": 5,
    "global_biz": 4,
}

PROMPTS = {
    "high_end_audio": """최근 45일 이내 High-End Audio 뉴스만 수집해. 주제: DAC, 하이엔드 앰프, 하이파이 스트리밍, 오디오 쇼/전시회, 플래그십 신제품.
반드시 실제 기사 원문 URL(https://...)만 사용.
JSON 배열만 출력:
[{"title":"", "source":"", "url":"https://...", "published_at":"YYYY-MM-DD", "tags":["",""], "summary":"한국어 1~2문장"}]""",
    "computer_ai": """최근 45일 이내 Computer & AI 뉴스만 수집해. 주제: GPU, AI 인프라, 데이터센터, 모델 릴리즈, 클라우드 단가/정책.
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

    by_cat = {cat: [] for cat in TARGET_COUNTS}
    for item in items:
        cat = item.get("category")
        if cat in by_cat:
            by_cat[cat].append(item)

    existing_ids = {it.get("id") for it in items if isinstance(it, dict)}
    existing_urls = {it.get("url") for it in items if isinstance(it, dict) and it.get("url")}

    client = Perplexity(api_key=api_key)

    added = 0
    for cat in ("high_end_audio", "computer_ai"):
        need = TARGET_COUNTS[cat]
        have = len(by_cat.get(cat, []))
        if have >= need:
            continue

        # 최대 4회 재시도하면서 누락 슬롯 채우기
        for attempt in range(1, 5):
            if len(by_cat[cat]) >= need:
                break

            excluded_urls = [it.get("url") for it in by_cat[cat] if it.get("url")]
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
                        "content": "너는 사실 기반 뉴스 큐레이터다. URL은 실제 기사 원문만 사용하고, 중복 URL을 절대 내지 마라.",
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
                if url in existing_urls:
                    continue

                item = {
                    "id": make_id(cat, title, url, source),
                    "category": cat,
                    "title": title,
                    "source": source,
                    "url": url,
                    "published_at": normalize_published_at(str(x.get("published_at", ""))),
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
