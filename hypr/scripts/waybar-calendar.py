#!/usr/bin/env python3
"""Small calendar popup toggled from waybar's clock module.

Usage (from waybar on-click):
    waybar-calendar.py --monitor DP-2 --anchor top-right
    waybar-calendar.py --monitor eDP-1 --anchor top-center

Clicking again with the same arguments closes the popup; clicking with
different arguments moves it to the new monitor/position.
"""

import argparse
import atexit
import json
import os
import signal
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gtk, GtkLayerShell

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
LOCK_PATH = os.path.join(RUNTIME, "waybar-calendar.lock")

ANCHOR_PRESETS = {
    "top-left": ("TOP", "LEFT"),
    "top-center": ("TOP",),
    "top-right": ("TOP", "RIGHT"),
    "bottom-left": ("BOTTOM", "LEFT"),
    "bottom-center": ("BOTTOM",),
    "bottom-right": ("BOTTOM", "RIGHT"),
    "left-center": ("LEFT",),
    "right-center": ("RIGHT",),
    "center": (),
}

EDGES = {
    "TOP": GtkLayerShell.Edge.TOP,
    "BOTTOM": GtkLayerShell.Edge.BOTTOM,
    "LEFT": GtkLayerShell.Edge.LEFT,
    "RIGHT": GtkLayerShell.Edge.RIGHT,
}

CSS = """
window {
    background-color: rgba(30, 30, 46, 0.94);
    border: 1px solid rgba(180, 190, 254, 0.35);
    border-radius: 14px;
}
#cal-box { padding: 12px; }
calendar {
    background-color: transparent;
    color: #cdd6f4;
    font-family: "JetBrainsMono Nerd Font Mono", monospace;
    font-size: 13px;
}
calendar.header {
    background-color: transparent;
    color: #cdd6f4;
    font-weight: bold;
}
calendar.button {
    background: transparent;
    border: none;
    color: #b4befe;
}
calendar:selected {
    background-color: #b4befe;
    color: #1e1e2e;
    border-radius: 6px;
}
calendar.highlight {
    color: #a6adc8;
}
"""


def hypr_monitors():
    try:
        out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
        return json.loads(out)
    except Exception:
        return []


def gdk_monitor_for(make, model):
    display = Gdk.Display.get_default()
    if display is None:
        return None
    for i in range(display.get_n_monitors()):
        gm = display.get_monitor(i)
        if gm.get_manufacturer() == make and gm.get_model() == model:
            return gm
    return None


def gdk_monitor_by_name(name):
    monitors = hypr_monitors()
    for m in monitors:
        if m.get("name") == name:
            gm = gdk_monitor_for(m.get("make"), m.get("model"))
            if gm is not None:
                return gm

    # Fall back to the monitor holding the active workspace.
    try:
        out = subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True)
        mon_name = json.loads(out).get("monitor")
        for m in monitors:
            if m.get("name") == mon_name:
                gm = gdk_monitor_for(m.get("make"), m.get("model"))
                if gm is not None:
                    return gm
    except Exception:
        pass

    display = Gdk.Display.get_default()
    return display.get_monitor(0) if display and display.get_n_monitors() else None


def read_lock():
    try:
        with open(LOCK_PATH) as f:
            data = json.load(f)
        pid = data.get("pid")
        if isinstance(pid, int):
            os.kill(pid, 0)
            return data
    except Exception:
        pass
    try:
        os.remove(LOCK_PATH)
    except OSError:
        pass
    return None


def write_lock(key):
    with open(LOCK_PATH, "w") as f:
        json.dump({"pid": os.getpid(), "key": key}, f)


def cleanup_lock():
    try:
        with open(LOCK_PATH) as f:
            data = json.load(f)
        if data.get("pid") == os.getpid():
            os.remove(LOCK_PATH)
    except Exception:
        pass


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--monitor", default=None)
    p.add_argument("--anchor", default="top-right", choices=list(ANCHOR_PRESETS))
    p.add_argument("--margin-top", type=int, default=None)
    p.add_argument("--margin-right", type=int, default=None)
    p.add_argument("--margin-bottom", type=int, default=None)
    p.add_argument("--margin-left", type=int, default=None)
    return p.parse_args()


