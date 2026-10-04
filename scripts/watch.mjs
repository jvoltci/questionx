/**
 * QUESTIONX & FORMULA X: LIVE WATCH
 * Internal talent telemetry, candidate scouting, and real-time student mastery monitor.
 *
 * Runs locally on http://127.0.0.1:4173 and LAN address for mobile check.
 * Streams live telemetry events from Cloudflare Workers (Padhai and Revision) or direct POSTs.
 * Separates real studious thinkers from mechanical churners for talent scouting.
 */

import { createServer } from "node:http";
import { networkInterfaces } from "node:os";
import { spawn } from "node:child_process";
import {
  createWriteStream,
  mkdirSync,
  readdirSync,
  unlinkSync,
  readFileSync,
  writeFileSync,
  existsSync,
} from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Port and network binding
const PORT = Number(process.env.QX_WATCH_PORT || process.env.PF_WATCH_PORT || 4173);
const BIND = process.env.QX_WATCH_BIND || "0.0.0.0";

const lanIp = () => {
  for (const list of Object.values(networkInterfaces())) {
    for (const i of list ?? []) {
      if (i.family === "IPv4" && !i.internal && !i.address.startsWith("169.254.")) {
        return i.address;
      }
    }
  }
  return null;
};

const LAN = lanIp();
const LAN_URL = LAN ? `http://${LAN}:${PORT}` : "";
const LOCAL_URL = `http://127.0.0.1:${PORT}`;

// Storage paths
const LOG_DIR = join(__dirname, "../logs");
mkdirSync(LOG_DIR, { recursive: true });

const KEEP_DAYS = 7;
const dayKey = (d = new Date()) => d.toISOString().slice(0, 10);
let logStream = null;
let logStreamDay = "";

function getLogStream() {
  const day = dayKey();
  if (logStream && logStreamDay === day) return logStream;
  if (logStream) logStream.end();
  logStreamDay = day;
  logStream = createWriteStream(join(LOG_DIR, `telemetry-${day}.jsonl`), { flags: "a" });
  logStream.on("error", () => {});
  return logStream;
}

function pruneLogs() {
  try {
    const cutoff = dayKey(new Date(Date.now() - KEEP_DAYS * 864e5));
    for (const f of readdirSync(LOG_DIR)) {
      const m = /^telemetry-(\d{4}-\d{2}-\d{2})\.jsonl$/.exec(f);
      if (m && m[1] < cutoff) {
        unlinkSync(join(LOG_DIR, f));
      }
    }
  } catch {}
}
pruneLogs();
setInterval(pruneLogs, 3600000);

// Scouted candidates roster path
const CANDIDATES_FILE = join(LOG_DIR, "scouted_candidates.jsonl");

// Geo cache
const GEO = new Map();
async function resolveLocation(ip, hintCity, hintCountry) {
  if (hintCity && hintCountry) {
    return `${hintCity}, ${hintCountry}`;
  }
  if (!ip || ip === "127.0.0.1" || ip === "::1" || ip.startsWith("192.168.") || ip.startsWith("10.")) {
    return "Local Network";
  }
  if (GEO.has(ip)) return GEO.get(ip);
  GEO.set(ip, null);
  try {
    const res = await fetch(`http://ip-api.com/json/${encodeURIComponent(ip)}?fields=status,city,countryCode`, {
      signal: AbortSignal.timeout(3000),
    });
    if (res.ok) {
      const data = await res.json();
      if (data.status === "success") {
        const loc = [data.city, data.countryCode].filter(Boolean).join(", ");
        GEO.set(ip, loc);
        return loc;
      }
    }
  } catch {}
  return "Unknown Location";
}

// In-memory student registry and recent events buffer
const students = new Map();
const recentEvents = [];
const MAX_RECENT_EVENTS = 200;

// Load past candidates if file exists
function loadSavedCandidates() {
  if (!existsSync(CANDIDATES_FILE)) return;
  try {
    const lines = readFileSync(CANDIDATES_FILE, "utf8").split("\n").filter(Boolean);
    for (const line of lines) {
      try {
        const cand = JSON.parse(line);
        if (cand && cand.student_id) {
          students.set(cand.student_id, {
            ...cand,
            recent_logs: cand.recent_logs || [],
          });
        }
      } catch {}
    }
  } catch {}
}
loadSavedCandidates();

