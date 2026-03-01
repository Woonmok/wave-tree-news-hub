#!/usr/bin/env python3
import argparse
import json
import os
import re
from urllib.parse import urlparse
from typing import Any, Dict, List, Tuple

import requests


def is_http_url(url: str) -> bool:
    return bool(re.match(r"^https?://", (url or "").strip(), re.IGNORECASE))


def classify_suspicious_url(url: str) -> str:
    try:
        parsed = urlparse(url)
    except Exception:
        return "invalid_url"

    host = (parsed.netloc or "").lower()
    if host.startswith("www."):
        host = host[4:]

    search_hosts = {
        "google.com",
        "bing.com",
        "duckduckgo.com",
        "search.naver.com",
        "search.daum.net",
        "news.google.com",
    }
    if any(host == h or host.endswith(f".{h}") for h in search_hosts):
        return "search_host"

    path = parsed.path or ""
    if path in ("", "/"):
        return "homepage_root"

    return ""


def probe_url(url: str, timeout: int = 8) -> Tuple[bool, str, str]:
    headers = {"User-Agent": "WaveTreeNewsBot/1.0 (+url-validator)"}
    try:
        h = requests.head(url, timeout=timeout, allow_redirects=True, headers=headers)
        status = int(getattr(h, "status_code", 0) or 0)
        final_url = str(getattr(h, "url", "") or url)
        if status in (404, 410):
            return False, f"http_{status}", final_url
        suspicious = classify_suspicious_url(final_url)
        if suspicious:
            return False, suspicious, final_url
        return True, f"http_{status}", final_url
    except Exception:
        try:
            g = requests.get(url, timeout=timeout, allow_redirects=True, headers=headers)
            status = int(getattr(g, "status_code", 0) or 0)
            final_url = str(getattr(g, "url", "") or url)
            if status in (404, 410):
                return False, f"http_{status}", final_url
            suspicious = classify_suspicious_url(final_url)
            if suspicious:
                return False, suspicious, final_url
            return True, f"http_{status}", final_url
        except Exception as e:
            return True, f"network_skip:{type(e).__name__}", url


def validate_items(
    items: List[Dict[str, Any]],
    check_http: bool,
    drop_http_dead: bool,
    drop_suspicious: bool,
) -> Tuple[List[Dict[str, Any]], List[str]]:
    kept: List[Dict[str, Any]] = []
    removed_reasons: List[str] = []

    for it in items:
        url = str(it.get("url") or "").strip()
        if not url or not is_http_url(url):
            removed_reasons.append("invalid_url_format")
            continue

        if check_http:
            ok, reason, final_url = probe_url(url)
            if final_url and is_http_url(final_url):
                it["url"] = final_url

            should_drop_dead = reason.startswith("http_") and drop_http_dead
            should_drop_suspicious = reason in {"search_host", "homepage_root"} and drop_suspicious

            if not ok and (should_drop_dead or should_drop_suspicious):
                removed_reasons.append(reason)
                continue

        kept.append(it)

    return kept, removed_reasons


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate news URLs and remove clearly broken ones")
    parser.add_argument("--file", required=True, help="Path to normalized news.json")
    parser.add_argument("--check-http", action="store_true", help="Enable HTTP status probing (404/410 removal)")
    parser.add_argument("--drop-http-dead", action="store_true", help="When used with --check-http, drop http 404/410 items")
    parser.add_argument("--drop-suspicious", action="store_true", help="When used with --check-http, drop search/homepage links after redirects")
    args = parser.parse_args()

    path = os.path.abspath(args.file)
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", []) if isinstance(data, dict) else []
    if not isinstance(items, list):
        items = []

    before = len(items)
    kept, removed = validate_items(
        items,
        check_http=args.check_http,
        drop_http_dead=args.drop_http_dead,
        drop_suspicious=args.drop_suspicious,
    )

    data["items"] = kept
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    after = len(kept)
    print(
        f"url_validate: before={before} after={after} removed={before - after} "
        f"check_http={args.check_http} drop_http_dead={args.drop_http_dead} drop_suspicious={args.drop_suspicious}"
    )
    if removed:
        counts: Dict[str, int] = {}
        for r in removed:
            counts[r] = counts.get(r, 0) + 1
        print("url_validate_reasons:", counts)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
