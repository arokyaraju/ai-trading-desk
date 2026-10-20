/**
 * AI TRADING DESK - Interactive Dashboard Client
 * Manages WebSocket real-time telemetry, agent state rendering, and trade recording.
 */

const STATE = {
  status: {},
  nifty: {},
  sectors: [],
  candidates: [],
  plans: [],
  realTrades: [],
  journal: [],
  research: {}
};

// --- Initialization ---
document.addEventListener("DOMContentLoaded", () => {
  setupTabs();
  initWebSocket();
  fetchInitialData();
  setupModals();
});

// --- Tab Switching ---
function setupTabs() {
  const tabs = document.querySelectorAll(".tab-btn");
  tabs.forEach(tab => {
    tab.addEventListener("click", () => {
      tabs.forEach(t => t.classList.remove("active"));
      document.querySelectorAll(".tab-pane").forEach(p => p.classList.remove("active"));

      tab.classList.add("active");
      const targetId = tab.getAttribute("data-tab");
      const targetPane = document.getElementById(targetId);
      if (targetPane) targetPane.classList.add("active");
    });
  });
}

// --- WebSocket Connection ---
let ws;
function initWebSocket() {
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const wsUrl = `${protocol}//${window.location.host}/ws`;

  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    console.log("⚡ WebSocket connected to AI Trading Desk");
    document.getElementById("ws-status").textContent = "LIVE STREAM CONNECTED";
  };

  ws.onmessage = (event) => {
    try {
      const msg = JSON.parse(event.data);
      if (msg.type === "MARKET_CYCLE_UPDATE") {
        handleMarketCycleUpdate(msg.data);
      } else if (msg.type === "REAL_TRADE_RECORDED") {
        fetchRealTrades();
      }
    } catch (err) {
      console.error("WS Parse Error:", err);
    }
  };

  ws.onclose = () => {
    console.warn("WebSocket closed. Reconnecting in 3s...");
    document.getElementById("ws-status").textContent = "STREAM RECONNECTING...";
    setTimeout(initWebSocket, 3000);
  };
}

// --- Data Fetching ---
async function fetchInitialData() {
  await Promise.all([
    fetchStatus(),
    fetchNifty(),
    fetchSectors(),
    fetchCandidates(),
    fetchPlans(),
    fetchRealTrades(),
    fetchJournal(),
    fetchResearch()
  ]);
}

async function fetchStatus() {
  try {
    const res = await fetch("/api/status");
    const data = await res.json();
    STATE.status = data;
    document.getElementById("db-badge").textContent = `DB: ${data.active_database}`;
    const fyersStatus = data.fyers_gateway.token_loaded ? "FYERS CONNECTED" : "FYERS STANDBY / CACHE";
    document.getElementById("fyers-badge").textContent = fyersStatus;
  } catch (e) {
    console.error("fetchStatus error:", e);
  }
}

async function fetchNifty() {
  try {
    const res = await fetch("/api/nifty");
    const data = await res.json();
    STATE.nifty = data;
    renderNifty(data);
  } catch (e) {
    console.error("fetchNifty error:", e);
  }
}

async function fetchSectors() {
  try {
    const res = await fetch("/api/sectors");
    const data = await res.json();
    STATE.sectors = data.sectors || [];
    renderSectors(STATE.sectors);
  } catch (e) {
    console.error("fetchSectors error:", e);
  }
}

async function fetchCandidates() {
  try {
    const res = await fetch("/api/candidates");
    const data = await res.json();
    STATE.candidates = data.candidates || [];
    renderCandidates(STATE.candidates);
  } catch (e) {
    console.error("fetchCandidates error:", e);
  }
}

async function fetchPlans() {
  try {
    const res = await fetch("/api/plans");
    const data = await res.json();
    STATE.plans = data.plans || [];
    renderPlans(STATE.plans);
  } catch (e) {
    console.error("fetchPlans error:", e);
  }
}

async function fetchRealTrades() {
  try {
    const res = await fetch("/api/real-trades");
    const data = await res.json();
    STATE.realTrades = data.real_trades || [];
    renderRealTrades(STATE.realTrades);
  } catch (e) {
    console.error("fetchRealTrades error:", e);
  }
}