// Calculate student archetype and scout score
function evaluateStudent(s) {
  const accuracy = s.questions_attempted > 0 ? (s.correct_answers / s.questions_attempted) * 100 : 0;
  const avgDwell = s.dwell_count > 0 ? Math.round(s.total_dwell_seconds / s.dwell_count) : 0;
  s.avg_dwell_seconds = avgDwell;

  // Archetype logic
  if (s.questions_attempted >= 3) {
    if (accuracy >= 75 && avgDwell >= 30 && (s.derivations_viewed >= 1 || s.best_streak >= 4)) {
      s.archetype = "Deep Thinker";
    } else if (accuracy >= 60 && avgDwell >= 20) {
      s.archetype = "Methodical Solver";
    } else if (avgDwell < 12 && s.derivations_viewed === 0) {
      s.archetype = "Rote Churner";
    } else if (avgDwell < 6 && accuracy < 50) {
      s.archetype = "Quick Guesser";
    } else {
      s.archetype = "Explorer";
    }
  } else if (s.derivations_viewed >= 2) {
    s.archetype = "Deep Thinker";
  } else {
    s.archetype = "Explorer";
  }

  // Scouting Score calculation (0 to 100)
  // Accuracy weight: 35 points
  const accScore = Math.min(35, (accuracy / 100) * 35);
  // Dwell quality: 30 points (optimum 45 to 90 seconds)
  let dwellScore = 0;
  if (avgDwell >= 35 && avgDwell <= 120) {
    dwellScore = 30;
  } else if (avgDwell >= 20) {
    dwellScore = 20;
  } else if (avgDwell > 0) {
    dwellScore = 10;
  }
  // Derivations depth: 20 points
  const derivScore = Math.min(20, s.derivations_viewed * 10);
  // Streak factor: 15 points
  const streakScore = Math.min(15, s.best_streak * 3);

  const rawScore = Math.round(accScore + dwellScore + derivScore + streakScore);
  s.scout_score = Math.min(100, rawScore);

  if (s.scout_score >= 78) {
    s.candidate_status = "Top Talent";
  } else if (s.scout_score >= 60) {
    s.candidate_status = "Strong Potential";
  } else if (s.scout_score >= 40) {
    s.candidate_status = "Developing";
  } else {
    s.candidate_status = "Standard";
  }

  // Persist high signal candidates to file
  if (s.candidate_status === "Top Talent" || s.candidate_status === "Strong Potential") {
    saveCandidateToRoster(s);
  }
}

function saveCandidateToRoster(candidate) {
  try {
    let existing = [];
    if (existsSync(CANDIDATES_FILE)) {
      const lines = readFileSync(CANDIDATES_FILE, "utf8").split("\n").filter(Boolean);
      for (const line of lines) {
        try {
          const item = JSON.parse(line);
          if (item.student_id !== candidate.student_id) existing.push(item);
        } catch {}
      }
    }
    const cleanCandidate = { ...candidate, recent_logs: candidate.recent_logs.slice(-10) };
    existing.push(cleanCandidate);
    existing.sort((a, b) => b.scout_score - a.scout_score);
    const content = existing.map((c) => JSON.stringify(c)).join("\n") + "\n";
    writeFileSync(CANDIDATES_FILE, content, "utf8");
  } catch {}
}

