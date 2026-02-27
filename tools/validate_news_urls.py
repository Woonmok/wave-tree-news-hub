#!/usr/bin/env python3
import argparse
import json
import os
import re
from typing import Any, Dict, List, Tuple

import requests


def is_http_url(url: str) -> bool:
    return bool(re.match(r"^https?://", (url or "").strip(), re.IGNORECASE))


def probe_url(url: str, timeout: int = 8) -> Tuple[bool, str]:
    try:
        h = requests.head(url, timeout=timeout, allow_redirects=True)
        status = int(h.status_code)
        if status in (404, 410):
            return False, f"http_{status}"
        return True, f"http_{status}"
    except Exception:
        try:
            g = requests.get(url, timeout=timeout, allow_redirects=True)
            status = int(g.status_code)
            if status in (404, 410):
                return False, f"http_{status}"
            return True, f"http_{status}"
        except Exception as e:
            return True, f"network_skip:{type(e).__name__}"


def validate_items(items: List[Dict[str, Any]], check_http: bool) -> Tuple[List[Dict[str, Any]], List[str]]:
    kept: List[Dict[str, Any]] = []
    removed_reasons: List[str] = []

    for it in items:
        url = str(it.get("url") or "").strip()
        if not url or not is_http_url(url):
            removed_reasons.append("invalid_url_format")
            continue

        if check_http:
            ok, reason = probe_url(url)
            if not ok:
                removed_reasons.append(reason)
                continue

        kept.append(it)

    return kept, removed_reasons


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate news URLs and remove clearly broken ones")
    parser.add_argument("--file", required=True, help="Path to normalized news.json")
    parser.add_argument("--check-http", action="store_true", help="Enable HTTP status probing (404/410 removal)")
    args = parser.parse_args()

    path = os.path.abspath(args.file)
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", []) if isinstance(data, dict) else []
    if not isinstance(items, list):
        items = []

    before = len(items)
    kept, removed = validate_items(items, check_http=args.check_http)

    data["items"] = kept
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    after = len(kept)
    print(f"url_validate: before={before} after={after} removed={before - after} check_http={args.check_http}")
    if removed:
        counts: Dict[str, int] = {}
        for r in removed:
            counts[r] = counts.get(r, 0) + 1
        print("url_validate_reasons:", counts)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
