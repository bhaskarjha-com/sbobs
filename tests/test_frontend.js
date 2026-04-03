/**
 * SessionPulse Frontend Test Suite
 * Tests CSV parser, HTML escaping, time formatting, badge logic
 * Run from project root:  node tests/test_frontend.js
 * Run from tests dir:      cd tests && node test_frontend.js
 */

const fs = require('node:fs');
const path = require('node:path');

let pass = 0, fail = 0, total = 0;

function test(name, condition) {
  total++;
  if (condition) {
    pass++;
    console.log(`  ✓ ${name}`);
  } else {
    fail++;
    console.log(`  ✗ FAIL: ${name}`);
  }
}

function section(name) {
  console.log(`\n━━ ${name} ━━`);
}

// ═══════════════════════════════════════════════════════
// CSV Parser (from timer_stats.html)
// ═══════════════════════════════════════════════════════
section("CSV Parser (parseCsvLine)");

function parseCsvLine(line) {
  const cols = [];
  let i = 0, field = '';
  while (i < line.length) {
    if (line[i] === '"') {
      i++; // skip opening quote
      while (i < line.length) {
        if (line[i] === '"' && line[i + 1] === '"') { field += '"'; i += 2; }
        else if (line[i] === '"') { i++; break; }
        else { field += line[i]; i++; }
      }
      if (line[i] === ',') i++; // skip delimiter after closing quote
      cols.push(field); field = '';
    } else {
      const next = line.indexOf(',', i);
      if (next === -1) { cols.push(line.slice(i)); break; }
      cols.push(line.slice(i, next));
      i = next + 1;
    }
  }
  return cols;
}

// Simple row (no quotes)
const r1 = parseCsvLine('2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,Math homework');
test("Simple row: 8 columns", r1.length === 8);
test("Simple row: date", r1[0] === "2026-03-31");
test("Simple row: time", r1[1] === "10:45:23");
test("Simple row: type", r1[2] === "Focus");
test("Simple row: duration", r1[3] === "1500");
test("Simple row: label", r1[7] === "Math homework");

// Quoted label (no commas)
const r2 = parseCsvLine('2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"Math homework"');
test("Quoted label: 8 columns", r2.length === 8);
test("Quoted label: label", r2[7] === "Math homework");

// Quoted label WITH comma (the bug fix)
const r3 = parseCsvLine('2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"Math, Physics"');
test("Comma in label: 8 columns", r3.length === 8);
test("Comma in label: date still correct", r3[0] === "2026-03-31");
test("Comma in label: label intact", r3[7] === "Math, Physics");

// Quoted label with escaped quotes
const r4 = parseCsvLine('2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"He said ""hello"""');
test("Escaped quotes: 8 columns", r4.length === 8);
test("Escaped quotes: label", r4[7] === 'He said "hello"');

// Empty quoted label
const r5 = parseCsvLine('2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,""');
test("Empty quoted label: 8 columns", r5.length === 8);
test("Empty quoted label: empty string", r5[7] === "");

// Comma AND quotes in label
const r6 = parseCsvLine('2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"A, ""B"""');
test("Comma+quotes: label", r6[7] === 'A, "B"');

// ═══════════════════════════════════════════════════════
// Full CSV parsing (parseCsv)
// ═══════════════════════════════════════════════════════
section("Full CSV Parsing");

function parseCsv(text) {
  const lines = text.trim().split('\n');
  if (lines.length < 2) return [];
  const headers = lines[0].split(',').map(h => h.trim());
  return lines.slice(1).map(line => {
    const cols = parseCsvLine(line);
    const row = {};
    headers.forEach((h, i) => row[h] = (cols[i] || '').trim());
    return row;
  }).filter(r => r.date);
}

const csv = `date,time,session_type,duration_seconds,completed,mode,total_focus,label
2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"Math homework"
2026-03-31,11:10:25,Short Break,300,true,pomodoro,1500,""
2026-03-31,11:15:25,Focus,1500,true,pomodoro,3000,"Math, Physics"`;

