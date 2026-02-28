#!/usr/bin/env python3
# sync_top_news.py - Top 2 뉴스를 The Wave Tree Project에 동기화

import json
import os
import re
import subprocess
import tempfile
import urllib.parse
import urllib.request
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORKSPACE_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))

DEFAULT_NEWS_JSON = os.path.join(BASE_DIR, "data", "normalized", "news.json")
TARGET_HTML = os.getenv(
    "TARGET_HTML_PATH",
    os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "index.html"),
)


def get_html_targets():
    targets = [os.path.abspath(TARGET_HTML)]
    repo_root = os.path.dirname(targets[0])
    docs_html = os.path.join(repo_root, "docs", "index.html")
    if os.path.exists(docs_html):
        targets.append(os.path.abspath(docs_html))

    deduped = []
    seen = set()
    for path in targets:
        if path in seen:
            continue
        seen.add(path)
        deduped.append(path)
    return deduped


def get_dashboard_targets():
    primary = os.path.abspath(
        os.getenv(
            "DASHBOARD_DATA_PATH",
            os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "dashboard_data.json"),
        )
    )
    targets = [primary]
    repo_root = os.path.dirname(primary)
    docs_dashboard = os.path.join(repo_root, "docs", "dashboard_data.json")
    if os.path.exists(docs_dashboard):
        targets.append(os.path.abspath(docs_dashboard))

    deduped = []
    seen = set()
    for path in targets:
        if path in seen:
            continue
        seen.add(path)
        deduped.append(path)
    return deduped


def get_news_json_targets():
    primary = os.path.abspath(
        os.getenv(
            "DEPLOY_NEWS_JSON_PATH",
            os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "news.json"),
        )
    )
    targets = [primary]
    repo_root = os.path.dirname(primary)
    docs_news = os.path.join(repo_root, "docs", "news.json")
    if os.path.exists(docs_news):
        targets.append(os.path.abspath(docs_news))

    deduped = []
    seen = set()
    for path in targets:
        if path in seen:
            continue
        seen.add(path)
        deduped.append(path)
    return deduped


