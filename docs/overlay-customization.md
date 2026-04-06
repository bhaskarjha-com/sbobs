# Overlay Customization

SessionPulse includes two overlay styles — a **circular ring** and a **horizontal bar** — both highly customizable via the **Custom CSS** field in OBS Browser Source properties.

> **How it works:** The overlay CSS uses `var(--sp-*, default)` references for all
> theme-able properties. When you set these properties in OBS Custom CSS, they
> override the defaults through the native CSS cascade — no JavaScript needed.

---

## Ring Overlay (`timer_overlay.html`)

### Basic Setup

1. Add a **Browser Source** to your scene
2. Check **Local file** → select `timer_overlay.html`
3. Set Width: **220**, Height: **220**

### Themes

SessionPulse ships with 3 preset themes. Copy-paste the full Custom CSS line into the **Custom CSS** field:

**Neon** — Bright glow, high contrast, thinner ring:
```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; --sp-ring-stroke: 6; --sp-ring-filter: drop-shadow(0 0 8px currentColor); --sp-glow-filter: blur(40px); }
```

**Minimal** — No glow, thin ring, light font:
```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; --sp-glow-opacity: 0; --sp-ring-stroke: 4; --sp-time-weight: 300; --sp-time-size: 2.4rem; }
```

**Glassmorphism** — Frosted glass circle behind the ring:
```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; --sp-glass-display: block; }
```

**Default** — No extra properties needed, use the standard Custom CSS:
```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }
```

### Theme Properties Reference

All properties are optional. Add them inside `body { }` in the Custom CSS field:

| Property | Default | Description |
|----------|---------|-------------|
| `--sp-ring-stroke` | `8` | Ring stroke width (lower = thinner) |
| `--sp-ring-filter` | `none` | SVG filter on the ring (e.g. `drop-shadow(...)`) |
| `--sp-glow-filter` | `blur(30px)` | Filter on the background glow |
| `--sp-glow-opacity` | `1` | Glow opacity when active (`0` to hide) |
| `--sp-time-size` | `2.8rem` | Timer text font size |
| `--sp-time-weight` | `700` | Timer text font weight |
| `--sp-glass-display` | `none` | Set to `block` to show frosted glass circle |

You can mix and match — for example, neon ring with glassmorphism glass:
```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; --sp-ring-stroke: 6; --sp-ring-filter: drop-shadow(0 0 8px currentColor); --sp-glass-display: block; }
```

### Custom Colors

Override the default session colors by adding CSS custom properties:

```css
body {
  background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden;
  --focus-color: #ec4899;
  --focus-glow: rgba(236, 72, 153, 0.3);
  --short-break-color: #06b6d4;
  --short-break-glow: rgba(6, 182, 212, 0.3);
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

### Behavior

- **Auto-hides** when the timer is idle (slides out)
- **Slides in** when the timer starts
- **Color-coded** by session type (same colors as the ring)
- The bar fills left-to-right as the session progresses

---

## Common Setups

### Gaming Stream
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-ring-stroke: 6; --sp-ring-filter: drop-shadow(0 0 8px currentColor); --sp-glow-filter: blur(40px); }
```
Small, glowing, unobtrusive. Set Browser Source to 150×150.

### Study With Me
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; }
```
Default theme. Larger, clean, readable. Set Browser Source to 250×250.

### Professional / Podcast
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-glow-opacity: 0; --sp-ring-stroke: 4; --sp-time-weight: 300; --sp-time-size: 2.4rem; --focus-color: #6366f1; }
```
Muted, branded colors, thin ring. Set Browser Source to 180×180.

### Aesthetic / Lofi
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-glass-display: block; --focus-color: #f472b6; --focus-glow: rgba(244, 114, 182, 0.3); }
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
