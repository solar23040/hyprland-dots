#!/usr/bin/env bash
# Nudge the focused monitor's scale by ±0.05 in real time (clamped 1.0–3.0).
# Preserves mode, position and transform, so it is safe on rotated outputs.
# Usage: monitor-scale.sh up|down
set -eu

dir="${1:?usage: monitor-scale.sh up|down}"
case "$dir" in
    up)   delta=0.05 ;;
    down) delta=-0.05 ;;
    *)    echo "monitor-scale: bad arg '$dir' (expected up|down)" >&2; exit 2 ;;
esac

# Serialize rapid key-repeat invocations so two runs can't read the same scale.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/monitor-scale.lock"
exec 9>"$LOCK"
flock -w 2 9 || exit 0

read -r MON MODE POS OLD NEW TRANSFORM < <(hyprctl monitors -j | python3 -c '
import json, sys

delta = float(sys.argv[1])
mons = json.load(sys.stdin)
mon = (next((m for m in mons if m.get("focused")), None)
       or next((m for m in mons if m["name"] in ("DP-1", "DP-2")), None)
       or (mons[0] if mons else None))
if mon is None:
    sys.exit(1)

old = float(mon["scale"])
new = max(1.0, min(3.0, round(old + delta, 2)))
mode = "{}x{}@{:.2f}".format(mon["width"], mon["height"], mon["refreshRate"])
print(mon["name"], mode, "{}x{}".format(mon["x"], mon["y"]),
      "{:.2f}".format(old), "{:.2f}".format(new), mon["transform"])
' "$delta") || exit 0

if [[ "$OLD" == "$NEW" ]]; then
    hyprctl notify 5 800 "rgb(f9e2af)" "Scale $MON: limit $NEW" >/dev/null 2>&1 || true
    exit 0
fi

hyprctl eval "hl.monitor({ output = '$MON', mode = '$MODE', position = '$POS', scale = $NEW, transform = $TRANSFORM })" >/dev/null

hyprctl notify 5 800 "rgb(89b4fa)" "Scale $MON: $OLD -> $NEW" >/dev/null 2>&1 || true