def atomic_write_json(file_path, payload):
    target_path = os.path.abspath(file_path)
    target_dir = os.path.dirname(target_path) or "."
    os.makedirs(target_dir, exist_ok=True)

    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=target_dir,
            prefix=f".{os.path.basename(target_path)}.",
            suffix=".tmp",
            delete=False,
        ) as f:
            tmp_path = f.name
            json.dump(payload, f, ensure_ascii=False, indent=2)
            f.flush()
            os.fsync(f.fileno())

        os.replace(tmp_path, target_path)

        try:
            dir_fd = os.open(target_dir, os.O_RDONLY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError:
            pass
    except Exception:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
        raise


def _read_env_file(path):
    values = {}
    if not path or not os.path.exists(path):
        return values
    try:
        with open(path, "r", encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                if key:
                    values[key] = val
    except Exception:
        return {}
    return values


def _get_telegram_credentials():
    token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
    chat_id = os.getenv("TELEGRAM_CHAT_ID", "").strip()
    if token and chat_id:
        return token, chat_id

    env_candidates = [
        os.path.join(BASE_DIR, ".env"),
        os.path.join(WORKSPACE_ROOT, "woonmok.github.io", ".env"),
    ]
    merged = {}
    for p in env_candidates:
        merged.update(_read_env_file(p))

    token = token or str(merged.get("TELEGRAM_BOT_TOKEN", "")).strip()
    chat_id = chat_id or str(merged.get("TELEGRAM_CHAT_ID", "")).strip()
    return token, chat_id


def send_sync_notification(top_news, html_success, dash_success):
    token, chat_id = _get_telegram_credentials()
    if not token or not chat_id:
        print("ℹ️ Telegram 알림 건너뜀: TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID 없음")
        return False

    status = "성공" if (html_success and dash_success) else "부분 성공"
    lines = [
        f"✅ Intelligence Hub Top2 동기화 {status}",
        f"- 시각: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"- index.html: {'OK' if html_success else 'FAIL'}",
        f"- dashboard_data.json: {'OK' if dash_success else 'FAIL'}",
    ]

    if top_news:
        lines.append("- 오늘 Top2")
        for idx, item in enumerate(top_news[:2], 1):
            category = item.get("category", "-")
            title = str(item.get("title", "")).strip()
            if len(title) > 80:
                title = title[:80] + "..."
            lines.append(f"  {idx}) [{category}] {title}")

    msg = "\n".join(lines)
    payload = urllib.parse.urlencode({"chat_id": chat_id, "text": msg}).encode("utf-8")
    url = f"https://api.telegram.org/bot{token}/sendMessage"

    try:
        req = urllib.request.Request(url, data=payload, method="POST")
        with urllib.request.urlopen(req, timeout=10) as resp:
            if 200 <= resp.status < 300:
                print("✅ Telegram Top2 동기화 알림 전송 완료")
                return True
    except Exception as e:
        err_text = str(e)
        if "CERTIFICATE_VERIFY_FAILED" in err_text:
            if _send_telegram_via_curl(token, chat_id, msg):
                print("✅ Telegram Top2 동기화 알림 전송 완료(curl fallback)")
                return True
        print(f"⚠️ Telegram 알림 전송 실패: {e}")
    return False


def _send_telegram_via_curl(token, chat_id, message):
    cmd = [
        "curl",
        "-fsS",
        "-X",
        "POST",
        f"https://api.telegram.org/bot{token}/sendMessage",
        "-d",
        f"chat_id={chat_id}",
        "--data-urlencode",
        f"text={message}",
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=12)
        return proc.returncode == 0
    except Exception:
        return False


def _parse_generated_at(data):
    raw = data.get("generated_at")
    if not raw:
        return None
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except Exception:
        return None


def _parse_published_at(item):
    raw = item.get("published_at")
    if not raw:
        return None
    try:
        parsed = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except Exception:
        return None


def _parse_decision_generated_at(item):
    raw = item.get("decision_generated_at")
    if not raw:
        return None
    try:
        parsed = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except Exception:
        return None


def _sort_key_for_top(item):
    decision_dt = _parse_decision_generated_at(item)
    published_dt = _parse_published_at(item)

    decision_key = (
        decision_dt.astimezone(timezone.utc).isoformat() if decision_dt else ""
    )
    published_key = (
        published_dt.astimezone(timezone.utc).isoformat() if published_dt else ""
    )

    # 우선순위: decision_generated_at(최신 의사결정) > published_at(기사 발행일)
    return (decision_key, published_key)


def resolve_news_json_path():
    env_path = os.getenv("NEWS_JSON_PATH", "").strip()
    if env_path:
        if os.path.exists(env_path):
            return env_path
        print(f"   ⚠️ NEWS_JSON_PATH 파일이 없어 자동 탐색으로 전환: {env_path}")

    candidates = [
        DEFAULT_NEWS_JSON,
        os.path.join(BASE_DIR, "data", "news.json"),
        os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "wave-tree-news-hub", "data", "normalized", "news.json"),
        os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "news.json"),
    ]

    # 우선순위 경로에서 첫 번째로 존재하는 파일을 사용 (결정론적 선택)
    for candidate in candidates:
        if candidate and os.path.exists(candidate):
            return candidate

    return DEFAULT_NEWS_JSON

