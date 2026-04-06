# Overlay Customization

SessionPulse includes two overlay styles — a **circular ring** and a **horizontal bar** — both highly customizable via the **Custom CSS** field in OBS Browser Source properties.

> **Why Custom CSS instead of URL parameters?**
> OBS's "Local File" mode doesn't support URL query parameters (`?theme=neon`).
> Using `file:///` URLs as a workaround breaks the overlay because OBS's CEF browser
> blocks `fetch()` requests from `file://` origins. The Custom CSS approach works
> perfectly with Local File mode — no workarounds needed.

---

## Ring Overlay (`timer_overlay.html`)

### Basic Setup

1. Add a **Browser Source** to your scene
2. Check **Local file** → select `timer_overlay.html`
3. Set Width: **220**, Height: **220**

### Themes

SessionPulse ships with 4 built-in themes. Set them in the **Custom CSS** field:

| Theme | Custom CSS | Look |
|-------|-----------|------|
| `default` | *(no extra CSS needed)* | Clean green ring, subtle glow |
| `neon` | `body { --sp-theme: neon; }` | Bright glow, high contrast |
| `minimal` | `body { --sp-theme: minimal; }` | No glow, thin ring, muted |
| `glassmorphism` | `body { --sp-theme: glassmorphism; }` | Frosted glass, blur effect |

**How to set a theme:**

1. Double-click the SP Overlay source in your scene
2. Find the **Custom CSS** field at the bottom of the properties
3. Add the theme variable alongside the existing CSS:

```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; --sp-theme: neon; }
```

### Custom CSS Properties Reference

All properties are optional. Add them inside `body { }` in the Custom CSS field:

```css
body {
  background-color: rgba(0, 0, 0, 0);
  margin: 0px auto;
  overflow: hidden;
  --sp-theme: neon;
  --sp-size: 300;
}
```

| Property | Default | Description | Example |
|----------|---------|-------------|---------|
| `--sp-theme` | `default` | Visual theme | `--sp-theme: neon;` |
| `--sp-size` | `220` | Ring diameter in pixels | `--sp-size: 300;` |

> **Tip:** When changing `--sp-size`, also update the Browser Source **Width** and **Height** to match.

### Custom Colors

Override the default session colors by adding CSS custom properties in the Custom CSS field:

```css
body {
  background-color: rgba(0, 0, 0, 0);
  margin: 0px auto;
  overflow: hidden;
  --focus-color: #ec4899;
  --focus-glow: rgba(236, 72, 153, 0.3);
  --short-break-color: #06b6d4;
  --short-break-glow: rgba(6, 182, 212, 0.3);
  --long-break-color: #8b5cf6;
  --long-break-glow: rgba(139, 92, 246, 0.3);
}
```

| Property | Default | Session |
|----------|---------|---------|
| `--focus-color` | `#22c55e` (green) | Focus |
| `--focus-glow` | `rgba(34, 197, 94, 0.3)` | Focus glow |
| `--short-break-color` | `#3b82f6` (blue) | Short Break |
| `--short-break-glow` | `rgba(59, 130, 246, 0.3)` | Short Break glow |
| `--long-break-color` | `#a855f7` (purple) | Long Break |
| `--long-break-glow` | `rgba(168, 85, 247, 0.3)` | Long Break glow |
| `--stopwatch-color` | `#f59e0b` (amber) | Stopwatch |
| `--countdown-color` | `#f97316` (orange) | Countdown |

### Size Recommendations

| Stream Resolution | Ring Size | Width/Height Setting |
|------------------|-----------|---------------------|
| 1080p (1920×1080) | 180–220 | 220×220 |
| 1440p (2560×1440) | 250–300 | 300×300 |
| 4K (3840×2160) | 350–400 | 400×400 |
| Small corner widget | 120–150 | 150×150 |

### Placement Tips

- **Bottom-right corner** — most common, doesn't obstruct gameplay
- **Top-left** — good for study/work streams
- **Center overlay** — use a larger size (300+) for "ambient" streams
- **Multiple overlays** — you can add more than one Browser Source with different sizes/positions

---

## Bar Overlay (`timer_overlay_bar.html`)

A horizontal progress bar for the edge of your stream.

### Basic Setup

1. Add a **Browser Source** → select `timer_overlay_bar.html`
2. Set Width: **1920** (your stream width), Height: **36**
3. Position at the top or bottom edge of your canvas

### Position

By default the bar slides in from the top. To slide from the bottom, add to Custom CSS:

```css
body { --sp-position: bottom; }
```

| Property | Default | Description |
|----------|---------|-------------|
| `--sp-position` | `top` | `top` or `bottom` — affects slide animation direction |

### Behavior

- **Auto-hides** when the timer is idle (slides out)
- **Slides in** when the timer starts
- **Color-coded** by session type (same colors as the ring)
- The bar fills left-to-right as the session progresses

---

## Common Setups

### Gaming Stream
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-theme: neon; --sp-size: 150; }
```
Small, glowing, unobtrusive. Set Browser Source to 150×150.

### Study With Me
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-size: 250; }
```
Larger, clean, readable. Set Browser Source to 250×250.

### Professional / Podcast
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-theme: minimal; --sp-size: 180; --focus-color: #6366f1; --focus-glow: rgba(99, 102, 241, 0.3); }
```
Muted, branded colors, thin ring. Set Browser Source to 180×180.

### Aesthetic / Lofi
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-theme: glassmorphism; --sp-size: 280; --focus-color: #f472b6; --focus-glow: rgba(244, 114, 182, 0.3); }
```
Frosted glass, soft pink. Set Browser Source to 280×280.

### Dual Overlay (Ring + Bar)
Add both as separate Browser Sources:
- Ring in a corner for viewers
- Bar at the top edge for at-a-glance progress

---

## Overtime Display

When overtime is enabled and the timer hits zero:
- The ring turns **red** and **pulses**
- The countdown shows `+0:00`, `+0:30`, `+1:00`, etc.
- The glow intensifies

This continues until you manually skip or stop the session.
