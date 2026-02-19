#!/usr/bin/env node
/**
 * Daily Bridge Markdown -> Dashboard JSON
 * Usage:
 *   node tools/ingest_daily_bridge.js --date 2026-02-10 --out data/daily_bridge_2026-02-10.json < daily_bridge.md
 *
 * Input assumptions:
 * - Section headers like: "## I. [진안/농업] ..."
 * - Bullet items like: "* **제목:** 내용"
 */

const fs = require("fs");

function readStdin() {
  return fs.readFileSync(0, "utf8"); // stdin
}

function argValue(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return null;
  return process.argv[idx + 1] ?? null;
}

function nowISODateKST() {
  // 간단히 로컬 날짜 사용(대표님 환경 KST 가정). 필요시 고정 --date 사용 권장.
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function parseDailyBridge(md, dateStr) {
  const lines = md.split(/\r?\n/);

  const doc = {
    schema_version: "1.0",
    kind: "daily_bridge",
    date: dateStr,
    generated_at: new Date().toISOString(),
    language: "ko-KR",
    owner: "운목(Woonmok)",
    sections: []
  };

  let current = null;
  let currentItem = null;

  // 예: ## I. [진안/농업] 지역 밀착 및 정책 동향
  const sectionRe = /^##\s+([IⅤVXLCDM]+)\.\s+\[([^\]]+)\]\s*(.+)\s*$/;
  const chapterRe = /^##\s*(\d+)\s*장\.\s*(.+?)(?:\s*\(([^)]+)\))?\s*$/;

  // 예: * **제목:** 내용
  const bulletRe = /^\*\s+\*\*(.+?)\*\*:\s*(.+)\s*$/;
  const itemHeaderRe = /^###\s+\d+\.\s+(.+)\s*$/;
  const itemFieldRe = /^-\s*(원문|영향도|실행 인사이트):\s*(.+)\s*$/;

  function flushItem() {
    if (!current || !currentItem || !currentItem.title) return;

    const summaryParts = [];
    if (currentItem.raw) summaryParts.push(currentItem.raw);
    if (currentItem.insight) summaryParts.push(currentItem.insight);

    current.items.push({
      title: currentItem.title,
      summary: summaryParts.join(" ").replace(/\s+/g, " ").trim(),
      keywords: extractKeywords(currentItem.title, summaryParts.join(" ")),
      importance: guessImportance(`${currentItem.scoreText || ""} ${summaryParts.join(" ")}`),
      source: null,
      url: null
    });

    currentItem = null;
  }

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const line = raw.trim();
    if (!line) continue;

    const chap = line.match(chapterRe);
    if (chap) {
      flushItem();
      const [, chapterNo, chapterTitle, chapterTag] = chap;
      current = {
        id: `S${chapterNo}`,
        tag: (chapterTag || chapterTitle).trim(),
        title: chapterTitle.trim(),
        items: []
      };
      doc.sections.push(current);
      continue;
    }

    const sec = line.match(sectionRe);
    if (sec) {
      flushItem();
      const [, roman, tag, title] = sec;
      current = {
        id: `S${roman}`,
        tag: tag.trim(),
        title: title.trim(),
        items: []
      };
      doc.sections.push(current);
      continue;
    }

    const itemHeader = line.match(itemHeaderRe);
    if (itemHeader && current) {
      flushItem();
      currentItem = {
        title: itemHeader[1].trim(),
        raw: "",
        scoreText: "",
        insight: ""
      };
      continue;
    }

    const itemField = line.match(itemFieldRe);
    if (itemField && current && currentItem) {
      const [, key, value] = itemField;
      if (key === "원문") currentItem.raw = value.trim();
      if (key === "영향도") currentItem.scoreText = value.trim();
      if (key === "실행 인사이트") currentItem.insight = value.trim();
      continue;
    }

    const b = line.match(bulletRe);
    if (b && current) {
      flushItem();
      const [, headline, body] = b;

      // 다음 줄들이 같은 아이템의 연속 문장일 수 있으니, 다음 섹션/불릿 전까지 합치기
      let extra = [];
      let j = i + 1;
      while (j < lines.length) {
        const nxt = lines[j];
        const t = nxt.trim();
        if (!t) { j++; continue; }
        if (sectionRe.test(t) || bulletRe.test(t) || t.startsWith("## ")) break;
        // 일반 문장/보조 설명은 아이템 body에 합침
        extra.push(t);
        j++;
      }
      i = j - 1;

      const fullBody = [body.trim(), ...extra].join(" ").replace(/\s+/g, " ").trim();

      current.items.push({
        title: headline.trim(),
        summary: fullBody,
        // 대시보드에서 필터링/강조 용도로 쓰기 좋게 키워드 자동 추출(아주 단순)
        keywords: extractKeywords(headline, fullBody),
        importance: guessImportance(fullBody), // 1~5
        source: null,
        url: null
      });
      continue;
    }
  }

  flushItem();

  return doc;
}

function extractKeywords(title, summary) {
  const text = `${title} ${summary}`.toLowerCase();
  const candidates = [
    "진안", "진안군", "후계농", "스마트팜", "고추", "수박",
    "넷플릭스", "티빙", "ott", "제로 클릭", "ai 에이전트",
    "krx", "한국거래소", "인수", "데이터센터", "광통신",
    "나스닥", "엔비디아", "환율", "관세", "성장률"
  ];
  const hit = [];
  for (const k of candidates) {
    if (text.includes(k.toLowerCase())) hit.push(k);
  }
  return Array.from(new Set(hit)).slice(0, 8);
}

function guessImportance(summary) {
  // 매우 러프하게 "마감/급등/변수/필수" 같은 신호로 점수
  const s = summary;
  let score = 2;
  if (/(마감|내일|임박|필수|긴급)/.test(s)) score += 2;
  if (/(급등|폭주|대세|본격화)/.test(s)) score += 1;
  if (/(변수|리스크|주의|모니터링)/.test(s)) score += 1;
  return Math.max(1, Math.min(5, score));
}

// Main
const dateArg = argValue("--date") || nowISODateKST();
const outArg = argValue("--out");

const input = readStdin();
if (!input || input.trim().length < 10) {
  console.error("No input received. Pipe your Daily Bridge markdown into stdin.");
  process.exit(1);
}

const parsed = parseDailyBridge(input, dateArg);
const json = JSON.stringify(parsed, null, 2);

if (outArg) {
  fs.mkdirSync(require("path").dirname(outArg), { recursive: true });
  fs.writeFileSync(outArg, json, "utf8");
  console.log(`OK: wrote ${outArg}`);
} else {
  process.stdout.write(json);
}
