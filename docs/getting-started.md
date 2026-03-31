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
[SessionPulse] Loaded v5.3.1
[SessionPulse] State saved → session_state.json
```

If you see errors instead, check the [FAQ](faq.md).

---

## Step 3: Create Text Sources

SessionPulse needs OBS **Text sources** to display the timer. You need to create these in your scene first, then tell the script which ones to use.

### Create a timer display source:

1. In your **Scene**, click **+** (under Sources)
2. Select **Text (GDI+)** (Windows) or **Text (FreeType 2)** (Mac/Linux)
3. Name it something like `Timer`
4. Click **OK** on the properties (don't worry about the text — the script will control it)

### Recommended sources to create:

| Source Name | Purpose | Required? |
|------------|---------|-----------|
| `Timer` | Shows countdown `24:59` | ✅ Yes |
| `Session` | Shows `Focus Time`, `Short Break`, etc. | Recommended |
| `Focus Count` | Shows `Done: 3/6` | Optional |
| `Progress` | Shows `████░░░░` bar | Optional |

> You can name them anything — you'll pick them from dropdown menus in the next step.

---

## Step 4: Connect Sources to the Script

1. Go to **Tools** → **Scripts** → select **SessionPulse**
2. In the script settings panel on the right, you'll see dropdown menus:
   - **Timer Display** → select your `Timer` text source
   - **Session Message** → select your `Session` text source
   - **Focus Count** → select your `Focus Count` text source
   - **Progress Bar** → select your `Progress` text source
3. The dropdowns show all text sources in your current scene

```mermaid
flowchart LR
    A[Create Text Sources\nin your Scene] --> B[Open Script Settings\nTools → Scripts]
    B --> C[Pick sources from\ndropdown menus]
    C --> D[Press a hotkey\nto start!]
```

---

## Step 5: Set Up Hotkeys

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

4. Click **Apply** → **OK**

---

## Step 6: Start Your First Session

1. Press your **Start/Pause** hotkey (e.g., `F9`)
2. Watch: your `Timer` source should start counting down from `25:00`
3. Your `Session` source should show `Focus Time`
4. When it hits `0:00`, it will automatically switch to a **Short Break** (5 minutes)
5. After the break, it auto-starts the next Focus session

**Default Pomodoro cycle:**
```
Focus (25 min) → Short Break (5 min) → Focus → Short Break → Focus → Short Break → Focus → Long Break (15 min)
```

> 💡 **Tip:** You can change all durations in the script settings (Tools → Scripts → select SessionPulse).

---

## Step 7: Add the Overlay (Optional but Recommended)

The ring overlay adds a beautiful visual timer to your stream:

1. In your scene, click **+** (add source) → **Browser**
2. Name it `Timer Overlay`
3. Check **✅ Local file**
4. Click **Browse** → navigate to your SessionPulse folder → select **`timer_overlay.html`**
5. Set **Width: 220**, **Height: 220**
6. Click **OK**
7. Position the overlay where you want it on your stream

You should see a circular ring with the countdown timer. It will be green during Focus, blue during Short Break, and purple during Long Break.

> For customization (themes, colors, sizes), see the [Overlay Customization Guide](overlay-customization.md).

---

## Step 8: Add the Control Dock (Optional)

The dock gives you clickable buttons inside OBS instead of using hotkeys:

1. Go to **View** → **Docks** → **Custom Browser Docks**
2. Fill in:
   - **Dock Name:** `SessionPulse`
   - **URL:** `file:///` + full path to `timer_dock.html`
   
   Examples:
   - Windows: `file:///D:/tools/SessionPulse/timer_dock.html`
   - Mac: `file:///Users/you/SessionPulse/timer_dock.html`
   
3. Click **Apply**

A new dock panel appears with Start/Pause, Skip, Stop buttons, a timer display, and session stats.

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
        Timer["Timer: 24:59"]
        Session["Session: Focus Time"]
        Overlay["Ring Overlay\n(Browser Source)"]
        Dock["Control Dock\n(Custom Browser Dock)"]
    end
    
    Script -->|updates| Timer
    Script -->|updates| Session
    Script -->|writes| State["session_state.json"]
    State -->|reads| Overlay
    State -->|reads| Dock
    Dock -->|WebSocket| Script
```

---

## Next Steps

| Want to... | Read... |
|-----------|---------|
| Customize overlay colors and themes | [Overlay Customization](overlay-customization.md) |
| Auto-switch scenes, duck music, control mic | [Automation Guide](automation-guide.md) |
| Set up Nightbot or Stream Deck | [Integrations](integrations.md) |
| Control from your phone | [Mobile Remote](mobile-remote.md) |
| Something isn't working | [FAQ & Troubleshooting](faq.md) |
