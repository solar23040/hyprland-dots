#!/usr/bin/env bash
# Control the laptop panel (eDP-1) rotation.
# Usage:
#   screen-invert.sh            toggle between normal (0) and inverted (2)
#   screen-invert.sh toggle
#   screen-invert.sh apply      re-apply the saved rotation without toggling
#   screen-invert.sh normal     force normal (0)
#   screen-invert.sh inverted   force inverted (2)

set -u

MONITOR="eDP-1"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/screen-invert"
STATE_FILE="$STATE_DIR/transform"
LEGACY_STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/screen-invert/state"

mkdir -p "$STATE_DIR"

# Serialize toggle/apply calls so an event-triggered apply cannot overwrite
# a manual Super+I change with a stale state.
LOCK_FILE="$STATE_DIR/lock"
exec 9>"$LOCK_FILE"
flock -w 5 9 || exit 0

current_transform() {
    hyprctl monitors 2>/dev/null | awk -v mon="$MONITOR" '
        $1 == "Monitor" && $2 == mon { found = 1; next }
        found && $1 == "transform:" { print $2; exit }
        found && $1 == "Monitor" { exit }
    '
}

apply_transform() {
    local transform="$1"
    hyprctl eval "hl.monitor({ output = '$MONITOR', mode = 'preferred', position = 'auto', scale = 1, transform = $transform })" >/dev/null 2>&1
}

notify() {
    hyprctl notify 5 1500 "rgb(89b4fa)" "$1" >/dev/null 2>&1 || true
}

read_state() {
    local transform=""

    if [[ -f "$STATE_FILE" ]]; then
        read -r transform < "$STATE_FILE" || transform=""
    fi

    # Migrate the old cache-based state once.
    if [[ ! "$transform" =~ ^[0-7]$ && -f "$LEGACY_STATE_FILE" ]]; then
        read -r transform < "$LEGACY_STATE_FILE" || transform=""
        if [[ "$transform" =~ ^[0-7]$ ]]; then
            printf '%s\n' "$transform" > "$STATE_FILE"
        fi
    fi

    printf '%s\n' "$transform"
}

write_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

set_transform() {
    local transform="$1"
    local label="$2"

    write_state "$transform"
    apply_transform "$transform"
    notify "Screen: $label"
}

desired="$(read_state)"

case "${1:-toggle}" in
    toggle)
        current="$(current_transform)"
        if [[ -z "$current" ]]; then
            notify "Screen: $MONITOR not found"
            exit 1
        fi

        if [[ "$current" == "2" ]]; then
            set_transform 0 "Normal"
        else
            set_transform 2 "Inverted"
        fi
        ;;
    apply)
        current="$(current_transform)"
        if [[ -z "$current" || -z "$desired" || ! "$desired" =~ ^[0-7]$ ]]; then
            exit 0
        fi
        if [[ "$current" != "$desired" ]]; then
            apply_transform "$desired"
        fi
        ;;
    normal)
        set_transform 0 "Normal"
        ;;
    inverted)
        set_transform 2 "Inverted"
        ;;
    *)
        printf 'Usage: %s [toggle|apply|normal|inverted]\n' "${0##*/}" >&2
        exit 2
        ;;
esac
