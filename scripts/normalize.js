#!/usr/bin/env node
/**
 * normalize.js
 * 목적: Perplexity 출력(텍스트 or JSON)을 Wave Tree news.json 스키마로 정규화
 *
 * 사용:
 *   node ./scripts/normalize.js --in ./data/raw/perplexity.txt --out ./data/normalized/news.json
 *   node ./scripts/normalize.js --in ./data/raw/perplexity.json --out ./data/normalized/news.json
 *
 * 입력 지원:
 * 1) 이미 JSON인 경우:
 *    - { items: [...] } 또는 [ ... ] 형태
 *    - items 요소는 최소 title/source/url/category 를 포함하도록 권장
 *
 * 2) 텍스트인 경우(권장 템플릿):
 *    [CATEGORY: listeria_free]
 *    - 제목 | 소스 | https://url | 2026-01-31T08:00:00Z | score=0.83 | tags=regulation,usa | summary=한줄
 *
 *    [CATEGORY: cultured_meat]
 *    - ...
 *
 * category enum:
 *   listeria_free, cultured_meat, high_end_audio, computer_ai, global_biz
 */

"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const ALLOWED_CATEGORY = new Set([
  "listeria_free",
  "cultured_meat",
  "high_end_audio",
  "computer_ai",
  "global_biz",
]);

function argValue(flag) {
  const i = process.argv.indexOf(flag);
  if (i >= 0 && i + 1 < process.argv.length) return process.argv[i + 1];
  return null;
}

const inPath = argValue("--in");
const outPath = argValue("--out") || "./data/normalized/news.json";

if (!inPath) {
  console.error("Usage: node normalize.js --in <input.txt|input.json> --out <news.json>");
  process.exit(1);
}

const raw = fs.readFileSync(inPath, "utf-8");
const items = parseInput(raw, inPath);

const out = {
  generated_at: new Date().toISOString(),
  items,
};

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(out, null, 2), "utf-8");
console.log(`OK: wrote ${items.length} items -> ${outPath}`);

function parseInput(raw, filename) {
  const isJson = filename.toLowerCase().endsWith(".json");
  if (isJson) return normalizeFromJson(raw);

  return normalizeFromText(raw);
}

function looksLikeJson(s) {
  const t = s.trim();
  return t.startsWith("{") || t.startsWith("[");
}

function normalizeFromJson(raw) {
  let data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    throw new Error("Invalid JSON input");
  }

  let arr = [];
  if (Array.isArray(data)) arr = data;
  else if (data && Array.isArray(data.items)) arr = data.items;
  else if (data && Array.isArray(data.results)) arr = data.results;

  const norm = [];
  for (const it of arr) {
    const category = guessCategory(it.category || it.section || it.topic);
    if (!category) continue;

    const title = String(it.title || it.headline || "").trim();
    const url = it.url ? String(it.url).trim() : null;
    const source = String(it.source || it.publisher || "").trim();

    if (!title) continue;

    const published_at = normalizeDate(it.published_at || it.published || it.date || null);
    const summary = it.summary ? String(it.summary).trim() : "";
    const highlights = Array.isArray(it.highlights) ? it.highlights.map(String) : [];
    const tags = Array.isArray(it.tags) ? it.tags.map(String) : [];
    const score = typeof it.score === "number" ? it.score : (typeof it.relevance === "number" ? it.relevance : null);

    norm.push({
      id: makeId(category, title, url, source),
      category,
      title,
      source,
      url,
      published_at,
      summary,
      highlights,
      tags,
      score,
    });
  }

  return dedup(norm);
}

