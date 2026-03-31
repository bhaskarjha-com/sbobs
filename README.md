# OBS Session Timer

A powerful multi-mode session orchestrator for OBS Studio. Built in pure Lua — zero dependencies, zero setup friction.

The timer is the heartbeat. Scenes, audio, filters, sources, and overlays all pulse to that beat. Works for any timed session format: study streams, HIIT workouts, cooking, meditation, podcasts, events, and accountability/body doubling streams.

> **v5.0** — Drift-proof wallclock timing, WebSocket dock control, warning alerts, time adjustment hotkeys, bar overlay, stats dashboard, mobile remote.

## Features

### Core Timer
- **4 timer modes** — Pomodoro, Stopwatch (count up), Countdown (single), Custom Intervals
- **Full Pomodoro cycle** — Focus → Short Break → Long Break, auto-cycling
- **Custom intervals** — define named segments like `Work:25,Break:5,Work:25,Break:5`
- **Overtime / negative timer** — when countdown hits zero, counts up in red instead of auto-switching
- **Session persistence** — save and restore timer state across OBS restarts
- **Session offset** — resume from a specific session count (e.g., "I already did 3 off-stream")
- **Auto-start toggle** — auto-advance between sessions or pause and wait
- **Session tracking** — "Done: 3/6" counter with configurable goal
- **Break suggestions** — cycle through customizable tips during breaks
- **Total focus time** — tracks cumulative focus seconds across the entire session
- **Crash resilience** — auto-saves state on change (atomic writes, corruption-proof)
- **Drift-proof timing** — wallclock-based (never drifts under CPU load)
- **Time adjustment** — add or subtract minutes mid-session via hotkey

### OBS Environment Control
- **Scene switching** — auto-switch OBS scenes per session type
- **Recording chapter markers** — auto-insert chapters at session transitions (OBS 30.2+)
- **Mic control** — auto-mute/unmute per session type
- **Source visibility** — auto-hide sources during focus (comma-separated list), show on break
- **Volume ducking** — auto-adjust music volume per session (with smooth 3-second fade)
- **Filter toggling** — enable/disable source filters per session type
- **Stream-aware** — auto-start timer when you go live, auto-stop when stream ends
- **Warning alerts** — configurable sounds at 5min, 1min remaining, and before break ends
- **Hotkey support** — Start/Pause, Stop, Skip, Add Time, Subtract Time
- **Background media** — swap background images or looping videos per session type
- **Audio alerts** — per-session custom sounds
- **Source dropdowns** — pick OBS sources and scenes from lists
- **Progress bar** — character-based bar that fills as the session progresses
- **Grouped settings** — collapsible sections keep the UI organized

### Visual Overlay & Dock
- **Browser Source overlay** — circular progress ring with session-colored glow
- **Bar overlay** — horizontal progress bar with glassmorphism backdrop
- **3 built-in themes** — Default, Neon, Minimal, Glassmorphism
- **URL-configurable** — customize size, colors, fonts, and visibility via URL parameters
- **Overtime display** — pulsing red ring and `+MM:SS` counter when in overtime
- **"Next up" indicator** — shows what session comes after the current one
- **Dockable control panel** — dark-themed dashboard with full control buttons via WebSocket
- **Mobile remote** — phone-friendly control page over WebSocket
- **Stream duration tracking** — shows total stream time in the dock
- Both update in real-time by polling the script's state file

### Data & Analytics
- **Session history log** — append-only CSV file with timestamps, durations, and session types
- **Productivity dashboard** — HTML stats page with 7-day chart, streaks, and session log
- **Chat-ready status** — pre-formatted `chat_status_line` in JSON for bot integration
- **Extended state JSON** — 30+ fields available for external tools (bots, Stream Deck, custom apps)

### Technical
- **Pure Lua** — no Python, no external installs, no compilation
- **Zero dependencies** — runs on any OBS 28+ installation
- **Memory safe** — proper reference counting on all OBS API objects
- **Cross-platform** — Windows, macOS, Linux

## Installation

1. Download the entire folder (or clone the repo)
2. Open OBS Studio → **Tools** → **Scripts**
3. Click **+** and select `obs_pomodoro_timer.lua`
4. Configure settings in the script panel

## Setup

### Required OBS Sources

Create these sources in your scene before configuring the script:

