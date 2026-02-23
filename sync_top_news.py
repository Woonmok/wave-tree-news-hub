#!/usr/bin/env python3
# sync_top_news.py - Top 2 뉴스를 The Wave Tree Project에 동기화

import json
import os
import re
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
        print(f"⚠️ Telegram 알림 전송 실패: {e}")
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


def resolve_news_json_path():
    env_path = os.getenv("NEWS_JSON_PATH", "").strip()
    if env_path:
        if os.path.exists(env_path):
            return env_path
        print(f"   ⚠️ NEWS_JSON_PATH 파일이 없어 자동 탐색으로 전환: {env_path}")

    candidates = [
        env_path,
        DEFAULT_NEWS_JSON,
        os.path.join(BASE_DIR, "data", "news.json"),
        os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "wave-tree-news-hub", "data", "normalized", "news.json"),
        os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "news.json"),
    ]

    existing = []
    for candidate in candidates:
        if candidate and os.path.exists(candidate):
            existing.append(candidate)

    if not existing:
        return DEFAULT_NEWS_JSON

    best_path = existing[0]
    best_time = datetime.min.replace(tzinfo=timezone.utc)
    best_count = -1

    for path in existing:
        generated_at = None
        item_count = 0
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            generated_at = _parse_generated_at(data)
            item_count = len(data.get("items", [])) if isinstance(data, dict) else 0
        except Exception:
            generated_at = None
            item_count = 0

        if generated_at is None:
            generated_at = datetime.fromtimestamp(os.path.getmtime(path), tz=timezone.utc)

        # 1) 아이템 수 많은 파일 우선, 2) 동률이면 최신 generated_at 우선
        if (item_count > best_count) or (item_count == best_count and generated_at > best_time):
            best_count = item_count
            best_time = generated_at
            best_path = path

    return best_path

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
            published = _parse_published_at(item)
            if published and published.astimezone(timezone.utc).date() == today_date:
                today_items.append(item)

        # 최신순 (published_at 기준, 없으면 빈 문자열)
        sorted_today = sorted(today_items, key=lambda x: (x.get("published_at") or ""), reverse=True)
        sorted_all = sorted(items, key=lambda x: (x.get("published_at") or ""), reverse=True)

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
    try:
        with open(TARGET_HTML, "r", encoding="utf-8") as f:
            content = f.read()
        
        # 먼저 기존 news-item들을 모두 제거하고 빈 상태로 복원
        pattern_clean = r'<div class="section-content" id="intelligence-hub-content">.*?</div>\s*</section>'
        
        replacement_clean = '''<div class="section-content" id="intelligence-hub-content">
                </div>
            </section>'''
        
        content_clean = re.sub(pattern_clean, replacement_clean, content, count=1, flags=re.DOTALL)
        
        # 이제 새로운 뉴스를 주입
        pattern_inject = r'(<div class="section-content" id="intelligence-hub-content">\s*)(\s*</div>)'
        
        replacement_inject = f'\\1{news_html}\\2'
        
        new_content = re.sub(pattern_inject, replacement_inject, content_clean, count=1, flags=re.DOTALL)
        
        with open(TARGET_HTML, "w", encoding="utf-8") as f:
            f.write(new_content)
        
        print("✅ The Wave Tree Project 업데이트 완료!")
        return True
        
    except Exception as e:
        print(f"❌ 업데이트 실패: {e}")
        return False


def update_dashboard_json(top_news):
    """dashboard_data.json의 intelligence 필드를 탑 뉴스 2개로 갱신"""
    DASHBOARD_JSON = os.getenv(
        "DASHBOARD_DATA_PATH",
        os.path.join(WORKSPACE_ROOT, "woonmok.github.io", "dashboard_data.json"),
    )
    try:
        with open(DASHBOARD_JSON, "r", encoding="utf-8") as f:
            dashboard = json.load(f)

        # 기존 intelligence 필드 백업(선택)
        dashboard["intelligence_backup"] = dashboard.get("intelligence", [])

        # 탑 뉴스 2개를 intelligence 필드에 맞게 변환
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

        atomic_write_json(DASHBOARD_JSON, dashboard)
        print("✅ dashboard_data.json intelligence 필드 동기화 완료!")
        return True
    except Exception as e:
        print(f"❌ dashboard_data.json 동기화 실패: {e}")
        return False


def sync_to_html():
    """news_hub.py에서 호출할 함수"""
    print("🔄 Intelligence Hub 동기화 시작...")
    
    # Top 2 뉴스 로드
    top_news = load_top_news()
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
    
    if success and dash_success:
        print("   🎉 Intelligence Hub 동기화 완료!")
    elif success:
        print("   ⚠️ index.html만 동기화, dashboard_data.json 실패")
    elif dash_success:
        print("   ⚠️ dashboard_data.json만 동기화, index.html 실패")
    else:
        print("   ⚠️ 동기화 모두 실패")

    send_sync_notification(top_news, success, dash_success)
    
    return success


def main():
    print("🔄 Top 2 뉴스 동기화 시작...")
    
    # Top 2 뉴스 로드
    top_news = load_top_news()
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
    
    if html_success and dash_success:
        print("🎉 index.html + dashboard_data.json 동기화 완료!")
    elif html_success:
        print("⚠️ index.html만 동기화, dashboard_data.json 실패")
    elif dash_success:
        print("⚠️ dashboard_data.json만 동기화, index.html 실패")
    else:
        print("⚠️ 동기화 모두 실패")

    send_sync_notification(top_news, html_success, dash_success)


if __name__ == "__main__":
    main()
