# Changelog

All notable changes to SessionPulse are documented here.

## [6.0.0] — 2026-04-06

### Breaking Changes
- **Overlay-first Quick Setup** — Quick Setup no longer auto-creates 5 text sources (`SP Timer`, `SP Session`, `SP Count`, `SP Progress`, `SP Status`). Overlays now handle all visual display. Power users can still manually create text sources — see `docs/overlay-customization.md`.
- **Asset directory reorganized** — README screenshots moved from `assets/` to `assets/screenshots/`. Background images in `assets/backgrounds/`, alert sounds in `assets/sounds/`.

### Added
- **Default background images** — 3 AI-generated, color-matched 1920×1080 PNG backgrounds bundled in `assets/backgrounds/` (Focus: green hexagonal, Short Break: blue waves, Long Break: purple rings). Quick Setup auto-assigns them when no custom paths are configured.
- **Default alert sounds** — 3 royalty-free MP3 alert sounds bundled in `assets/sounds/` (focus_start, short_break_start, long_break_start). Quick Setup auto-assigns them when no custom paths are configured. Sounds play when a session starts (matching the code's session_type assignment order).
- **`SP Overlay Bar`** — bar overlay is now auto-created by Quick Setup alongside the ring overlay.
- **One-click complete stream setup** — Quick Setup now configures everything needed for a fully functional stream layout in a single click: overlays, backgrounds, alert sounds, music source, and infrastructure.

### Changed
- **Bar overlay progress bar** — removed `max-width: 40%` cap; progress bar now fills all available space between timer and right-side info. Eliminates the large empty gap.
- **Bar overlay typography** — session counter bumped to `0.95rem` with primary text color; next-info bumped to `0.92rem`. Both are now more readable.
- **Bar overlay divider** — increased height (16px → 20px), opacity (0.15 → 0.3), and width (1px → 1.5px) for better visual separation.
- **Asset organization** — `assets/` now has 3 subdirectories: `backgrounds/`, `screenshots/`, `sounds/`.

### Fixed
- **Lua test failures** — removed 5 stale assertions checking for auto-created text sources; added bar overlay placement test. Added `obs_video_info` nil guard in `fit_source_to_canvas` for test environments.
- **Test counts** — Lua runtime queue: 79 → 75 (removed stale, added new); JS frontend: 104 (unchanged).

## [5.4.1] — 2026-04-02

### Fixed
- **CRITICAL: OBS "Not Responding" deadlock on scene transitions** — `obs_frontend_set_current_scene()` was called from a `timer_add` callback (graphics thread) which holds the Lua mutex. This function posts to the Qt UI thread and blocks. If the Qt UI thread needed the Lua mutex (for property refreshes, event callbacks, etc.), both threads waited on each other → deadlock. Fix: replaced the `timer_add(callback, 20)` pattern with `script_tick()` polling. Scene switches are now queued as a flag and executed in `script_tick()`, which runs in the main application loop's execution context — the documented safe context for OBS frontend API calls. Added pcall guard, cooldown, and stale-request timeout.
- **Quick Setup scene dropdowns stuck on "(None)"** — after creating "SP Focus" / "SP Break" scenes, the scene-list dropdowns hadn't been re-populated so `obs_properties_apply_settings` silently rejected the new values (no matching item → fallback to empty string). Fix: re-populate both scene list and source list dropdown properties from the live OBS state *after* scene/source creation, *before* applying settings.
- **Quick Setup source dropdowns** — same stale-list issue affected the four text source dropdowns (`SP Timer`, `SP Session`, `SP Count`, `SP Progress`) and `SP Overlay`. Now all source-list properties are refreshed after Quick Setup creates items.
- **`compute_daily_focus` CSV parser couldn't parse its own output** — `log_session()` wraps all fields in double quotes, but the CSV reader used a naive `([^,]+)` pattern that can't handle quoted fields. Daily goal progress would silently read 0 instead of the actual focus total. Fixed with a quote-aware pattern.
- **Version mismatch across project** — `VERSION` was `5.4.1` in Lua but `shared.js`, `timer_dock.html` footer, `docs/getting-started.md`, `docs/faq.md`, and the Lua header comment all referenced `5.4.0`. All synced to `5.4.1`.
- **README.md was empty** — contained only `=` (1 byte). Rebuilt with full project overview, feature table, quick start guide, state file API documentation, project structure, and links to all 7 docs.
- **Overlay customization docs had wrong parameter names** — documented `color_short`, `color_long`, `color_paused` but code actually uses `color_short_break`, `color_long_break`; `color_paused` and `showTime` params don't exist. Default size was documented as 200 but actual is 220.
- **Integrations doc `getBadgeInfo()` example was wrong** — showed `getBadgeInfo(state.session_type)` but the function takes the full state object, not a type string.
- **Integrations doc broken README link** — referenced `../README.md#state-file-api` anchor that didn't exist.
- **Architecture doc file structure was incomplete** — only listed 3 files; now documents all 12+ project files in a table.
- **Test suites tested different behavior than actual code** — `format_time` tests used non-zero-padded output (`0:01`) when actual code produces zero-padded (`00:01`); negative time tests expected `-1:30` when actual code clamps to `00:00`; CSV parser tests used the old broken pattern. All tests now mirror actual code behavior.
- **`stop_timer()` didn't reset `completed_focus_sessions`** — stopping then restarting would show stale session count, and the `starting_session_offset` logic would fire incorrectly on the second start. Now resets alongside `cycle_count`.
- **`skip_session()` on stopped timer caused uninitialized state** — set `is_running=true` but never called `start_timer()`'s initialization (no `session_epoch`, `session_target_duration`, or `session_type` assignment). Now properly delegates to `start_timer()` first.
- **`subtract_time()` could trigger `switch_session()` while paused** — subtracting enough time to push `current_time <= 0` during a pause would unexpectedly advance to the next session. Added `is_paused` guard.
- **`fire_warning_alert()` always used focus alert sound** — break-ending warnings played the focus sound instead of the break's configured alert sound. Now uses session-type-aware sound selection matching `play_alert_sound()`.
- **`json_escape()` catch-all `[%c]` pattern could re-match already-escaped chars** — the control character fallback `[%c]` includes `\n`, `\r`, `\t` which were already handled by earlier substitutions. Narrowed to explicit char ranges excluding 0x09, 0x0A, 0x0D.
- **`paused_message` was hardcoded and not user-configurable** — variable initialized as `"Paused"` but had no `script_defaults` entry, no `script_properties` UI field, and was never read from settings. Added to all three.
- **`update_display_texts()` progress bar used potentially stale `current_time`** — during the transition window or when called from non-tick contexts, `current_time` could lag. Now uses `compute_current_time()` for fresh values.

## [5.4.0] — 2026-03-31

### Added
- **🚀 Quick Setup wizard** — one-click button that auto-creates text sources (`SP Timer`, `SP Session`, `SP Count`, `SP Progress`), a ring overlay Browser Source (`SP Overlay`), Focus and Break scenes (`SP Focus`, `SP Break`), wires all sources to script settings, and enables scene switching. Detects platform (GDI+ on Windows, FreeType2 on Mac/Linux). Safe to re-run (skips existing items).
- **`docs/` directory** — 6 comprehensive guides:
  - `getting-started.md` — zero-to-hero for complete beginners
  - `overlay-customization.md` — themes, colors, URL params, setup recipes
  - `automation-guide.md` — scene switching, volume ducking, mic, filters, chapters, custom intervals
  - `integrations.md` — Nightbot, Stream Deck, custom tools with code examples
  - `mobile-remote.md` — phone setup, IP finding, home screen bookmark
  - `faq.md` — 30+ issues organized by category
- **`tests/` directory** — automated test suites checked into the repo:
  - `test_session_pulse.lua` — 67 Lua core logic tests
  - `test_frontend.js` — 55 JavaScript frontend tests
- **GitHub Actions CI** — `.github/workflows/test.yml` runs both test suites on push and PR
- **`.editorconfig`** — enforces 4-space Lua, 2-space HTML/JS, LF line endings

### Changed
- **README restructured** — trimmed from 584 to ~275 lines; detailed setup moved to `docs/getting-started.md`; added Documentation section linking all 6 guides; Quick Start now highlights the Quick Setup button
- **CONTRIBUTING.md** — added automated test commands above manual testing checklist

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