| Source | Type | Purpose |
|--------|------|---------|
| Timer display | Text (GDI+) | Shows the countdown (e.g. `24:59`) |
| Session message | Text (GDI+) | Shows "Focus Time", "Short Break", etc. |
| Focus count | Text (GDI+) | Shows "Done: 3/6" |
| Progress bar | Text (GDI+) | Visual progress bar (`████░░░░`) |
| Background media | Image **or** Media Source | Switches per session type |
| Alert sound | Media Source | Plays audio alerts on session change |

> **Note**: Source names are picked from dropdowns in the script settings — no manual typing needed.

### Timer Modes

Select a timer mode from the **"Timer Mode"** dropdown:

| Mode | Behavior |
|------|----------|
| **Pomodoro** | Standard Focus → Short Break → Long Break cycle (default) |
| **Stopwatch** | Counts up from 0:00. No auto-stop. Good for tracking total time on a task. |
| **Countdown** | Single countdown from a set duration. Stops and alerts at zero. |
| **Custom Intervals** | Named segments you define. Enter in the format `Name:Minutes,Name:Minutes,...` |

**Custom Intervals examples:**
- HIIT: `Warm-up:5,Exercise:20,Rest:5,Exercise:20,Cool-down:5`
- Podcast: `Intro:2,Guest Segment:25,Ads:3,Discussion:20,Outro:2`
- Study: `Review:10,Practice:30,Break:5,Practice:30,Break:5`

Custom intervals advance automatically. If "Auto-start Next Session / Loop" is enabled, the sequence restarts from the beginning after the last segment.

### Browser Source Overlay (Optional)

Add a beautiful circular timer overlay to your stream:

1. In OBS, add a new **Browser Source** to your scene
2. Check **"Local file"** and browse to `timer_overlay.html`
3. Set width to **220** and height to **220**
4. Position it wherever you want on your stream layout
5. The overlay automatically connects to the timer — no configuration needed

**URL Customization — append parameters to the file path:**

| Parameter | Values | Example |
|-----------|--------|---------|
| `theme` | `default`, `neon`, `minimal`, `glassmorphism` | `?theme=neon` |
| `size` | Any integer (pixels) | `?size=300` |
| `font` | Any Google Font name | `?font=Outfit` |
| `showStats` | `true` / `false` | `?showStats=false` |
| `showNext` | `true` / `false` | `?showNext=false` |
| `color_focus` | Hex color | `?color_focus=10b981` |
| `color_short_break` | Hex color | `?color_short_break=6366f1` |

Combine parameters: `timer_overlay.html?theme=neon&size=300&font=Outfit`

### Dockable Stats Panel (Optional)

Add a control dashboard that docks into the OBS window:

1. In OBS, go to **View** → **Docks** → **Custom Browser Docks**
2. Enter dock name: `Session Timer`
3. Enter URL: `file:///` followed by the full path to `timer_dock.html`
   - Example: `file:///D:/dev/pro/sbobs/timer_dock.html`
4. Click **Apply** — the dock appears as a draggable panel

Features:
- Dark theme that matches the OBS interface
- **Full control buttons** — Start/Pause, Stop, Skip, +Time, −Time, Reset
- Controls use **obs-websocket** to trigger hotkeys (requires WebSocket enabled)
- WebSocket connection status indicator with auto-reconnect
- Timer mode badge in header
- Large timer display with colored session badge
- Break suggestion display during breaks
- "Next up" indicator showing the upcoming session
- Stats grid: sessions, focus time, cycle, progress, stream duration
- Chat status line with click-to-copy
- Overtime display with red pulsing indicator

**WebSocket Setup (for dock control buttons):**

1. In OBS, go to **Tools** → **WebSocket Server Settings**
2. Check **"Enable WebSocket server"**
3. Note the port (default: `4455`) and set a password if desired
4. The dock auto-connects to `ws://127.0.0.1:4455` on load
5. If you set a password, append it to the dock URL: `?ws_password=YOUR_PASSWORD`
6. Custom port: `?ws_port=4466&ws_password=YOUR_PASSWORD`

> **Note**: If WebSocket is unavailable, the dock still works as a read-only display. The control buttons are disabled until a WebSocket connection is established.

### Bar Overlay (Optional)

A horizontal progress bar overlay — perfect for the top or bottom of your stream:

1. Add a new **Browser Source** to your scene
2. Check **"Local file"** and browse to `timer_overlay_bar.html`
3. Set width to **1920** (or your stream width) and height to **36**
4. Position at the top or bottom edge of your canvas

