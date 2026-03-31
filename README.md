<p align="center">
  <img src="assets/banner.png" alt="SessionPulse" width="100%">
</p>

<p align="center">
  <strong>Session automation engine for OBS Studio</strong><br>
  One timer orchestrates your scenes, audio, filters, overlays, and sources.<br>
  Pure Lua. Zero dependencies. Drag-and-drop install.
</p>

<p align="center">
  <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/version-5.3.1-6366f1?style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="License"></a>
  <a href="https://obsproject.com"><img src="https://img.shields.io/badge/OBS_Studio-28%2B-1a1a2e?style=flat-square" alt="OBS"></a>
  <a href="#compatibility"><img src="https://img.shields.io/badge/platform-Win%20%7C%20Mac%20%7C%20Linux-94a3b8?style=flat-square" alt="Platform"></a>
</p>

---

## Quick Start

```
1. Clone or download this folder
2. OBS → Tools → Scripts → + → select session_pulse.lua
3. Pick your text sources from the dropdowns. Done.
```

Optional: Add `timer_overlay.html` as a Browser Source for a visual ring overlay.

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
- **Source visibility** — auto-hide sources during focus (comma-separated)
- **Chapter markers** — auto-insert at session transitions (OBS 30.2+)
- **Background media** — swap images/videos per session type
- **Stream-aware** — auto-start timer when you go live, auto-stop when stream ends
- **Warning alerts** — configurable sounds at 5min, 1min, and before break ends
- **Audio alerts** — per-session custom sounds on transitions

### Visual Overlays
- **Circular ring overlay** — animated progress ring with session-colored glow
- **Horizontal bar overlay** — progress bar for top/bottom of stream
- **4 themes** — Default, Neon, Minimal, Glassmorphism
- **URL-configurable** — size, colors, fonts, visibility via URL parameters
- **Overtime display** — pulsing red ring with `+MM:SS` counter

### Control Interfaces
- **Dockable control panel** — dark-themed OBS dock with WebSocket buttons, daily goal progress bar
- **Mobile remote** — phone-friendly control via WebSocket
- **6 hotkeys** — Start/Pause, Stop, Skip, Add Time, Subtract Time, Reset

### Data & Analytics
- **Session history log** — append-only CSV with timestamps, durations, and labels
- **Productivity dashboard** — HTML stats page with 7-day chart, streaks, and session labels
- **Chat-ready status** — pre-formatted string for Nightbot/StreamElements
- **State JSON API** — 36+ fields for external tools (bots, Stream Deck, apps)

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

---

## Setup Guide

### 1. Create OBS Sources

Create these in your scene before configuring the script:

| Source | OBS Type | Purpose |
|--------|----------|---------|
| Timer display | Text (GDI+) | Countdown `24:59` |
| Session message | Text (GDI+) | `Focus Time`, `Short Break`, etc. |
| Focus count | Text (GDI+) | `Done: 3/6` |
| Progress bar | Text (GDI+) | `████░░░░` character bar |
| Background media | Image or Media Source | Swaps per session type |
| Alert sound | Media Source | Audio alerts on transitions |

> Source names are picked from dropdowns — no manual typing needed.

### 2. Choose Timer Mode

| Mode | Behavior |
|------|----------|
| **Pomodoro** | Focus → Short Break → Long Break cycle (default) |
| **Stopwatch** | Counts up from 0:00. No auto-stop. |
| **Countdown** | Single countdown, stops at zero. |
| **Custom Intervals** | Named segments: `Work:25,Break:5,Work:25,Break:5` |

**Custom Intervals examples:**
| Use Case | Config |
|----------|--------|
| HIIT | `Warm-up:5,Exercise:20,Rest:5,Exercise:20,Cool-down:5` |
| Podcast | `Intro:2,Guest:25,Ads:3,Discussion:20,Outro:2` |
| Study | `Review:10,Practice:30,Break:5,Practice:30,Break:5` |

### 3. Browser Source Overlay (Optional)

Add a circular timer ring to your stream:

1. Add a **Browser Source** to your scene
2. Check **"Local file"** → browse to `timer_overlay.html`
3. Set width and height to **220**
4. Position wherever you want

**URL customization:**

| Parameter | Example | Description |
|-----------|---------|-------------|
| `theme` | `?theme=neon` | `default`, `neon`, `minimal`, `glassmorphism` |
| `size` | `?size=300` | Ring size in pixels |
| `font` | `?font=Outfit` | Any Google Font name |
| `showStats` | `?showStats=false` | Hide session counter |
| `showNext` | `?showNext=false` | Hide "Next up" text |
| `color_focus` | `?color_focus=10b981` | Custom hex color |

Combine: `timer_overlay.html?theme=neon&size=300&font=Outfit`

### 4. Bar Overlay (Optional)

Horizontal progress bar for top/bottom edge:

1. Add a **Browser Source** → `timer_overlay_bar.html`
2. Width: **1920** (your stream width), Height: **36**
3. Position at top or bottom edge

Parameters: `?position=top` (default) or `?position=bottom`

Auto-hides when idle, slides in when running.

