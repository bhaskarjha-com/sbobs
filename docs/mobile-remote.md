# Mobile Remote

Control SessionPulse from your phone or tablet using the built-in mobile remote.

---

## Prerequisites

- OBS Studio running on your PC
- **WebSocket server enabled** in OBS (for control buttons)
- Phone and PC on the **same WiFi network**

---

## Step 1: Enable OBS WebSocket

1. In OBS: **Tools** → **WebSocket Server Settings**
2. Check **✅ Enable WebSocket server**
3. Note:
   - **Port:** default `4455`
   - **Password:** optional but recommended for security

---

## Step 2: Find Your PC's IP Address

You need your PC's local IP address (not `localhost` — that only works on the PC itself).

### Windows
```
ipconfig
```
Look for **IPv4 Address** under your WiFi adapter (e.g., `192.168.1.105`)

### Mac
```
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### Linux
```
ip addr show | grep "inet " | grep -v 127.0.0.1
```

The address will look like `192.168.x.x` or `10.0.x.x`.

---

## Step 3: Open the Remote on Your Phone

### Option A — Serve via HTTP (recommended)

1. On your PC, open a terminal in the SessionPulse folder:
   ```bash
   python -m http.server 8080
   ```
   (or `py -m http.server 8080` on some Windows installs)

2. On your phone's browser, go to:
   ```
   http://192.168.1.105:8080/timer_remote.html
   ```
   (replace with your PC's IP)

### Option B — Direct file transfer

1. Copy `timer_remote.html` to your phone
2. Open it in a mobile browser

> **Note:** Option A is better because the remote can also poll `session_state.json` for live status updates.

---

## Step 4: Configure the Connection

When the remote opens, you'll see a setup screen:

| Field | Value | Example |
|-------|-------|---------|
| **WebSocket Host** | Your PC's IP | `192.168.1.105` |
| **WebSocket Port** | OBS WebSocket port | `4455` |
| **WebSocket Password** | Your OBS WebSocket password | `mypassword123` |
| **HTTP Port** | The HTTP server port (for state polling) | `8080` |

Fill in the fields and tap **Connect**.

The settings are saved to your phone's browser storage — you only need to configure once.

---

## Step 5: Use the Remote

Once connected, you get large, touch-friendly buttons:

| Button | Action |
|--------|--------|
| ▶️ **Start / Pause** | Toggle timer |
| ⏭️ **Skip** | Jump to next session |
| ⏹️ **Stop** | End session completely |
| ➕ **+ Time** | Add 5 minutes |
| ➖ **- Time** | Subtract 5 minutes |
| 🔄 **Reset** | Clear all progress |

The remote also shows:
- Current session type and timer
- Session progress
- Connection status indicator

---

## Save as "App" on Home Screen

### iOS (Safari)
1. Open the remote URL in Safari
2. Tap the **Share** icon (square with arrow)
3. Select **Add to Home Screen**
4. Name it `SessionPulse`
5. Tap **Add**

### Android (Chrome)
1. Open the remote URL in Chrome
2. Tap the **⋮** menu (three dots)
3. Select **Add to Home screen**
4. Name it `SessionPulse`
5. Tap **Add**

Now you have a home screen icon that opens the remote like a native app.

---

## Troubleshooting

### "Connection failed"

1. **Same network?** — PC and phone must be on the same WiFi
2. **Firewall** — Windows Firewall may block WebSocket connections:
   - Open **Windows Defender Firewall**
   - Click **Allow an app through firewall**
   - Make sure **OBS Studio** is allowed for **Private** networks
3. **Correct IP?** — Run `ipconfig` again, IPs can change if you reconnect
4. **WebSocket enabled?** — Verify in OBS: Tools → WebSocket Server Settings

### "Buttons work but no timer display"

- The timer display uses HTTP polling of `session_state.json`
- Make sure you're running the HTTP server (`python -m http.server 8080`)
- Make sure the **HTTP Port** field in the remote matches the server port

### "Timer display works but buttons don't"

- Buttons use OBS WebSocket — different from the HTTP server
- Check the WebSocket host/port/password fields
- Look for the connection indicator at the top of the remote

### Can I control from outside my home network?

Not directly — WebSocket requires LAN access. For remote control over the internet, you'd need:
- A VPN (e.g., Tailscale, WireGuard) to join your home network
- Or port forwarding on your router (not recommended for security reasons)
