#!/usr/bin/env python3
import argparse
import json
import os
from datetime import datetime, timezone

import requests
from dotenv import load_dotenv


BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ENV_PATH = os.path.join(BASE_DIR, ".env")
load_dotenv(ENV_PATH)

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "").strip()
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-20250514").strip()

CATEGORY_SLOT = {
    "listeria_free": 4,
    "cultured_meat": 5,
    "high_end_audio": 5,
    "computer_ai": 5,
    "global_biz": 4,
}

CATEGORY_CONTEXT = {
    "listeria_free": (
        "Farmerstree는 무균 버섯 기술 기반 식품 사업을 운영 중이다. "
        "리스테리아 발병/리콜/규제 강화가 수출 단가, 통관, 브랜드 신뢰에 미치는 영향을 우선 평가한다."
    ),
    "cultured_meat": (
        "Wave Tree는 균사체 기반 대체육 및 바이오미디어 확장을 추진한다. "
        "규제, 투자, 상용화 일정, 경쟁사 협업/자금조달 이슈를 중심으로 평가한다."
    ),
    "high_end_audio": (
        "THE EIGHT GATES 및 DARS 관련 사업에 영향을 줄 오디오 기술/시장 동향을 평가한다. "
        "제품 로드맵, 특허/IP, 수익화 가능성에 초점을 둔다."
    ),
    "computer_ai": (
        "Wavtree의 AI 인프라 사업 관점에서 GPU 공급, 모델 경쟁, 클라우드 단가를 평가한다. "
        "서버 투자 회수, 가격 정책, 경쟁력에 미치는 영향을 우선 본다."
    ),
    "global_biz": (
        "포트폴리오 전반에 영향을 주는 거시 이슈를 평가한다. "
        "무역/환율/금리/보조금/정책 변화의 교차영향을 우선 본다."
    ),
}


def _score_val(item):
    decision = item.get("decision") if isinstance(item.get("decision"), dict) else {}
    score = decision.get("impact_score", 0)
    try:
        return float(score)
    except Exception:
        return 0.0


def _conf_val(item):
    decision = item.get("decision") if isinstance(item.get("decision"), dict) else {}
    conf = decision.get("confidence", 0)
    try:
        return float(conf)
    except Exception:
        return 0.0


def _published_val(item):
    return str(item.get("published_at") or "")


def call_claude(item, context):
    if not ANTHROPIC_API_KEY:
        return None

    prompt = f"""당신은 한국 창업자의 사업 의사결정 분석가다.

[사업 컨텍스트]
{context}

[뉴스]
제목: {item.get('title', '')}
요약: {item.get('summary', '')}
출처: {item.get('source', '')}
링크: {item.get('url', '')}

아래 JSON만 출력하라. 다른 설명 금지.
{{
  "impact_score": 0~10 숫자(소수1자리),
  "impact_reason": "한국어 1~2문장",
  "confidence": 0~1 숫자(소수2자리),
  "confidence_basis": "한국어 1문장",
  "next_action": "대표가 할 다음 행동 1문장",
  "time_sensitivity": "IMMEDIATE|SHORT|MEDIUM|LOW",
  "opportunity": "기회 요인 1문장",
  "risk": "리스크 요인 1문장"
}}"""

    headers = {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }
    payload = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 500,
        "messages": [{"role": "user", "content": prompt}],
    }

    try:
        resp = requests.post("https://api.anthropic.com/v1/messages", headers=headers, json=payload, timeout=30)
        resp.raise_for_status()
        text = resp.json().get("content", [{}])[0].get("text", "")
        start = text.find("{")
        end = text.rfind("}")
        if start == -1 or end == -1 or end <= start:
            return None
        parsed = json.loads(text[start : end + 1])
        return {
            "impact_score": float(parsed.get("impact_score", 0)),
            "impact_reason": str(parsed.get("impact_reason", "")).strip(),
            "confidence": float(parsed.get("confidence", 0)),
            "confidence_basis": str(parsed.get("confidence_basis", "")).strip(),
            "next_action": str(parsed.get("next_action", "")).strip(),
            "time_sensitivity": str(parsed.get("time_sensitivity", "LOW")).strip().upper(),
            "opportunity": str(parsed.get("opportunity", "")).strip(),
            "risk": str(parsed.get("risk", "")).strip(),
        }
    except Exception:
        return None


def enrich_items(items, max_enrich):
    enriched_count = 0
    for item in items:
        if max_enrich > 0 and enriched_count >= max_enrich:
            break
        if not isinstance(item, dict):
            continue
        if not item.get("url"):
            item["mode"] = item.get("mode", "info")
            item["status"] = item.get("status", "COLLECTING")
            continue

        has_decision = isinstance(item.get("decision"), dict) and bool(item.get("decision", {}).get("next_action"))
        if has_decision:
            continue

        context = CATEGORY_CONTEXT.get(item.get("category", ""), "사업 영향 중심으로 판단")
        decision = call_claude(item, context)
        if decision:
            item["decision"] = decision
            item["mode"] = "decision"
            item["status"] = "PENDING_ACTION"
            item["decision_generated_at"] = datetime.now(timezone.utc).isoformat()
            enriched_count += 1
        else:
            item["mode"] = item.get("mode", "info")
            item["status"] = item.get("status", "COLLECTING")

    return enriched_count


def reorder_and_trim(items):
    grouped = {k: [] for k in CATEGORY_SLOT.keys()}
    for item in items:
        cat = item.get("category")
        if cat in grouped:
            grouped[cat].append(item)

    out = []
    for cat, bucket in grouped.items():
        decision_items = [x for x in bucket if x.get("mode") == "decision"]
        info_items = [x for x in bucket if x.get("mode") != "decision"]

        decision_items.sort(key=lambda x: (_score_val(x), _conf_val(x), _published_val(x)), reverse=True)
        info_items.sort(key=lambda x: _published_val(x), reverse=True)

        limit = CATEGORY_SLOT[cat] * 2
        out.extend((decision_items + info_items)[:limit])
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="in_path", required=True)
    parser.add_argument("--out", dest="out_path", required=True)
    parser.add_argument("--max-enrich", dest="max_enrich", type=int, default=20)
    args = parser.parse_args()

    with open(args.in_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", []) if isinstance(data, dict) else []
    if not isinstance(items, list):
        items = []

    enriched = enrich_items(items, args.max_enrich)
    result_items = reorder_and_trim(items)

    out = {
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "items": result_items,
    }
    with open(args.out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"✅ Claude enrichment: {enriched} items")
    print(f"✅ news.json updated: {len(result_items)} items")


if __name__ == "__main__":
    main()
