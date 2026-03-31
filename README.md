# OBS Pomodoro Timer

A customizable Pomodoro timer script for OBS Studio. Built for "study with me" and "work with me" live streams.

## Features

- **Full Pomodoro cycle** — Focus → Short Break → Long Break, auto-cycling
- **Hotkey support** — Start/Pause, Stop, and Skip from anywhere in OBS (no need to open the Scripts panel)
- **Audio alerts** — Per-session custom sounds (focus, short break, long break)
- **Background switching** — Automatically swap background images per session type
- **Progress bar** — Character-based bar that fills as the session progresses
- **Session tracking** — "Done: 3/6" counter with configurable goal
- **Transition messages** — Brief overlay messages between sessions ("Time for a break!")
- **Auto-start toggle** — Choose between auto-advancing or pausing between sessions
- **Source dropdowns** — Pick OBS sources from a list instead of typing names manually
- **Zero dependencies** — Pure Lua, no Python or external installs required

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
| Background image | Image | Switches per session type |
| Alert sound | Media Source | Plays audio alerts on session change |

> **Note**: Source names are picked from dropdowns in the script settings — no manual typing needed.

### Audio Setup

The alert sound source must be a **Media Source** (not a regular audio input). The script changes its file path and triggers playback on each session transition.

## Hotkeys

After loading the script, go to **Settings** → **Hotkeys** and search for "Pomodoro":

| Hotkey | Action |
|--------|--------|
| Pomodoro: Start / Pause | Toggle timer on/off |
| Pomodoro: Stop | Stop and reset to Focus |
| Pomodoro: Skip Session | Jump to next session |

## Configuration

All settings are available in the script panel (**Tools** → **Scripts** → select the script):

### Durations
- Focus Duration (1–120 min, default: 25)
- Short Break (1–30 min, default: 5)
- Long Break (1–60 min, default: 15)
- Long Break interval (every N cycles, default: 4)

### Behavior
- **Auto-start Next Session** — When enabled, the next session starts immediately. When disabled, the timer pauses between sessions and waits for you to resume.
- **Show Progress Bar** — Toggle the visual progress bar on/off
- **Goal Sessions** — Target number of focus sessions (used in the "Done: X/Y" counter)

### Messages
All session and transition messages are customizable.

## Compatibility

- OBS Studio 28+ (uses LuaJIT, built-in)
- Windows, macOS, Linux
- No Python required

## License

MIT — see [LICENSE](LICENSE)