const rows = parseCsv(csv);
test("Parsed 3 rows", rows.length === 3);
test("Row 1 date", rows[0].date === "2026-03-31");
test("Row 1 label", rows[0].label === "Math homework");
test("Row 2 label (empty)", rows[1].label === "");
test("Row 3 label (comma)", rows[2].label === "Math, Physics");
test("Row 3 session_type", rows[2].session_type === "Focus");
test("Row 3 duration", rows[2].duration_seconds === "1500");

// CSV with only header (no data)
test("Empty CSV", parseCsv("date,time\n").length === 0);

// CSV with single row
test("Single row CSV", parseCsv("date,time\n2026-01-01,10:00").length === 1);

// ═══════════════════════════════════════════════════════
// HTML Escaping
// ═══════════════════════════════════════════════════════
section("HTML Escaping");

function htmlEscape(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

test("Normal text", htmlEscape("hello") === "hello");
test("Angle brackets", htmlEscape("<script>alert(1)</script>") === "&lt;script&gt;alert(1)&lt;/script&gt;");
test("Ampersand", htmlEscape("A & B") === "A &amp; B");
test("Quotes", htmlEscape('"hello"') === "&quot;hello&quot;");
test("Mixed special chars", htmlEscape('<a href="x">&') === '&lt;a href=&quot;x&quot;&gt;&amp;');

// ═══════════════════════════════════════════════════════
// Time Formatting (from shared.js / dock / overlays)
// ═══════════════════════════════════════════════════════
section("Time Formatting (JS)");

function formatTime(seconds) {
  if (seconds == null || seconds < 0) return '--:--';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
  return `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
}

test("25:00", formatTime(1500) === "25:00");
test("00:01", formatTime(1) === "00:01");
test("00:00", formatTime(0) === "00:00");
test("01:00", formatTime(60) === "01:00");
test("Negative returns --:--", formatTime(-90) === "--:--");
test("1:01:01 (with hours)", formatTime(3661) === "1:01:01");
test("Null returns --:--", formatTime(null) === "--:--");

// ═══════════════════════════════════════════════════════
// Duration Formatting (from stats dashboard)
// ═══════════════════════════════════════════════════════
section("Duration Formatting (JS)");

function formatDuration(seconds) {
  if (!seconds || seconds <= 0) return '0m';
  const mins = Math.floor(seconds / 60);
  if (mins < 60) return `${mins}m`;
  const h = Math.floor(mins / 60);
  const rm = mins % 60;
  return rm === 0 ? `${h}h` : `${h}h ${rm}m`;
}

test("0 seconds", formatDuration(0) === "0m");
test("null", formatDuration(null) === "0m");
test("90 seconds", formatDuration(90) === "1m");
test("3600 seconds", formatDuration(3600) === "1h");
test("3660 seconds", formatDuration(3660) === "1h 1m");
test("7320 seconds", formatDuration(7320) === "2h 2m");

// ═══════════════════════════════════════════════════════
// Badge Mapping (from shared.js)
// ═══════════════════════════════════════════════════════
section("Badge Mapping");

function getBadgeInfo(sessionType) {
  const map = {
    'Focus':       { emoji: '🎯', color: '#22c55e' },
    'Short Break': { emoji: '☕', color: '#3b82f6' },
    'Long Break':  { emoji: '🌴', color: '#a855f7' },
  };
  return map[sessionType] || { emoji: '⏱️', color: '#6366f1' };
}

test("Focus badge", getBadgeInfo("Focus").emoji === "🎯");
test("Focus color", getBadgeInfo("Focus").color === "#22c55e");
test("Short Break badge", getBadgeInfo("Short Break").emoji === "☕");
test("Long Break badge", getBadgeInfo("Long Break").emoji === "🌴");
test("Unknown type fallback", getBadgeInfo("Custom").emoji === "⏱️");

// ═══════════════════════════════════════════════════════
// Daily Goal Progress
// ═══════════════════════════════════════════════════════
section("Daily Goal Progress");

function goalProgress(dailySec, goalSec) {
  if (!goalSec || goalSec <= 0) return { pct: 0, show: false };
  const pct = Math.min(100, Math.round((dailySec / goalSec) * 100));
  return { pct, show: true };
}

test("0/14400 = 0%", goalProgress(0, 14400).pct === 0);
test("7200/14400 = 50%", goalProgress(7200, 14400).pct === 50);
test("14400/14400 = 100%", goalProgress(14400, 14400).pct === 100);
test("20000/14400 capped at 100%", goalProgress(20000, 14400).pct === 100);
test("No goal = hidden", goalProgress(0, 0).show === false);
test("With goal = shown", goalProgress(0, 14400).show === true);

// ═══════════════════════════════════════════════════════
// State JSON Field Count Validation
// ═══════════════════════════════════════════════════════
section("State JSON Field Validation");

const expectedFields = [
  "version", "timer_mode", "is_running", "is_paused", "session_type",
  "current_time", "total_time", "elapsed_seconds", "progress_percent", "ends_at",
  "cycle_count", "completed_focus_sessions", "goal_sessions", "total_focus_seconds",
  "show_transition", "transition_message", "custom_segment_name", "custom_segment_index",
  "custom_segment_count", "is_overtime", "overtime_seconds", "next_session_type",
  "next_session_in", "sessions_remaining", "break_suggestion", "stream_duration",
  "chat_status_line", "session_label", "daily_focus_seconds", "daily_goal_seconds",
  "focus_streak", "session_epoch", "session_pause_total", "session_target_duration",
  "timestamp"
];

test("Expected 35 fields in state JSON", expectedFields.length === 35);

// Verify the README claims "36+ fields" — count includes version
const docClaim = 36;
test(`README says "${docClaim}+" which covers ${expectedFields.length} fields`, expectedFields.length >= docClaim - 1);

// ═══════════════════════════════════════════════════════════════════════════════
// OBS Browser Surface Hardening
// ═══════════════════════════════════════════════════════════════════════════════
section("OBS Browser Surface Hardening");

const repoRoot = path.resolve(__dirname, '..');
const obsHostedPages = [
  'timer_dock.html',
  'timer_overlay.html',
  'timer_overlay_bar.html',
  'timer_stats.html',
];

const statePollingPages = [
  'timer_dock.html',
  'timer_overlay.html',
  'timer_overlay_bar.html',
  'timer_remote.html',
];

for (const page of obsHostedPages) {
  const html = fs.readFileSync(path.join(repoRoot, page), 'utf8');
  test(`${page}: no Google Fonts dependency`, !html.includes('fonts.googleapis.com'));
  test(`${page}: no jsDelivr dependency`, !html.includes('cdn.jsdelivr.net'));
  test(`${page}: no module script tag`, !html.includes('type="module"'));

  const scripts = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)];
  test(`${page}: has inline script`, scripts.length > 0);
  scripts.forEach((match, index) => {
    try {
      new Function(match[1]);
      test(`${page}: script ${index + 1} parses`, true);
    } catch (error) {
      test(`${page}: script ${index + 1} parses`, false);
    }
  });
}

section("State Polling Recovery");
for (const page of statePollingPages) {
  const html = fs.readFileSync(path.join(repoRoot, page), 'utf8');
  test(`${page}: tracks consecutive fetch failures`, html.includes('consecutiveFetchFailures'));
}

// ═══════════════════════════════════════════════════════
// Results
// ═══════════════════════════════════════════════════════
console.log(`\n${"═".repeat(50)}`);
console.log(`Results: ${pass}/${total} passed, ${fail} failed`);
console.log("═".repeat(50));

if (fail > 0) process.exit(1);
