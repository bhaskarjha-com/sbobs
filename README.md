<p align="center">
  <img src="assets/banner.png" alt="SessionPulse" width="100%">
</p>

<p align="center">
  <strong>Session automation engine for OBS Studio</strong><br>
  One timer orchestrates your scenes, audio, filters, overlays, and sources.<br>
  Pure Lua. Zero dependencies. Drag-and-drop install.
</p>

<p align="center">
  <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/version-5.4.0-6366f1?style=flat-square" alt="Version"></a>
  <a href="https://github.com/bhaskarjha-com/sbobs/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/bhaskarjha-com/sbobs/test.yml?style=flat-square&label=tests" alt="Tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="License"></a>
  <a href="https://obsproject.com"><img src="https://img.shields.io/badge/OBS_Studio-28%2B-1a1a2e?style=flat-square" alt="OBS"></a>
  <a href="#compatibility"><img src="https://img.shields.io/badge/platform-Win%20%7C%20Mac%20%7C%20Linux-94a3b8?style=flat-square" alt="Platform"></a>
</p>

---

## Quick Start

```
1. Clone or download this folder
2. OBS → Tools → Scripts → + → select session_pulse.lua
3. Click "🚀 Quick Setup" — sources, scenes, and overlay created automatically
4. Set hotkeys (Settings → Hotkeys → search "SessionPulse")
5. Press Start. Done.
```

> **New to OBS scripting?** Read the [Getting Started Guide](docs/getting-started.md) — it walks through every click.

---

## Preview

<p align="center">
  <img src="assets/overlay.png" alt="Circular timer overlay" width="220">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/dock.png" alt="Dockable control panel" width="280">
</p>

<p align="center">
  <em>Circular ring overlay (left) — Dockable control panel (right)</em>
</p>

<p align="center">
  <img src="assets/stats.png" alt="Productivity stats dashboard" width="600">
</p>

<p align="center">
  <em>Productivity stats dashboard with 7-day chart and session history</em>
</p>

---

## What It Does

SessionPulse is a **session automation engine** — not just a timer. It transforms OBS into a fully automated studio that reacts to your work/break cycle.

| You get... | Instead of... |
|-----------|--------------| 
| Timer auto-switches your scene to "Break" | Manually clicking scenes mid-stream |
| Music volume fades to 30% during focus | Dragging the volume slider every time |
| Mic mutes during focus, unmutes on break | Fumbling with mute hotkeys |
| Beautiful overlay ring shows progress | A plain text counter |
| Session history CSV tracks your productivity | No record of what you did |
| Chat bot gets `Focus 20:34 (3/6)` | Copying timer values manually |
| Chapter markers appear in recordings | Editing chapter timestamps by hand |

---

## Features

### Timer Engine
- **4 modes** — Pomodoro, Stopwatch (count up), Countdown (single), Custom Intervals
- **Wallclock-based** — drift-proof, never loses time under CPU load
- **"Ends at" display** — shows when the session finishes (e.g., "Ends 15:45")
- **Session labels** — name what you're working on, saved to CSV and state JSON
- **Daily focus goal** — set a daily target, track progress across OBS restarts
- **Focus streak** — tracks consecutive completed focus sessions (🔥3 in a row!)
- **Overtime** — optional negative timer counts up in red instead of auto-switching
- **Crash resilient** — auto-saves state with atomic writes, resume after OBS restart
- **Time adjustment** — add or subtract minutes mid-session via hotkey

### OBS Automation
- **Scene switching** — auto-switch per session type (Focus → Break scene)
- **Volume ducking** — smooth configurable fade (1–15s) between focus/break volume levels
- **Mic control** — auto-mute/unmute per session type
- **Filter toggling** — enable/disable source filters per session type
- **Source visibility** — auto-hide sources during focus
- **Chapter markers** — auto-insert at session transitions (OBS 30.2+)
- **Background media** — swap images/videos per session type
- **Stream-aware** — auto-start timer when you go live, auto-stop when stream ends
- **Warning alerts** — configurable sounds at 5min, 1min, and before break ends

### Visual Overlays
- **Circular ring overlay** — animated progress ring with session-colored glow
- **Horizontal bar overlay** — progress bar for top/bottom of stream
- **4 themes** — Default, Neon, Minimal, Glassmorphism
- **URL-configurable** — size, colors, fonts, visibility via URL parameters

### Control Interfaces
- **Dockable control panel** — dark-themed OBS dock with WebSocket buttons
- **Mobile remote** — phone-friendly control via WebSocket
- **Stats dashboard** — 7-day chart, streaks, session history with labels
- **6 hotkeys** — Start/Pause, Stop, Skip, Add Time, Subtract Time, Reset

### Data & Analytics
- **Session history log** — append-only CSV with timestamps, durations, and labels
- **Chat-ready status** — pre-formatted string for Nightbot/StreamElements
- **State JSON API** — 35+ fields for external tools (bots, Stream Deck, apps)

---

## Use Cases

