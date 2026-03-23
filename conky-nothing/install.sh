#!/usr/bin/env bash
# install.sh — Nothing Phone Conky Widget Installer
# Tested on Ubuntu 20.04 / 22.04 / 24.04

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONKY_DIR="$HOME/.config/conky"
AUTOSTART_DIR="$HOME/.config/autostart"
THEME="${1:-dark}"   # pass 'light' as first arg for light theme

# ── Color output helpers ──────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Check / install dependencies ─────────────────────────────
check_deps() {
    info "Checking dependencies…"

    local missing=()
    command -v conky  &>/dev/null || missing+=(conky)
    command -v fc-list &>/dev/null || missing+=(fontconfig)

    if [ ${#missing[@]} -gt 0 ]; then
        info "Installing: ${missing[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y "${missing[@]}"
    fi

    success "Dependencies satisfied."
}

# ── Install fonts ─────────────────────────────────────────────
install_fonts() {
    info "Checking for JetBrains Mono font…"
    if fc-list | grep -qi "JetBrains Mono"; then
        success "JetBrains Mono already installed."
        return
    fi

    info "Installing JetBrains Mono…"
    local font_dir="$HOME/.local/share/fonts"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Try downloading from GitHub releases
    local font_url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
    if command -v wget &>/dev/null; then
        wget -q "$font_url" -O "$tmp_dir/jb.zip" \
            && unzip -q "$tmp_dir/jb.zip" "fonts/ttf/*.ttf" -d "$tmp_dir" \
            && mkdir -p "$font_dir" \
            && cp "$tmp_dir/fonts/ttf/"*.ttf "$font_dir/" \
            && fc-cache -f "$font_dir" \
            && success "JetBrains Mono installed." \
            || warn "Font download failed. Conky will fall back to a system monospace font."
    else
        # Try apt as fallback
        sudo apt-get install -y fonts-jetbrains-mono 2>/dev/null \
            && success "JetBrains Mono installed via apt." \
            || warn "Could not install JetBrains Mono. Falling back to system monospace."
    fi

    rm -rf "$tmp_dir"
}

# ── Copy configuration files ──────────────────────────────────
install_config() {
    info "Installing Conky configuration to $CONKY_DIR …"
    mkdir -p "$CONKY_DIR"

    # Main config
    cp "$SCRIPT_DIR/.conkyrc"           "$CONKY_DIR/.conkyrc"
    # LUA script
    cp "$SCRIPT_DIR/conky_nothing.lua"  "$CONKY_DIR/conky_nothing.lua"
    # Themes directory
    cp -r "$SCRIPT_DIR/themes"          "$CONKY_DIR/themes"

    # Apply selected theme overlay
    local theme_file="$CONKY_DIR/themes/${THEME}.conf"
    if [ -f "$theme_file" ]; then
        info "Applying ${THEME} theme…"
        cat "$theme_file" >> "$CONKY_DIR/.conkyrc"
        success "Theme '${THEME}' applied."
    else
        warn "Theme file '$theme_file' not found. Using default settings."
    fi

    success "Configuration files installed."
}

# ── Detect screen width and adjust panel X position ──────────
detect_screen() {
    info "Detecting screen resolution…"
    local width=1920  # default

    if command -v xrandr &>/dev/null; then
        width=$(xrandr --current 2>/dev/null \
            | grep '\*' | awk '{print $1}' | cut -dx -f1 \
            | sort -n | tail -1)
        width=${width:-1920}
    elif [ -f /sys/class/drm/card0-*/modes ]; then
        width=$(head -1 /sys/class/drm/card0-*/modes | cut -dx -f1)
        width=${width:-1920}
    fi

    info "Screen width detected: ${width}px"

    # Patch PANEL.x in LUA script so the panel sits in the top-right corner
    local panel_x=$(( width - 310 ))
    sed -i "s/PANEL.x\s*=\s*[0-9]*/PANEL.x      = ${panel_x}/" \
        "$CONKY_DIR/conky_nothing.lua" \
        || true   # non-fatal

    success "Panel X position set to ${panel_x}."
}

# ── Autostart entry ───────────────────────────────────────────
setup_autostart() {
    info "Creating autostart entry…"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/conky-nothing.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Conky Nothing Widget
Comment=Nothing Phone-inspired Conky widget
Exec=/bin/bash -c "sleep 5 && conky -c $CONKY_DIR/.conkyrc"
Icon=utilities-system-monitor
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
    success "Autostart entry created."
}

# ── Kill existing Conky instance and start fresh ─────────────
start_conky() {
    info "Starting Conky widget…"
    pkill conky 2>/dev/null || true
    sleep 1
    nohup conky -c "$CONKY_DIR/.conkyrc" &>/dev/null &
    success "Conky started (PID $!)."
}

# ── Main ──────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Nothing Phone Conky Widget Installer ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""

    check_deps
    install_fonts
    install_config
    detect_screen
    setup_autostart
    start_conky

    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo -e "  Config : ${CYAN}$CONKY_DIR/.conkyrc${NC}"
    echo -e "  LUA    : ${CYAN}$CONKY_DIR/conky_nothing.lua${NC}"
    echo -e "  Theme  : ${CYAN}${THEME}${NC}"
    echo ""
    echo -e "To switch themes, run:  ${YELLOW}bash install.sh light${NC}  or  ${YELLOW}bash install.sh dark${NC}"
    echo ""
}

main "$@"