// Ingest single telemetry event
async function ingestEvent(raw, clientIp) {
  const now = Date.now();
  const evtName = raw.event || "unknown_event";
  const studentId = raw.student_id || "anonymous_student";
  const sessionId = raw.session_id || "unknown_session";
  const props = raw.properties || {};
  const ip = raw.ip || clientIp || "";
  const location = await resolveLocation(ip, raw.city, raw.country);

  let profile = students.get(studentId);
  if (!profile) {
    profile = {
      student_id: studentId,
      app: props.app || "padhai",
      location,
      first_seen: now,
      last_seen: now,
      total_events: 0,
      questions_attempted: 0,
      correct_answers: 0,
      best_streak: 0,
      current_streak: 0,
      total_dwell_seconds: 0,
      dwell_count: 0,
      avg_dwell_seconds: 0,
      derivations_viewed: 0,
      latex_copies: 0,
      searches_count: 0,
      subjects: {},
      archetype: "Explorer",
      scout_score: 0,
      candidate_status: "Standard",
      recent_logs: [],
    };
    students.set(studentId, profile);
  }

  profile.last_seen = now;
  profile.total_events++;
  if (location !== "Local Network" && location !== "Unknown Location") {
    profile.location = location;
  }
  if (props.app) profile.app = props.app;

  // Event specific logic
  if (evtName === "question_answered") {
    if (props.is_new_answer !== false) {
      profile.questions_attempted++;
      if (props.is_correct) profile.correct_answers++;
    }
    if (props.dwell_seconds) {
      profile.total_dwell_seconds += Number(props.dwell_seconds);
      profile.dwell_count++;
    }
    if (props.subject) {
      profile.subjects[props.subject] = (profile.subjects[props.subject] || 0) + 1;
    }
    if (props.streak_at_answer) {
      profile.current_streak = props.streak_at_answer;
      if (props.streak_at_answer > profile.best_streak) {
        profile.best_streak = props.streak_at_answer;
      }
    }
  } else if (evtName === "quiz_completed") {
    if (props.correct) profile.correct_answers = Math.max(profile.correct_answers, props.correct);
    if (props.answered) profile.questions_attempted = Math.max(profile.questions_attempted, props.answered);
    if (props.best_streak) profile.best_streak = Math.max(profile.best_streak, props.best_streak);
    if (props.avg_dwell_seconds && profile.dwell_count === 0) {
      profile.total_dwell_seconds = props.avg_dwell_seconds * (props.answered || 1);
      profile.dwell_count = props.answered || 1;
    }
  } else if (evtName === "derivation_expanded") {
    profile.derivations_viewed++;
    if (props.subject) {
      profile.subjects[props.subject] = (profile.subjects[props.subject] || 0) + 1;
    }
  } else if (evtName === "latex_copied") {
    profile.latex_copies++;
  } else if (evtName === "formula_searched") {
    profile.searches_count++;
  } else if (evtName === "streak_milestone") {
    if (props.streak && props.streak > profile.best_streak) {
      profile.best_streak = props.streak;
    }
  }

  evaluateStudent(profile);

  const fullEvent = {
    id: "evt_" + Math.random().toString(36).substring(2, 10),
    timestamp: now,
    event: evtName,
    student_id: studentId,
    session_id: sessionId,
    location: profile.location,
    app: profile.app,
    archetype: profile.archetype,
    scout_score: profile.scout_score,
    properties: props,
  };

  profile.recent_logs.push(fullEvent);
  if (profile.recent_logs.length > 30) profile.recent_logs.shift();

  recentEvents.unshift(fullEvent);
  if (recentEvents.length > MAX_RECENT_EVENTS) recentEvents.pop();

  // Write to daily telemetry log
  try {
    const stream = getLogStream();
    stream.write(JSON.stringify(fullEvent) + "\n");
  } catch {}

  // Broadcast to live SSE clients
  broadcast({
    type: "event",
    event: fullEvent,
    student: profile,
    summary: getSystemSummary(),
  });
}

function getSystemSummary() {
  const now = Date.now();
  const tenMinsAgo = now - 600000;
  let activeCount = 0;
  let deepThinkerCount = 0;
  let totalQuestions = 0;
  let totalDerivations = 0;
  let topCandidatesCount = 0;

  for (const s of students.values()) {
    if (s.last_seen >= tenMinsAgo) activeCount++;
    if (s.archetype === "Deep Thinker" || s.archetype === "Methodical Solver") deepThinkerCount++;
    totalQuestions += s.questions_attempted;
    totalDerivations += s.derivations_viewed;
    if (s.candidate_status === "Top Talent" || s.candidate_status === "Strong Potential") {
      topCandidatesCount++;
    }
  }

  const studiousRatio = activeCount > 0 ? Math.round((deepThinkerCount / Math.max(1, students.size)) * 100) : 0;

  return {
    active_students: activeCount,
    total_students_tracked: students.size,
    studious_ratio: studiousRatio,
    total_questions: totalQuestions,
    total_derivations: totalDerivations,
    scouted_candidates: topCandidatesCount,
  };
}

// SSE Connection Management
const sseClients = new Set();

function broadcast(obj) {
  const line = `data: ${JSON.stringify(obj)}\n\n`;
  for (const res of [...sseClients]) {
    try {
      if (res.writableEnded || res.destroyed) {
        sseClients.delete(res);
      } else {
        res.write(line);
      }
    } catch {
      sseClients.delete(res);
    }
  }
}