| Stream Type | Focus Session | Break Session |
|------------|---------------|---------------|
| 📚 Study with me | Silent study | Chat interaction |
| 🏋️ HIIT workout | Exercise interval | Rest period |
| 🍳 Cooking | Prep / Cook | Plating / Chat |
| 🧘 Meditation | Sit meditation | Walking break |
| 🎙️ Podcast | Guest segment | Transition / Ads |
| 🎨 Creative | Drawing / Coding | Showcase / Feedback |
| 📺 Event | Main content | Intermission |
| 🤝 Body doubling | Focused work | Accountability check-in |

---

## 📚 Documentation

| Guide | Audience | What You'll Learn |
|-------|----------|------------------|
| **[Getting Started](docs/getting-started.md)** | Beginners | Install, configure, and run your first session — every click explained |
| **[Overlay Customization](docs/overlay-customization.md)** | Visual streamers | Themes, colors, sizes, fonts, and setup recipes |
| **[Automation Guide](docs/automation-guide.md)** | Power users | Scene switching, volume ducking, mic, filters, chapters, custom intervals |
| **[Integrations](docs/integrations.md)** | Bot builders | Nightbot, Stream Deck, custom tools — with code examples |
| **[Mobile Remote](docs/mobile-remote.md)** | Phone users | Phone setup, network config, save as home screen app |
| **[FAQ & Troubleshooting](docs/faq.md)** | Everyone | 30+ common issues and solutions |

---

## Installation

### Requirements
- OBS Studio **28+** (chapter markers need 30.2+)
- obs-websocket **5.x** (built into OBS 28+ — enable in Tools → WebSocket Server Settings)
- No Python. No npm. No compilation. No external dependencies.

### Steps

1. **Download** — clone or download this folder
2. **Load** — OBS → **Tools** → **Scripts** → click **+** → select `session_pulse.lua`
3. **Configure** — pick your sources from the dropdowns in the script panel
4. **Optional** — add overlay HTML files as Browser Sources

> Need detailed steps? See the [Getting Started Guide](docs/getting-started.md).

---

## Hotkeys

**Settings** → **Hotkeys** → search "SessionPulse":

| Hotkey | Action |
|--------|--------|
| Start / Pause | Toggle timer |
| Stop | Stop timer |
| Skip Session | Jump to next session |
| Add Time | Add N minutes (configurable) |
| Subtract Time | Subtract N minutes |
| Reset All | Full reset |

---

## State File API

`session_state.json` is the **public API** for external tools. Updated every second:

```json
{
  "version": "5.4.0",
  "timer_mode": "pomodoro",
  "is_running": true,
  "is_paused": false,
  "session_type": "Focus",
  "current_time": 1234,
  "total_time": 1500,
  "elapsed_seconds": 266,
  "progress_percent": 18,
  "ends_at": "15:45",
  "chat_status_line": "Focus 20:34 (2/6)",
  "session_label": "Math homework",
  "focus_streak": 2,
  "daily_focus_seconds": 7200,
  "daily_goal_seconds": 14400,
  "completed_focus_sessions": 2,
  "goal_sessions": 6,
  "next_session_type": "Short Break",
  "is_overtime": false,
  "timestamp": 1743385200
}
```

> **20 of 35 fields shown.** Full reference in the [Integrations Guide](docs/integrations.md#key-fields-reference).

---

## File Structure

```
sbobs/
├── session_pulse.lua         # Core engine — load this in OBS
├── shared.js                 # Shared utilities for custom integrations
├── timer_overlay.html        # Browser Source — circular ring (viewers)
├── timer_overlay_bar.html    # Browser Source — horizontal bar (viewers)
├── timer_dock.html           # Custom Browser Dock — control panel (streamer)
├── timer_stats.html          # Productivity dashboard (streamer)
├── timer_remote.html         # Mobile remote control (phone)
├── docs/                     # Guides and documentation
├── tests/                    # Automated test suites
│   ├── test_session_pulse.lua    # Lua core logic (67 tests)
│   └── test_frontend.js          # JS frontend logic (55 tests)
├── assets/                   # Preview images for documentation
├── CONTRIBUTING.md           # Contribution guide
├── CHANGELOG.md              # Version history
├── README.md
├── LICENSE
└── .gitignore
```

---

## Testing

```bash
lua tests/test_session_pulse.lua    # 67 tests: CSV, JSON, timing, parsing
node tests/test_frontend.js         # 55 tests: CSV parser, formatting, badges
```

Both return exit code 1 on failure — CI-ready.

---

## Compatibility

| Component | Requirement |
|-----------|-------------|
| OBS Studio | 28+ |
| Chapter markers | OBS 30.2+ |
| Filter toggling | OBS 30.2+ |
| obs-websocket | 5.x (built into OBS 28+) |
| Platforms | Windows, macOS, Linux |
| Dependencies | None |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for architecture overview, design decisions, and how to submit changes.

---

## License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  <sub>Built for streamers who take their sessions seriously.</sub>
</p>