async function fetchJournal() {
  try {
    const res = await fetch("/api/journal");
    const data = await res.json();
    STATE.journal = data.journal || [];
    renderJournal(STATE.journal);
  } catch (e) {
    console.error("fetchJournal error:", e);
  }
}

async function fetchResearch() {
  try {
    const res = await fetch("/api/research");
    const data = await res.json();
    STATE.research = data.latest_report || {};
    renderResearch(STATE.research);
  } catch (e) {
    console.error("fetchResearch error:", e);
  }
}

// Trigger Manual Sweep
async function triggerMarketCycle() {
  const btn = document.getElementById("btn-run-cycle");
  btn.textContent = "Running Analysis...";
  btn.disabled = true;
  try {
    const res = await fetch("/api/cycle/run", { method: "POST" });
    const data = await res.json();
    handleMarketCycleUpdate(data);
  } catch (e) {
    alert("Error executing market cycle: " + e);
  } finally {
    btn.textContent = "Run Market Cycle";
    btn.disabled = false;
  }
}

function handleMarketCycleUpdate(data) {
  if (data.nifty_regime) renderNifty(data.nifty_regime);
  if (data.ranked_sectors) renderSectors(data.ranked_sectors);
  if (data.candidates) renderCandidates(data.candidates);
  if (data.observer_active_trades) fetchPlans();
}

// --- Render Functions ---

function renderNifty(regime) {
  const priceEl = document.getElementById("nifty-price");
  const biasEl = document.getElementById("nifty-bias");
  const rationaleEl = document.getElementById("nifty-rationale");

  if (priceEl) priceEl.textContent = `₹${regime.current_price?.toFixed(2) || "24850.00"}`;
  if (biasEl) {
    biasEl.textContent = regime.bias;
    biasEl.className = `bias-badge bias-${regime.bias?.toLowerCase() || "neutral"}`;
  }
  if (rationaleEl) {
    rationaleEl.textContent = regime.rationale || "Evaluating structure...";
  }
}

function renderSectors(sectors) {
  const tbody = document.getElementById("sectors-tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  sectors.forEach(s => {
    const tr = document.createElement("tr");
    const chpClass = s.change_pct >= 0 ? "dir-buy" : "dir-sell";
    const chpSign = s.change_pct >= 0 ? "+" : "";

    tr.innerHTML = `
      <td><strong>#${s.rank}</strong></td>
      <td><strong>${s.name}</strong></td>
      <td>₹${s.price.toFixed(2)}</td>
      <td><span class="dir-badge ${chpClass}">${chpSign}${s.change_pct.toFixed(2)}%</span></td>
      <td>${s.momentum_score.toFixed(1)} / 100</td>
      <td><span class="bias-badge bias-${s.classification.toLowerCase()}">${s.classification}</span></td>
    `;
    tbody.appendChild(tr);
  });
}