def load_top_news():
    """news.json에서 오늘자 우선 Top 2 뉴스 로드 (없으면 최신순 fallback)"""
    try:
        news_json_path = resolve_news_json_path()
        print(f"   📥 뉴스 소스: {news_json_path}")
        with open(news_json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        items = data.get("items", [])

        generated_at = _parse_generated_at(data)
        if generated_at:
            today_date = generated_at.astimezone(timezone.utc).date()
        else:
            today_date = datetime.now(timezone.utc).date()

        today_items = []
        for item in items:
            decision_generated = _parse_decision_generated_at(item)
            published = _parse_published_at(item)
            decision_is_today = (
                decision_generated
                and decision_generated.astimezone(timezone.utc).date() == today_date
            )
            published_is_today = (
                published and published.astimezone(timezone.utc).date() == today_date
            )

            if decision_is_today or published_is_today:
                today_items.append(item)

        # 최신순 (decision_generated_at 우선, 없으면 published_at)
        sorted_today = sorted(today_items, key=_sort_key_for_top, reverse=True)
        sorted_all = sorted(items, key=_sort_key_for_top, reverse=True)

        def pick_top2_with_diversity(candidates, fallback):
            if not candidates:
                candidates = fallback
            if not candidates:
                return []

            first = candidates[0]
            first_category = first.get("category")
            second = None

            # 두 번째 뉴스는 가능하면 다른 카테고리로 선택
            for item in candidates[1:]:
                if item.get("category") and item.get("category") != first_category:
                    second = item
                    break

            # 오늘 뉴스에서 못 찾으면 전체 뉴스에서 다른 카테고리 탐색
            if second is None:
                for item in fallback:
                    if item.get("id") == first.get("id"):
                        continue
                    if item.get("category") and item.get("category") != first_category:
                        second = item
                        break

            # 그래도 없으면 단순 최신 2건
            if second is None:
                for item in candidates[1:]:
                    if item.get("id") != first.get("id"):
                        second = item
                        break
            if second is None:
                for item in fallback:
                    if item.get("id") != first.get("id"):
                        second = item
                        break

            return [first, second] if second else [first]

        # 오늘자 우선, 단 카테고리 다양성 우선 적용
        candidate_pool = sorted_today if len(sorted_today) >= 2 else sorted_all
        return pick_top2_with_diversity(candidate_pool, sorted_all)[:2]
    except Exception as e:
        print(f"Error loading news: {e}")
        return []


def generate_news_html(top_news):
    """Top 2 뉴스 HTML 생성 (새 구조)"""
    if not top_news or len(top_news) == 0:
        return ""
    
    category_icons = {
        "listeria_free": "🦠",
        "cultured_meat": "🥩",
        "high_end_audio": "🎵",
        "computer_ai": "🤖",
        "global_biz": "🌍"
    }
    
    html_parts = []
    
    for news in top_news:
        title = news.get("title", "제목 없음")
        category = news.get("category", "")
        icon = category_icons.get(category, "📰")
        score = news.get("score")
        summary = news.get("summary", "")
        url = news.get("url", "")
        
        score_display = f"Score: {score:.2f}" if score else "Score: -"
        
        # 제목 길이 제한
        if len(title) > 75:
            title = title[:75] + "..."
        
        summary_display = summary[:120] + "..." if len(summary) > 120 else summary
        
        html_item = f'''<div class="news-item">
                        <div class="news-title">{icon} {title}</div>
                        <div class="news-summary">{summary_display}</div>
                        <div class="news-meta">
                            <span>{category}</span>
                            <span>{score_display}</span>
                        </div>
                        {f'<a href="{url}" target="_blank" style="color: #00ccff; font-size: 0.75em;">원문</a>' if url else ''}
                    </div>'''
        
        html_parts.append(html_item)
    
    return '\n                    '.join(html_parts)


def update_html(news_html):
    """index.html 업데이트 - Intelligence Hub 섹션에 주입"""
    ok = True
    for target_html in get_html_targets():
        try:
            with open(target_html, "r", encoding="utf-8") as f:
                content = f.read()

            pattern_clean = r'<div class="section-content" id="intelligence-hub-content">.*?</div>\s*</section>'
            replacement_clean = '''<div class="section-content" id="intelligence-hub-content">
                </div>
            </section>'''
            content_clean = re.sub(pattern_clean, replacement_clean, content, count=1, flags=re.DOTALL)

            pattern_inject = r'(<div class="section-content" id="intelligence-hub-content">\s*)(\s*</div>)'
            replacement_inject = f'\\1{news_html}\\2'
            new_content = re.sub(pattern_inject, replacement_inject, content_clean, count=1, flags=re.DOTALL)

            with open(target_html, "w", encoding="utf-8") as f:
                f.write(new_content)

            print(f"✅ The Wave Tree Project 업데이트 완료: {target_html}")
        except Exception as e:
            ok = False
            print(f"❌ 업데이트 실패({target_html}): {e}")
    return ok


def update_dashboard_json(top_news):
    """dashboard_data.json의 intelligence 필드를 탑 뉴스 2개로 갱신"""
    ok = True
    for dashboard_path in get_dashboard_targets():
        try:
            with open(dashboard_path, "r", encoding="utf-8") as f:
                dashboard = json.load(f)

            dashboard["intelligence_backup"] = dashboard.get("intelligence", [])
            dashboard["intelligence"] = [
                {
                    "title": n.get("title", ""),
                    "summary": n.get("summary", ""),
                    "tag": n.get("category", ""),
                    "score": str(n.get("score", "")),
                    "url": n.get("url", "")
                }
                for n in top_news
            ]
            dashboard["last_updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

            atomic_write_json(dashboard_path, dashboard)
            print(f"✅ dashboard_data.json intelligence 필드 동기화 완료: {dashboard_path}")
        except Exception as e:
            ok = False
            print(f"❌ dashboard_data.json 동기화 실패({dashboard_path}): {e}")
    return ok


def mirror_news_json_source(news_json_path):
    """선택된 뉴스 소스를 deploy root/docs news.json으로 동기화"""
    ok = True
    try:
        with open(news_json_path, "r", encoding="utf-8") as f:
            payload = json.load(f)
    except Exception as e:
        print(f"❌ news.json 소스 로드 실패({news_json_path}): {e}")
        return False

    for target in get_news_json_targets():
        try:
            atomic_write_json(target, payload)
            print(f"✅ news.json 동기화 완료: {target}")
        except Exception as e:
            ok = False
            print(f"❌ news.json 동기화 실패({target}): {e}")

    return ok


def sync_to_html():
    """news_hub.py에서 호출할 함수"""
    print("🔄 Intelligence Hub 동기화 시작...")
    
    # Top 2 뉴스 로드
    top_news = load_top_news()
    news_json_path = resolve_news_json_path()
    print(f"   📰 로드된 뉴스: {len(top_news)}개")

    if len(top_news) == 0:
        print("   ⚠️ 동기화 건너뜀: 뉴스 0건(기존 대시보드 유지)")
        send_sync_notification(top_news, False, False)
        return False
    
    # HTML 생성
    news_html = generate_news_html(top_news)
    
    # HTML 업데이트
    success = update_html(news_html)
    
    # dashboard_data.json intelligence 필드 동기화
    dash_success = update_dashboard_json(top_news)
    news_success = mirror_news_json_source(news_json_path)
    
    if success and dash_success and news_success:
        print("   🎉 Intelligence Hub 동기화 완료!")
    elif success:
        print("   ⚠️ index.html 동기화 완료, 일부 데이터 동기화 실패")
    elif dash_success:
        print("   ⚠️ dashboard_data.json 동기화 완료, 일부 동기화 실패")
    else:
        print("   ⚠️ 동기화 모두 실패")

    send_sync_notification(top_news, success, dash_success)
    
    return success


def main():
    print("🔄 Top 2 뉴스 동기화 시작...")
    
    # Top 2 뉴스 로드
    top_news = load_top_news()
    news_json_path = resolve_news_json_path()
    print(f"📰 로드된 뉴스: {len(top_news)}개")

    if len(top_news) == 0:
        print("⚠️ 동기화 건너뜀: 뉴스 0건(기존 대시보드 유지)")
        send_sync_notification(top_news, False, False)
        return
    
    # HTML 생성
    news_html = generate_news_html(top_news)
    
    # HTML 업데이트
    html_success = update_html(news_html)
    
    # dashboard_data.json intelligence 필드 동기화
    dash_success = update_dashboard_json(top_news)
    news_success = mirror_news_json_source(news_json_path)
    
    if html_success and dash_success and news_success:
        print("🎉 index.html + dashboard_data.json + news.json 동기화 완료!")
    elif html_success:
        print("⚠️ index.html 동기화 완료, 일부 데이터 동기화 실패")
    elif dash_success:
        print("⚠️ dashboard_data.json 동기화 완료, 일부 동기화 실패")
    else:
        print("⚠️ 동기화 모두 실패")

    send_sync_notification(top_news, html_success, dash_success)


if __name__ == "__main__":
    main()
