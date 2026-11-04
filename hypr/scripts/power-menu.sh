#!/usr/bin/env bash
# Rofi power menu: Sleep / Reboot / Shutdown
# Bound to SUPER+P in the Hyprland config.

set -euo pipefail

theme="$HOME/.config/rofi/powermenu.rasi"

icon_sleep=$'\uF186'      # moon
icon_reboot=$'\uF021'     # refresh
icon_shutdown=$'\uF011'   # power
icon_yes=$'\uF00C'        # check
icon_no=$'\uF00D'         # times

# Pango markup rows (colors: Catppuccin mauve / green / pink)
row_sleep="<span foreground='#CBA6F7'>$icon_sleep</span>   Sleep"
row_reboot="<span foreground='#ABE9B3'>$icon_reboot</span>   Reboot"
row_shutdown="<span foreground='#F28FAD'>$icon_shutdown</span>   Shutdown"
row_yes="<span foreground='#ABE9B3'>$icon_yes</span>   Yes"
row_no="<span foreground='#F28FAD'>$icon_no</span>   No"

uptime_msg() {
    printf 'Uptime: %s' "$(uptime -p 2>/dev/null | sed 's/^up //')"
}

main_menu() {
    printf '%s\n' "$row_sleep" "$row_reboot" "$row_shutdown" \
        | rofi -theme "$theme" -markup-rows -dmenu -i \
               -p "$icon_shutdown  Power Menu" -mesg "$(uptime_msg)"
}

confirm_menu() {
    printf '%s\n' "$row_yes" "$row_no" \
        | rofi -theme "$theme" -markup-rows -dmenu -i \
               -p "$1" -mesg "Are you sure?"
}

choice="$(main_menu)" || exit 0
[[ -z "$choice" ]] && exit 0

case "$choice" in
    *Sleep)
        systemctl suspend
        ;;
    *Reboot)
        if [[ "$(confirm_menu "$icon_reboot  Reboot?")" == "$row_yes" ]]; then
            systemctl reboot
        fi
        ;;
    *Shutdown)
        if [[ "$(confirm_menu "$icon_shutdown  Shutdown?")" == "$row_yes" ]]; then
            systemctl poweroff
        fi
        ;;
esac
