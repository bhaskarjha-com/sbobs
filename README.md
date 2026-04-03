# SessionPulse

**Session automation engine for OBS Studio** — Pomodoro timer, scene switching, volume ducking, overlays, and more.

![banner](assets/banner.png)

> One script. Zero dependencies. Full automation.

SessionPulse turns OBS into a productivity cockpit. Start a focus timer, and it handles everything: switching scenes, ducking music, muting your mic, swapping backgrounds, playing alerts — all automatically. When the session ends, it transitions to break mode and reverses everything.

---

## ✨ Features

| Category | What It Does |
|----------|-------------|
| **Timer Modes** | Pomodoro, Stopwatch, Countdown, Custom Intervals |
| **Scene Switching** | Auto-switch OBS scenes per session type |
| **Volume Ducking** | Smooth fade between focus/break volume levels |
| **Mic Control** | Auto-mute during focus, unmute during breaks |
| **Filter Toggle** | Enable/disable OBS filters per session |
| **Source Visibility** | Hide distracting sources during focus |
| **Warning Alerts** | 5-min, 1-min, and break-ending sound alerts |
| **Chapter Markers** | Auto-insert recording chapters at transitions |
| **Session Labels** | Name what you're working on — tracked in CSV |
| **Daily Focus Goal** | Set a target, track progress in the dock |
| **Focus Streak** | Track consecutive completed focus sessions 🔥 |
| **Overlays** | Circular ring + horizontal bar (themeable) |
| **Control Dock** | Clickable buttons inside OBS via WebSocket |
| **Mobile Remote** | Control from your phone over WiFi |
| **Stats Dashboard** | 7-day chart, streaks, completion rate |
| **State File API** | 35-field JSON updated every second for integrations |
| **Session Logging** | CSV history for analytics |
| **Persistence** | Survives OBS restarts with atomic state saves |

---

## 🚀 Quick Start

### 1. Load the Script

1. Download or `git clone https://github.com/bhaskarjha-com/sbobs.git`
2. In OBS: **Tools → Scripts → + → select `session_pulse.lua`**

### 2. One-Click Setup

Click **🚀 Quick Setup** in the script panel. Done.

This creates text sources, an overlay, focus/break scenes — and wires everything together.

### 3. Set Hotkeys

**Settings → Hotkeys → search "SessionPulse":**

| Hotkey | Suggested | Action |
|--------|-----------|--------|
| Start / Pause | `F9` | Toggle timer |
| Stop | `F10` | End session |
| Skip | `F11` | Next session |

### 4. Press Start

Hit your Start hotkey. Watch the magic.

> **Full walkthrough:** [Getting Started Guide](docs/getting-started.md)

---

## 📸 Screenshots

| Control Dock | Ring Overlay | Stats Dashboard |
|:---:|:---:|:---:|
| ![dock](assets/dock.png) | ![overlay](assets/overlay.png) | ![stats](assets/stats.png) |

---

## 📖 Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Zero-to-hero setup in ~10 minutes |
| [Automation Guide](docs/automation-guide.md) | Scene switching, volume ducking, mic, filters, chapters |
| [Overlay Customization](docs/overlay-customization.md) | Themes, colors, sizes, URL parameters |
| [Mobile Remote](docs/mobile-remote.md) | Control from your phone |
| [Integrations](docs/integrations.md) | Nightbot, Stream Deck, custom tools |
| [FAQ & Troubleshooting](docs/faq.md) | 30+ issues organized by category |
| [Architecture](docs/architecture.md) | Developer reference: state machine, code map, data flows |

---

## 🏗️ Project Structure

```
session_pulse.lua          ← Core engine (Lua, runs inside OBS)
                              ↓ writes
                         session_state.json    ← Public state API (35 fields, updated every second)
                              ↑ reads
┌──────────────────┬──────────────────┬────────────────┬──────────────┐
│ timer_dock.html  │ timer_overlay.html│ timer_stats.html│ timer_remote │
│ (Control Dock)   │ (Ring Overlay)   │ (Stats Page)   │ (Mobile)     │
│ WebSocket + Poll │ Poll only        │ CSV + Poll     │ WebSocket    │
└──────────────────┴──────────────────┴────────────────┴──────────────┘
timer_overlay_bar.html     ← Horizontal bar overlay (Poll only)
shared.js                  ← ES module utilities for custom integrations
```

---

## 📊 State File API

`session_state.json` is the integration point — any tool that reads JSON can connect.

<details>
<summary><strong>All 35 fields</strong> (click to expand)</summary>

```json
{
  "version": "5.4.1",
  "timer_mode": "pomodoro",
  "is_running": true,
  "is_paused": false,
  "session_type": "Focus",
  "current_time": 1234,
  "total_time": 1500,
  "elapsed_seconds": 266,
  "progress_percent": 18,
  "ends_at": "15:45",
  "cycle_count": 1,
  "completed_focus_sessions": 2,
  "goal_sessions": 6,
  "total_focus_seconds": 3000,
  "show_transition": false,
  "transition_message": "",
  "custom_segment_name": "",
  "custom_segment_index": 1,
  "custom_segment_count": 0,
  "is_overtime": false,
  "overtime_seconds": 0,
  "next_session_type": "Short Break",
  "next_session_in": 1234,
  "sessions_remaining": 4,
  "break_suggestion": "Stretch!",
  "stream_duration": 7200,
  "chat_status_line": "Focus 20:34 (2/6)",
  "session_label": "Math homework",
  "daily_focus_seconds": 7200,
  "daily_goal_seconds": 14400,
  "focus_streak": 2,
  "session_epoch": 1711983000,
  "session_pause_total": 0,
  "session_target_duration": 1500,
  "timestamp": 1711983266
}
```

</details>

**Usage examples:** [Integrations Guide](docs/integrations.md)

---

## 🧪 Testing

```bash
# Lua core tests (67 tests)
lua tests/test_session_pulse.lua

# JavaScript frontend tests (55 tests)
node tests/test_frontend.js
```

CI runs on every push via [GitHub Actions](.github/workflows/test.yml).

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines, architecture overview, and the manual testing checklist.

---

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

**Current version:** 5.4.1

---

## 📄 License

[MIT](LICENSE) — Bhaskar Jha