#!/usr/bin/env bash
# Fast keyboard-driven wallpaper selector using rofi (horizontal, with thumbnails).

set -euo pipefail

WALL_DIR="${WALLPAPER_DIR:-/home/solar/Pictures/Wallpapers}"
if [[ ! -d "$WALL_DIR" ]]; then
    WALL_DIR="$HOME/Pictures"
fi

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

# Prepare thumbnails (cached) so rofi can show image previews.
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbs"
mkdir -p "$THUMB_DIR"

THUMBS=()
for f in "${FILES[@]}"; do
    h=$(printf '%s' "$f" | md5sum | cut -d' ' -f1)
    thumb="$THUMB_DIR/$h.png"
    if [[ ! -f "$thumb" ]]; then
        python3 - "$f" "$thumb" <<'PY' 2>/dev/null || true
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
try:
    im = Image.open(src).convert("RGB")
    im.thumbnail((160, 160))
    # pad to square
    sq = Image.new("RGB", (160, 160), (30, 30, 46))
    x = (160 - im.width) // 2
    y = (160 - im.height) // 2
    sq.paste(im, (x, y))
    sq.save(dst, "PNG")
except Exception:
    pass
PY
    fi
    THUMBS+=("$thumb")
done

# Feed rofi with icon metadata so thumbnails are displayed.
SELECTION=$(
    for i in "${!FILES[@]}"; do
        printf '%s\0icon\x1f%s\x1f\n' "$(basename "${FILES[$i]}")" "${THUMBS[$i]}"
    done | rofi -config /home/solar/.config/rofi/wallpaper.rasi -dmenu -i -p "Wallpaper" 2>/dev/null
) || true

if [[ -z "${SELECTION:-}" ]]; then
    exit 0
fi

# rofi returns the selected label text (basename).
TARGET=""
for f in "${FILES[@]}"; do
    if [[ "$(basename "$f")" == "$SELECTION" ]]; then
        TARGET="$f"
        break
    fi
done

if [[ -z "$TARGET" ]]; then
    exit 1
fi

hyprctl notify 5 1500 "rgb(89b4fa)" "Wallpaper: $(basename "$TARGET")" >/dev/null 2>&1 || true
waypaper --wallpaper "$TARGET" --backend hyprpaper >/dev/null 2>&1