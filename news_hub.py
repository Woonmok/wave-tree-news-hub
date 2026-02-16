#!/usr/bin/env python3
# news_hub.py (로컬 규칙 기반 뉴스 분석 + Daily Bridge)
import os
import re
from dotenv import load_dotenv
from datetime import datetime
import json
import shutil
import requests

# .env 파일 로드
load_dotenv()

# 경로 설정
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORK_DIR = BASE_DIR
DAILY_BRIDGE_PATH = os.path.join(BASE_DIR, "Daily_Bridge.md")

ANTIGRAVITY_PATH = os.getenv("ANTIGRAVITY_PATH", "").strip()
if not ANTIGRAVITY_PATH:
    workspace_root = os.path.abspath(os.path.join(BASE_DIR, ".."))
    ANTIGRAVITY_PATH = os.path.join(workspace_root, "woonmok.github.io", "Project_Radar.md")

# ===== 설정 =====
KEYWORDS = [
    "균사체", "mycelium", "배양육", "cultured meat",
    "진안", "POM", "Bio-R&D", "바이오",
    "cell-based", "fermentation", "배양",
    "listeria", "리스테리아", "고급 오디오", "하이엔드",
    "ai", "computer", "gpu", "blackwell"
]

EXCLUDE_KEYWORDS = [
    "광고", "스폰서", "sponsored", "promo", "affiliate"
]


def score_news(news_text, matched_keywords):
    """로컬 점수 계산"""
    text_lower = news_text.lower()
    score = 5.0

    high_impact = ["절감", "효율", "혁신", "긴급", "fda", "blackwell", "배양육", "균사체"]
    for keyword in high_impact:
        if keyword.lower() in text_lower:
            score += 0.8

    score += min(len(matched_keywords) * 0.6, 2.0)
    score = max(1.0, min(10.0, score))
    return round(score, 1)

# 1. 키워드 필터링 함수
def filter_by_keywords(news_text, keywords=KEYWORDS, exclude=EXCLUDE_KEYWORDS):
    """특정 키워드가 포함된 뉴스만 선택"""
    text_lower = news_text.lower()
    
    # 제외 키워드 확인
    for exclude_kw in exclude:
        if exclude_kw.lower() in text_lower:
            return False, "제외 키워드 포함"
    
    # 포함 키워드 확인
    matched_keywords = [kw for kw in keywords if kw.lower() in text_lower]
    if matched_keywords:
        return True, matched_keywords
    
    return False, "관련 키워드 없음"


# 2. 정보 수집 (RSS/API)
def fetch_news():
    """뉴스 데이터 수집 (2026년 시장 트렌드 시뮬레이션)"""
    # 실제 운영 시: NewsAPI나 RSS 피드를 연동합니다.
    sample_news = [
        "미국 내 배양육 시장, 고비용 문제로 세포 배양 방식에서 균사체(Mycelium) 기반 발효 방식으로 급격한 이동 중",
        "Better Meat Co 및 Prime Roots, 산업용 연속 발효 시스템 도입으로 생산 단가 30% 절감 성공",
        "2026년 푸드테크 트렌드: 'Precision Fermentation'과 버섯 균사체를 결합한 하이브리드 단백질 부상",
        "FDA 리스테리아 긴급 알림 발표 - 냉장 식품 관련",
        "고급 오디오 기술 최신 동향 - DSD 포맷 주류화",
        "NVIDIA Blackwell GPU, AI 인프라 혁신 주도",
        "스타트업 광고: 새 제품 출시 스폰서됨 (제외 대상)",
    ]
    return sample_news


# 3. 전략적 필터링 (로컬 규칙 기반)
def analyze_importance(news_text, matched_keywords):
    """로컬 규칙 기반 뉴스 중요도 분석"""
    score = score_news(news_text, matched_keywords)
    title = news_text[:48] + ("..." if len(news_text) > 48 else "")

    actions = []
    lower_text = news_text.lower()
    if any(keyword in lower_text for keyword in ["절감", "효율", "발효"]):
        actions.append("비용 절감 PoC 우선 검토")
    if any(keyword in lower_text for keyword in ["리스테리아", "listeria", "fda", "긴급"]):
        actions.append("식품안전 모니터링 카드 즉시 생성")
    if any(keyword in lower_text for keyword in ["gpu", "blackwell", "ai", "인프라"]):
        actions.append("인프라 투자/업그레이드 영향도 계산")
    if not actions:
        actions.append("주간 회의 안건으로 추적")

    return (
        f"[{score}/10] | {title}\n"
        f"분석: 감지 키워드({', '.join(matched_keywords)}) 기준으로 프로젝트 관련성이 확인되었습니다.\n"
        f"액션: {actions[0]}"
    )