// Start Cloudflare Wrangler tailers for live Workers
function startWranglerTail(workerName, cwdPath) {
  const child = spawn("npx", ["wrangler", "tail", workerName, "--format=json"], {
    cwd: cwdPath,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let buf = "";
  child.stdout.on("data", (d) => {
    buf += d.toString();
    let idx;
    while ((idx = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, idx).trim();
      buf = buf.slice(idx + 1);
      if (!line) continue;
      try {
        const payload = JSON.parse(line);
        if (payload.logs && Array.isArray(payload.logs)) {
          for (const l of payload.logs) {
            const msg = (l.message || []).join(" ");
            if (msg.includes("[STUDENT_TELEMETRY]")) {
              const jsonStr = msg.replace(/.*\[STUDENT_TELEMETRY\]\s*/, "");
              const eventData = JSON.parse(jsonStr);
              if (eventData.events && Array.isArray(eventData.events)) {
                for (const ev of eventData.events) {
                  ingestEvent({
                    ...ev,
                    student_id: eventData.student_id || ev.student_id,
                    ip: eventData.ip,
                    city: eventData.city,
                    country: eventData.country,
                  });
                }
              } else {
                ingestEvent(eventData);
              }
            }
          }
        }
      } catch {}
    }
  });

  child.on("error", () => {});
  child.on("exit", () => {
    setTimeout(() => startWranglerTail(workerName, cwdPath), 6000);
  });
}

// Start tailing both live Workers
const qxWebDir = join(__dirname, "../web");
const formulaWebDir = join(__dirname, "../../formulax/web");

if (existsSync(qxWebDir)) startWranglerTail("padhai", qxWebDir);
if (existsSync(formulaWebDir)) startWranglerTail("revision", formulaWebDir);

// Defensive exception handling
process.on("uncaughtException", (err) => console.error("Watcher survived error:", err?.message || err));
process.on("unhandledRejection", (err) => console.error("Watcher survived rejection:", err?.message || err));

// Dashboard Single-Page HTML
const DASHBOARD_HTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>QuestionX & Revision: Live Talent Telemetry Watch</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    :root {
      --bg: #05070a;
      --card-bg: rgba(255, 255, 255, 0.035);
      --card-border: rgba(255, 255, 255, 0.08);
      --ink: #e7ece9;
      --dim: #7f8a86;
      --gold: #e8a04a;
      --purple: #8a7ef7;
      --good: #5bb98c;
      --danger: #ef4444;
      --cyan: #38bdf8;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: radial-gradient(ellipse 80% 60% at 50% 0%, #121720 0%, #05070a 70%);
      color: var(--ink);
      font: 13px/1.45 ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      min-height: 100vh;
      padding: 20px;
    }
    header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 24px;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--card-border);
      flex-wrap: wrap;
      gap: 12px;
    }
    .brand-title {
      font: 800 15px/1.2 system-ui, sans-serif;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--gold);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .brand-sub {
      color: var(--dim);
      font-size: 11px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-top: 4px;
    }
    .endpoint-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid var(--card-border);
      border-radius: 9999px;
      font-size: 11px;
      color: var(--ink);
    }
    .pulse-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--good);
      box-shadow: 0 0 8px var(--good);
      animation: pulse 2s infinite;
    }
    @keyframes pulse { 0%,100%{opacity:1;} 50%{opacity:0.3;} }

    /* Metric Cards */
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
      gap: 12px;
      margin-bottom: 24px;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 10px;
      padding: 14px 16px;
      position: relative;
    }
    .card-k {
      font-size: 10px;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      color: var(--dim);
    }
    .card-v {
      font: 700 28px/1.1 system-ui, sans-serif;
      margin-top: 6px;
      color: var(--ink);
      font-variant-numeric: tabular-nums;
    }
    .card-sub {
      font-size: 11px;
      color: var(--dim);
      margin-top: 4px;
    }

    /* Tabs */
    .tabs {
      display: flex;
      gap: 8px;
      margin-bottom: 16px;
      border-bottom: 1px solid var(--card-border);
      padding-bottom: 10px;
    }
    .tab {
      background: transparent;
      border: 1px solid var(--card-border);
      color: var(--dim);
      padding: 7px 16px;
      border-radius: 9999px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.06em;
      cursor: pointer;
      text-transform: uppercase;
      font-family: inherit;
    }
    .tab.active {
      background: rgba(232, 160, 74, 0.14);
      color: var(--gold);
      border-color: var(--gold);
    }

    /* Panels */
    .panel { display: none; }
    .panel.active { display: block; }

    /* Tables */
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
    }
    th {
      text-align: left;
      padding: 10px 12px;
      font-size: 10px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--dim);
      border-bottom: 1px solid var(--card-border);
    }
    td {
      padding: 10px 12px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
      vertical-align: middle;
    }
    tr:hover td {
      background: rgba(255, 255, 255, 0.02);
    }

    /* Badges */
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 3px 8px;
      border-radius: 9999px;
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }
    .badge-top { background: rgba(232, 160, 74, 0.18); color: var(--gold); border: 1px solid rgba(232, 160, 74, 0.4); }
    .badge-strong { background: rgba(91, 185, 140, 0.18); color: var(--good); border: 1px solid rgba(91, 185, 140, 0.4); }
    .badge-thinker { background: rgba(138, 126, 247, 0.18); color: var(--purple); border: 1px solid rgba(138, 126, 247, 0.4); }
    .badge-labor { background: rgba(239, 68, 68, 0.14); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }
    .badge-dim { background: rgba(255, 255, 255, 0.08); color: var(--dim); }

    /* Live feed */
    .feed-container {
      max-height: 520px;
      overflow-y: auto;
      border: 1px solid var(--card-border);
      border-radius: 10px;
      background: rgba(0, 0, 0, 0.2);
    }
    .feed-row {
      display: grid;
      grid-template-columns: 80px 140px 130px 110px 1fr 60px;
      gap: 10px;
      padding: 9px 12px;
      align-items: center;
      border-bottom: 1px solid rgba(255, 255, 255, 0.03);
      cursor: pointer;
      font-size: 11.5px;
    }
    .feed-row:hover {
      background: rgba(255, 255, 255, 0.04);
    }
    .feed-time { color: var(--dim); }
    .feed-event { font-weight: 700; color: var(--cyan); }
    .feed-loc { color: #cbd5e1; }
    .feed-details {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      color: #94a3b8;
    }

    /* Log Drawer / Modal */
    .drawer-overlay {
      display: none;
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0, 0, 0, 0.75);
      z-index: 100;
      backdrop-filter: blur(4px);
    }
    .drawer {
      position: fixed;
      right: 0; top: 0; bottom: 0;
      width: min(600px, 92vw);
      background: #090d14;
      border-left: 1px solid var(--card-border);
      z-index: 101;
      padding: 24px;
      display: flex;
      flex-direction: column;
      box-shadow: -10px 0 30px rgba(0,0,0,0.6);
    }
    .drawer-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--card-border);
    }
    .drawer-title { font-size: 14px; font-weight: 800; color: var(--gold); }
    .drawer-close {
      background: transparent;
      border: 1px solid var(--card-border);
      color: var(--dim);
      padding: 4px 10px;
      border-radius: 6px;
      cursor: pointer;
    }
    .drawer-body {
      flex: 1;
      overflow-y: auto;
    }
    pre.json-view {
      background: #040609;
      border: 1px solid rgba(255,255,255,0.06);
      padding: 14px;
      border-radius: 8px;
      font-size: 11px;
      color: #a5f3fc;
      overflow-x: auto;
      white-space: pre-wrap;
      word-break: break-all;
    }
    .btn-action {
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid var(--card-border);
      color: var(--ink);
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 11px;
      cursor: pointer;
      font-family: inherit;
    }
    .btn-action:hover {
      background: rgba(255, 255, 255, 0.15);
    }
  </style>
