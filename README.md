# OBS Session Timer

A powerful session timer and environment controller for OBS Studio. Built in pure Lua — zero dependencies, zero setup friction.

Originally designed for "study with me" streams, but works for any timed session format: HIIT workouts, cooking streams, meditation, podcast segments, event broadcasts, and accountability/body doubling streams.

**The timer is the heartbeat. Scenes, audio, visuals, and overlays pulse to that beat.**

## Features

### Core Timer
- **Full Pomodoro cycle** — Focus → Short Break → Long Break, auto-cycling
- **Session persistence** — save and restore timer state across OBS restarts and stream interruptions
- **Auto-start toggle** — auto-advance between sessions or pause and wait for manual resume
- **Session tracking** — "Done: 3/6" counter with configurable goal
- **Total focus time** — tracks cumulative focus seconds across the entire session
- **Crash resilience** — auto-saves state every 30 seconds

### OBS Integration
- **Scene switching** — auto-switch to different OBS scenes per session (Focus Scene, Break Scene, etc.)
- **Recording chapter markers** — auto-insert chapter markers at every session transition (OBS 30.2+, MP4/MKV)
- **Mic control** — auto-mute/unmute your mic per session type (mute during focus, unmute on break)
- **Stream-aware** — auto-start timer when you go live, auto-stop (with summary) when stream ends
- **Hotkey support** — Start/Pause, Stop, and Skip from anywhere in OBS
- **Background media** — swap background images or looping videos per session type
- **Audio alerts** — per-session custom sounds (focus, short break, long break)
- **Source dropdowns** — pick OBS sources and scenes from lists instead of typing names
- **Progress bar** — character-based bar that fills as the session progresses

### Technical
- **Pure Lua** — no Python, no external installs, no compilation
- **Zero dependencies** — runs on any OBS 28+ installation out of the box
- **Memory safe** — proper reference counting on all OBS API objects
- **Cross-platform** — Windows, macOS, Linux

## Installation

1. Download `obs_pomodoro_timer.lua`
2. Open OBS Studio → **Tools** → **Scripts**
3. Click **+** and select the `.lua` file
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

### Scene Switching (Optional)

To have OBS automatically switch scenes on session transitions:

1. Create separate scenes for each session type (e.g. "Study Scene", "Break Scene")
2. Enable **"Enable Scene Switching"** in the script settings
3. Assign scenes from the dropdowns: Focus Scene, Short Break Scene, Long Break Scene

Leave any scene dropdown set to "(None)" to skip switching for that session type.

### Mic Control (Optional)

To have the script auto-mute/unmute your mic:

1. Enable **"Enable Mic Control"** in settings
2. Select your mic from the **"Mic Source"** dropdown
3. Check **"Mute Mic During Focus"** to mute during focus and unmute on breaks (or uncheck for the opposite)

### Recording Chapter Markers

When recording in MP4 or MKV format, the script automatically inserts chapter markers at every session transition. These show up as chapters in video players and editors, making it easy to jump to specific focus segments in VODs.

**Requirements**: OBS 30.2+, recording format must support chapters (Fragmented MP4 or MKV).

The script gracefully handles older OBS versions — no errors if the feature isn't available.

### Background Media

The script supports both **static images** and **looping videos** as backgrounds:

- **Image Source** → use any `.png`, `.jpg`, `.jpeg`, `.bmp`, or `.gif` (including animated GIFs)
- **Media Source** → use any video format OBS supports (`.mp4`, `.webm`, `.mov`, etc.). Videos automatically loop and restart on session transitions.

The script auto-detects the source type and handles it accordingly.

### Stream-Aware Behavior (Optional)

- **Auto-start on stream**: Timer starts automatically when you click "Start Streaming"
- **Auto-stop on stream end**: Timer stops and shows a session summary when the stream ends
- Both are off by default — enable them in the settings if desired

## Session Persistence

The timer automatically saves its state to a JSON file (`pomodoro_state.json` next to the script). This means:

- **Stream interrupted?** → Restart OBS, the timer picks up exactly where you left off
- **OBS crashed?** → State was auto-saved within the last 30 seconds
- **Changing scenes mid-session?** → Timer state is always preserved

A "Resume Previous Session" button appears in the script panel when a saved state is detected. You can also choose to start fresh.

## Hotkeys

After loading the script, go to **Settings** → **Hotkeys** and search for "Pomodoro":

| Hotkey | Action |
|--------|--------|
| Pomodoro: Start / Pause | Toggle timer on/off |
| Pomodoro: Stop | Stop and reset to Focus |
| Pomodoro: Skip Session | Jump to next session |

> **Stream Deck users**: These hotkeys work with Stream Deck's OBS integration — assign them to physical buttons for one-touch control.

## Configuration

All settings are available in the script panel (**Tools** → **Scripts** → select the script):

### Durations
- Focus Duration (1–120 min, default: 25)
- Short Break (1–30 min, default: 5)
- Long Break (1–60 min, default: 15)
- Long Break interval (every N cycles, default: 4)

### Behavior
- **Auto-start Next Session** — auto-advance or pause between sessions
- **Show Progress Bar** — toggle the visual progress bar
- **Goal Sessions** — target focus session count for "Done: X/Y"

### Stream Integration
- **Auto-start Timer on Stream Start** — timer begins when you go live
- **Auto-stop Timer on Stream End** — timer stops and shows summary on stream end
- **Add Recording Chapter Markers** — insert chapters at session transitions (default: on)

### Scene Switching
- **Enable Scene Switching** — master toggle
- **Focus Scene / Short Break Scene / Long Break Scene** — scene dropdowns

### Mic Control
- **Enable Mic Control** — master toggle
- **Mute Mic During Focus** — mute during focus, unmute on break (or vice versa)
- **Mic Source** — dropdown to select your mic

### Messages
All session and transition messages are customizable — change "Focus Time" to "Deep Work", "Short Break" to "Stretch Break", etc.

## Compatibility

- OBS Studio 28+ (chapter markers require 30.2+)
- Windows, macOS, Linux
- No Python required

## Roadmap

- [x] **v2.0** — Core rewrite: hotkeys, source dropdowns, bug fixes
- [x] **v2.1** — Session persistence, background video support
- [x] **v2.2** — Scene switching, chapter markers, mic control, stream awareness
- [ ] **v3.0** — Browser Source overlay (circular progress ring, animations, themes)
- [ ] **v3.1** — Multiple timer modes (stopwatch, countdown, custom intervals)

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

## License

MIT — see [LICENSE](LICENSE)
