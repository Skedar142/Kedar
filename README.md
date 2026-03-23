# Kedar — Nothing Phone Conky Widget

A minimalist Conky desktop widget for Ubuntu/Debian-based Linux systems, inspired by the Nothing Phone's iconic Glyph Interface design language: pure-black panel, rounded cards, glyph dot accents, and a live 60-dot minute/second ring clock.

```
╔══════════════════════════╗
║  •                     • ║  ← corner glyph dots
║   · · ○ · · ● · · · ·   ║  ← 60-dot minute/second ring
║                           ║       (● = current second)
║         14:27             ║  ← large centered clock
║    Monday, March 23       ║
║ ─────────────────────── ║
║ ┌─────────────────────┐  ║
║ │ SYSTEM              │  ║  ← section card
║ │ CPU  12%  ████░░░░  │  ║
║ │ MEM  48%  █████░░░  │  ║
║ │ DISK 61%  ██████░░  │  ║
║ └─────────────────────┘  ║
║ ┌─────────────────────┐  ║
║ │ CPU CORES           │  ║
║ │ Core1 12%  Core2 8% │  ║
║ │ Core3  5%  Core4 3% │  ║
║ └─────────────────────┘  ║
║ ┌─────────────────────┐  ║
║ │ BATTERY  87%        │  ║
║ └─────────────────────┘  ║
║ ┌─────────────────────┐  ║
║ │ NETWORK             │  ║
║ │ UP 128K  DOWN 512K  │  ║
║ └─────────────────────┘  ║
║ ┌─────────────────────┐  ║
║ │ NOW PLAYING         │  ║
║ │ Particles           │  ║
║ │ Nothing (band)      │  ║
║ └─────────────────────┘  ║
║    uptime  3h 22m         ║
║  ───────────────────────  ║  ← glyph accent line
║         •   •   •         ║  ← USB-C glyph dots
╚══════════════════════════╝
```

---

## Requirements

| Dependency | Notes |
|---|---|
| Ubuntu / Debian-based Linux | 20.04, 22.04, or 24.04 recommended |
| Conky 1.12+ | installed automatically if missing |
| JetBrains Mono font | installed automatically |
| `git` | to clone this repository |
| `playerctl` *(optional)* | for the Now Playing section |

---

## Ubuntu Packages

The table below lists every `apt` package involved. The **installer handles all of them automatically** — this section is here so you know exactly what will be installed on your system.

| Package | `apt` name | Why it's needed | Auto-installed? |
|---|---|---|---|
| Conky | `conky` | The widget engine | ✅ yes |
| Font utilities | `fontconfig` | Provides `fc-list` / `fc-cache` for font detection | ✅ yes |
| ZIP extractor | `unzip` | Extracts the JetBrains Mono font archive | ✅ yes |
| JetBrains Mono *(apt fallback)* | `fonts-jetbrains-mono` | Font used by the widget — installed via apt if `wget` is unavailable | ✅ yes (fallback) |
| Now Playing support | `playerctl` | Reads the current track from Spotify, VLC, etc. | ⬜ optional |

**To pre-install everything in one command** (including the optional `playerctl`):

```bash
sudo apt update && sudo apt install -y conky fontconfig unzip playerctl
```

> **Note:** `wget` is also used by the installer to download the JetBrains Mono font directly from GitHub. It ships pre-installed on Ubuntu desktop; if it is missing, the installer falls back to `sudo apt install fonts-jetbrains-mono` automatically.

---

## Installation

### Step 1 — Clone the repository

```bash
git clone https://github.com/Skedar142/Kedar.git
cd Kedar
```

### Step 2 — Run the installer

**Dark theme (default):**

```bash
bash conky-nothing/install.sh
```

**Light theme:**

```bash
bash conky-nothing/install.sh light
```

The installer automatically:

1. Checks for `conky`, `fontconfig`, and `unzip`; installs any that are missing via `apt`
2. Downloads and installs the **JetBrains Mono** font to `~/.local/share/fonts/`
3. Copies config files to `~/.config/conky/`
4. Detects your screen width and positions the panel in the top-right corner
5. Creates a GNOME autostart entry so the widget launches on login (`~/.config/autostart/conky-nothing.desktop`)
6. Starts Conky immediately

### Step 3 — (Optional) Install playerctl for Now Playing

```bash
sudo apt install playerctl
```

This enables the Now Playing section to show the track/artist from any MPRIS-compatible player (Spotify, VLC, Rhythmbox, Firefox, Chromium, etc.).

---

## Manual Installation (no installer)

If you prefer to install without the script:

```bash
mkdir -p ~/.config/conky
cp conky-nothing/.conkyrc           ~/.config/conky/.conkyrc
cp conky-nothing/conky_nothing.lua  ~/.config/conky/conky_nothing.lua
cp -r conky-nothing/themes          ~/.config/conky/themes
conky -c ~/.config/conky/.conkyrc &
```

---

## Switching Themes

Re-run the installer at any time to switch:

```bash
bash conky-nothing/install.sh dark
bash conky-nothing/install.sh light
```

---

## Stopping & Restarting

```bash
pkill conky                                      # stop
conky -c ~/.config/conky/.conkyrc &              # start
```

To disable autostart on login:

```bash
rm ~/.config/autostart/conky-nothing.desktop
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Widget not visible | Ensure your compositor supports ARGB/transparent windows |
| Fonts look wrong | Run `fc-cache -fv` then restart Conky |
| No battery info | Run `ls /sys/class/power_supply/` and update `BAT0` in `~/.config/conky/.conkyrc` |
| No music info | Install `playerctl`: `sudo apt install playerctl` |
| Panel off-screen | Re-run `install.sh` or adjust `gap_x`/`gap_y` in `~/.config/conky/.conkyrc` |
| Lua/Cairo errors | Ensure Conky was built with `--enable-lua-cairo` (default in Ubuntu repos) |

---

## Project Structure

```
conky-nothing/
├── .conkyrc              Main Conky configuration
├── conky_nothing.lua     Lua script — cards, rings, bars
├── install.sh            One-command installer
├── README.md             Detailed widget documentation
└── themes/
    ├── dark.conf         Dark palette reference
    └── light.conf        Light palette reference
```

---

## License

MIT — do whatever you like with this configuration.