function normalizeFromText(raw) {
  const lines = raw.split(/\r?\n/);

  let currentCategory = null;
  let inNumberedList = false;
  let itemBuffer = null;
  const out = [];

  for (let i = 0; i < lines.length; i++) {
    const lineRaw = lines[i];
    const line = lineRaw.trim();
    if (!line) {
      // flush any buffered item on blank line
      if (itemBuffer) {
        const item = parseNumberedItem(itemBuffer, currentCategory);
        if (item) out.push(item);
        itemBuffer = null;
      }
      inNumberedList = false;
      continue;
    }

    // [CATEGORY: xxx]
    const m = line.match(/^\[CATEGORY:\s*([a-z0-9_]+)\s*\]$/i);
    if (m) {
      if (itemBuffer) {
        const item = parseNumberedItem(itemBuffer, currentCategory);
        if (item) out.push(item);
        itemBuffer = null;
      }
      const cat = m[1].toLowerCase();
      currentCategory = ALLOWED_CATEGORY.has(cat) ? cat : null;
      inNumberedList = false;
      continue;
    }

    // Markdown heading like "## 🦠 Listeria Free (4)"
    if (line.match(/^#+\s*.*\([0-9]+\)\s*$/)) {
      if (itemBuffer) {
        const item = parseNumberedItem(itemBuffer, currentCategory);
        if (item) out.push(item);
        itemBuffer = null;
      }
      const guessed = guessCategory(line);
      if (guessed) {
        currentCategory = guessed;
        inNumberedList = true;
      }
      continue;
    }

    // Allow other headings like "LISTERIA FREE:" etc.
    if (line.match(/^#+\s+/) && !currentCategory) {
      if (itemBuffer) {
        const item = parseNumberedItem(itemBuffer, currentCategory);
        if (item) out.push(item);
        itemBuffer = null;
      }
      const guessed = guessCategory(line);
      if (guessed) {
        currentCategory = guessed;
        inNumberedList = true;
      }
      continue;
    }

    // numbered list item "1. **title**" in markdown
    const numMatch = line.match(/^(\d+)\.\s*\*\*(.+?)\*\*\s*(.*)?$/);
    if (numMatch && inNumberedList && currentCategory) {
      // flush previous item
      if (itemBuffer) {
        const item = parseNumberedItem(itemBuffer, currentCategory);
        if (item) out.push(item);
      }
      itemBuffer = {
        title: numMatch[2].trim(),
        lines: [line],
      };
      continue;
    }

    // continuation line "   - ..." (indented bullet under numbered item)
    if ((line.startsWith("-") || line.startsWith("•")) && itemBuffer) {
      itemBuffer.lines.push(line);
      continue;
    }

    // bullet item "- ..." (old format)
    if (line.startsWith("-") || line.startsWith("•")) {
      if (!currentCategory) continue;
      const body = line.replace(/^[-•]+\s*/, "");
      const item = parseBullet(body, currentCategory);
      if (item) out.push(item);
      continue;
    }
  }

  // flush final buffer
  if (itemBuffer) {
    const item = parseNumberedItem(itemBuffer, currentCategory);
    if (item) out.push(item);
  }

  return dedup(out);
}

function parseNumberedItem(buffer, category) {
  // buffer = { title: "...", lines: ["1. **title**", "   - content", "   - content", ...] }
  if (!buffer || !buffer.title || !category) return null;

  let summary = "";
  let highlights = [];
  let url = null;
  let source = "";
  let score = null;
  let tags = [];

  // parse continuation lines (indented bullet points)
  for (let i = 1; i < buffer.lines.length; i++) {
    const line = buffer.lines[i].trim();
    if (!line) continue;

    // remove leading bullet
    const content = line.replace(/^[-•]\s*/, "");

    // look for [web:XX] references for sources
    const webMatch = content.match(/\[web:(\d+)\]/);
    if (webMatch && !source) {
      source = `web:${webMatch[1]}`;
    }

    // extract URL if present
    if (!url) url = extractUrl(content);

    // treat each bullet as a highlight/summary item
    if (!summary) {
      summary = content;
    } else {
      highlights.push(content);
    }
  }

  // extract tags from summary if using [tag:...] format
  if (summary) {
    const tagMatches = summary.match(/\[tag:([^\]]+)\]/g);
    if (tagMatches) {
      tags = tagMatches.map((m) => m.replace(/\[tag:|\]/g, "").trim());
    }
  }

  const title = String(buffer.title).trim();

  if (!title) return null;

  return {
    id: makeId(category, title, url, source),
    category,
    title,
    source,
    url,
    published_at: null,
    summary,
    highlights,
    tags,
    score,
  };
}

function parseBullet(body, category) {
  // Split by | first (recommended)
  const parts = body.split("|").map((s) => s.trim()).filter(Boolean);

  let title = "";
  let source = "";
  let url = null;
  let published_at = null;
  let score = null;
  let tags = [];
  let summary = "";

  if (parts.length >= 1) title = parts[0] || "";
  if (parts.length >= 2) source = parts[1] || "";
  if (parts.length >= 3) url = extractUrl(parts[2]) || null;

  // remaining parts may include date, score, tags, summary
  for (let i = 3; i < parts.length; i++) {
    const p = parts[i];
    const date = normalizeDate(p);
    if (date && !published_at) { published_at = date; continue; }

    const sm = p.match(/^score\s*=\s*([0-9]*\.?[0-9]+)$/i);
    if (sm) { score = Number(sm[1]); continue; }

    const tm = p.match(/^tags\s*=\s*(.+)$/i);
    if (tm) { tags = tm[1].split(",").map((x) => x.trim()).filter(Boolean); continue; }

    const sum = p.match(/^summary\s*=\s*(.+)$/i);
    if (sum) { summary = sum[1].trim(); continue; }
  }

  // fallback parsing when not using pipes: try to find url anywhere
  if (!url) url = extractUrl(body);

  title = String(title).trim();
  source = String(source).trim();

  if (!title) return null;

  return {
    id: makeId(category, title, url, source),
    category,
    title,
    source,
    url,
    published_at,
    summary,
    highlights: [],
    tags,
    score,
  };
}

function extractUrl(s) {
  const m = String(s).match(/https?:\/\/[^\s)]+/i);
  return m ? m[0] : null;
}

