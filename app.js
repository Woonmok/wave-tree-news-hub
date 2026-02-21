/* Wave Tree News Hub - app.js
 * - Reads ./data/normalized/news.json (schema fixed)
 * - Category filter + search + sort
 * - Saved/Scrapbook uses localStorage
 */

(function () {
  "use strict";

  const CONFIG = {
    dataUrl: "./data/normalized/news.json",
    savedStorageKey: "waveTreeSavedNews.v1",
    maxPerCategory: 40, // UI에서 카테고리 당 렌더 상한(원하면 늘리세요)
  };

  // UI category definitions (stable keys)
  const CATEGORY = {
    listeria_free: { title: "🦠 LISTERIA FREE", icon: "🦠" },
    cultured_meat: { title: "🥩 CULTURED MEAT", icon: "🥩" },
    high_end_audio: { title: "🎵 HIGH-END AUDIO", icon: "🎵" },
    computer_ai: { title: "🤖 COMPUTER & AI", icon: "🤖" },
    global_biz: { title: "🌍 GLOBAL BIZ", icon: "🌍" },
  };

  // ---------- State ----------
  let allItems = []; // normalized items
  let generatedAt = null;

  let saved = loadSaved(); // array of saved objects
  let filter = "all";
  let q = "";
  let sortMode = "published_desc";

  // ---------- DOM ----------
  const el = {};
  document.addEventListener("DOMContentLoaded", init);

  function init() {
    el.newsGrid = document.getElementById("newsGrid");
    el.totalNews = document.getElementById("totalNews");
    el.savedCount = document.getElementById("savedCount");
    el.scrapbookCount = document.getElementById("scrapbookCount");
    el.scrapbookPanel = document.getElementById("scrapbookPanel");
    el.scrapbookContent = document.getElementById("scrapbookContent");
    el.timestamp = document.getElementById("timestamp");
    el.shownNews = document.getElementById("shownNews");
    el.categoryCount = document.getElementById("categoryCount");
    el.searchInput = document.getElementById("searchInput");
    el.searchHint = document.getElementById("searchHint");
    el.sortSelect = document.getElementById("sortSelect");
    el.dataStatus = document.getElementById("dataStatus");
    el.processorValue = document.getElementById("processorValue");
    el.processorLabel = document.getElementById("processorLabel");

    // expose minimal API for inline onclick
    window.WaveTree = {
      toggleScrapbook,
      toggleSave,
      removeSaved,
      openLink,
    };

    wireEvents();
    bootstrapTimestamp();
    renderProcessorSummary();
    renderSavedCounters();
    renderScrapbook();

    fetchData()
      .then(() => {
        el.dataStatus.textContent = `data: ${allItems.length.toLocaleString()} items`;
        el.dataStatus.style.opacity = "1";
        render();
      })
      .catch((err) => {
        console.error(err);
        el.dataStatus.textContent = "data: 로드 실패 (news.json 경로 확인)";
        el.dataStatus.style.borderColor = "rgba(255,0,110,.6)";
      });
  }

  function wireEvents() {
    // filters
    document.querySelectorAll(".filter-btn").forEach((btn) => {
      btn.addEventListener("click", function () {
        document.querySelectorAll(".filter-btn").forEach((b) => b.classList.remove("active"));
        this.classList.add("active");
        filter = this.getAttribute("data-filter") || "all";
        render();
      });
    });

    // search
    el.searchInput.addEventListener("input", () => {
      q = (el.searchInput.value || "").trim();
      el.searchHint.textContent = q ? `“${q}”` : "";
      render();
    });

    // sort
    el.sortSelect.addEventListener("change", () => {
      sortMode = el.sortSelect.value || "published_desc";
      render();
    });

    // ESC closes scrapbook
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && el.scrapbookPanel.classList.contains("open")) {
        toggleScrapbook();
      }
    });
  }

  function bootstrapTimestamp() {
    const renderNow = () => {
      const now = new Date();
      el.timestamp.textContent = formatKST(now);
    };
    renderNow();
    setInterval(renderNow, 1000);
  }

  function renderProcessorSummary() {
    if (!el.processorValue || !el.processorLabel) return;

    const cores = Number(navigator.hardwareConcurrency) || 0;
    const memory = Number(navigator.deviceMemory) || 0;
    const platform = (navigator.platform || navigator.userAgent || "").toLowerCase();

    let platformLabel = "CPU";
    if (platform.includes("mac")) platformLabel = "macOS CPU";
    else if (platform.includes("win")) platformLabel = "Windows CPU";
    else if (platform.includes("linux")) platformLabel = "Linux CPU";
    else if (platform.includes("android")) platformLabel = "Android CPU";
    else if (platform.includes("iphone") || platform.includes("ipad")) platformLabel = "iOS CPU";

    const coreText = cores ? `${cores}-core` : "CPU";
    const memText = memory ? `${memory}GB RAM` : "RAM ?";

    el.processorValue.textContent = coreText;
    el.processorLabel.textContent = `${platformLabel} · ${memText}`;
  }

  async function fetchData() {
    const requestUrl = `${CONFIG.dataUrl}?v=${Date.now()}`;
    const res = await fetch(requestUrl, { cache: "no-store" });
    if (!res.ok) throw new Error(`Failed to fetch: ${requestUrl} (${res.status})`);
    const data = await res.json();

    generatedAt = data.generated_at ? new Date(data.generated_at) : null;
    allItems = Array.isArray(data.items) ? data.items : [];

    // normalize fields to safe defaults
    allItems = allItems.map((it) => ({
      id: String(it.id || ""),
      category: String(it.category || ""),
      title: String(it.title || ""),
      url: it.url ? String(it.url) : null,
      source: String(it.source || ""),
      published_at: it.published_at ? String(it.published_at) : null,
      summary: it.summary ? String(it.summary) : "",
      highlights: Array.isArray(it.highlights) ? it.highlights.map(String) : [],
      tags: Array.isArray(it.tags) ? it.tags.map(String) : [],
      score: typeof it.score === "number" ? it.score : null,
    })).filter((it) => it.id && it.category && it.title);

    // stats
    el.categoryCount.textContent = String(Object.keys(CATEGORY).length);
    el.totalNews.textContent = allItems.length.toLocaleString();

    // timestamp: generated_at first, fallback to now
    el.timestamp.textContent = formatKST(generatedAt || new Date());
  }

  // ---------- Rendering ----------
  function render() {
    const filtered = applyFilterSearchSort(allItems);
    el.shownNews.textContent = filtered.length.toLocaleString();

    // group by category (preserve UI order)
    const groups = {};
    Object.keys(CATEGORY).forEach((k) => (groups[k] = []));
    filtered.forEach((it) => {
      if (groups[it.category]) groups[it.category].push(it);
    });

    el.newsGrid.innerHTML = "";
    Object.keys(CATEGORY).forEach((catKey) => {
      if (filter !== "all" && filter !== catKey) return;

      const items = groups[catKey] || [];
      const def = CATEGORY[catKey];

      const catDiv = document.createElement("div");
      catDiv.className = "news-category";
      catDiv.setAttribute("data-category", catKey);

      const header = document.createElement("div");
      header.className = "category-header";
      header.innerHTML = `
        <div class="category-title">
          <span class="category-icon">${escapeHtml(def.icon)}</span>
          <span>${escapeHtml(def.title)}</span>
        </div>
        <span class="category-count">${items.length.toLocaleString()}</span>
      `;
      catDiv.appendChild(header);

      const slice = items.slice(0, CONFIG.maxPerCategory);
      if (slice.length === 0) {
        const empty = document.createElement("div");
        empty.className = "empty-state";
        empty.style.padding = "18px 6px";
        empty.textContent = "표시할 뉴스가 없습니다";
        catDiv.appendChild(empty);
      } else {
        slice.forEach((it) => catDiv.appendChild(renderItemCard(it)));
      }

      el.newsGrid.appendChild(catDiv);
    });

    // update saved styling/counters
    renderSavedCounters();
  }

  function renderItemCard(it) {
    const isSaved = saved.some((s) => s.id === it.id);
    const div = document.createElement("div");
    div.className = `news-item ${isSaved ? "saved" : ""}`;
    div.setAttribute("data-id", it.id);

    const summary = it.summary || (it.highlights && it.highlights.length ? it.highlights[0] : "");
    const tagsHtml = (it.tags || []).slice(0, 5).map((t) => `<span class="tag">${escapeHtml(t)}</span>`).join("");
    const decision = (it && typeof it.decision === "object" && it.decision) ? it.decision : null;

    const impact = decision && Number.isFinite(Number(decision.impact_score))
      ? Number(decision.impact_score).toFixed(1)
      : "-";
    const confidence = decision && Number.isFinite(Number(decision.confidence))
      ? Number(decision.confidence).toFixed(2)
      : "-";
    const timeSensitivity = decision && decision.time_sensitivity
      ? String(decision.time_sensitivity).toUpperCase()
      : "LOW";
    const nextAction = decision && decision.next_action
      ? String(decision.next_action).trim()
      : "";

    const decisionHtml = decision ? `
      <div class="decision-panel">
        <div class="decision-row">
          <span class="decision-chip">Impact ${escapeHtml(impact)}</span>
          <span class="decision-chip">Confidence ${escapeHtml(confidence)}</span>
          <span class="decision-chip ts-${escapeHtml(timeSensitivity.toLowerCase())}">${escapeHtml(timeSensitivity)}</span>
        </div>
        ${nextAction ? `<div class="decision-next">🧭 ${escapeHtml(nextAction)}</div>` : ""}
      </div>
    ` : "";

    const sourceText = [
      it.source ? `📰 ${it.source}` : "📰",
      it.published_at ? `· ${formatShortKST(it.published_at)}` : "",
      (typeof it.score === "number") ? `· score ${it.score.toFixed(2)}` : "",
    ].filter(Boolean).join(" ");

    div.innerHTML = `
      <div class="news-title">${escapeHtml(it.title)}</div>
      ${summary ? `<div class="news-summary">${escapeHtml(summary)}</div>` : ""}
      ${decisionHtml}
      ${tagsHtml ? `<div class="news-tags">${tagsHtml}</div>` : ""}
      <div class="news-meta">
        <span class="news-source" title="${escapeHtml(sourceText)}">${escapeHtml(sourceText)}</span>
        <div class="news-actions">
          ${it.url
            ? `<button class="action-btn" onclick="WaveTree.openLink('${escapeJs(it.url)}')">열기</button>`
            : `<button class="action-btn" disabled title="원문 링크 없음">링크없음</button>`}
          <button class="action-btn ${isSaved ? "saved-btn" : ""}" onclick="WaveTree.toggleSave('${escapeJs(it.id)}')">
            ${isSaved ? "✓ 저장됨" : "+ 저장"}
          </button>
        </div>
      </div>
    `;
    return div;
  }

  // ---------- Filter/Search/Sort ----------
  function applyFilterSearchSort(items) {
    let out = items.slice();

    // filter
    if (filter !== "all") out = out.filter((it) => it.category === filter);

    // search
    if (q) {
      const needle = q.toLowerCase();
      out = out.filter((it) => {
        const hay = [
          it.title,
          it.summary || "",
          it.source || "",
          (it.tags || []).join(" "),
        ].join(" ").toLowerCase();
        return hay.includes(needle);
      });
    }

    // sort
    out.sort((a, b) => compareBySortMode(a, b, sortMode));
    return out;
  }

  function compareBySortMode(a, b, mode) {
    const pa = a.published_at ? Date.parse(a.published_at) : 0;
    const pb = b.published_at ? Date.parse(b.published_at) : 0;
    const sa = (typeof a.score === "number") ? a.score : -1;
    const sb = (typeof b.score === "number") ? b.score : -1;

    switch (mode) {
      case "published_asc":
        return pa - pb || sb - sa;
      case "score_desc":
        return (sb - sa) || (pb - pa);
      case "score_asc":
        return (sa - sb) || (pb - pa);
      case "source_asc":
        return (a.source || "").localeCompare(b.source || "") || (pb - pa);
      case "published_desc":
      default:
        return (pb - pa) || (sb - sa);
    }
  }

  // ---------- Saved/Scrapbook ----------
  function loadSaved() {
    try {
      const raw = localStorage.getItem(CONFIG.savedStorageKey);
      const arr = raw ? JSON.parse(raw) : [];
      return Array.isArray(arr) ? arr : [];
    } catch {
      return [];
    }
  }

  function persistSaved() {
    localStorage.setItem(CONFIG.savedStorageKey, JSON.stringify(saved));
  }

  function toggleSave(itemId) {
    const it = allItems.find((x) => x.id === itemId);
    if (!it) return;

    const idx = saved.findIndex((s) => s.id === itemId);
    if (idx >= 0) {
      saved.splice(idx, 1);
    } else {
      saved.push({
        id: it.id,
        category: it.category,
        categoryTitle: CATEGORY[it.category]?.title || it.category,
        title: it.title,
        source: it.source,
        url: it.url,
        savedAt: new Date().toISOString(),
      });
    }

    persistSaved();
    renderSavedCounters();
    render(); // refresh saved highlighting
    renderScrapbook();
  }

  function removeSaved(itemId) {
    saved = saved.filter((s) => s.id !== itemId);
    persistSaved();
    renderSavedCounters();
    render();
    renderScrapbook();
  }

  function renderSavedCounters() {
    el.savedCount.textContent = saved.length.toLocaleString();
    el.scrapbookCount.textContent = saved.length.toLocaleString();
  }

  function renderScrapbook() {
    if (!el.scrapbookContent) return;

    if (!saved.length) {
      el.scrapbookContent.innerHTML = '<div class="empty-state">저장된 뉴스가 없습니다</div>';
      return;
    }

    // newest saved first
    const list = saved.slice().sort((a, b) => Date.parse(b.savedAt) - Date.parse(a.savedAt));

    el.scrapbookContent.innerHTML = list.map((s) => `
      <div class="scrapbook-item">
        <div class="scrapbook-category">${escapeHtml(s.categoryTitle || s.category)}</div>
        <div class="scrapbook-title">${escapeHtml(s.title)}</div>
        <div class="scrapbook-date">📅 ${escapeHtml(formatKST(new Date(s.savedAt)))}</div>
        <div style="display:flex; gap:8px; margin-top:10px;">
          ${s.url
            ? `<button class="action-btn" onclick="WaveTree.openLink('${escapeJs(s.url)}')">열기</button>`
            : `<button class="action-btn" disabled title="원문 링크 없음">링크없음</button>`}
          <button class="remove-btn" onclick="WaveTree.removeSaved('${escapeJs(s.id)}')">✕ 삭제</button>
        </div>
      </div>
    `).join("");
  }

  function toggleScrapbook() {
    el.scrapbookPanel.classList.toggle("open");
  }

  function openLink(url) {
    try {
      window.open(url, "_blank", "noopener,noreferrer");
    } catch {}
  }

  // ---------- utils ----------
  function formatKST(date) {
    // browser local time is already KST on 대표님 Mac settings; this keeps it readable.
    const d = (date instanceof Date) ? date : new Date(date);
    const yy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    const hh = String(d.getHours()).padStart(2, "0");
    const mi = String(d.getMinutes()).padStart(2, "0");
    const ss = String(d.getSeconds()).padStart(2, "0");
    return `${yy}.${mm}.${dd} | ${hh}:${mi}:${ss}`;
  }

  function formatShortKST(iso) {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "";
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    const hh = String(d.getHours()).padStart(2, "0");
    const mi = String(d.getMinutes()).padStart(2, "0");
    return `${mm}/${dd} ${hh}:${mi}`;
  }

  function escapeHtml(s) {
    return String(s)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function escapeJs(s) {
    // safe for single-quoted inline handlers
    return String(s).replaceAll("\\", "\\\\").replaceAll("'", "\\'");
  }



})();