**URL parameters:**
- `?position=top` — slides in from top (default)
- `?position=bottom` — slides in from bottom

The bar automatically hides when the timer is idle and slides in when running.

### Productivity Stats Dashboard (Optional)

A full-page stats dashboard that reads your session history:

1. Open `timer_stats.html` in any browser, or dock it in OBS
2. Shows: today's focus time, total sessions, day streak, avg session duration
3. 7-day focus time chart
4. Recent sessions log table with completion status
5. Auto-refreshes every 30 seconds

> **Note**: Requires "Log Sessions to CSV File" to be enabled in script settings.

### Mobile Remote Control (Optional)

Control the timer from your phone during streams:

1. Open `timer_remote.html` on your phone's browser
2. Enter your OBS machine's IP address (e.g. `192.168.1.5`), port, and password
3. Large touch-friendly buttons: Start/Pause, Stop, Skip, +Time, −Time
4. Connection settings are saved in localStorage for next time

> **Requires**: OBS WebSocket enabled, phone on the same network as OBS machine.

### Volume Ducking (Optional)

Auto-adjust music volume based on session type:

1. Select a music source from **"Volume Ducking Source"** dropdown
2. Set **"Focus Volume %"** (default: 30%) — volume during focus sessions
3. Set **"Break Volume %"** (default: 80%) — volume during breaks
4. Enable **"Smooth Volume Fade"** for a 3-second ease-in-out transition

### Filter Toggle (Optional)

Auto-enable/disable source filters per session type:

1. Select the source from **"Filter Toggle Source"** dropdown (e.g. your Camera)
2. Enter filter names to **enable during Focus** (comma-separated)
3. Enter filter names to **disable during Focus** (comma-separated)

Example: Enable "Color Correction" during focus, disable "Background Blur" during focus (which means it gets enabled during breaks).

### Scene Switching (Optional)

1. Create separate scenes for each session type
2. Enable **"Enable Scene Switching"** in the script settings
3. Assign scenes from the dropdowns

### Mic Control (Optional)

1. Enable **"Enable Mic Control"** in settings
2. Select your mic from the dropdown
3. Check **"Mute Mic During Focus"** to mute during focus and unmute on breaks

### Recording Chapter Markers

Automatically inserts chapter markers at every session transition. Shows up as chapters in video players. **Requires**: OBS 30.2+, MP4/MKV format.

### Source Visibility (Optional)

Auto-hide sources during focus sessions:

1. Enter source names in **"Hide During Focus"** (comma-separated for multiple)
2. Example: `Webcam, Chat Box, Alerts`
3. Sources are disabled during Focus and re-enabled during breaks

### Break Suggestions

Rotating tips during break sessions (e.g. "Short Break · Stretch!"). Customize via a comma-separated list.

### Session History Log

Enable **"Log Sessions to CSV File"** to track every session:

```csv
date,time,session_type,duration_seconds,completed,mode,total_focus
2026-03-31,10:45:23,Focus,1500,true,pomodoro,1500
2026-03-31,11:10:25,Short Break,300,true,pomodoro,1500
```

The file (`session_history.csv`) is created next to the script. Import into any spreadsheet for productivity analysis.

### Overtime (Negative Timer)

Enable **"Enable Overtime"** to prevent auto-switching when a session ends:

- When the timer hits 0:00, it starts counting up: `+00:01`, `+00:02`, etc.
- The overlay turns red with a pulsing ring
- Use **Skip** to manually move to the next session
- Great for "I need a few more minutes" situations

### Stream-Aware Behavior (Optional)

- **Auto-start on stream**: Timer starts when you click "Start Streaming"
- **Auto-stop on stream end**: Timer stops with session summary
- Both are off by default

## Session Persistence

The timer saves state to `pomodoro_state.json` on every change (not every second — only when something meaningful changes). Uses atomic writes (temp file + rename) to prevent corruption. Resume after crashes, OBS restarts, or stream interruptions via the "Resume Previous Session" button.

### State Migration

v5.0 changed the timer engine from tick-counting to wallclock-based timing. Old v4.x state files are automatically migrated on resume — the wallclock epoch is synthesized from the saved `current_time`.

## Hotkeys

Go to **Settings** → **Hotkeys** and search for "Pomodoro":

