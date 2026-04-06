# FAQ & Troubleshooting

Common issues and their solutions, organized by category.

---

## Timer Issues

### Timer doesn't start

1. **Check the Script Log:** Tools → Scripts → Script Log. Look for errors.
2. **Loaded correctly?** You should see `[SessionPulse] Loaded v6.0.0` in the log.
3. **Hotkey set?** Go to Settings → Hotkeys → search "SessionPulse". Make sure Start/Pause has a key assigned.
4. **Custom Intervals format:** If using Custom mode, verify the format is `Name:Minutes,Name:Minutes` — no spaces around colons.

### Timer shows wrong time

- SessionPulse uses **wallclock timing** (`os.time()`), so the timer is always accurate even under CPU load.
- If the time seems wrong, check if you accidentally added/subtracted time with the time adjustment hotkey.
- Check the **Starting Session Offset** setting — if set to a non-zero value, sessions start from that count.

### Timer doesn't auto-advance

- Check that **Auto-start Next / Loop** is enabled in script settings.
- If **Overtime** is enabled, the timer will count up past zero instead of auto-transitioning. Disable overtime or manually skip.

### Timer doesn't survive OBS restart

- SessionPulse auto-saves public runtime state to `session_state.json` and keeps a separate internal recovery snapshot in `session_resume.json`.
- After restarting OBS, look for the **Resume Previous Session** option in the script settings.
- Resume restores the exact saved timer value and progress position; it does not reset the segment back to the beginning.
- If the resume snapshot is missing or corrupted, the session cannot be restored.


### OBS freezes / "Not Responding" when session transitions

- SessionPulse no longer switches OBS scenes automatically.
- If OBS was crashing during Focus/Break transitions, keep Scene Switching disabled and use source-level automation instead.
- If you still need different layouts, switch scenes manually or with a dedicated scene-management tool outside SessionPulse.

---

## Overlay Issues

### Overlay shows "Offline" or nothing

1. **Same directory?** — `timer_overlay.html` and `session_pulse.lua` **must be in the same folder**. The overlay reads `session_state.json` via relative path.
2. **Local file checked?** — In Browser Source properties, make sure **✅ Local file** is checked.
3. **Timer running?** — The overlay only shows content when the timer is active. Start a session first.
4. **Refresh** — Right-click the Browser Source in OBS → **Refresh**.

### Overlay is too big or too small

- The overlay renders at **400×400** by default for maximum crispness.
- In OBS, resize using **Edit Transform** (right-click the source → Transform → Edit Transform) to scale it down.
- Alternatively, drag the source corners in the OBS preview to resize visually.
- For a different base resolution, set `--sp-size` in Custom CSS: `body { --sp-size: 600; }` and update Browser Source Width/Height to match.

### Overlay colors are wrong

Override session colors in the Browser Source **Custom CSS** field:
```css
body { --focus-color: #ec4899; --short-break-color: #06b6d4; }
```
See [Overlay Customization](overlay-customization.md) for all available color properties.

### How do I change the overlay theme?

Paste one of the theme presets into the Browser Source **Custom CSS** field. For example, the **Neon** theme:
```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; --sp-ring-stroke: 6; --sp-ring-filter: drop-shadow(0 0 8px currentColor); --sp-glow-filter: blur(40px); }
```
See [Overlay Customization](overlay-customization.md) for all themes and properties.

### Overlay doesn't update / is frozen

- The overlay polls `session_state.json` every 750ms. If it's not updating:
  - Check that the file exists in the SessionPulse folder
  - Try removing and re-adding the Browser Source
  - Check OBS Script Log for write errors

---

## Dock Issues

### Dock buttons are grayed out / disabled

- Dock control requires **WebSocket connection**.
- Enable WebSocket: **Tools** → **WebSocket Server Settings** → **Enable** ✅
- Without WebSocket, the dock still works as a **read-only display** (shows timer, stats, chat status).

### Dock shows "WS ✗" (disconnected)

1. **WebSocket enabled?** — Tools → WebSocket Server Settings → enable it
2. **Password correct?** — If you set a password, add `?ws_password=YOUR_PASSWORD` to the dock URL
3. **Port correct?** — Default is `4455`. Check in WebSocket Server Settings.
4. **Multiple docks?** — Each dock creates its own WebSocket connection. Too many can hit OBS limits.

### Dock shows timer but wrong values

- The dock reads from `session_state.json` — same file as the overlay.
- Make sure the dock URL points to the correct folder using `file:///`.
- Most reliable setup: pass the state file explicitly, e.g. `timer_dock.html?state_path=file:///D:/tools/SessionPulse/session_state.json`
- Try closing and re-opening the dock (View → Docks).

### Daily goal bar doesn't appear

