/**
 * SessionPulse — Shared Utilities (ES Module)
 * v6.0.0
 *
 * Canonical formatting, badge mapping, and state helpers for SessionPulse UIs.
 *
 * NOTE: The built-in HTML files (timer_dock, timer_overlay, etc.) inline their
 * own copies of these functions because OBS Browser Sources load via file://
 * protocol, which doesn't support ES module imports from relative paths in CEF.
 *
 * This module is provided for:
 *   - External tool builders creating custom dashboards or bots
 *   - HTTP-served UIs (e.g., served via `python -m http.server`)
 *   - Reference implementation of formatting logic
 *
 * Usage: import { formatTime, getBadgeInfo } from './shared.js';
 */

// ── Time Formatting ──

export function formatTime(seconds) {
  if (seconds == null || seconds < 0) return '--:--';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export function formatDuration(seconds) {
  if (!seconds || seconds <= 0) return '0m';
  const mins = Math.floor(seconds / 60);
  if (mins < 60) return `${mins}m`;
  const h = Math.floor(mins / 60);
  const rm = mins % 60;
  return rm === 0 ? `${h}h` : `${h}h ${rm}m`;
}

export function formatOvertime(seconds) {
  return '+' + formatTime(seconds || 0);
}

// ── Badge / Color Mapping ──

export const BADGE_CLASSES = {
  'Focus': 'focus',
  'Short Break': 'short-break',
  'Long Break': 'long-break',
};

export const SESSION_ICONS = {
  'Focus': '📚',
  'Short Break': '☕',
  'Long Break': '🧘',
  'Stopwatch': '⏱️',
  'Countdown': '⏳',
};

// ── State Helpers ──

export function getBadgeInfo(state) {
  if (!state || !state.is_running) return { text: 'Ready', cls: 'idle' };

  const { session_type, timer_mode, is_paused, is_overtime,
          custom_segment_name } = state;
  const mode = timer_mode || 'pomodoro';

  let text = session_type || 'Ready';
  let cls = BADGE_CLASSES[session_type] || 'idle';

  if (is_overtime) {
    text = (session_type || 'Session') + ' · Overtime';
    cls = 'overtime';
  } else if (mode === 'stopwatch') {
    text = 'Stopwatch'; cls = 'stopwatch';
  } else if (mode === 'countdown') {
    text = 'Countdown'; cls = 'countdown';
  } else if (mode === 'custom' && custom_segment_name) {
    text = custom_segment_name; cls = 'custom';
  }

  if (is_paused && !is_overtime) text += ' · Paused';
  return { text, cls };
}

export function getProgress(state) {
  if (!state) return 0;
  const { current_time, total_time, timer_mode, is_overtime, progress_percent } = state;

  // Use pre-computed value if available (v5.1+)
  if (progress_percent != null) return progress_percent;

  if (is_overtime) return 100;
  const mode = timer_mode || 'pomodoro';
  if (mode === 'stopwatch') return ((current_time % 3600) / 3600) * 100;
  if (total_time > 0) return ((total_time - current_time) / total_time) * 100;
  return 0;
}

// ── Polling Helper ──

export function createPoller(url, callback, interval = 500) {
  let lastState = null;

  async function poll() {
    try {
      const resp = await fetch(url + '?t=' + Date.now());
      if (resp.ok) {
        lastState = await resp.json();
        callback(lastState);
      } else {
        callback(null);
      }
    } catch (e) {
      callback(lastState);
    }
  }

  poll();
  return setInterval(poll, interval);
}
