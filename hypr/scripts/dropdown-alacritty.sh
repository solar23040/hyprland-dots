#!/usr/bin/env bash
set -euo pipefail

CLASS="AlacrittyDropdown"

# Check whether the dropdown terminal is already running.
dropdown_running() {
    python3 -c '
import json, subprocess, sys
data = subprocess.check_output(["hyprctl", "clients", "-j"])
clients = json.loads(data)
sys.exit(0 if any(c.get("class") == sys.argv[1] for c in clients) else 1)
' "$CLASS"
}

if dropdown_running; then
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("dropdown")'
else
    hyprctl dispatch "hl.dsp.exec_cmd(\"alacritty --class $CLASS\")"

    # Wait for the window to be created, then show the scratchpad.
    for _ in $(seq 1 30); do
        if dropdown_running; then
            break
        fi
        sleep 0.1
    done

    hyprctl dispatch 'hl.dsp.workspace.toggle_special("dropdown")'
fi