| Hotkey | Action |
|--------|--------|
| Pomodoro: Start / Pause | Toggle timer on/off |
| Pomodoro: Stop | Stop and reset |
| Pomodoro: Skip Session | Jump to next session |
| Pomodoro: Add Time | Add N minutes to current session |
| Pomodoro: Subtract Time | Subtract N minutes from current session |

The time adjustment increment (default: 5 minutes) is configurable in script settings.

## Configuration

All settings in **Tools** → **Scripts** → select the script:

### Timer Mode
- **Timer Mode** — Pomodoro / Stopwatch / Countdown / Custom Intervals
- **Countdown Duration** — for Countdown mode (1–480 min)
- **Custom Intervals** — `Name:Min,...` format

### Durations (Pomodoro)
- Focus Duration (1–120 min, default: 25)
- Short Break (1–30 min, default: 5)
- Long Break (1–60 min, default: 15)
- Long Break interval (every N cycles, default: 4)
- Starting Session Offset (default: 0)

### Behavior
- **Auto-start Next Session / Loop**
- **Show Progress Bar**
- **Enable Overtime** — negative timer
- **Break Suggestions** — comma-separated tips
- **Log Sessions to CSV File**

### Volume Ducking
- **Volume Ducking Source** — music source dropdown
- **Focus Volume %** — slider (default: 30%)
- **Break Volume %** — slider (default: 80%)
- **Smooth Volume Fade** — 3-second ease-in-out

### Filter Toggle
- **Filter Toggle Source** — e.g. Camera
- **Enable During Focus** — comma-separated filter names
- **Disable During Focus** — comma-separated filter names

### Scene Switching, Mic Control, Source Visibility
- Enable/configure each from dedicated sections

### Messages
All session and transition messages are customizable.

## State File (External API)

The `pomodoro_state.json` file is the **public API** for external tools. Any bot, Stream Deck plugin, or custom application can read it:

```json
{
  "version": "5.0.0",
  "timer_mode": "pomodoro",
  "is_running": true,
  "session_type": "Focus",
  "current_time": 1234,
  "total_time": 1500,
  "completed_focus_sessions": 2,
  "goal_sessions": 6,
  "total_focus_seconds": 3000,
  "is_overtime": false,
  "overtime_seconds": 0,
  "next_session_type": "Short Break",
  "next_session_in": 1234,
  "sessions_remaining": 4,
  "break_suggestion": "Stretch!",
  "stream_duration": 7200,
  "chat_status_line": "Focus 20:34 (2/6)",
  "session_epoch": 1743385200,
  "session_pause_total": 0,
  "session_target_duration": 1500,
  "timestamp": 1743385200
}
```

The `chat_status_line` field is a pre-formatted string ready for chat bot responses. Use this for `!timer`, `!focus`, or `!study` commands in Nightbot, StreamElements, Fossabot, etc.

## File Structure

```
sbobs/
├── obs_pomodoro_timer.lua    # Main script (load this in OBS)
├── timer_overlay.html        # Browser Source overlay — circular ring (viewers)
├── timer_overlay_bar.html    # Browser Source overlay — horizontal bar (viewers)
├── timer_dock.html           # Custom Browser Dock with WebSocket control (streamer)
├── timer_stats.html          # Productivity stats dashboard (streamer)
├── timer_remote.html         # Mobile remote control page (phone)
├── pomodoro_state.json       # Auto-generated state file (git-ignored)
├── session_history.csv       # Auto-generated session log (git-ignored)
├── README.md
├── LICENSE
└── .gitignore
```

## Compatibility

- OBS Studio 28+ (chapter markers require 30.2+)
- obs-websocket 5.x (built into OBS 28+ — enable in Tools → WebSocket Server Settings)
- Windows, macOS, Linux
- No Python required

## Roadmap

- [x] **v2.0** — Core rewrite: hotkeys, source dropdowns, bug fixes
- [x] **v2.1** — Session persistence, background video support
- [x] **v2.2** — Scene switching, chapter markers, mic control, stream awareness
- [x] **v3.0** — Browser Source overlay + dockable stats panel
- [x] **v3.1** — Timer modes, break suggestions, source visibility
- [x] **v4.0** — Volume ducking, filter toggle, overtime, session log, overlay themes, extended API
- [x] **v5.0** — Wallclock timing, WebSocket dock control, warning alerts, time adjustment, bar overlay, stats dashboard, mobile remote, multi-source visibility, grouped settings UI, chat status line, atomic writes

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

## License

MIT — see [LICENSE](LICENSE)
