# Nothing Phone Conky Widget for Ubuntu

A minimalist Conky desktop widget inspired by the Nothing Phone's iconic design language — functional simplicity, geometric clarity, and intentional whitespace.

---

## Preview

```
╔══════════════════════════╗
║        ·  ·  ·  ·        ║  ← minute ring
║                           ║
║         14:27             ║  ← large clock
║    Monday, March 23       ║
║ ─────────────────────── ║
║  SYSTEM                   ║
║  CPU   12%  ████░░░░░░░  ║
║  MEM   48%  █████░░░░░░  ║
║  DISK  61%  ██████░░░░░  ║
║ ─────────────────────── ║
║  BATTERY  87%  ████████░░ ║
║ ─────────────────────── ║
║  NOW PLAYING              ║
║  Particles                ║
║  Nothing (band)           ║
║ ─────────────────────── ║
║    uptime  3h 22m         ║
╚══════════════════════════╝
```

---

## Design Principles

The widget follows Nothing Phone's core aesthetic:

| Principle | Implementation |
|---|---|
| Monochromatic | Black, white, and gray only |
| Geometric clarity | Rounded-rectangle cards, dot accents |
| Intentional whitespace | Generous padding between sections |
| Functional simplicity | Only essential information shown |
| Glyph motif | Minute-ring and corner dots echo the Nothing Glyph Interface |

---

## File Structure

```
conky-nothing/
├── .conkyrc              Main Conky configuration
├── conky_nothing.lua     LUA script — custom drawing (cards, rings, bars)
├── install.sh            One-command installer
├── README.md             This file
└── themes/
    ├── dark.conf         Dark palette reference
    └── light.conf        Light palette reference
```

---

## Requirements

| Dependency | Version |
|---|---|
| Conky | 1.12+ |
| LuaJIT / Lua 5.1 | bundled with Conky |
| Cairo (Xlib) | bundled with Conky |
| JetBrains Mono | auto-installed |
| playerctl (optional) | for Now Playing section |

---

## Installation

### Quick install (recommended)

```bash
git clone https://github.com/Skedar142/Kedar.git
cd Kedar/conky-nothing
bash install.sh           # dark theme (default)
# or
bash install.sh light     # light theme
```

The installer will:
1. Install `conky` and `fontconfig` via `apt` if missing
2. Download and install **JetBrains Mono** font
3. Copy config files to `~/.config/conky/`
4. Auto-detect screen width and position the panel
5. Create a GNOME autostart entry (`~/.config/autostart/`)
6. Launch Conky immediately

### Manual install

```bash
mkdir -p ~/.config/conky
cp .conkyrc           ~/.config/conky/.conkyrc
cp conky_nothing.lua  ~/.config/conky/conky_nothing.lua
cp -r themes          ~/.config/conky/themes
conky -c ~/.config/conky/.conkyrc &
```

---

## Configuration

### Adjusting widget position

Edit `~/.config/conky/.conkyrc`:

```lua
alignment = 'top_right',   -- top_left | top_right | bottom_left | bottom_right
gap_x     = 30,            -- horizontal gap from screen edge (pixels)
gap_y     = 50,            -- vertical gap from screen edge (pixels)
```

### Changing the network interface

The widget defaults to `wlan0`. Replace with your interface name:

```lua
-- in conky.text
${addr wlan0}     →  ${addr eth0}     -- wired
${upspeed}        →  ${upspeed eth0}
${downspeed}      →  ${downspeed eth0}
```

Find your interface name with `ip link show`.

### Changing the battery device

The widget defaults to `BAT0`. Check available batteries with:

```bash
ls /sys/class/power_supply/
```

Then update all occurrences of `BAT0` in `~/.config/conky/.conkyrc`.

### Now Playing

The widget uses `playerctl` to show the currently playing track from any
MPRIS-compatible player (Spotify, Rhythmbox, VLC, Firefox, Chromium, etc.).

Install playerctl:

```bash
sudo apt install playerctl
```

### Switching themes

Re-run the installer with the desired theme:

```bash
bash install.sh dark
bash install.sh light
```

Or manually adjust the color variables in `~/.config/conky/.conkyrc`:

```lua
-- Dark (default)
default_color = 'EEEEEE'
color0        = 'FFFFFF'   -- primary text
color1        = 'AAAAAA'   -- secondary text
color2        = '555555'   -- dim / separators

-- Light
default_color = '111111'
color0        = '111111'
color1        = '555555'
color2        = 'AAAAAA'
```

---

## Stopping / Restarting

```bash
pkill conky                                         # stop
conky -c ~/.config/conky/.conkyrc &                 # start
```

To disable autostart:

```bash
rm ~/.config/autostart/conky-nothing.desktop
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Widget not visible | Ensure `own_window_type = 'desktop'` and your compositor supports ARGB windows |
| Fonts look wrong | Run `fc-cache -fv` then restart Conky |
| No battery info | Check `ls /sys/class/power_supply/` and update `BAT0` |
| No music info | Install `playerctl` (`sudo apt install playerctl`) |
| Panel off-screen | Adjust `gap_x` / `gap_y` or re-run `install.sh` to recalculate position |
| LUA errors | Ensure Conky was compiled with `--enable-lua-cairo` (default in Ubuntu repos) |

---

## License

MIT — do whatever you like with this configuration.