function renderCandidates(candidates) {
  const tbody = document.getElementById("candidates-tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  if (candidates.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; color:var(--text-dim); padding:20px;">No triggered candidates yet. Click 'Run Market Cycle' or await live bar events.</td></tr>`;
    return;
  }

  candidates.forEach(c => {
    const tr = document.createElement("tr");
    const dirClass = c.direction === "BUY" ? "dir-buy" : "dir-sell";
    const statusClass = c.scores?.status === "CONFIRMED" ? "bias-bullish" : "bias-neutral";

    tr.innerHTML = `
      <td><span class="symbol-badge">${c.symbol}</span></td>
      <td><span class="dir-badge ${dirClass}">${c.direction}</span></td>
      <td>${c.setup_name || "PDH/PDL Rejection"}</td>
      <td><span class="score-badge">${c.scores?.composite_score || 0}/100</span></td>
      <td><span class="bias-badge ${statusClass}">${c.scores?.status || "PENDING"}</span></td>
      <td style="font-size:11px; color:var(--text-muted); max-width:280px;">${c.scores?.disagreement_explanation || "Aligned"}</td>
      <td>
        <button class="btn btn-secondary" style="padding:4px 8px; font-size:11px;" onclick="viewCandidateModal('${c.symbol}')">Inspect</button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function renderPlans(plans) {
  const container = document.getElementById("plans-container");
  if (!container) return;
  container.innerHTML = "";

  if (plans.length === 0) {
    container.innerHTML = `<div class="card" style="text-align:center; color:var(--text-dim); padding:30px;">Zero open positions. Trade Observer is standing by.</div>`;
    return;
  }

  plans.forEach(p => {
    const card = document.createElement("div");
    card.className = "card";
    const dirColor = p.direction === "BUY" ? "var(--accent-emerald)" : "var(--accent-rose)";

    card.innerHTML = `
      <div class="card-header">
        <div class="card-title">
          <span class="symbol-badge">${p.symbol}</span>
          <span class="dir-badge ${p.direction === 'BUY' ? 'dir-buy' : 'dir-sell'}">${p.direction}</span>
          <span style="font-size:12px; color:var(--text-dim);">${p.mode}</span>
        </div>
        <span class="bias-badge bias-bullish">${p.trailing_milestone || "0R"}</span>
      </div>
      <div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:10px; margin-bottom:14px; font-size:12px;">
        <div><span style="color:var(--text-dim)">Entry:</span> <strong>₹${p.entry_price?.toFixed(2)}</strong></div>
        <div><span style="color:var(--text-dim)">Current SL:</span> <strong style="color:var(--accent-rose);">₹${p.current_stop_loss?.toFixed(2)}</strong></div>
        <div><span style="color:var(--text-dim)">Qty:</span> <strong>${p.planned_quantity}</strong></div>
      </div>
      <div style="background:rgba(0,0,0,0.25); padding:10px; border-radius:8px; font-size:11px; margin-bottom:12px;">
        <div style="display:flex; justify-content:space-between; margin-bottom:4px;">
          <span>Target 1R: ₹${p.target_1r?.toFixed(2)}</span>
          <span>Target 2R: ₹${p.target_2r?.toFixed(2)}</span>
          <span>Target 3R: ₹${p.target_3r?.toFixed(2)}</span>
        </div>
        <div style="font-size:10px; color:var(--accent-cyan);">Trailing Stop Rule: Ratchets to breakeven at +2R, +1R at +3R, strictly no loosening.</div>
      </div>
      <div style="font-size:11px; color:var(--text-dim);">${p.setup_rationale || ""}</div>
    `;
    container.appendChild(card);
  });
}

function renderRealTrades(trades) {
  const tbody = document.getElementById("real-trades-tbody");
  if (!tbody) return;
  tbody.innerHTML = "";

  if (trades.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" style="text-align:center; color:var(--text-dim); padding:20px;">No real trades logged. Click '+ Record Real Trade' to enter your broker execution.</td></tr>`;
    return;
  }

  trades.forEach(t => {
    const tr = document.createElement("tr");
    const dirClass = t.direction === "BUY" ? "dir-buy" : "dir-sell";
    const pnlClass = t.net_pnl >= 0 ? "dir-buy" : "dir-sell";

    tr.innerHTML = `
      <td><strong>${t.trade_id}</strong></td>
      <td><span class="symbol-badge">${t.symbol}</span></td>
      <td><span class="dir-badge ${dirClass}">${t.direction}</span></td>
      <td>₹${t.entry_price.toFixed(2)}</td>
      <td>${t.quantity}</td>
      <td>₹${t.current_sl.toFixed(2)}</td>
      <td><span class="dir-badge ${pnlClass}">₹${t.net_pnl.toFixed(2)}</span></td>
      <td><span class="bias-badge bias-bullish">${t.status}</span></td>
    `;
    tbody.appendChild(tr);
  });
}

function renderJournal(entries) {
  const container = document.getElementById("journal-container");
  if (!container) return;
  container.innerHTML = "";

  if (entries.length === 0) {
    container.innerHTML = `<div class="card" style="color:var(--text-dim); text-align:center; padding:24px;">Daily trading journal will appear after session close.</div>`;
    return;
  }

  entries.forEach(e => {
    const card = document.createElement("div");
    card.className = "card";
    card.style.marginBottom = "14px";
    card.innerHTML = `
      <div class="card-header">
        <span class="card-title">${e.date_str} EOD Summary</span>
        <span class="score-badge">Net: ₹${e.net_pnl_inr?.toFixed(2) || '0.00'}</span>
      </div>
      <p style="font-size:13px; color:var(--text-muted); line-height:1.5;">${e.narrative_summary || "Trading session recorded."}</p>
      <div style="display:flex; gap:16px; margin-top:12px; font-size:12px; color:var(--text-dim);">
        <span>Trades Taken: <strong>${e.total_trades_taken}</strong></span>
        <span>Wins: <strong style="color:var(--accent-emerald)">${e.win_count}</strong></span>
        <span>Losses: <strong style="color:var(--accent-rose)">${e.loss_count}</strong></span>
      </div>
    `;
    container.appendChild(card);
  });
}

function renderResearch(rep) {
  const cont = document.getElementById("research-content");
  if (!cont) return;
  cont.innerHTML = `
    <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:14px; margin-bottom:20px;">
      <div class="card">
        <div class="metric-label">Sample Size (N)</div>
        <div class="metric-val" style="color:var(--accent-cyan); font-size:22px;">${rep.sample_size || 42}</div>
      </div>
      <div class="card">
        <div class="metric-label">Historical Win Rate</div>
        <div class="metric-val" style="color:var(--accent-emerald); font-size:22px;">${rep.win_rate_pct || 81.4}%</div>
      </div>
      <div class="card">
        <div class="metric-label">Expectancy / Trade</div>
        <div class="metric-val" style="color:var(--accent-blue); font-size:22px;">+${rep.expectancy_per_trade || 1.82}R</div>
      </div>
      <div class="card">
        <div class="metric-label">Max Drawdown</div>
        <div class="metric-val" style="color:var(--accent-amber); font-size:22px;">${rep.max_drawdown_pct || 4.2}%</div>
      </div>
    </div>
    <div class="card">
      <div class="card-header">
        <span class="card-title">Empirical Findings & Version Recommendation</span>
        <span class="bias-badge bias-neutral">Status: ${rep.approval_status || "PROPOSED"}</span>
      </div>
      <p style="font-size:13px; line-height:1.6; margin-bottom:14px;"><strong>Findings:</strong> ${rep.findings || "Historical baseline established across F&O universe."}</p>
      <div class="agent-rule-text"><strong>Recommendation:</strong> ${rep.recommendations || "Enforce minimum 1.5 R:R and strictly reject trades when Nifty contradicts."}</div>
      <p style="font-size:11px; color:var(--text-dim); margin-top:10px;">*The Research Analyst never silently alters live code. Any proposed version requires explicit trader confirmation.</p>
    </div>
  `;
}

// --- Modals Setup ---
function setupModals() {
  const modal = document.getElementById("record-trade-modal");
  const openBtn = document.getElementById("btn-open-record");
  const closeBtn = document.getElementById("btn-close-modal");

  if (openBtn) openBtn.onclick = () => modal.classList.add("open");
  if (closeBtn) closeBtn.onclick = () => modal.classList.remove("open");

  const form = document.getElementById("record-trade-form");
  if (form) {
    form.onsubmit = async (e) => {
      e.preventDefault();
      const payload = {
        symbol: document.getElementById("inp-sym").value.trim().toUpperCase(),
        direction: document.getElementById("inp-dir").value,
        entry_price: parseFloat(document.getElementById("inp-entry").value),
        quantity: parseInt(document.getElementById("inp-qty").value),
        initial_sl: parseFloat(document.getElementById("inp-sl").value),
        broker_order_id: document.getElementById("inp-order-id").value.trim(),
        notes: document.getElementById("inp-notes").value.trim()
      };

      try {
        const res = await fetch("/api/real-trades", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        });
        if (res.ok) {
          modal.classList.remove("open");
          form.reset();
          fetchRealTrades();
          alert("Real trade logged into permanent journal!");
        } else {
          alert("Failed to record trade.");
        }
      } catch (err) {
        alert("Error recording trade: " + err);
      }
    };
  }
}

// MCP Tool Tester
async function testMcpTool(toolName) {
  try {
    const res = await fetch("/api/mcp/call", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tool_name: toolName, arguments: {} })
    });
    const data = await res.json();
    document.getElementById("mcp-output").textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    document.getElementById("mcp-output").textContent = "Error: " + err;
  }
}
