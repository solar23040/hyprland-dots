#!/usr/bin/env bash
# Adjust the laptop backlight through systemd-logind.
# This works as a normal user (no root, udev rule, or extra package required).
#
# Usage: brightness.sh up|down [step-percent]
#        brightness.sh set <percent> [quiet]

set -euo pipefail

ACTION="${1:-}"
ARG2="${2:-}"
ARG3="${3:-}"

# Use the first backlight device with a sane max_brightness.
NAME=""
for DEV in /sys/class/backlight/*; do
    [[ -r "$DEV/max_brightness" && -r "$DEV/brightness" ]] || continue
    MAX="$(cat "$DEV/max_brightness")"
    if [[ "$MAX" -gt 0 ]]; then
        NAME="$(basename "$DEV")"
        break
    fi
done

if [[ -z "$NAME" ]]; then
    echo "brightness.sh: no backlight device found" >&2
    exit 1
fi

# Serialize rapid key repeats so read-modify-write steps aren't lost.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/brightness.lock"
exec 9>"$LOCK"
flock -w 1 9 || exit 0

CUR="$(cat "/sys/class/backlight/$NAME/brightness")"

# Never let the panel go completely dark; treat 1% as the floor.
MIN=$(( MAX / 100 )); (( MIN < 1 )) && MIN=1

QUIET=0

if [[ "$ACTION" == "set" ]]; then
    # Absolute value in percent, used by the brightness sidebar (and scripts).
    if [[ ! "$ARG2" =~ ^[0-9]+$ ]]; then
        echo "Usage: $0 set <percent> [quiet]" >&2
        exit 2
    fi
    PCT="$ARG2"
    if (( PCT < 1 )); then PCT=1; fi
    if (( PCT > 100 )); then PCT=100; fi
    TARGET=$(( (PCT * MAX + 50) / 100 ))
    [[ "$ARG3" == "quiet" ]] && QUIET=1
else
    STEP="${ARG2:-5}"
    DELTA=$(( MAX * STEP / 100 )); (( DELTA < 1 )) && DELTA=1

    case "$ACTION" in
        up)   TARGET=$(( CUR + DELTA )) ;;
        down) TARGET=$(( CUR - DELTA )) ;;
        *)
            echo "Usage: $0 up|down [step-percent] | $0 set <percent> [quiet]" >&2
            exit 2
            ;;
    esac
fi

(( TARGET > MAX )) && TARGET=$MAX
(( TARGET < MIN )) && TARGET=$MIN

busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
    org.freedesktop.login1.Session SetBrightness ssu \
    backlight "$NAME" "$TARGET" >/dev/null

if (( QUIET == 0 )); then
    PCT=$(( (TARGET * 100 + MAX / 2) / MAX ))
    hyprctl notify 5 800 "rgb(89b4fa)" "Brightness: ${PCT}%" >/dev/null 2>&1 || true
fi
