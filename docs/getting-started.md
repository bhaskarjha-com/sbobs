# Getting Started with SessionPulse

> **Time to complete:** ~10 minutes  
> **Prerequisite:** OBS Studio 28+ installed ([download here](https://obsproject.com))

This guide takes you from zero to a fully running Pomodoro timer with overlay — no prior OBS scripting experience needed.

---

## Step 1: Download SessionPulse

**Option A — Git clone** (recommended):
```bash
git clone https://github.com/bhaskarjha-com/sbobs.git
```

**Option B — Download ZIP:**
1. Go to the [GitHub repo](https://github.com/bhaskarjha-com/sbobs)
2. Click the green **Code** button → **Download ZIP**
3. Extract the ZIP to a permanent location (e.g., `D:\tools\SessionPulse\`)

> ⚠️ **Important:** Don't put it in a temporary folder. OBS remembers the script path — if you move it later, OBS won't find it.

---

## Step 2: Load the Script in OBS

1. Open **OBS Studio**
2. Go to **Tools** → **Scripts**
3. Click the **+** button (bottom-left)
4. Navigate to where you extracted SessionPulse
5. Select **`session_pulse.lua`**
6. Click **Open**

You should see the script appear in the scripts list. The Script Log (bottom panel) should show:

```
[SessionPulse] Loaded v5.4.1
```

If you see errors instead, check the [FAQ](faq.md).

---

## Step 3: Quick Setup (Recommended) 🚀

Click **one button** and SessionPulse creates everything for you:

1. In the script settings panel (right side), click **🚀 Quick Setup**
2. Done.

This automatically:
- ✅ Creates the **ring overlay** (`SP Overlay` — circular timer, 400×400)
- ✅ Creates the **bar overlay** (`SP Overlay Bar` — horizontal status strip, 1920×48)
- ✅ Creates the internal control source (`SP Control`) used by the dock and overlay controls
- ✅ Creates background sources (`SP Background Image`, `SP Background Video`)
- ✅ Assigns **default background images** (Focus, Short Break, Long Break) — color-matched to the overlays
- ✅ Creates a looping music source (`SP Background Music`)
- ✅ Creates an alert sound source (`SP Alert Sound`)
- ✅ Adds all sources to your currently active scene
- ✅ Auto-fits background sources to your canvas (any resolution)

Check the Script Log to confirm:
```
[SessionPulse] Quick Setup: ✓ Complete! Created 8 items. Press Start to begin!
```

> **Skip to [Step 4: Set Up Hotkeys](#step-4-set-up-hotkeys)** — overlays and sources are ready.

If OBS closes during a session, reopen OBS and use **Resume Previous Session** in the script panel to continue from the exact saved timer value and progress position.

> 💡 **Need individual text sources?** Quick Setup creates overlays only (they display everything: timer, session type, progress, goals, next-up info). If you prefer separate text elements for custom positioning, see [Manual Text Sources](overlay-customization.md#manual-text-sources-advanced).

---

## Step 4: Set Up Hotkeys

SessionPulse uses OBS hotkeys to control the timer. Set them up:

1. Go to **Settings** → **Hotkeys**
2. Scroll down or search for **SessionPulse**
3. Assign keys to at least these:

| Hotkey | Suggested Key | What It Does |
|--------|--------------|--------------|
| **Start / Pause** | `F9` | Toggle timer on/off |
| **Stop** | `F10` | End current session completely |
| **Skip Session** | `F11` | Jump to next session type |

Optional but useful:

| Hotkey | Suggested Key | What It Does |
|--------|--------------|--------------|
| Add Time | `Ctrl+F9` | Add 5 minutes to current session |
| Subtract Time | `Ctrl+F10` | Remove 5 minutes from current session |
| Reset All | `Ctrl+F11` | Clear all progress and start fresh |
| Resume Previous | `Ctrl+F12` | Restore a session interrupted by crash/close |

4. Click **Apply** → **OK**

---

## Step 5: Start Your First Session

1. Press your **Start/Pause** hotkey (e.g., `F9`)
2. Watch: the **ring overlay** starts counting down from `25:00`
3. The **bar overlay** at the top shows session type, timer, progress, and goal count
4. When it hits `0:00`, it will automatically switch to a **Short Break** (5 minutes)
5. After the break, it auto-starts the next Focus session

**Default Pomodoro cycle:**
```
Focus (25 min) → Short Break (5 min) → Focus → Short Break → Focus → Short Break → Focus → Long Break (15 min)
```

> 💡 **Tip:** You can change all durations in the script settings (Tools → Scripts → select SessionPulse).

---

## Step 6: Customize Your Overlays

Both overlays are highly customizable via the **Custom CSS** field in OBS Browser Source properties.

### Ring Overlay
- Created by Quick Setup as `SP Overlay` (400×400)
- Scale it down in OBS to your preferred size (e.g., 150px for gaming, 280px for study streams)
- Themes: Neon, Minimal, Glassmorphism, or default

### Bar Overlay
- Created by Quick Setup as `SP Overlay Bar` (1920×48)
- Sits at the top edge of your canvas
- Shows: session icon, label, timer, progress bar, goal count, next-up info
- Auto-hides when the timer is idle

> For full theme presets, CSS variables, and color customization, see the [Overlay Customization Guide](overlay-customization.md).

---

## Step 7: Add the Control Dock (Optional)

The dock gives you clickable buttons inside OBS instead of using hotkeys:

1. Go to **View** → **Docks** → **Custom Browser Docks**
2. Fill in:
   - **Dock Name:** `SessionPulse`
   - **URL:** `file:///` + full path to `timer_dock.html`
   - Recommended: also add `?state_path=file:///FULL/PATH/session_state.json`
   
   Examples:
   - Windows: `file:///D:/tools/SessionPulse/timer_dock.html?state_path=file:///D:/tools/SessionPulse/session_state.json`
   - Mac: `file:///Users/you/SessionPulse/timer_dock.html?state_path=file:///Users/you/SessionPulse/session_state.json`
   
3. Click **Apply**

A new dock panel appears with Start/Pause, Skip, Stop buttons, a timer display, session stats, and the live status message when one is active.

**For control buttons to work**, you need WebSocket enabled:
1. Go to **Tools** → **WebSocket Server Settings**
2. Check **✅ Enable WebSocket server**
3. Note the port (default: `4455`)
4. If you set a password, add `?ws_password=YOUR_PASSWORD` to the dock URL

---

## You're Done! 🎉

Your setup should now look like this:

```mermaid
flowchart TB
    subgraph OBS["OBS Studio"]
        Script["session_pulse.lua\n(engine)"]
        Ring["SP Overlay\n(Ring — 400×400)"]
        Bar["SP Overlay Bar\n(Bar — 1920×48)"]
        BG["SP Background\nImage / Video"]
        Dock["Control Dock\n(Custom Browser Dock)"]
    end
    
    Script -->|writes| State["session_state.json"]
    State -->|reads| Ring
    State -->|reads| Bar
    State -->|reads| Dock
    Dock -->|WebSocket| Script
    Script -->|updates| BG
```

---

## Next Steps

| Want to... | Read... |
|-----------|---------|
| Customize overlay colors and themes | [Overlay Customization](overlay-customization.md) |
| Auto-duck music, control mic, toggle filters | [Automation Guide](automation-guide.md) |
| Set up Nightbot or Stream Deck | [Integrations](integrations.md) |
| Control from your phone | [Mobile Remote](mobile-remote.md) |
| Use individual text sources instead of overlays | [Manual Text Sources](overlay-customization.md#manual-text-sources-advanced) |
| Something isn't working | [FAQ & Troubleshooting](faq.md) |
