#!/usr/bin/env python3
# sync_top_news.py - Top 3 뉴스를 The Wave Tree Project에 동기화

import json
import re
from datetime import datetime

NEWS_JSON = "/Users/seunghoonoh/Desktop/wave-tree-news-hub/data/normalized/news.json"
TARGET_HTML = "/Users/seunghoonoh/woonmok.github.io/index.html"

def load_top_news():
    """news.json에서 상위 2개 뉴스 로드 (score 기준)"""
    try:
        with open(NEWS_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        items = data.get("items", [])
        
        # score가 있는 것 우선, 없으면 최신순
        sorted_items = sorted(
            items, 
            key=lambda x: (x.get("score") or 0, x.get("published_at") or ""), 
            reverse=True
        )
        
        return sorted_items[:2]
    except Exception as e:
        print(f"Error loading news: {e}")
        return []


def generate_news_html(top_news):
    """Top 2 뉴스 HTML 생성"""
    if not top_news or len(top_news) == 0:
        return """
        <section class="proposal-section glass" style="border-color: #ff3366; margin-bottom: 30px;">
            <h2 style="color: #ff3366;">🔥 Intelligence Hub</h2>
            <p style="opacity: 0.7;">뉴스를 불러오는 중...</p>
        </section>
"""
    
    html_parts = [
        '<section class="proposal-section glass" style="border-color: #ff3366; margin-top: 0; margin-bottom: 30px;">',
        '    <h2 style="color: #ff3366;">🔥 Intelligence Hub</h2>',
        '    <div style="display: flex; flex-direction: column; gap: 15px;">'
    ]
    
    category_icons = {
        "listeria_free": "🦠",
        "cultured_meat": "🥩",
        "high_end_audio": "🎵",
        "computer_ai": "🤖",
        "global_biz": "🌍"
    }
    
    for idx, news in enumerate(top_news, 1):
        title = news.get("title", "제목 없음")
        category = news.get("category", "")
        icon = category_icons.get(category, "📰")
        score = news.get("score")
        summary = news.get("summary", "")
        url = news.get("url", "")
        
        score_text = f"Score: {score:.2f}" if score else ""
        
        # 제목 길이 제한
        if len(title) > 80:
            title = title[:80] + "..."
        
        html_parts.append(f'''
        <div style="background: rgba(255, 255, 255, 0.05); padding: 15px; border-radius: 10px; border-left: 4px solid #ff3366;">
            <div style="display: flex; justify-content: space-between; align-items: start;">
                <div style="flex: 1;">
                    <div style="font-size: 1.3em; font-weight: 600; margin-bottom: 8px;">
                        {icon} {idx}. {title}
                    </div>
                    {"<p style='font-size: 0.95em; opacity: 0.8; margin: 8px 0;'>" + summary + "</p>" if summary else ""}
                </div>
                {"<div style='color: #00ff9d; font-weight: 600; margin-left: 15px;'>" + score_text + "</div>" if score_text else ""}
            </div>
            {"<a href='" + url + "' target='_blank' style='color: #00ccff; text-decoration: none; font-size: 0.9em;'>🔗 원문 보기</a>" if url else ""}
        </div>''')
    
    html_parts.append('    </div>')
    html_parts.append('</section>')
    
    return '\n'.join(html_parts)


def update_html(news_html):
    """index.html 업데이트"""
    try:
        with open(TARGET_HTML, "r", encoding="utf-8") as f:
            content = f.read()
        
        # "연구 우선순위 조정안" 섹션을 Top 3 뉴스로 대체
        pattern = r'<section class="proposal-section glass"[^>]*>.*?</section>'
        
        # 첫 번째 proposal-section만 교체
        new_content = re.sub(
            pattern,
            news_html,
            content,
            count=1,
            flags=re.DOTALL
        )
        
        with open(TARGET_HTML, "w", encoding="utf-8") as f:
            f.write(new_content)
        
        print("✅ The Wave Tree Project 업데이트 완료!")
        return True
        
    except Exception as e:
        print(f"❌ 업데이트 실패: {e}")
        return False


def main():
    print("🔄 Top 2 뉴스 동기화 시작...")
    
    # Top 2 뉴스 로드
    top_news = load_top_news()
    print(f"📰 로드된 뉴스: {len(top_news)}개")
    
    # HTML 생성
    news_html = generate_news_html(top_news)
    
    # HTML 업데이트
    success = update_html(news_html)
    
    if success:
        print("🎉 동기화 완료!")
        print("📍 확인: /Users/seunghoonoh/woonmok.github.io/index.html")
    else:
        print("⚠️ 동기화 실패")


if __name__ == "__main__":
    main()
