#!/usr/bin/env bash
# Cycle through wallpapers in a folder using Waypaper + hyprpaper.
# Usage: wallpaper-cycle.sh [next|prev|random]

set -euo pipefail

WALL_DIR="${WALLPAPER_DIR:-/home/solar/Pictures/Wallpapers}"
if [[ ! -d "$WALL_DIR" ]]; then
    WALL_DIR="$HOME/Pictures"
fi

# Collect wallpapers (recursive, common image types), sorted.
mapfile -d '' -t FILES < <(
    find "$WALL_DIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.jxl' \) \
        -print0 2>/dev/null | sort -z
)

COUNT="${#FILES[@]}"
if (( COUNT == 0 )); then
    hyprctl notify 3 3000 "rgb(ff5555)" "No wallpapers found in $WALL_DIR" >/dev/null 2>&1 || true
    exit 1
fi

# Try to sync with the last wallpaper recorded by Waypaper, so cycling
# stays correct even after picking one in the GUI.
WP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"
CURRENT=""
if [[ -f "$WP_CONFIG" ]]; then
    CURRENT=$(python3 - "$WP_CONFIG" <<'PY'
import configparser, sys
cp = configparser.ConfigParser()
try:
    cp.read(sys.argv[1])
    # Waypaper stores the active wallpaper in [Settings] by default,
    # or in [State] when use_xdg_state is enabled.
    for section in ("State", "Settings"):
        if cp.has_section(section) and cp.has_option(section, "wallpaper"):
            val = cp.get(section, "wallpaper", raw=True)
            lines = [l.strip() for l in val.splitlines() if l.strip()]
            if lines:
                print(lines[0])
                break
except Exception:
    pass
PY
)
fi
# Expand a leading ~/
CURRENT="${CURRENT/#\~/$HOME}"

BASE=0
if [[ -n "$CURRENT" ]]; then
    for i in "${!FILES[@]}"; do
        if [[ "${FILES[$i]}" == "$CURRENT" ]]; then
            BASE="$i"
            break
        fi
    done
fi

MODE="${1:-next}"
case "$MODE" in
    next)   IDX=$(( (BASE + 1) % COUNT )) ;;
    prev)   IDX=$(( (BASE - 1 + COUNT) % COUNT )) ;;
    random) IDX=$(( RANDOM % COUNT )) ;;
    *)
        # Allow passing an explicit index.
        if [[ "$MODE" =~ ^[0-9]+$ ]] && (( MODE < COUNT )); then
            IDX="$MODE"
        else
            echo "Unknown mode: $MODE" >&2
            exit 2
        fi
        ;;
esac

TARGET="${FILES[$IDX]}"
hyprctl notify 5 1500 "rgb(89b4fa)" "Wallpaper $((IDX + 1))/${COUNT}: $(basename "$TARGET")" >/dev/null 2>&1 || true

# Apply via Waypaper so state/config stay in sync with hyprpaper backend.
waypaper --wallpaper "$TARGET" --backend hyprpaper >/dev/null 2>&1