function normalizeDate(x) {
  if (!x) return null;
  const s = String(x).trim();

  // Accept ISO 8601
  if (/^\d{4}-\d{2}-\d{2}t/i.test(s) || /^\d{4}-\d{2}-\d{2}T/.test(s)) {
    const d = new Date(s);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  // Accept YYYY-MM-DD
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (m) {
    const d = new Date(`${m[1]}-${m[2]}-${m[3]}T00:00:00Z`);
    return isNaN(d.getTime()) ? null : d.toISOString();
  }

  return null;
}

function guessCategory(x) {
  if (!x) return null;
  const s = String(x).toLowerCase();

  // direct match
  if (ALLOWED_CATEGORY.has(s)) return s;

  // heuristics
  if (s.includes("listeria")) return "listeria_free";
  if (s.includes("cultured") || s.includes("cell") || s.includes("배양")) return "cultured_meat";
  if (s.includes("audio") || s.includes("hifi") || s.includes("하이엔드") || s.includes("jubilee")) return "high_end_audio";
  if (s.includes("computer") || s.includes("ai") || s.includes("openai") || s.includes("gpu") || s.includes("blackwell")) return "computer_ai";
  if (s.includes("global") || s.includes("biz") || s.includes("efsa") || s.includes("mafra")) return "global_biz";

  return null;
}

function makeId(category, title, url, source) {
  const base = `${category}||${title}||${url || ""}||${source || ""}`.toLowerCase();
  return crypto.createHash("sha1").update(base).digest("hex");
}

function dedup(items) {
  const seen = new Set();
  const out = [];
  for (const it of items) {
    if (!it.id) continue;
    if (seen.has(it.id)) continue;
    seen.add(it.id);
    out.push(it);
  }
  return out;
}
