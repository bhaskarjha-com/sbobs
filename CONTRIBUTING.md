# Contributing to SessionPulse

Thanks for your interest in contributing! SessionPulse is a session automation engine for OBS Studio — every improvement directly helps streamers and creators worldwide.

## How to Contribute

### Reporting Bugs

- Open an [issue](../../issues) with:
  - OBS Studio version
  - Operating system
  - Steps to reproduce
  - What you expected vs. what happened
  - Relevant lines from OBS Script Log (`Tools → Scripts → Script Log`)

### Suggesting Features

- Open an [issue](../../issues) tagged with `enhancement`
- Describe the use case — *why* do you need it, not just *what*

### Submitting Code

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-change`
3. Make your changes
4. Test in OBS Studio (load the script, run through a full focus/break cycle)
5. Submit a Pull Request

## Architecture Overview

```
session_pulse.lua          ← Core engine (Lua, runs inside OBS)
                              ↓ writes
                         session_state.json    ← Public state API (JSON file)
                              ↑ reads
┌──────────────────┬──────────────────┬────────────────┬──────────────┐
│ timer_dock.html  │ timer_overlay.html│ timer_stats.html│ timer_remote │
│ (Control Dock)   │ (Ring Overlay)   │ (Stats Page)   │ (Mobile)     │
│ WebSocket + Poll │ Poll only        │ CSV + Poll     │ WebSocket    │
└──────────────────┴──────────────────┴────────────────┴──────────────┘
shared.js ← Reference utilities (ES module for custom integrations)
```

### Key Design Decisions

- **Flat file structure** — OBS Browser Sources use `file://` protocol and resolve relative paths from the script directory. Subdirectories would break source resolution.
- **Inline JS in HTML** — OBS's CEF (Chromium Embedded Framework) doesn't reliably support ES module imports from `file://` origins. Each HTML file is self-contained by necessity.
- **Wallclock-based timing** — `os.time()` instead of tick-counting to prevent drift under CPU load.
- **JSON state file as API** — Simpler and more universal than WebSocket for read-only consumers (bots, Stream Deck, etc.).

### Code Style

- **Lua**: 4-space indentation, `local` everything, release all OBS source references
- **HTML/JS**: 2-space indentation, vanilla JS only, no build tools
- **Naming**: `snake_case` for Lua and JSON fields, `camelCase` for JS variables

### Testing

**Automated tests** — run these first, they must pass:

```bash
lua tests/test_session_pulse.lua    # 67 tests: CSV, JSON, timing, parsing
node tests/test_frontend.js         # 55 tests: CSV parser, formatting, badges
```

**Manual verification in OBS** — verify after code changes:

- [ ] Timer starts, pauses, resumes, stops, and resets correctly
- [ ] Session transitions work (Focus → Break → Focus)
- [ ] Overlay displays correctly (ring + bar)
- [ ] Dock buttons work via WebSocket
- [ ] State JSON updates reflect changes
- [ ] No OBS Script Log errors

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
