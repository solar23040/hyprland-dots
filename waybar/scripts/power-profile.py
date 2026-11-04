#!/usr/bin/env python3
"""Waybar custom module: power mode (power-profiles-daemon).

Prints one JSON line per change and keeps running; updates arrive over the
system D-Bus PropertiesChanged signal, with a polling fallback if
dbus-monitor is unavailable. Also provides the rofi picker and the
scroll/right-click actions used by the module's click handlers.

    power-profile.py             # stream status to waybar
    power-profile.py menu        # rofi picker
    power-profile.py cycle       # next profile (towards performance)
    power-profile.py cycle down  # previous profile (towards power saver)
"""

import json
import os
import re
import subprocess
import sys
import time

ORDER = ["power-saver", "balanced", "performance"]

META = {
    "power-saver": {
        "icon": "\U000F032A",          # md-leaf
        "label": "Power Saver",
        "class": "power-saver",
    },
    "balanced": {
        "icon": "\U000F05D1",          # md-scale-balance
        "label": "Balanced",
        "class": "balanced",
    },
    "performance": {
        "icon": "\U000F04C5",          # md-speedometer
        "label": "Performance",
        "class": "performance",
    },
}

# Pango markup rows for the rofi menu (Catppuccin Mocha accents)
ROWS = {
    "power-saver": "<span foreground='#A6E3A1'>\U000F032A</span>   Power Saver",
    "balanced":    "<span foreground='#89B4FA'>\U000F05D1</span>   Balanced",
    "performance": "<span foreground='#FAB387'>\U000F04C5</span>   Performance",
}

THEME = "~/.config/rofi/powermenu.rasi"
PROFILE_RE = re.compile(r'variant\s+string "(power-saver|balanced|performance)"')

_last = None


def get_profile():
    try:
        return subprocess.check_output(
            ["powerprofilesctl", "get"], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def set_profile(profile):
    try:
        subprocess.run(
            ["powerprofilesctl", "set", profile],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.CalledProcessError):
        pass


def emit(profile):
    global _last
    if profile == _last:
        return
    _last = profile
    meta = META.get(profile, {
        "icon": "?",
        "label": profile or "unknown",
        "class": "unknown",
    })
    print(json.dumps({
        "text": meta["icon"],
        "tooltip": f"Power profile: {meta['label']}\n"
                   "Left-click: choose · Right-click/scroll: cycle",
        "class": meta["class"],
    }), flush=True)


def watch():
    """Emit whenever power-profiles-daemon changes ActiveProfile."""
    try:
        proc = subprocess.Popen(
            ["dbus-monitor", "--system",
             "type='signal',sender='net.hadess.PowerProfiles',"
             "interface='org.freedesktop.DBus.Properties',"
             "member='PropertiesChanged',"
             "path='/net/hadess/PowerProfiles'"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
    except OSError:
        return False

    pending = False
    for line in proc.stdout:
        if "member=PropertiesChanged" in line:
            pending = True
        elif pending:
            match = PROFILE_RE.search(line)
            if match:
                emit(match.group(1))
                pending = False
    proc.wait()
    return True


def poll():
    while True:
        emit(get_profile())
        time.sleep(5)


def menu():
    current = get_profile()
    try:
        row = str(ORDER.index(current))
    except ValueError:
        row = "0"

    cmd = ["rofi", "-theme", os.path.expanduser(THEME),
           "-markup-rows", "-dmenu", "-i",
           "-p", "\U000F04C5  Power Profile", "-selected-row", row]
    if not os.path.exists(os.path.expanduser(THEME)):
        del cmd[1:3]
    try:
        choice = subprocess.run(
            cmd, input="\n".join(ROWS[p] for p in ORDER) + "\n",
            text=True, capture_output=True,
        ).stdout
    except OSError:
        return

    for profile in ORDER:
        if META[profile]["label"] in choice:
            set_profile(profile)
            return


def cycle(direction="up"):
    current = get_profile()
    if current not in ORDER:
        set_profile("balanced")
        return
    step = -1 if direction == "down" else 1
    set_profile(ORDER[(ORDER.index(current) + step) % len(ORDER)])


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action == "menu":
        return menu()
    if action == "cycle":
        return cycle(sys.argv[2] if len(sys.argv) > 2 else "up")

    emit(get_profile())
    if not watch():
        poll()


if __name__ == "__main__":
    main()
