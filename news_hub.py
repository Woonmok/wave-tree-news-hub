#!/usr/bin/env python3
# news_hub.py (로컬 규칙 기반 뉴스 분석 + Daily Bridge)
import os
import re
import logging
from dotenv import load_dotenv
from datetime import datetime
import json
import shutil
import tempfile
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

CATEGORY_RULES = {
    "listeria_free": ["리스테리아", "listeria", "fda", "긴급", "식품안전"],
    "cultured_meat": ["배양육", "cultured meat", "균사체", "mycelium", "fermentation", "발효", "cell-based"],
    "high_end_audio": ["고급 오디오", "하이엔드", "dsd", "audio", "오디오"],
    "computer_ai": ["ai", "gpu", "blackwell", "computer", "인프라"],
    "global_biz": ["규제", "시장", "정책", "관세", "수출", "비즈니스", "투자", "글로벌", "market", "regulation", "policy", "trade", "economy", "approval"],
}

REQUIRED_KEYS = {"id", "category", "title", "summary"}

logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO),
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)


def atomic_write_json(file_path, data, ensure_ascii=False, indent=2):
    """JSON 파일을 원자적으로 저장하고 디스크 반영까지 보장한다."""
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
            json.dump(data, f, ensure_ascii=ensure_ascii, indent=indent)
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


def validate_news_items_schema(items, context="news.json"):
    """REQUIRED_KEYS 기준으로 뉴스 아이템 스키마를 검증하고 유효 항목만 반환한다."""
    valid_items = []
    invalid_count = 0

    if not isinstance(items, list):
        logger.warning("%s: items가 list가 아닙니다. 빈 목록으로 처리합니다.", context)
        return [], 0

    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            invalid_count += 1
            logger.warning("%s: items[%d]가 dict가 아닙니다. 제외합니다.", context, idx)
            continue

        missing = REQUIRED_KEYS - set(item.keys())
        if missing:
            invalid_count += 1
            logger.warning(
                "%s: items[%d] 필수 키 누락(%s). 제외합니다.",
                context,
                idx,
                ", ".join(sorted(missing)),
            )
            continue

        valid_items.append(item)

    if invalid_count:
        logger.warning("%s: 스키마 불일치 %d건 제외", context, invalid_count)

    return valid_items, invalid_count


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


def classify_news_category(news_text, matched_keywords=None):
    matched_keywords = matched_keywords or []
    probe = f"{news_text} {' '.join(matched_keywords)}".lower()

    for category in ["listeria_free", "cultured_meat", "high_end_audio", "computer_ai"]:
        if any(needle.lower() in probe for needle in CATEGORY_RULES[category]):
            return category

    if any(needle.lower() in probe for needle in CATEGORY_RULES["global_biz"]):
        return "global_biz"

    return "global_biz"

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
        logger.warning("   ⚠️ 분석할 뉴스가 없습니다.")
        return
    
    timestamp = datetime.now().strftime("%Y년 %m월 %d일 %H:%M:%S")
    
    chapter_defs = [
        ("listeria_free", "리스테리아/식품안전", CATEGORY_RULES["listeria_free"]),
        ("cultured_meat", "배양육/균사체", CATEGORY_RULES["cultured_meat"]),
        ("high_end_audio", "하이엔드 오디오", CATEGORY_RULES["high_end_audio"]),
        ("computer_ai", "컴퓨터/AI", CATEGORY_RULES["computer_ai"]),
        ("global_biz", "글로벌 비즈니스/규제", CATEGORY_RULES["global_biz"]),
    ]

    def classify_category(item):
        text = item.get("text", "")
        keywords = item.get("keywords", [])
        return classify_news_category(text, keywords)

    def has_global_signal(item):
        text = item.get("text", "")
        keywords = item.get("keywords", [])
        probe = f"{text} {' '.join(keywords)}".lower()
        global_needles = chapter_defs[-1][2]
        return any(needle.lower() in probe for needle in global_needles)

    def add_unique(bucket_list, item):
        text = item.get("text", "")
        if any(existing.get("text", "") == text for existing in bucket_list):
            return
        bucket_list.append(item)

    buckets = {category: [] for category, _, _ in chapter_defs}
    for item in news_data_list:
        category = classify_category(item)
        add_unique(buckets[category], item)
        if category != "global_biz" and has_global_signal(item):
            add_unique(buckets["global_biz"], item)

    for category in buckets:
        buckets[category] = sorted(
            buckets[category],
            key=lambda item: score_news(item.get("text", ""), item.get("keywords", [])),
            reverse=True,
        )[:3]

    min_global_items = 2
    if len(buckets["global_biz"]) < min_global_items and news_data_list:
        ranked_all = sorted(
            news_data_list,
            key=lambda item: score_news(item.get("text", ""), item.get("keywords", [])),
            reverse=True,
        )
        for candidate in ranked_all:
            add_unique(buckets["global_biz"], candidate)
            if len(buckets["global_biz"]) >= min_global_items:
                break

    sections = ["## 레이더 감지 결과 (5챕터)", ""]
    for chapter_index, (category, chapter_title, _) in enumerate(chapter_defs, 1):
        sections.append(f"## {chapter_index}장. {chapter_title} ({category})")
        chapter_items = buckets.get(category, [])

        if not chapter_items:
            sections.extend([
                "- 원문: 해당 카테고리 감지 뉴스 없음",
                "- 영향도: 0/10",
                "- 실행 인사이트: 다음 수집 주기에 재확인",
                "",
            ])
            continue

        for item_index, item in enumerate(chapter_items, 1):
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
                f"### {item_index}. {title}",
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
        logger.info("   ✅ Daily_Bridge.md 생성 완료: %s", DAILY_BRIDGE_PATH)
        return DAILY_BRIDGE_PATH
    except Exception as e:
        logger.error("   ⚠️ Daily_Bridge.md 저장 실패: %s", str(e))
        return None