- Daily goal must be set to a value **greater than 0** in script settings.
- Set **Daily Focus Goal (minutes)** to your target (e.g., `120` for 2 hours).
- The bar appears below the control buttons.

---

## Sound Issues

### Alert sounds don't play

1. **Media Source exists?** — You need a **Media Source** in your active scene.
2. **Selected in settings?** — Set it in the **Alert Sound Source (Media)** dropdown.
3. **Sound files set?** — Configure file paths in the Alert Sounds section.
4. **Source in active scene?** — The Media Source must be in the **currently active scene** to play.
5. **Volume not zero?** — Check the Media Source's volume in OBS's audio mixer.

Quick Setup creates `SP Alert Sound` automatically, so in most cases you only need to assign the audio files.

### How do I show an AFK / BRB / custom status message?

- You can create an `SP Status` text source manually (see [Manual Text Sources](overlay-customization.md#manual-text-sources-advanced)), or use the overlay's built-in status display.
- In the script panel, type your message in **Status Message** and click **Show Status**.
- Set **Duration (minutes)** to `0` to keep it visible until cleared, or a positive number to auto-clear it.
- Click **Clear Status** when you return.
- The status message also appears in the dock, ring overlay, and bar overlay automatically.

### Background image or video doesn't change

1. **Correct source type selected?** — `Background Visual Source` must point to either `SP Background Image` or `SP Background Video`.
2. **Matching file fields filled?** — Image sources use the `Focus/Break Image` fields, while media sources use the `Focus/Break Video` fields.
3. **Source in active scene?** — The selected background source must be present in the current scene.

Quick Setup creates both `SP Background Image` and `SP Background Video`, so you can pick the one that matches your setup.

### Background music doesn't play

1. **Media Source exists?** — Use a Media Source such as `SP Background Music`.
2. **Selected in settings?** — Choose it in **Background Music Source**.
3. **Track set?** — Set **Looping Music Track** to an audio file.
4. **Timer running?** — Background music starts only while the timer is active.

### Warning sounds don't trigger

- Check that warning checkboxes are enabled (5-min, 1-min, break ending).
- Warning sounds use the same Media Source as alerts — make sure it's configured.
- The break ending warning triggers N seconds before the break ends (configurable).

---

## Automation Issues

### Scene switching doesn't work

- Automatic scene switching has been removed from SessionPulse for stability.
- Keep your timer flow inside one stable scene, or change scenes manually if you need a full layout swap.

### Volume ducking isn't smooth

- Enable **Smooth Volume Fade** ✅ in script settings.
- Increase **Fade Duration** (default 3 seconds, up to 15).
- If it's still jarring, the source might have its own volume automation conflicting.

### Mic doesn't mute/unmute

- Check that the correct mic source is selected in the dropdown.
- The script mutes/unmutes the OBS source directly — if another plugin is also controlling the mic, there may be conflicts.

### Filters don't toggle

- Filter names are **case-sensitive** — `Color Correction` ≠ `color correction`.
- Separate multiple filter names with commas: `Filter A,Filter B`
- OBS 30.2+ required for reliable filter toggling.

---

## Data Issues

### CSV file not created

- Enable **Log Sessions to CSV File** in script settings.
- The file (`session_history.csv`) is created in the same folder as `session_pulse.lua`.
- The first row is logged after you **complete** a session (not when you start one).

### CSV has corrupted rows

- This was fixed in **v5.3.1** — labels with commas are now properly quoted per RFC 4180.
- If you have old corrupted data, delete the affected rows from `session_history.csv`.

### `session_state.json` is empty or contains `{}`

- The file is written atomically (temp file -> rename/restore fallback). An empty file usually means a write was interrupted or the folder is blocked by permissions.
- Restart the timer — it will re-create the state file.
- If Resume Previous Session also disappears, check whether `session_resume.json` is being created in the same folder.

---

## Performance

### Does SessionPulse affect stream performance?

No measurable impact:
- The timer tick runs once per second via OBS's timer API
- JSON file writes are atomic and take <1ms
- Overlay polling uses lightweight fetch polling roughly every 750ms (negligible)
- Volume fading uses OBS's native volume API with smooth interpolation

### Does it work with 100+ sources?

Yes — SessionPulse only interacts with the sources you configure in the dropdowns. It doesn't scan or iterate over all sources.

---

## Reset & Recovery

### How do I reset everything?

1. Press the **Reset** hotkey (or the Reset button in the dock)
2. This clears: session count, cycle count, focus time, streak, daily progress

### How do I start fresh?

1. Stop the timer
2. Delete `session_state.json` and `session_resume.json` from the SessionPulse folder
3. Restart OBS or reload the script (Tools → Scripts → 🔄)

### How do I keep my CSV history but reset the timer?

- The CSV file is independent of the timer state
- Resetting the timer doesn't affect `session_history.csv`
- Your history is safe — only manual deletion removes it