# 3-1. Daily Bridge 생성 함수 (새로운 기능!)
def create_daily_bridge(news_data_list):
    """
    매일 수집된 뉴스 중 TOP 3을 정제하여 Daily_Bridge.md 생성
    이 파일이 VS Code ↔ Antigravity 연결점
    """
    if not news_data_list:
        print("   ⚠️ 분석할 뉴스가 없습니다.")
        return
    
    timestamp = datetime.now().strftime("%Y년 %m월 %d일 %H:%M:%S")
    
    ranked = sorted(
        news_data_list,
        key=lambda item: score_news(item.get("text", ""), item.get("keywords", [])),
        reverse=True,
    )[:3]

    sections = ["## 레이더 감지 결과 (TOP 3)", ""]
    for index, item in enumerate(ranked, 1):
        text = item.get("text", "")
        keywords = item.get("keywords", [])
        score = score_news(text, keywords)
        action_line = "주간 트래킹 유지"
        lower_text = text.lower()
        if any(keyword in lower_text for keyword in ["절감", "효율", "발효"]):
            action_line = "비용 절감 실험 항목 우선 배치"
        elif any(keyword in lower_text for keyword in ["리스테리아", "listeria", "fda", "긴급"]):
            action_line = "식품안전 대응 시나리오 점검"
        elif any(keyword in lower_text for keyword in ["gpu", "blackwell", "ai", "인프라"]):
            action_line = "서버 인프라 대응 계획 업데이트"

        title = text[:45] + ("..." if len(text) > 45 else "")
        sections.extend([
            f"### {index}️⃣ {title}",
            f"- 원문: {text}",
            f"- 영향도: {score}/10",
            f"- 실행 인사이트: {action_line}",
            "",
        ])

    bridge_content = "\n".join(sections).strip()
    
    # Daily_Bridge.md 생성
    full_content = f"""# 📡 Daily Bridge - {timestamp}

**이 파일은 VS Code와 Antigravity를 연결하는 인사이트 브릿지입니다.**

{bridge_content}

---

## 다음 단계
이 내용을 Antigravity에 복사하여 다음과 같이 질문하세요:
> "오늘의 레이더 감지 결과야. 
> 이 데이터를 바탕으로 현재 Wave Tree Project Dashboard에서 
> 수정하거나 새로 추가해야 할 To-Do 카드 3개를 뽑아줘."

생성 시각: {timestamp}
"""
    
    # 파일 저장
    try:
        with open(DAILY_BRIDGE_PATH, "w", encoding="utf-8") as f:
            f.write(full_content)
        print(f"   ✅ Daily_Bridge.md 생성 완료: {DAILY_BRIDGE_PATH}")
        return DAILY_BRIDGE_PATH
    except Exception as e:
        print(f"   ⚠️ Daily_Bridge.md 저장 실패: {str(e)}")
        return None