def margins_for(args):
    m = {"TOP": 0, "BOTTOM": 0, "LEFT": 0, "RIGHT": 0}
    if args.anchor == "top-right":
        m["TOP"], m["RIGHT"] = 56, 112
    elif args.anchor == "top-center":
        m["TOP"] = 48
    elif args.anchor == "top-left":
        m["TOP"], m["LEFT"] = 56, 112
    elif args.anchor == "bottom-right":
        m["BOTTOM"], m["RIGHT"] = 56, 112
    elif args.anchor == "bottom-center":
        m["BOTTOM"] = 48
    elif args.anchor == "bottom-left":
        m["BOTTOM"], m["LEFT"] = 56, 112
    elif args.anchor == "right-center":
        m["RIGHT"] = 112
    elif args.anchor == "left-center":
        m["LEFT"] = 112
    if args.margin_top is not None:
        m["TOP"] = args.margin_top
    if args.margin_right is not None:
        m["RIGHT"] = args.margin_right
    if args.margin_bottom is not None:
        m["BOTTOM"] = args.margin_bottom
    if args.margin_left is not None:
        m["LEFT"] = args.margin_left
    return m


def on_key(_win, event):
    if event.keyval == Gdk.KEY_Escape:
        Gtk.main_quit()
        return True
    return False


def build_window(args, mon):
    win = Gtk.Window()
    win.set_title("waybar-calendar")
    win.set_decorated(False)
    win.set_resizable(False)
    win.set_app_paintable(True)
    win.set_skip_taskbar_hint(True)
    win.set_skip_pager_hint(True)

    visual = win.get_screen().get_rgba_visual()
    if visual:
        win.set_visual(visual)

    GtkLayerShell.init_for_window(win)
    if mon is not None:
        GtkLayerShell.set_monitor(win, mon)
    GtkLayerShell.set_namespace(win, "waybar-calendar")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.ON_DEMAND)
    GtkLayerShell.set_exclusive_zone(win, 0)

    anchored = set(ANCHOR_PRESETS[args.anchor])
    for name, edge in EDGES.items():
        GtkLayerShell.set_anchor(win, edge, name in anchored)

    m = margins_for(args)
    for name, edge in EDGES.items():
        GtkLayerShell.set_margin(win, edge, m[name])

    cal = Gtk.Calendar()
    cal.set_display_options(
        Gtk.CalendarDisplayOptions.SHOW_HEADING
        | Gtk.CalendarDisplayOptions.SHOW_DAY_NAMES
    )

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.set_name("cal-box")
    box.set_border_width(8)
    box.pack_start(cal, True, True, 0)
    win.add(box)

    provider = Gtk.CssProvider()
    try:
        provider.load_from_data(CSS)
    except TypeError:
        provider.load_from_data(CSS.encode())
    for widget in (win, box, cal):
        Gtk.StyleContext.add_provider(
            widget.get_style_context(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    win.connect("key-press-event", on_key)
    win.connect("destroy", Gtk.main_quit)
    return win


def main():
    args = parse_args()
    key = json.dumps(
        {
            "monitor": args.monitor,
            "anchor": args.anchor,
            "mt": args.margin_top,
            "mr": args.margin_right,
            "mb": args.margin_bottom,
            "ml": args.margin_left,
        },
        sort_keys=True,
    )

    existing = read_lock()
    if existing:
        if existing.get("key") == key:
            try:
                os.kill(existing["pid"], signal.SIGTERM)
            except ProcessLookupError:
                pass
            sys.exit(0)

        try:
            os.kill(existing["pid"], signal.SIGTERM)
        except ProcessLookupError:
            pass
        for _ in range(20):
            try:
                os.kill(existing["pid"], 0)
                time.sleep(0.05)
            except ProcessLookupError:
                break

    try:
        os.remove(LOCK_PATH)
    except FileNotFoundError:
        pass

    write_lock(key)
    atexit.register(cleanup_lock)
    signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())

    mon = gdk_monitor_by_name(args.monitor) if args.monitor else None
    win = build_window(args, mon)
    win.show_all()
    Gtk.main()
    cleanup_lock()


if __name__ == "__main__":
    main()
