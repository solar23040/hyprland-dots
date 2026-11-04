#!/usr/bin/env python3
"""Waybar custom module: the focused Hyprland workspace.

Prints one JSON line per update and keeps running (waybar re-reads every
line). Updates arrive over Hyprland's event socket; falls back to polling
if the socket is unavailable.
"""

import json
import os
import socket
import subprocess
import time

RELEVANT_EVENTS = {
    "workspace", "workspacev2",
    "createworkspace", "destroyworkspace", "renameworkspace",
    "moveworkspace", "moveworkspacev2",
    "focusedmon", "activespecial",
    "openwindow", "closewindow",
}


def emit():
    try:
        aw = json.loads(
            subprocess.check_output(["hyprctl", "-j", "activeworkspace"], text=True)
        )
    except Exception:
        return
    name = str(aw.get("name") or aw.get("id") or "?")
    wid = str(aw.get("id", "?"))
    mon = aw.get("monitor") or ""
    wins = int(aw.get("windows", 0))

    text = name if len(name) <= 4 else wid
    tooltip = f"Workspace {name} (id {wid})"
    if mon:
        tooltip += f" · {mon}"
    tooltip += f" · {wins} window{'s' if wins != 1 else ''}"

    print(json.dumps({
        "text": text,
        "tooltip": tooltip,
        "class": "occupied" if wins else "empty",
    }), flush=True)


def event_socket():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not sig:
        return None
    return os.path.join(runtime, "hypr", sig, ".socket2.sock")


def main():
    emit()

    path = event_socket()
    if path:
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(path)
            buf = b""
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    event = line.split(b">>", 1)[0].decode("utf-8", "replace")
                    if event in RELEVANT_EVENTS:
                        emit()
            return
        except OSError:
            pass

    while True:                      # fallback: poll every 2 s
        time.sleep(2)
        emit()


if __name__ == "__main__":
    main()