def append_daily_bridge_to_news_json(bridge_path, category="global_biz"):
    if not bridge_path or not os.path.exists(bridge_path):
        print("   ⚠️ Daily Bridge 파일이 없어 news.json 추가를 건너뜁니다.")
        return False

    news_json_path = os.path.join(BASE_DIR, "data", "normalized", "news.json")

    try:
        with open(bridge_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"   ⚠️ Daily Bridge 읽기 실패: {str(e)}")
        return False

    date_match = re.search(r"(\d{4})년\s*(\d{2})월\s*(\d{2})일", content)
    if date_match:
        date_str = f"{date_match.group(1)}-{date_match.group(2)}-{date_match.group(3)}"
    else:
        date_str = datetime.now().strftime("%Y-%m-%d")

    bridge_id = f"daily_bridge_{date_str}"
    title = f"Daily Bridge {date_str}"

    bullets = []
    for line in content.splitlines():
        text = line.strip()
        if text.startswith("*"):
            bullets.append(text.lstrip("* ").strip())
        if len(bullets) >= 3:
            break

    summary = " ".join(bullets).strip()
    if not summary:
        summary = content.replace("\n", " ")
    summary = " ".join(summary.split()).strip()
    summary = summary[:180]

    try:
        if os.path.exists(news_json_path):
            with open(news_json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        else:
            data = {"generated_at": datetime.now().isoformat(), "items": []}

        items = data.get("items", [])
        if any(str(item.get("id")) == bridge_id for item in items):
            print("   ℹ️ Daily Bridge가 이미 news.json에 존재합니다.")
            return False

        items.insert(0, {
            "id": bridge_id,
            "category": category,
            "title": title,
            "source": "Daily_Bridge",
            "url": None,
            "published_at": datetime.now().isoformat(),
            "summary": summary,
            "highlights": [],
            "tags": ["daily_bridge"],
            "score": 0.95
        })

        data["generated_at"] = datetime.now().isoformat()
        data["items"] = items

        os.makedirs(os.path.dirname(news_json_path), exist_ok=True)
        with open(news_json_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        print(f"   ✅ Daily Bridge가 news.json에 추가되었습니다: {news_json_path}")
        return True
    except Exception as e:
        print(f"   ⚠️ news.json 추가 실패: {str(e)}")
        return False


# 4. 결과 저장 (Markdown)
def save_to_radar(news_text, matched_keywords, analysis=None):
    """Project_Radar.md에 결과 저장 및 Antigravity로 자동 동기화"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    radar_file = "Project_Radar.md"
    
    # 파일이 없으면 헤더 생성
    if not os.path.exists(radar_file):
        with open(radar_file, "w", encoding="utf-8") as f:
            f.write("# Project Radar - 뉴스 감지 로그\n\n")
    
    with open(radar_file, "a", encoding="utf-8") as f:
        f.write(f"## [{timestamp}] 신규 감지\n")
        f.write(f"**뉴스**: {news_text[:100]}...\n\n")
        f.write(f"**감지 키워드**: {', '.join(matched_keywords)}\n\n")
        if analysis:
            f.write(f"**분석**: {analysis}\n")
        f.write("\n---\n\n")
    
    # Antigravity로 자동 동기화
    try:
        shutil.copy2(radar_file, ANTIGRAVITY_PATH)
        print(f"   🔄 Antigravity 동기화 완료: {ANTIGRAVITY_PATH}")
    except Exception as e:
        print(f"   ⚠️ Antigravity 동기화 실패: {str(e)}")


# 5. JSON으로도 저장 (API 연동 용)
def save_to_json(news_data):
    """감지된 뉴스를 JSON으로 저장"""
    json_file = "detected_news.json"
    
    try:
        with open(json_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        data = []
    
    data.append({
        "timestamp": datetime.now().isoformat(),
        "news": news_data["text"],
        "keywords": news_data["keywords"],
        "analysis": news_data.get("analysis", "")
    })
    
    with open(json_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


# Dashboard 업데이트 함수
def update_dashboard(news_data_list):
    """
    dashboard_data.json의 intelligence 섹션을 최신 뉴스로 업데이트
    """
    dashboard_env = os.getenv("DASHBOARD_DATA_PATH", "").strip()
    if dashboard_env:
        DASHBOARD_PATH = dashboard_env
    else:
        workspace_root = os.path.abspath(os.path.join(BASE_DIR, ".."))
        DASHBOARD_PATH = os.path.join(workspace_root, "woonmok.github.io", "dashboard_data.json")
    
    if not news_data_list:
        print("   ⚠️ 업데이트할 뉴스가 없습니다.")
        return
    
    try:
        # 기존 dashboard_data.json 로드
        if os.path.exists(DASHBOARD_PATH):
            with open(DASHBOARD_PATH, 'r', encoding='utf-8') as f:
                dashboard_data = json.load(f)
        else:
            dashboard_data = {
                "todo_list": [],
                "system_status": "NORMAL",
                "intelligence": []
            }
        
        # 상위 3개 뉴스 추출
        top_news = []
        for item in news_data_list[:3]:
            title = item.get('text', '')[:100]  # 제목 추출
            analysis = item.get('analysis', '')
            
            # 간단한 요약 추출 (첫 문장)
            summary = analysis.split('.')[0] if analysis else "분석 중"
            
            # 카테고리 판단
            keywords = item.get('keywords', [])
            if any(kw in ['listeria', '리스테리아'] for kw in keywords):
                tag = "긴급"
                score = "0.95"
            elif any(kw in ['배양육', 'cultured meat', '균사체'] for kw in keywords):
                tag = "중요"
                score = "0.85"
            else:
                tag = "정보"
                score = "0.75"
            
            top_news.append({
                "title": title,
                "summary": summary[:150],
                "tag": tag,
                "score": score
            })
        
        # intelligence 섹션 업데이트
        dashboard_data["intelligence"] = top_news
        dashboard_data["last_updated"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # 저장
        with open(DASHBOARD_PATH, 'w', encoding='utf-8') as f:
            json.dump(dashboard_data, f, ensure_ascii=False, indent=2)
        
        print(f"   ✅ Dashboard 업데이트 완료: {len(top_news)}개 뉴스")
        
    except Exception as e:
        print(f"   ⚠️ Dashboard 업데이트 오류: {str(e)}")


# 6. 메인 실행 함수
def process_news(use_local_analysis=True):
    """뉴스 필터링 및 분석 메인 함수 + Daily_Bridge.md 생성"""
    news_list = fetch_news()
    processed_count = 0
    skipped_count = 0
    processed_news_data = []
    
    print("=" * 60)
    print("🛰️ 외부 정보 감지 시스템 가동 중...")
    print("=" * 60)
    print(f"📋 감지 키워드 ({len(KEYWORDS)}개): {', '.join(KEYWORDS[:5])}...")
    print(f"🚫 제외 키워드 ({len(EXCLUDE_KEYWORDS)}개): {', '.join(EXCLUDE_KEYWORDS)}\n")
    
    for idx, news in enumerate(news_list, 1):
        print(f"\n[{idx}/{len(news_list)}] 처리 중...")
        print(f"   📝 뉴스: {news[:60]}...")
        
        # 키워드 필터링
        is_relevant, result = filter_by_keywords(news)
        
        if not is_relevant:
            print(f"   ✗ 건너뜀: {result}")
            skipped_count += 1
            continue
        
        matched_keywords = result
        print(f"   ✓ 필터 통과!")
        print(f"   🎯 감지된 키워드: {', '.join(matched_keywords)}")
        
        # 로컬 분석
        analysis = None
        try:
            print(f"   🔄 로컬 분석 진행 중...")
            analysis = analyze_importance(news, matched_keywords)
            print(f"   ✅ 분석 완료")
        except Exception as e:
            print(f"   ⚠️ 분석 오류: {str(e)}")
        
        # Markdown 저장
        try:
            save_to_radar(news, matched_keywords, analysis)
            print(f"   💾 Markdown 저장 완료")
        except Exception as e:
            print(f"   ⚠️ 저장 오류: {str(e)}")
        
        # JSON 저장
        try:
            save_to_json({
                "text": news,
                "keywords": matched_keywords,
                "analysis": analysis or ""
            })
            print(f"   💾 JSON 저장 완료")
        except Exception as e:
            print(f"   ⚠️ JSON 저장 오류: {str(e)}")
        
        # Daily Bridge 생성용 데이터 수집
        processed_news_data.append({
            "text": news,
            "keywords": matched_keywords,
            "analysis": analysis
        })
        
        processed_count += 1
    
    # Daily_Bridge.md 생성 (핵심!)
    print("\n" + "=" * 60)
    print("🌉 Daily Bridge 생성 중...")
    print("=" * 60)
    bridge_path = create_daily_bridge(processed_news_data)

    # Daily_Bridge.md -> news.json append
    if bridge_path:
        append_daily_bridge_to_news_json(bridge_path, category="global_biz")
    
    # Dashboard 업데이트
    print("\n" + "=" * 60)
    print("📊 Dashboard 업데이트 중...")
    print("=" * 60)
    update_dashboard(processed_news_data)
    
    # Intelligence Hub 업데이트 (index.html)
    print("\n" + "=" * 60)
    print("🌐 Intelligence Hub 업데이트 중...")
    print("=" * 60)
    try:
        from sync_top_news import sync_to_html
        sync_to_html()
        print("   ✅ Intelligence Hub 업데이트 완료")
    except Exception as e:
        print(f"   ⚠️ Intelligence Hub 업데이트 오류: {str(e)}")
    
    print("\n" + "=" * 60)
    print(f"✅ 분석 완료. 모든 파일이 업데이트되었습니다.")
    print(f"   ✓ 저장됨: {processed_count}개")
    print(f"   ✗ 건너뜀: {skipped_count}개")
    print(f"   📁 생성 파일:")
    print(f"      - Project_Radar.md (Antigravity 동기화)")
    print(f"      - detected_news.json (API 연동)")
    print(f"      - Daily_Bridge.md ⭐ (VS Code ↔ Antigravity 브릿지)")
    print(f"      - dashboard_data.json ⭐ (대시보드 동기화)")
    print(f"      - index.html Intelligence Hub ⭐ (웹사이트 동기화)")
    print("=" * 60)


# 실행
if __name__ == "__main__":
    process_news(use_local_analysis=True)
