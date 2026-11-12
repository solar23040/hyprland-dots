#!/usr/bin/env bash
#
# install.sh — download & install Solar's Hyprland dots
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/solar23040/hyprland-dots/main/install.sh | bash
#   ./install.sh            (from a cloned repo)
#   REPO_DIR=/path ./install.sh
#
set -euo pipefail

REPO_URL="https://github.com/solar23040/hyprland-dots.git"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
BACKUP_DIR="$HOME/.config-backup-$(date +%s)"

# ---------- helpers ----------
c_reset="\033[0m"; c_bold="\033[1m"; c_green="\033[32m"; c_yellow="\033[33m"; c_red="\033[31m"; c_blue="\033[34m"
info()  { printf "${c_blue}==>${c_reset} ${c_bold}%s${c_reset}\n" "$*"; }
ok()    { printf "  ${c_green}✓${c_reset} %s\n" "$*"; }
warn()  { printf "  ${c_yellow}!${c_reset} %s\n" "$*"; }
err()   { printf "  ${c_red}✗${c_reset} %s\n" "$*"; }

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "Missing dependency: $1"
        return 1
    fi
}

# ---------- locate / download repo ----------
REPO_DIR="${REPO_DIR:-}"
TMP_DIR=""
cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

if [ -z "$REPO_DIR" ]; then
    # Running from a cloned checkout?
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/hypr/hyprland.lua" ]; then
        REPO_DIR="$SCRIPT_DIR"
    else
        info "Downloading repository..."
        need git || { err "git is required"; exit 1; }
        TMP_DIR="$(mktemp -d)"
        git clone --depth 1 "$REPO_URL" "$TMP_DIR/hyprland-dots" >/dev/null 2>&1
        REPO_DIR="$TMP_DIR/hyprland-dots"
        ok "Cloned $REPO_URL"
    fi
fi

if [ ! -d "$REPO_DIR" ]; then
    err "Repository directory not found: $REPO_DIR"
    exit 1
fi

# ---------- config dirs to install ----------
CONFIG_DIRS=(alacritty fastfetch hypr kitty quickshell rofi swaylock waybar waypaper)

# ---------- backup ----------
info "Backing up existing configs to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$CONFIG_DIR/$dir" ]; then
        cp -rT "$CONFIG_DIR/$dir" "$BACKUP_DIR/$dir" 2>/dev/null && ok "Backed up $dir" || warn "Could not back up $dir"
    fi
done
# home dotfiles backup
for f in .bashrc .bash_profile .zshrc starship.toml; do
    if [ -f "$HOME/$f" ]; then
        cp -a "$HOME/$f" "$BACKUP_DIR/${f#.}" 2>/dev/null || true
    fi
done

# ---------- install configs ----------
info "Installing configs into $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$REPO_DIR/$dir" ]; then
        rm -rf "$CONFIG_DIR/$dir"
        cp -rT "$REPO_DIR/$dir" "$CONFIG_DIR/$dir"
        ok "Installed $dir"
    else
        warn "Skipped (not in repo): $dir"
    fi
done

# ---------- home dotfiles ----------
info "Installing shell / starship configs"
for f in starship.toml .bashrc .bash_profile .zshrc; do
    if [ -f "$REPO_DIR/$f" ]; then
        cp -a "$REPO_DIR/$f" "$HOME/$f"
        ok "Installed $f"
    fi
done

# ---------- executable bits ----------
find "$CONFIG_DIR/hypr/scripts" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} \; 2>/dev/null || true
find "$REPO_DIR/hypr/scripts" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} \; 2>/dev/null || true

# ---------- done ----------
echo ""
printf "${c_green}${c_bold}✅ Installation complete!${c_reset}\n"
echo ""
echo "📌 Old config backed up at: $BACKUP_DIR"
echo ""
echo "🔄 Next steps:"
echo "  1. Reload shell:  source ~/.zshrc  (or ~/.bashrc)"
echo "  2. Restart Hyprland: Super+Alt+R  (or log out & back in)"
echo "  3. Restart Waybar:  killall waybar; waybar &"
echo ""
echo "📦 Suggested dependencies (Arch):"
echo "  sudo pacman -S hyprland waybar alacritty rofi swaylock fastfetch kitty \\"
echo "    waypaper quickshell starship ttf-jetbrains-mono-nerd bibata-cursor-theme \\"
echo "    hyprpaper grim slurp wl-clipboard playerctl brightnessctl imagemagick chafa"
echo ""
echo "  Debian/Ubuntu: sudo apt install hyprland waybar alacritty rofi swaylock fastfetch kitty"
echo "  Fedora:        sudo dnf install hyprland waybar alacritty rofi swaylock fastfetch kitty"
