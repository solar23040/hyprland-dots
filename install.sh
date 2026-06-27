#!/bin/bash

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTS_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%s)"

echo "🔧 Installing Solar's Hyprland Dots..."
echo ""

# Backup existing configs
echo "📦 Backing up existing configs..."
mkdir -p "$BACKUP_DIR"
for dir in fastfetch alacritty hyprland rofi swaylock waybar; do
    if [ -d "$DOTS_DIR/$dir" ]; then
        cp -r "$DOTS_DIR/$dir" "$BACKUP_DIR/" 2>/dev/null && echo "  ✓ Backed up $dir"
    fi
done

# Copy configs
echo ""
echo "📋 Installing configs..."
for dir in fastfetch alacritty hyprland rofi swaylock waybar; do
    if [ -d "$REPO_DIR/$dir" ]; then
        cp -r "$REPO_DIR/$dir" "$DOTS_DIR/"
        echo "  ✓ Installed $dir"
    fi
done

echo ""
echo "✅ Installation complete!"
echo ""
echo "📌 Your old config backed up at: $BACKUP_DIR"
echo ""
echo "🔄 Next steps:"
echo "  1. Reload shell: source ~/.bashrc (or ~/.zshrc)"
echo "  2. Restart Hyprland: Super+Alt+R or logout and login"
echo "  3. Restart Waybar: killall waybar && waybar &"
