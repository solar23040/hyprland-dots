#!/usr/bin/env bash
# Lock the screen using the current wallpaper (via Waypaper state).

WP=$(python3 - <<'PY'
import configparser, os
cp = configparser.ConfigParser()
p = os.path.expanduser("~/.config/waypaper/config.ini")
try:
    cp.read(p)
    for section in ("State", "Settings"):
        if cp.has_section(section) and cp.has_option(section, "wallpaper"):
            val = cp.get(section, "wallpaper", raw=True)
            lines = [l.strip() for l in val.splitlines() if l.strip()]
            if lines:
                print(os.path.expanduser(lines[0]))
                break
except Exception:
    pass
PY
)

CONF="$HOME/.config/hypr/hyprlock.conf"

if [[ -n "$WP" && -f "$WP" ]]; then
    BG_PATH="$WP"
else
    BG_PATH="screenshot"
fi

cat > "$CONF" <<EOF
general {
    hide_cursor = false
}

background {
    monitor =
    path = $BG_PATH
    blur_passes = 2
    blur_size = 7
}

label {
    monitor =
    text = cmd[update:1000] date +"%H:%M"
    color = rgb(205, 214, 244)
    font_size = 96
    font_family = Sans
    position = 0, 180
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 20%, 5%
    outline_thickness = 3
    inner_color = rgba(0, 0, 0, 0.0)
    outer_color = rgba(33ccffee) rgba(00ff99ee) 45deg
    check_color = rgba(00ff99ee) rgba(ff6633ee) 120deg
    fail_color = rgba(ff6633ee) rgba(ff0066ee) 40deg
    font_color = rgb(205, 214, 244)
    fade_on_empty = false
    rounding = 15
    font_family = Sans
    placeholder_text = Input password...
    fail_text = \$PAMFAIL
    dots_spacing = 0.3
    position = 0, -20
    halign = center
    valign = center
}
EOF

hyprlock