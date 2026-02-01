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
