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
3. Set Width: **400**, Height: **400** (renders at high resolution; scale down in OBS for crispness)

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
| `--sp-ring-stroke` | `14` | Ring stroke width |
| `--sp-ring-filter` | `drop-shadow(...)` | SVG filter on the ring |
| `--sp-glow-filter` | `blur(40px)` | Filter on the background glow |
| `--sp-glow-opacity` | `1` | Glow opacity when active (`0` to hide) |
| `--sp-time-size` | `5.4rem` | Timer text font size |
| `--sp-time-weight` | `700` | Timer text font weight |
| `--sp-time-stroke` | `0.5px` | Timer text outline for readability |
| `--sp-label-size` | `1.45rem` | Session label font size |
| `--sp-stats-size` | `1rem` | Stats text font size |
| `--sp-glass-display` | `none` | Set to `block` to show frosted glass circle |
| `--sp-tracker-stroke` | `4` | Session tracker segment thickness |
| `--sp-next-size` | `0.82rem` | Next-up line text size |
| `--sp-transition-display` | `block` | Set to `none` to hide transition pill |
| `--sp-backdrop-bg` | dark radial | Backdrop center color |
| `--sp-backdrop-bg-edge` | darker radial | Backdrop edge color |
| `--sp-backdrop-blur` | `24px` | Backdrop blur strength |

You can mix and match — for example, neon ring with glassmorphism glass:
```css
body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; --sp-ring-stroke: 6; --sp-ring-filter: drop-shadow(0 0 8px currentColor); --sp-glass-display: block; }
```

### Visual Features

- **Frosted glass backdrop** — dark radial-gradient circle with `backdrop-filter: blur(24px)`, readable on any stream background (light or dark)
- **Gradient progress ring** — session-colored gradient (e.g., green→cyan for Focus) with `stroke-linecap: round` and dual drop-shadow glow
- **Glow cap** — a bright dot that tracks the leading edge of the ring progress
- **Session tracker** — inner segmented ring showing completed vs. goal sessions. Each segment lights up as sessions complete
- **Next-up line** — inline text below stats showing the next session type and end time (always visible during sessions)
- **Transition pill** — dark pill at the bottom that briefly flashes transition messages ("Time for a Short Break")
- **Breathing glow** — subtle 5-second scale+fade animation behind the ring when running
- **Tick marks** — 12 subtle clock-face marks for visual reference
- **Paused state** — timer and label pulse, glow dims
- **Overtime** — ring pulses red, timer shows `+0:00` counting up

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

### Size & Resolution

The overlay renders at **400×400** by default for maximum sharpness. In OBS, resize using **Edit Transform** (right-click → Transform → Edit Transform) to scale it down. This gives retina-quality crispness at any display size.

| Use Case | Browser Source Size | OBS Display Size |
|----------|-------------------|-----------------|
| Corner widget | 400×400 (default) | Scale to ~180px via transform |
| Study stream (prominent) | 400×400 | Scale to ~280px |
| Full-screen overlay | 600×600 | Full canvas or large |
| Small/gaming | 400×400 | Scale to ~120px |

### Placement Tips

- **Bottom-right corner** — most common, doesn't obstruct gameplay
- **Top-left** — good for study/work streams
- **Center overlay** — use a larger size (300+) for "ambient" streams
- **Multiple overlays** — you can add more than one Browser Source with different sizes/positions

---

## Bar Overlay (`timer_overlay_bar.html`)

A horizontal progress bar for the edge of your stream. Shares the same color system as the ring overlay — user color customizations apply to both.

### Basic Setup

1. Add a **Browser Source** → select `timer_overlay_bar.html`
2. Set Width: **1920** (your stream width), Height: **48**
3. Position at the top or bottom edge of your canvas

### Position

By default the bar slides in from the top. To slide from the bottom, add to Custom CSS:

```css
body { --sp-position: bottom; }
```

### Bar Properties

All properties are optional. Add them inside `body { }` in the Custom CSS field:

| Property | Default | Description |
|----------|---------|-------------|
| `--sp-bar-height` | `48px` | Bar height |
| `--sp-bar-bg` | dark (0.82 opacity) | Bar background color |
| `--sp-bar-blur` | `18px` | Bar backdrop blur strength |
| `--sp-bar-progress-height` | `6px` | Progress bar track height |
| `--sp-bar-label-size` | `0.88rem` | Session label font size |
| `--sp-bar-time-size` | `1.25rem` | Timer text font size |
| `--sp-bar-counter-size` | `0.82rem` | Session counter font size |
| `--sp-bar-next-size` | `0.78rem` | Next-up info font size |
| `--sp-position` | `top` | Bar position: `top` or `bottom` |

### Visual Features

- **Gradient progress bar** — session-colored gradient (e.g., green→cyan for Focus) with glow
- **Session-colored border accent** — 2px colored line at the sliding edge
- **Status takeover** — when SP Status is active, label changes to status message in amber with pulse
- **Next-up info** — "Next: Short Break · 10:20" displayed on the right side
- **Focus duration** — counter shows `3/6 · 23m` (sessions + total time)
- **Paused state** — timer and label pulse, progress dims
- **Overtime** — progress track pulses red

### Behavior

- **Auto-hides** when the timer is idle (slides out)
- **Slides in** when the timer starts
- **Color-coded** — gradient fill + border glow matches session type
- **Shared colors** — uses the same `--focus-color`, `--short-break-color`, etc. as the ring
- Transition messages ("Time for a Short Break") appear briefly on the right

---

## Common Setups

### Gaming Stream
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-ring-stroke: 6; --sp-ring-filter: drop-shadow(0 0 8px currentColor); --sp-glow-filter: blur(40px); }
```
Small, glowing, unobtrusive. Keep Browser Source at 400×400, then scale to ~150px via OBS transform.

### Study With Me
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; }
```
Default theme. Larger, clean, readable. Keep Browser Source at 400×400, scale to ~280px via OBS transform.

### Professional / Podcast
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-glow-opacity: 0; --sp-ring-stroke: 4; --sp-time-weight: 300; --sp-time-size: 2.4rem; --focus-color: #6366f1; }
```
Muted, branded colors, thin ring. Keep Browser Source at 400×400, scale to ~180px via OBS transform.

### Aesthetic / Lofi
```css
body { background-color: rgba(0,0,0,0); margin: 0px auto; overflow: hidden; --sp-glass-display: block; --focus-color: #f472b6; --focus-glow: rgba(244, 114, 182, 0.3); }
```
Frosted glass, soft pink. Keep Browser Source at 400×400, scale to ~280px via OBS transform.

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