### 5. Dockable Control Panel (Optional)

1. OBS → **View** → **Docks** → **Custom Browser Docks**
2. Name: `SessionPulse`
3. URL: `file:///` + full path to `timer_dock.html`
   - Example: `file:///D:/dev/pro/sbobs/timer_dock.html`
4. Click **Apply**

The dock provides:
- Full control buttons (Start/Pause, Stop, Skip, ±Time, Reset)
- Timer display with colored session badge
- Session stats, "Next up" indicator, "Ends at" time
- Chat status line (click to copy)
- WebSocket connection status with auto-reconnect

**WebSocket setup** (for control buttons):
1. OBS → **Tools** → **WebSocket Server Settings**
2. Enable, note the port (default `4455`)
3. If password set: append `?ws_password=YOUR_PASSWORD` to dock URL

> Without WebSocket, the dock still works as a read-only display.

### 6. Stats Dashboard (Optional)

1. Open `timer_stats.html` in a browser or dock it in OBS
2. Shows: today's focus time, total sessions, day streak, avg duration
3. 7-day focus time bar chart
4. Recent sessions log table with labels

> Requires "Log Sessions to CSV File" enabled in script settings.

### 7. Mobile Remote (Optional)

1. Open `timer_remote.html` on your phone
2. Enter your OBS machine's IP, port, and password
3. Large touch-friendly buttons for full control

> Requires OBS WebSocket enabled, phone on the same network.

---

## Hotkeys

Go to **Settings** → **Hotkeys** → search "SessionPulse":

| Hotkey | Action |
|--------|--------|
| SessionPulse: Start / Pause | Toggle timer |
| SessionPulse: Stop | Stop timer |
| SessionPulse: Skip Session | Jump to next session |
| SessionPulse: Add Time | Add N minutes |
| SessionPulse: Subtract Time | Subtract N minutes |
| SessionPulse: Reset All | Full reset (clears all progress) |

Time adjustment increment (default: 5 minutes) is configurable in script settings.

---

## Configuration Reference

All settings in **Tools** → **Scripts** → select the script:

<details>
<summary><strong>Timer & Durations</strong></summary>

| Setting | Default | Range |
|---------|---------|-------|
| Timer Mode | Pomodoro | Pomodoro / Stopwatch / Countdown / Custom |
| Focus Duration | 25 min | 1–120 min |
| Short Break | 5 min | 1–30 min |
| Long Break | 15 min | 1–60 min |
| Long Break Every | 4 cycles | 1–10 |
| Goal Sessions | 6 | 1–20 |
| Starting Session Offset | 0 | 0–20 |
| Countdown Duration | 25 min | 1–480 min |
| Custom Intervals | `Work:25,Break:5,...` | Name:Min format |

</details>

<details>
<summary><strong>Behavior</strong></summary>

| Setting | Default | Description |
|---------|---------|-------------|
| Auto-start Next / Loop | ✅ | Advance between sessions automatically |
| Show Progress Bar | ✅ | Character-based bar `████░░` |
| Enable Overtime | ❌ | Count up after zero instead of switching |
| Transition Message Duration | 2 sec | How long "Time for a break!" shows |
| Time Adjust Increment | 5 min | Minutes per hotkey press |
| Break Suggestions | 8 tips | Comma-separated, shown during breaks |
| Log Sessions to CSV | ❌ | Append to `session_history.csv` |
| Session Label | (empty) | Name what you're working on |
| Daily Focus Goal | 0 min | Daily target in minutes (0 = disabled) |

</details>

<details>
<summary><strong>Volume Ducking</strong></summary>

| Setting | Default | Description |
|---------|---------|-------------|
| Music/Audio Source | (None) | Dropdown of OBS sources |
| Focus Volume % | 30% | During focus sessions |
| Break Volume % | 80% | During breaks |
| Smooth Volume Fade | ✅ | Enable ease-in-out transition |
| Fade Duration | 3 sec | 1–15 seconds |

</details>

<details>
<summary><strong>Filter Toggle</strong></summary>

| Setting | Description |
|---------|-------------|
| Source | The source containing filters (e.g., Camera) |
| Enable During Focus | Comma-separated filter names activated during focus |
| Disable During Focus | Comma-separated filter names deactivated during focus |

Example: Enable "Color Correction" during focus, disable "Background Blur" during focus.

</details>

<details>
<summary><strong>Warning Alerts</strong></summary>

| Setting | Default |
|---------|---------|
| 5-Minute Warning Sound | ✅ |
| 1-Minute Warning Sound | ✅ |
| Break Ending Warning | ✅ |
| Break Warning At (sec) | 30 |

</details>

<details>
<summary><strong>Stream Integration</strong></summary>

| Setting | Default |
|---------|---------|
| Auto-start Timer on Stream Start | ❌ |
| Auto-stop Timer on Stream End | ❌ |
| Add Recording Chapter Markers | ✅ |

</details>

<details>
<summary><strong>Messages</strong></summary>

All session and transition messages are customizable:
- Focus / Short Break / Long Break messages
- Transition messages ("Time for a short break!", "Back to focus time!", etc.)

