# Overlay Customization

SessionPulse includes two overlay styles — a **circular ring** and a **horizontal bar** — both highly customizable via URL parameters.

---

## Ring Overlay (`timer_overlay.html`)

### Basic Setup

1. Add a **Browser Source** to your scene
2. Check **Local file** → select `timer_overlay.html`
3. Set Width: **220**, Height: **220**

### Themes

Add `?theme=THEME_NAME` to the file path:

| Theme | Look | Best For |
|-------|------|----------|
| `default` | Clean green ring, subtle glow | Most streams |
| `neon` | Bright glow, high contrast | Dark/gaming streams |
| `minimal` | No glow, thin ring, muted colors | Professional/clean layouts |
| `glassmorphism` | Frosted glass background, blur effect | Modern/aesthetic streams |

**How to set a theme:**

In the Browser Source properties, after the file path, add the parameter:
```
timer_overlay.html?theme=neon
```

### URL Parameters Reference

All parameters are optional. Combine them with `&`:

```
timer_overlay.html?theme=neon&size=300&font=Outfit&showStats=false
```

| Parameter | Default | Description | Example |
|-----------|---------|-------------|---------|
| `theme` | `default` | Visual theme | `?theme=glassmorphism` |
| `size` | `200` | Ring diameter in pixels | `?size=300` |
| `font` | `Inter` | Any [Google Font](https://fonts.google.com) name | `?font=Outfit` |
| `showStats` | `true` | Show session count below timer | `?showStats=false` |
| `showNext` | `true` | Show "Next: Short Break" text | `?showNext=false` |
| `showTime` | `true` | Show "Ends 15:45" text | `?showTime=false` |

### Custom Colors

Override the default session colors with hex codes (without `#`):

| Parameter | Default | Session |
|-----------|---------|---------|
| `color_focus` | `22c55e` (green) | Focus |
| `color_short` | `3b82f6` (blue) | Short Break |
| `color_long` | `a855f7` (purple) | Long Break |
| `color_paused` | `eab308` (yellow) | Paused |
| `color_overtime` | `ef4444` (red) | Overtime |

**Example — Pink focus, cyan breaks:**
```
timer_overlay.html?color_focus=ec4899&color_short=06b6d4&color_long=8b5cf6
```

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

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `position` | `top` | `top` or `bottom` — affects slide animation direction |

```
timer_overlay_bar.html?position=bottom
```

### Behavior

- **Auto-hides** when the timer is idle (slides out)
- **Slides in** when the timer starts
- **Color-coded** by session type (same colors as the ring)
- The bar fills left-to-right as the session progresses

---

## Common Setups

### Gaming Stream
```
timer_overlay.html?theme=neon&size=150&showStats=false&showNext=false
```
Small, glowing, unobtrusive. No text clutter.

### Study With Me
```
timer_overlay.html?theme=default&size=250&font=Outfit
```
Larger, clean, readable. Shows all stats.

### Professional / Podcast
```
timer_overlay.html?theme=minimal&size=180&color_focus=6366f1&showNext=false
```
Muted, branded colors, no distracting text.

### Aesthetic / Lofi
```
timer_overlay.html?theme=glassmorphism&size=280&font=DM+Sans&color_focus=f472b6
```
Frosted glass, soft pink, modern font.

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
