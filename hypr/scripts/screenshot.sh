#!/usr/bin/env bash
# Hyprland screenshot helper — grim + slurp + wl-clipboard
#
#   region → drag-select an area        (ESC cancels)
#   window → focused window
#   full   → all outputs as one image
#
# Every shot is saved to ~/Pictures/Screenshots/ and copied to the clipboard.
# Wired to Waybar (custom/screenshot) and to the Print keybinds in hyprland.lua.

set -u

MODE="${1:-region}"
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S)-${MODE}.png"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "screenshot" "Screenshot" "$1"
    elif command -v hyprctl >/dev/null 2>&1; then
        hyprctl notify 5 3000 "rgb(94e2d5)" "$1" >/dev/null 2>&1
    fi
}

capture() {
    # $@ = extra grim args (-g geometry, -o output, ...)
    local tmp
    tmp="$(mktemp "$DIR/.shot.XXXXXX.png")"
    if grim "$@" - > "$tmp" && [ -s "$tmp" ]; then
        mv "$tmp" "$FILE"
        wl-copy -t image/png < "$FILE"
        notify "Saved + copied: ${FILE##*/}"
    else
        rm -f "$tmp"
        notify "Screenshot failed"
        exit 1
    fi
}

case "$MODE" in
    region)
        GEOM="$(slurp)" || exit 0            # cancelled with ESC / right-click
        [ -n "$GEOM" ] || exit 0
        capture -g "$GEOM"
        ;;
    window)
        GEOM="$(hyprctl -j activewindow | python3 -c '
import json, sys
w = json.load(sys.stdin)
at, sz = w["at"], w["size"]
print(f"{at[0]},{at[1]} {sz[0]}x{sz[1]}")
')" || { notify "No active window"; exit 1; }
        capture -g "$GEOM"
        ;;
    full)
        capture
        ;;
    *)
        echo "usage: $0 [region|window|full]" >&2
        exit 2
        ;;
esac
