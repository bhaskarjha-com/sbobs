# Changelog

All notable changes to SessionPulse are documented here.

## [5.3.1] — 2026-03-31

### Added
- **Label column in stats dashboard** — session history table now shows what you were working on
- **Configurable HTTP port in mobile remote** — no longer hardcoded to 8080, saved to localStorage
- **HTML escaping in stats dashboard** — labels with special characters render safely

### Fixed
- **CSV label injection** — labels containing commas corrupted CSV rows; now properly quoted per RFC 4180
- **CSV parser** — stats dashboard parser now handles quoted fields correctly (supports commas in labels)
- **Daily goal progress bar color** — bar no longer stays green after dropping below 100% (e.g., new day)
- **README version references** — troubleshooting section referenced v5.1.0, state JSON example was missing v5.3 fields (`focus_streak`, `show_transition`, `custom_segment_name`, etc.)
- **`shared.js` documentation** — clarified it's a reference module for custom integrations, not consumed by built-in UIs (CEF `file://` protocol doesn't support ES module imports)

## [5.3.0] — 2026-03-31

### Added
- **Focus streak** — tracks consecutive completed focus sessions (`🔥3 in a row!`), displayed in dock, logged to script log, and exposed as `focus_streak` in state JSON
- **Warnings for custom intervals** — break-end warnings now fire in Custom and Countdown modes, not just Pomodoro

### Changed
- Warning log message: "break ending" → "session ending" (accurate for all modes)

## [5.2.0] — 2026-03-31

### Added
- **Session labels** — name what you're working on (text field in script settings), saved to CSV and state JSON, displayed in dock
- **Daily focus goal** — configurable daily goal in minutes, with progress bar in dock; reads CSV history on load for cumulative tracking
- **Configurable fade duration** — volume ducking fade time now user-adjustable (1–15 sec, default 3s) instead of hardcoded
- **`session_label` field** in state JSON — current work label for external tools
- **`daily_focus_seconds` field** in state JSON — today's cumulative focus time (from CSV + current session)
- **`daily_goal_seconds` field** in state JSON — configured daily goal in seconds (0 = disabled)
- **Custom intervals validation** — parsed segments are logged to OBS script log for verification on every settings update
- **`label` column** in session CSV — tracks what the user was working on per session

### Changed
- Mic control label clarified — now reads "Mute During Focus (uncheck to mute during breaks instead)"
- Volume ducking UI — "Smooth Volume Fade (3s)" split into toggle + separate "Fade Duration (sec)" slider
- State JSON expanded to 36+ fields

## [5.1.0] — 2026-03-31

### Added
- **"Ends at" time display** — shows when the current session will end (e.g., "Ends 15:45") in dock, overlays, and state JSON
- **Reset hotkey** — `SessionPulse: Reset All` hotkey for full progress reset via WebSocket, Stream Deck, or keyboard
- **`ends_at` field** in state JSON — human-readable local time string for external tools
- **`elapsed_seconds` field** in state JSON — seconds elapsed in current session
- **`progress_percent` field** in state JSON — 0–100 integer, pre-computed for external tools
- **Filter toggle fallback** — `pcall` wrapper for OBS 28–30.1 backward compatibility
- **`shared.js`** — shared utility module for HTML frontends (eliminates code duplication)

### Fixed
- **Warning alerts could be missed** — removed narrow 2-second detection window; warnings now fire reliably using flag-only threshold checks
- **Overtime used tick-counting** — overtime now uses wallclock timing (drift-proof, matches the main timer engine)
- **Stats dashboard duplicated tables** — `renderLog()` now clears previous table before appending on auto-refresh
- **`stop_timer()` ignored current mode** — stopping a countdown/custom/stopwatch timer no longer resets to Pomodoro defaults
- **Dock reset button only stopped** — now triggers the dedicated reset hotkey (clears progress, not just stops)

### Changed
- Version bumped to 5.1.0 across all files

## [5.0.0] — 2026-03-31

### Added
- Drift-proof wallclock-based timing engine (replaces tick-counting)
- WebSocket dock control panel (`timer_dock.html`) with full button controls
- Warning alerts at 5min, 1min remaining, and before break ends
- Time adjustment hotkeys (add/subtract minutes mid-session)
- Horizontal bar overlay (`timer_overlay_bar.html`)
- Productivity stats dashboard (`timer_stats.html`) with 7-day chart
- Mobile remote control (`timer_remote.html`)
- Multi-source visibility toggling (comma-separated source names)
- Grouped/collapsible settings UI in OBS script panel
- Chat-ready status line (`chat_status_line` in JSON)
- Atomic writes for state file (temp file + rename)
- State migration from v4.x files

### Changed
- Timer engine rewritten from tick-based to wallclock-based
- State JSON expanded to 30+ fields

## [4.0.0] — 2026-03-30

### Added
- Volume ducking with smooth 3-second fade
- Filter toggling per session type
- Overtime / negative timer mode
- Session history logging to CSV
- Overlay themes: Neon, Minimal, Glassmorphism
- Extended state JSON API for external tools

## [3.1.0] — 2026-03-29

### Added
- Timer modes: Stopwatch, Countdown, Custom Intervals
- Break suggestions during break sessions
- Source visibility toggling during focus

## [3.0.0] — 2026-03-28

### Added
- Browser Source circular overlay (`timer_overlay.html`)
- Dockable stats panel
- URL-configurable overlay customization

## [2.2.0] — 2026-03-27

### Added
- Scene switching per session type
- Recording chapter markers (OBS 30.2+)
- Mic control (auto-mute/unmute)
- Stream-aware behavior (auto-start/stop)

## [2.1.0] — 2026-03-26

### Added
- Session persistence across OBS restarts
- Background video/image support per session type

## [2.0.0] — 2026-03-25

### Added
- Hotkey support (Start/Pause, Stop, Skip)
- Source dropdowns in settings UI
- Core rewrite with proper OBS API reference management