def append_daily_bridge_to_news_json(bridge_path, category="global_biz"):
    if not bridge_path or not os.path.exists(bridge_path):
        logger.warning("   ⚠️ Daily Bridge 파일이 없어 news.json 추가를 건너뜁니다.")
        return False

    news_json_path = os.path.join(BASE_DIR, "data", "normalized", "news.json")

    try:
        with open(bridge_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        logger.error("   ⚠️ Daily Bridge 읽기 실패: %s", str(e))
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
        if text.startswith("- 원문:") or text.startswith("- 실행 인사이트:"):
            bullets.append(text.split(":", 1)[1].strip())
        elif text.startswith("*"):
            bullets.append(text.lstrip("* ").strip())
        if len(bullets) >= 3:
            break

    summary = " ".join(bullets).strip()
    if not summary:
        summary = content.replace("\n", " ")
    summary = " ".join(summary.split()).strip()
    summary = summary.replace("**", "")
    summary = summary[:180]

    try:
        if os.path.exists(news_json_path):
            with open(news_json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        else:
            data = {"generated_at": datetime.now().isoformat(), "items": []}

        items, _ = validate_news_items_schema(data.get("items", []), context=news_json_path)
        if any(str(item.get("id")) == bridge_id for item in items):
            logger.info("   ℹ️ Daily Bridge가 이미 news.json에 존재합니다.")
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

        atomic_write_json(news_json_path, data, ensure_ascii=False, indent=2)

        logger.info("   ✅ Daily Bridge가 news.json에 추가되었습니다: %s", news_json_path)
        return True
    except Exception as e:
        logger.error("   ⚠️ news.json 추가 실패: %s", str(e))
        return False


def sync_news_hub_source_from_canonical():
    target_path = os.path.join(BASE_DIR, "data", "normalized", "news.json")
    source_candidates = [
        os.path.join(os.path.abspath(os.path.join(BASE_DIR, "..")), "woonmok.github.io", "news.json"),
        target_path,
    ]

    chosen_data = None
    chosen_path = None
    for candidate in source_candidates:
        if not os.path.exists(candidate):
            continue
        try:
            with open(candidate, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            items, _ = validate_news_items_schema(loaded.get("items", []), context=candidate)
            if isinstance(items, list) and len(items) >= 20:
                loaded["items"] = items
                chosen_data = loaded
                chosen_path = candidate
                break
        except Exception:
            continue

    if not chosen_data:
        logger.warning("   ⚠️ canonical news.json을 찾지 못해 기존 normalized/news.json 유지")
        return False

    try:
        atomic_write_json(target_path, chosen_data, ensure_ascii=False, indent=2)
        logger.info("   ✅ normalized/news.json 동기화 완료: %s (%d개)", chosen_path, len(chosen_data.get("items", [])))
        return True
    except Exception as e:
        logger.error("   ⚠️ normalized/news.json 동기화 실패: %s", str(e))
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
        logger.info("   🔄 Antigravity 동기화 완료: %s", ANTIGRAVITY_PATH)
    except Exception as e:
        logger.error("   ⚠️ Antigravity 동기화 실패: %s", str(e))


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
    
    atomic_write_json(json_file, data, ensure_ascii=False, indent=2)


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
        logger.warning("   ⚠️ 업데이트할 뉴스가 없습니다.")
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
        atomic_write_json(DASHBOARD_PATH, dashboard_data, ensure_ascii=False, indent=2)
        
        logger.info("   ✅ Dashboard 업데이트 완료: %d개 뉴스", len(top_news))
        
    except Exception as e:
        logger.error("   ⚠️ Dashboard 업데이트 오류: %s", str(e))


def filter_and_analyze(news_list, use_local_analysis=True):
    """뉴스를 필터링/분석하여 후속 단계용 리스트를 구성한다."""
    processed_news_data = []
    skipped_count = 0

    logger.info("=" * 60)
    logger.info("🛰️ 외부 정보 감지 시스템 가동 중...")
    logger.info("=" * 60)
    logger.info("📋 감지 키워드 (%d개): %s...", len(KEYWORDS), ", ".join(KEYWORDS[:5]))
    logger.info("🚫 제외 키워드 (%d개): %s\n", len(EXCLUDE_KEYWORDS), ", ".join(EXCLUDE_KEYWORDS))

    for idx, news in enumerate(news_list, 1):
        logger.info("\n[%d/%d] 처리 중...", idx, len(news_list))
        logger.info("   📝 뉴스: %s...", news[:60])

        is_relevant, result = filter_by_keywords(news)
        if not is_relevant:
            logger.info("   ✗ 건너뜀: %s", result)
            skipped_count += 1
            continue

        matched_keywords = result
        logger.info("   ✓ 필터 통과!")
        logger.info("   🎯 감지된 키워드: %s", ", ".join(matched_keywords))

        analysis = None
        if use_local_analysis:
            try:
                logger.info("   🔄 로컬 분석 진행 중...")
                analysis = analyze_importance(news, matched_keywords)
                logger.info("   ✅ 분석 완료")
            except Exception as e:
                logger.error("   ⚠️ 분석 오류: %s", str(e))

        processed_news_data.append({
            "text": news,
            "keywords": matched_keywords,
            "analysis": analysis,
            "category": classify_news_category(news, matched_keywords),
        })

    return processed_news_data, skipped_count


def persist(processed_news_data):
    """분석 결과를 파일로 저장하고 관련 아티팩트를 수집한다."""
    artifacts = {
        "radar_saved": 0,
        "json_saved": 0,
        "bridge_path": None,
        "news_sync_ok": False,
    }

    for item in processed_news_data:
        try:
            save_to_radar(item["text"], item["keywords"], item.get("analysis"))
            artifacts["radar_saved"] += 1
            logger.info("   💾 Markdown 저장 완료")
        except Exception as e:
            logger.error("   ⚠️ 저장 오류: %s", str(e))

        try:
            save_to_json({
                "text": item["text"],
                "keywords": item["keywords"],
                "analysis": item.get("analysis") or "",
            })
            artifacts["json_saved"] += 1
            logger.info("   💾 JSON 저장 완료")
        except Exception as e:
            logger.error("   ⚠️ JSON 저장 오류: %s", str(e))

    logger.info("\n%s", "=" * 60)
    logger.info("🌉 Daily Bridge 생성 중...")
    logger.info("%s", "=" * 60)
    artifacts["bridge_path"] = create_daily_bridge(processed_news_data)

    artifacts["news_sync_ok"] = sync_news_hub_source_from_canonical()
    return artifacts


def publish(processed_news_data, artifacts):
    """저장된 결과를 대시보드/웹으로 발행한다."""
    logger.info("\n%s", "=" * 60)
    logger.info("📊 Dashboard 업데이트 중...")
    logger.info("%s", "=" * 60)
    try:
        update_dashboard(processed_news_data)
        artifacts["dashboard_ok"] = True
    except Exception as e:
        artifacts["dashboard_ok"] = False
        logger.error("   ⚠️ Dashboard 업데이트 오류: %s", str(e))

    logger.info("\n%s", "=" * 60)
    logger.info("🌐 Intelligence Hub 업데이트 중...")
    logger.info("%s", "=" * 60)
    try:
        from sync_top_news import sync_to_html

        sync_to_html()
        artifacts["html_ok"] = True
        logger.info("   ✅ Intelligence Hub 업데이트 완료")
    except Exception as e:
        artifacts["html_ok"] = False
        logger.error("   ⚠️ Intelligence Hub 업데이트 오류: %s", str(e))


def summary(processed_news_data, skipped_count, artifacts):
    """실행 결과를 요약 로그로 남긴다."""
    logger.info("\n%s", "=" * 60)
    logger.info("✅ 분석 완료. 모든 파일이 업데이트되었습니다.")
    logger.info("   ✓ 저장됨: %d개", len(processed_news_data))
    logger.info("   ✗ 건너뜀: %d개", skipped_count)
    logger.info("   📁 생성 파일:")
    logger.info("      - Project_Radar.md (Antigravity 동기화, %d건)", artifacts.get("radar_saved", 0))
    logger.info("      - detected_news.json (API 연동, %d건)", artifacts.get("json_saved", 0))
    logger.info("      - Daily_Bridge.md ⭐ (VS Code ↔ Antigravity 브릿지): %s", artifacts.get("bridge_path"))
    logger.info("      - dashboard_data.json ⭐ (대시보드 동기화): %s", artifacts.get("dashboard_ok", False))
    logger.info("      - index.html Intelligence Hub ⭐ (웹사이트 동기화): %s", artifacts.get("html_ok", False))
    logger.info("      - news.json canonical sync: %s", artifacts.get("news_sync_ok", False))
    logger.info("%s", "=" * 60)


# 6. 메인 실행 함수
def process_news(use_local_analysis=True):
    """오케스트레이터: 실행 순서 제어 + 최종 요약 출력만 담당"""
    news_list = fetch_news()
    processed_news_data, skipped_count = filter_and_analyze(news_list, use_local_analysis=use_local_analysis)
    artifacts = persist(processed_news_data)
    publish(processed_news_data, artifacts)
    summary(processed_news_data, skipped_count, artifacts)


# 실행
if __name__ == "__main__":
    process_news(use_local_analysis=True)