</head>
<body>
  <header>
    <div>
      <div class="brand-title">
        <span>⚡</span> QuestionX &amp; Formula X Ecosystem Watch
      </div>
      <div class="brand-sub">Real-Time Student Cognitive Telemetry &amp; Talent Scouting Engine</div>
    </div>
    <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
      <div class="endpoint-pill">
        <div class="pulse-dot"></div>
        <span>Live: ${LOCAL_URL}</span>
      </div>
      ${LAN_URL ? `<div class="endpoint-pill" title="Open on mobile phone on same Wi-Fi"><span>📱 LAN: ${LAN_URL}</span></div>` : ""}
    </div>
  </header>

  <!-- Metric Cards -->
  <div class="grid">
    <div class="card">
      <div class="card-k">Active Right Now</div>
      <div class="card-v" id="kpi-active">0</div>
      <div class="card-sub">Students in last 10 minutes</div>
    </div>
    <div class="card">
      <div class="card-k">Real Studious Ratio</div>
      <div class="card-v" style="color: var(--purple);" id="kpi-studious">0%</div>
      <div class="card-sub">Deep thinkers vs rote churners</div>
    </div>
    <div class="card">
      <div class="card-k">Scouted Candidates</div>
      <div class="card-v" style="color: var(--gold);" id="kpi-candidates">0</div>
      <div class="card-sub">Flagged for direct recruitment</div>
    </div>
    <div class="card">
      <div class="card-k">Derivations Studied</div>
      <div class="card-v" style="color: var(--good);" id="kpi-derivations">0</div>
      <div class="card-sub">Deep conceptual proof reads</div>
    </div>
  </div>

  <!-- Navigation Tabs -->
  <div class="tabs">
    <button class="tab active" data-tab="feed">Live Event Stream</button>
    <button class="tab" data-tab="scouted">Scouted Talent Roster</button>
    <button class="tab" data-tab="students">All Student Profiles</button>
  </div>

  <!-- Panel 1: Live Event Stream -->
  <div class="panel active" id="panel-feed">
    <div class="card" style="margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center;">
      <span style="font-size: 11px; color: var(--dim);">Streaming incoming telemetry events. Click any row to inspect raw payload.</span>
      <span style="font-size: 11px; color: var(--dim);" id="feed-counter">0 events</span>
    </div>
    <div class="feed-container">
      <div id="feed-rows"></div>
    </div>
  </div>

  <!-- Panel 2: Scouted Talent Roster -->
  <div class="panel" id="panel-scouted">
    <div class="card" style="padding: 0; overflow-x: auto;">
      <table>
        <thead>
          <tr>
            <th>Candidate ID</th>
            <th>Location</th>
            <th>Cognitive Archetype</th>
            <th>Accuracy</th>
            <th>Avg Dwell Time</th>
            <th>Derivations</th>
            <th>Best Streak</th>
            <th>Talent Score</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody id="scouted-tbody">
          <tr><td colspan="9" style="text-align: center; color: var(--dim); padding: 24px;">No candidates scouted yet. As students practice, high-signal profiles will appear here.</td></tr>
        </tbody>
      </table>
    </div>
  </div>

  <!-- Panel 3: All Student Profiles -->
  <div class="panel" id="panel-students">
    <div class="card" style="padding: 0; overflow-x: auto;">
      <table>
        <thead>
          <tr>
            <th>Student ID</th>
            <th>App</th>
            <th>Location</th>
            <th>Questions</th>
            <th>Accuracy</th>
            <th>Avg Dwell</th>
            <th>Derivations</th>
            <th>Archetype</th>
            <th>Last Active</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody id="students-tbody"></tbody>
      </table>
    </div>
  </div>

  <!-- Slide-out Drawer for Payload Inspection -->
  <div class="drawer-overlay" id="drawer-overlay"></div>
  <div class="drawer" id="drawer" style="display: none;">
    <div class="drawer-header">
      <div class="drawer-title" id="drawer-title">Event Inspection</div>
      <button class="drawer-close" id="drawer-close">✕ Close</button>
    </div>
    <div class="drawer-body">
      <div style="margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center;">
        <span style="font-size: 11px; color: var(--dim);" id="drawer-sub">Raw Telemetry Object</span>
        <button class="btn-action" id="copy-json-btn">Copy JSON</button>
      </div>
      <pre class="json-view" id="drawer-json"></pre>
    </div>
  </div>

  <script>
    const events = [];
    const studentsMap = new Map();
    let currentPayload = null;

    // Tabs switching
    document.querySelectorAll('.tab').forEach(t => {
      t.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
        t.classList.add('active');
        document.getElementById('panel-' + t.dataset.tab).classList.add('active');
      });
    });

    // Drawer modal
    const drawer = document.getElementById('drawer');
    const drawerOverlay = document.getElementById('drawer-overlay');
    const drawerClose = document.getElementById('drawer-close');
    const drawerTitle = document.getElementById('drawer-title');
    const drawerJson = document.getElementById('drawer-json');

    function openDrawer(title, data) {
      currentPayload = data;
      drawerTitle.textContent = title;
      drawerJson.textContent = JSON.stringify(data, null, 2);
      drawer.style.display = 'flex';
      drawerOverlay.style.display = 'block';
    }

    function closeDrawer() {
      drawer.style.display = 'none';
      drawerOverlay.style.display = 'none';
    }

    drawerClose.addEventListener('click', closeDrawer);
    drawerOverlay.addEventListener('click', closeDrawer);

    document.getElementById('copy-json-btn').addEventListener('click', () => {
      if (!currentPayload) return;
      navigator.clipboard.writeText(JSON.stringify(currentPayload, null, 2));
      const btn = document.getElementById('copy-json-btn');
      btn.textContent = '✓ Copied';
      setTimeout(() => btn.textContent = 'Copy JSON', 1500);
    });

    function formatTime(ts) {
      const d = new Date(ts);
      return d.toTimeString().split(' ')[0];
    }

    function renderFeedRow(evt) {
      const row = document.createElement('div');
      row.className = 'feed-row';
      const timeStr = formatTime(evt.timestamp);
      
      let badgeClass = 'badge-dim';
      if (evt.archetype === 'Deep Thinker') badgeClass = 'badge-thinker';
      else if (evt.archetype === 'Methodical Solver') badgeClass = 'badge-strong';
      else if (evt.archetype === 'Rote Churner') badgeClass = 'badge-labor';

      let details = '';
      if (evt.event === 'question_answered') {
        details = (evt.properties.subject || '') + ' Q: ' + (evt.properties.is_correct ? '✓ Correct' : '✕ Incorrect') + ' (' + (evt.properties.dwell_seconds || 0) + 's dwell)';
      } else if (evt.event === 'derivation_expanded') {
        details = 'Read proof: ' + (evt.properties.formula_title || evt.properties.formula_id || '');
      } else if (evt.event === 'quiz_completed') {
        details = 'Finished quiz: ' + evt.properties.correct + '/' + evt.properties.total_questions + ' (' + evt.properties.accuracy_percent + '%)';
      } else if (evt.event === 'formula_searched') {
        details = 'Search: "' + evt.properties.query + '" in ' + (evt.properties.subject || '');
      } else {
        details = JSON.stringify(evt.properties);
      }

      row.innerHTML = \`
        <span class="feed-time">\${timeStr}</span>
        <span class="feed-event">\${evt.event}</span>
        <span class="feed-loc">\${evt.location}</span>
        <span><span class="badge \${badgeClass}">\${evt.archetype}</span></span>
        <span class="feed-details" title="\${details}">\${details}</span>
        <span style="color: var(--dim); font-size: 10px;">Inspect ›</span>
      \`;

      row.addEventListener('click', () => openDrawer(evt.event + ' (' + evt.student_id + ')', evt));
      return row;
    }

    function renderScoutedRoster() {
      const tbody = document.getElementById('scouted-tbody');
      const candidates = Array.from(studentsMap.values())
        .filter(s => s.candidate_status === 'Top Talent' || s.candidate_status === 'Strong Potential')
        .sort((a, b) => b.scout_score - a.scout_score);

      if (candidates.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" style="text-align: center; color: var(--dim); padding: 24px;">No candidates scouted yet. As students practice, high-signal profiles will appear here.</td></tr>';
        return;
      }

      tbody.innerHTML = candidates.map(s => {
        const accuracy = s.questions_attempted > 0 ? Math.round((s.correct_answers / s.questions_attempted) * 100) : 0;
        const statusBadge = s.candidate_status === 'Top Talent' ? 'badge-top' : 'badge-strong';
        const archBadge = s.archetype === 'Deep Thinker' ? 'badge-thinker' : 'badge-strong';

        return \`
          <tr>
            <td style="font-weight: 700; color: var(--gold);">\${s.student_id}</td>
            <td>\${s.location}</td>
            <td><span class="badge \${archBadge}">\${s.archetype}</span></td>
            <td style="font-weight: 700; color: \${accuracy >= 75 ? 'var(--good)' : 'var(--ink)'};">\${accuracy}%</td>
            <td>\${s.avg_dwell_seconds}s</td>
            <td style="font-weight: 700; color: var(--cyan);">\${s.derivations_viewed}</td>
            <td>\${s.best_streak}</td>
            <td><span class="badge \${statusBadge}">\${s.scout_score} / 100</span></td>
            <td><button class="btn-action" onclick="inspectStudent('\${s.student_id}')">View</button></td>
          </tr>
        \`;
      }).join('');
    }

    function renderAllStudents() {
      const tbody = document.getElementById('students-tbody');
      const list = Array.from(studentsMap.values()).sort((a, b) => b.last_seen - a.last_seen);
      if (list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="10" style="text-align: center; color: var(--dim); padding: 24px;">No students logged in yet.</td></tr>';
        return;
      }

      tbody.innerHTML = list.map(s => {
        const accuracy = s.questions_attempted > 0 ? Math.round((s.correct_answers / s.questions_attempted) * 100) : 0;
        const agoSec = Math.round((Date.now() - s.last_seen) / 1000);
        const timeAgo = agoSec < 60 ? agoSec + 's ago' : Math.round(agoSec / 60) + 'm ago';

        return \`
          <tr>
            <td style="font-weight: 600;">\${s.student_id}</td>
            <td style="color: var(--dim); text-transform: uppercase;">\${s.app}</td>
            <td>\${s.location}</td>
            <td>\${s.questions_attempted}</td>
            <td>\${accuracy}%</td>
            <td>\${s.avg_dwell_seconds}s</td>
            <td>\${s.derivations_viewed}</td>
            <td><span class="badge badge-dim">\${s.archetype}</span></td>
            <td style="color: var(--dim);">\${timeAgo}</td>
            <td><button class="btn-action" onclick="inspectStudent('\${s.student_id}')">View</button></td>
          </tr>
        \`;
      }).join('');
    }

    window.inspectStudent = function(studentId) {
      const s = studentsMap.get(studentId);
      if (s) openDrawer('Student Profile: ' + studentId, s);
    };

    // Live Server Sent Events listener
    function connectSSE() {
      const sse = new EventSource('/events');
      sse.onmessage = (e) => {
        try {
          const payload = JSON.parse(e.data);
          if (payload.summary) {
            document.getElementById('kpi-active').textContent = payload.summary.active_students;
            document.getElementById('kpi-studious').textContent = payload.summary.studious_ratio + '%';
            document.getElementById('kpi-candidates').textContent = payload.summary.scouted_candidates;
            document.getElementById('kpi-derivations').textContent = payload.summary.total_derivations;
          }

          if (payload.student) {
            studentsMap.set(payload.student.student_id, payload.student);
            renderScoutedRoster();
            renderAllStudents();
          }

          if (payload.event) {
            events.unshift(payload.event);
            if (events.length > 200) events.pop();
            const feedContainer = document.getElementById('feed-rows');
            feedContainer.insertBefore(renderFeedRow(payload.event), feedContainer.firstChild);
            document.getElementById('feed-counter').textContent = events.length + ' events';
          }
        } catch {}
      };

      sse.onerror = () => {
        sse.close();
        setTimeout(connectSSE, 3000);
      };
    }

    // Initial state fetch
    fetch('/api/snapshot')
      .then(res => res.json())
      .then(data => {
        if (data.students) {
          for (const s of data.students) studentsMap.set(s.student_id, s);
          renderScoutedRoster();
          renderAllStudents();
        }
        if (data.recent_events) {
          const feedContainer = document.getElementById('feed-rows');
          feedContainer.innerHTML = '';
          for (const ev of data.recent_events) {
            events.push(ev);
            feedContainer.appendChild(renderFeedRow(ev));
          }
          document.getElementById('feed-counter').textContent = events.length + ' events';
        }
        if (data.summary) {
          document.getElementById('kpi-active').textContent = data.summary.active_students;
          document.getElementById('kpi-studious').textContent = data.summary.studious_ratio + '%';
          document.getElementById('kpi-candidates').textContent = data.summary.scouted_candidates;
          document.getElementById('kpi-derivations').textContent = data.summary.total_derivations;
        }
        connectSSE();
      })
      .catch(() => connectSSE());
  </script>
</body>
</html>`;

// HTTP Server
const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  // CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  // Dashboard UI
  if (url.pathname === "/" || url.pathname === "/index.html") {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(DASHBOARD_HTML);
    return;
  }

  // Server Sent Events endpoint
  if (url.pathname === "/events") {
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    });
    res.write(":\n\n");
    sseClients.add(res);

    // Initial message
    res.write(`data: ${JSON.stringify({ summary: getSystemSummary() })}\n\n`);

    req.on("close", () => {
      sseClients.delete(res);
    });
    return;
  }

  // Snapshot API
  if (url.pathname === "/api/snapshot") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        summary: getSystemSummary(),
        students: Array.from(students.values()),
        recent_events: recentEvents,
      })
    );
    return;
  }

  // Direct Ingestion API
  if (url.pathname === "/api/telemetry" && req.method === "POST") {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 5e6) req.destroy();
    });
    req.on("end", async () => {
      try {
        const payload = JSON.parse(body);
        const clientIp =
          req.headers["cf-connecting-ip"] ||
          req.headers["x-forwarded-for"] ||
          req.socket.remoteAddress;

        if (payload.events && Array.isArray(payload.events)) {
          for (const ev of payload.events) {
            await ingestEvent({
              ...ev,
              student_id: payload.student_id || ev.student_id,
            }, String(clientIp));
          }
        } else {
          await ingestEvent(payload, String(clientIp));
        }

        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ status: "ok" }));
      } catch {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "bad json" }));
      }
    });
    return;
  }

  // 404
  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("Not Found");
});

server.listen(PORT, BIND, () => {
  console.log(`\n⚡ QUESTIONX & FORMULA X: LIVE WATCH`);
  console.log(`   Local Dashboard: ${LOCAL_URL}`);
  if (LAN_URL) {
    console.log(`   Mobile LAN Feed: ${LAN_URL}`);
  }
  console.log(`   Log Storage:     ${LOG_DIR}/telemetry-YYYY-MM-DD.jsonl`);
  console.log(`   Scouted Bucket:  ${CANDIDATES_FILE}\n`);
});
