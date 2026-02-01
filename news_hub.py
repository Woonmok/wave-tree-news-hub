#!/usr/bin/env python3
# news_hub.py (Gemini API 기반 뉴스 분석)
import os
import google.generativeai as genai
from datetime import datetime
import json

# Gemini API 설정
os.environ["GOOGLE_API_KEY"] = os.getenv("GOOGLE_API_KEY", "YOUR_GEMINI_API_KEY")
genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
model = genai.GenerativeModel('gemini-1.5-pro')

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


# 3. Gemini를 통한 전략적 필터링 (눈의 역할)
def analyze_importance(news_text, matched_keywords):
    """Gemini를 사용한 뉴스 중요도 분석"""
    try:
        keywords_str = ", ".join(matched_keywords)
        prompt = f"""당신은 '진안 Farmerstree' 프로젝트의 전략 AI입니다.
다음 뉴스를 분석하여 다음 정보를 제공하세요:
1. 프로젝트(균사체 배양육, 고급 오디오, AI 인프라)와의 관련성 점수 (1-10)
2. 전략적 평가 (2-3줄)
3. 액션 아이템 (있으면)

감지된 키워드: {keywords_str}

뉴스: {news_text}

형식:
[점수/10] | [제목 한줄] 
분석: [내용]
액션: [필요시]"""
        
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        print(f"   ⚠️ Gemini API 오류: {str(e)}")
        return f"[분석 불가] {', '.join(matched_keywords)} 포함"


# 4. 결과 저장 (Markdown)
def save_to_radar(news_text, matched_keywords, analysis=None):
    """Project_Radar.md에 결과 저장"""
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


# 6. 메인 실행 함수
def process_news(use_gemini=True):
    """뉴스 필터링 및 분석 메인 함수"""
    news_list = fetch_news()
    processed_count = 0
    skipped_count = 0
    
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
        
        # Gemini 분석 (기본 활성화)
        analysis = None
        if use_gemini:
            try:
                print(f"   🔄 Gemini 분석 진행 중...")
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
        
        processed_count += 1
    
    print("\n" + "=" * 60)
    print(f"✅ 분석 완료. Project_Radar.md가 업데이트되었습니다.")
    print(f"   ✓ 저장됨: {processed_count}개")
    print(f"   ✗ 건너뜀: {skipped_count}개")
    print(f"   📁 생성 파일: Project_Radar.md, detected_news.json")
    print("=" * 60)


# 실행
if __name__ == "__main__":
    # use_gemini=True로 설정하면 Gemini API 사용 (API 키 필요)
    process_news(use_gemini=False)