</details>

---

## State File API

`session_state.json` is the **public API** for external tools. Read it from any bot, Stream Deck plugin, or custom app:

```json
{
  "version": "5.3.1",
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
  "session_epoch": 1743385200,
  "session_pause_total": 0,
  "session_target_duration": 1500,
  "timestamp": 1743385200
}
```

### Key Fields for Bot Integration

| Field | Use Case |
|-------|----------|
| `chat_status_line` | Drop into any `!timer` chat command response |
| `ends_at` | "Session ends at 15:45" display |
| `progress_percent` | Progress bars in external UIs |
| `elapsed_seconds` | "Been focusing for 12 minutes" display |
| `is_running` + `is_paused` | State detection for conditional logic |
| `next_session_type` | "Next up: Short Break" announcements |
| `session_label` | "Currently working on: Math homework" |
| `total_focus_seconds` | Lifetime focus counter for this OBS session |
| `focus_streak` | "🔥3 in a row!" — consecutive completed focus sessions |
| `daily_focus_seconds` / `daily_goal_seconds` | Daily goal progress in external dashboards |

### Chat Bot Setup

**Nightbot / StreamElements / Fossabot:**

For bots that support custom API responses, point the `!timer` command to read `chat_status_line` from the state file. Since most chat bots can't read local files directly, use one of these approaches:

1. **File-based** — If your bot runs locally (e.g., Streamer.bot), read `session_state.json` directly
2. **HTTP server** — Serve the script directory over HTTP (e.g., `python -m http.server 8080`) and point your bot to `http://localhost:8080/session_state.json`
3. **Manual copy** — Click the "Chat" row in the dock panel to copy the status line to clipboard

---

## Session History

Enable **"Log Sessions to CSV File"** to track every session:

```csv
date,time,session_type,duration_seconds,completed,mode,total_focus,label
2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500,"Math homework"
2026-03-31,11:10:25,Short Break,300,true,pomodoro,1500,""
```

File: `session_history.csv` (created next to the script, git-ignored).
Import into any spreadsheet or view in the built-in stats dashboard.

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
├── tests/                    # Automated test suites
│   ├── test_session_pulse.lua    # Lua core logic (67 tests)
│   └── test_frontend.js          # JS frontend logic (55 tests)
├── assets/                   # Preview images for documentation
├── session_state.json        # Auto-generated state (git-ignored)
├── session_history.csv       # Auto-generated log (git-ignored)
├── CONTRIBUTING.md           # Contribution guide
├── CHANGELOG.md              # Version history
├── README.md
├── LICENSE
└── .gitignore
```

---

## Testing

Run the automated test suites before submitting changes:

```bash
# Lua core tests (CSV, JSON, timing, parsing, state format)
lua tests/test_session_pulse.lua

# JavaScript frontend tests (CSV parser, formatting, badges)
node tests/test_frontend.js
```

Both suites return exit code 1 on failure — safe to use in CI.

---

## Compatibility

| Component | Requirement |
|-----------|-------------|
| OBS Studio | 28+ |
| Chapter markers | OBS 30.2+ |
| Filter toggling | OBS 30.2+ (fallback for older) |
| obs-websocket | 5.x (built into OBS 28+) |
| Platforms | Windows, macOS, Linux |
| Dependencies | None |

---

## Session Persistence

State saves to `session_state.json` on every meaningful change (not every tick). Uses atomic writes (temp file → rename) to prevent corruption. Resume after crashes via the "Resume Previous Session" button.

**State migration:** v5.x state files auto-migrate from v4.x format — wallclock epoch is synthesized from saved `current_time`.

---

## Troubleshooting

<details>
<summary><strong>Timer doesn't start</strong></summary>

- Check the OBS Script Log (Tools → Scripts → Script Log) for errors
- Ensure the script loaded without errors (look for `[SessionPulse] Loaded v5.3.1`)
- If using Custom Intervals, verify the format is `Name:Minutes,Name:Minutes`

</details>

<details>
<summary><strong>Overlay shows "Offline"</strong></summary>

- The overlay reads `session_state.json` via relative file path
- Make sure the HTML file and the Lua script are in the **same directory**
- In the Browser Source properties, verify "Local file" is checked

</details>

<details>
<summary><strong>Dock buttons are disabled</strong></summary>

- Dock controls require WebSocket connection
- Enable WebSocket: OBS → Tools → WebSocket Server Settings → Enable
- If using a password, append `?ws_password=YOUR_PASSWORD` to the dock URL
- The WS indicator in the dock header shows connection status

</details>

<details>
<summary><strong>Sounds don't play</strong></summary>

- Alert sounds require a **Media Source** in your scene
- Select it in the "Alert Sound Source (Media)" dropdown
- Set your sound files in the "Alert Sounds" section
- The Media Source must be in the **active scene** to play

</details>

<details>
<summary><strong>Scene switching doesn't work</strong></summary>

- Enable "Scene Switching" in the checkable group
- Select scenes from the dropdowns (they show your existing scenes)
- Scene switching only occurs at session transitions, not during paused state

</details>

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
