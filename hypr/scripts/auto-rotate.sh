#!/usr/bin/env bash
# Auto-rotate the laptop panel (eDP-1) using iio-sensor-proxy.
# Runs as a daemon: monitor-sensor -> Hyprland transform.

MONITOR="eDP-1"
FLAG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/screen-orientation"
FLAG="$FLAG_DIR/auto-rotate-disabled"

declare -A TRANSFORM=(
    [normal]=0
    [left-up]=3
    [right-up]=1
    [bottom-up]=2
)

# Make sure monitor-sensor exists.
if ! command -v monitor-sensor >/dev/null 2>&1; then
    hyprctl notify 3 4000 "rgb(ff5555)" "monitor-sensor not found (install iio-sensor-proxy)" >/dev/null 2>&1
    exit 1
fi

stdbuf -oL monitor-sensor 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" == *"Orientation changed:"* ]]; then
        # Respect manual inversion: do not override while auto-rotate is paused.
        if [[ -f "$FLAG" ]]; then
            continue
        fi
        orient="${line#*Orientation changed:}"
        orient="${orient//[[:space:]]/}"
        t="${TRANSFORM[$orient]:-}"
        if [[ -n "$t" ]]; then
            hyprctl eval "hl.monitor({ output = '$MONITOR', mode = 'preferred', position = 'auto', scale = 1, transform = $t })" >/dev/null 2>&1
            hyprctl notify 1 1500 "rgb(89b4fa)" "Auto-rotate: $orient" >/dev/null 2>&1
        fi
    fi
done