#!/usr/bin/env python3
"""Desktop clock widget for Hyprland (wlr-layer-shell via GTK3).

A frameless time + date card pinned to the desktop. It lives on the
layer-shell "bottom" layer: above the wallpaper, behind normal windows.
Autostarted from hyprland.lua, one instance per Hyprland session.

Tweak the constants below, then restart it (or relogin), e.g.:
    pkill -f desktop-clock.py; setsid -f ~/.config/hypr/scripts/desktop-clock.py
"""

import argparse
import fcntl
import os
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

# ------------------------------ tweak me ------------------------------
FONT_FAMILY = "JetBrainsMono Nerd Font Mono"
TIME_SIZE = "96px"
DATE_SIZE = "22px"
SHOW_SECONDS = False        # show HH:MM:SS instead of HH:MM
ANCHOR = "center"           # center | top-right | bottom-center | left-center ...
MARGIN = 60                 # px from the screen edges when not centered
LAYER = "bottom"            # background | bottom | top | overlay

TIME_COLOR = "#cdd6f4"                 # catppuccin mocha "text"
DATE_COLOR = "#a6adc8"                 # "subtext0"
CARD_COLOR = "rgba(30, 30, 46, 0.55)"  # "base" at 55% alpha
CARD_BORDER = "rgba(180, 190, 254, 0.28)"  # "lavender" at 28% alpha
# ------------------------------------------------------------------------

CSS = f"""
window {{
    background-color: {CARD_COLOR};
    border: 1px solid {CARD_BORDER};
    border-radius: 28px;
}}
#time-label {{
    font-family: "{FONT_FAMILY}";
    font-size: {TIME_SIZE};
    color: {TIME_COLOR};
}}
#date-label {{
    font-family: "{FONT_FAMILY}";
    font-size: {DATE_SIZE};
    color: {DATE_COLOR};
}}
"""

ANCHORS = {
    "center": [],
    "top-left": ["TOP", "LEFT"],
    "top-center": ["TOP"],
    "top-right": ["TOP", "RIGHT"],
    "bottom-left": ["BOTTOM", "LEFT"],
    "bottom-center": ["BOTTOM"],
    "bottom-right": ["BOTTOM", "RIGHT"],
    "left-center": ["LEFT"],
    "right-center": ["RIGHT"],
}

LAYERS = {
    "background": GtkLayerShell.Layer.BACKGROUND,
    "bottom": GtkLayerShell.Layer.BOTTOM,
    "top": GtkLayerShell.Layer.TOP,
    "overlay": GtkLayerShell.Layer.OVERLAY,
}

EDGES = {
    "TOP": GtkLayerShell.Edge.TOP,
    "BOTTOM": GtkLayerShell.Edge.BOTTOM,
    "LEFT": GtkLayerShell.Edge.LEFT,
    "RIGHT": GtkLayerShell.Edge.RIGHT,
}


def build_window(monitor=None):
    win = Gtk.Window()
    win.set_title("desktop-clock")
    win.set_decorated(False)
    win.set_resizable(False)
    win.set_app_paintable(True)
    win.set_skip_taskbar_hint(True)
    win.set_skip_pager_hint(True)

    visual = win.get_screen().get_rgba_visual()
    if visual:
        win.set_visual(visual)

    GtkLayerShell.init_for_window(win)
    if monitor is not None:
        GtkLayerShell.set_monitor(win, monitor)
    GtkLayerShell.set_namespace(win, "desktop-clock")
    GtkLayerShell.set_layer(win, LAYERS[LAYER])
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)
    GtkLayerShell.set_exclusive_zone(win, 0)

    anchored = ANCHORS[ANCHOR]
    for name, edge in EDGES.items():
        GtkLayerShell.set_anchor(win, edge, name in anchored)
        GtkLayerShell.set_margin(win, edge, MARGIN if name in anchored else 0)

    time_label = Gtk.Label(xalign=0.5)
    time_label.set_name("time-label")
    date_label = Gtk.Label(xalign=0.5)
    date_label.set_name("date-label")

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.set_border_width(28)
    box.pack_start(time_label, False, False, 0)
    box.pack_start(date_label, False, False, 0)
    win.add(box)

    provider = Gtk.CssProvider()
    try:
        provider.load_from_data(CSS)
    except TypeError:  # older PyGObject wants bytes
        provider.load_from_data(CSS.encode())
    Gtk.StyleContext.add_provider(
        win.get_style_context(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    def update():
        time_label.set_text(time.strftime("%H:%M:%S" if SHOW_SECONDS else "%H:%M"))
        date_label.set_text(time.strftime("%A, %d %B"))
        return True

    update()
    GLib.timeout_add_seconds(1, update)
    win.connect("destroy", Gtk.main_quit)
    return win


def single_instance_lock():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "default")
    path = os.path.join(runtime, f"desktop-clock-{sig}.lock")
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)              # this session already has a clock
    return path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Desktop clock widget for Hyprland (one window per monitor)."
    )
    parser.add_argument(
        "--monitor",
        action="append",
        default=[],
        metavar="NAME",
        help="only show on monitors whose model/manufacturer contains NAME "
             "(repeatable; default: all monitors)",
    )
    return parser.parse_args()


def select_monitors(names):
    display = Gdk.Display.get_default()
    if display is None:
        return []

    monitors = []
    for i in range(display.get_n_monitors()):
        monitor = display.get_monitor(i)
        if not names:
            monitors.append(monitor)
            continue
        haystack = " ".join(
            part for part in (monitor.get_model(), monitor.get_manufacturer()) if part
        ).lower()
        if any(name.lower() in haystack for name in names):
            monitors.append(monitor)
    return monitors


def main():
    args = parse_args()
    lock_path = single_instance_lock()
    try:
        monitors = select_monitors(args.monitor)
        if not monitors:
            print("desktop-clock: no matching monitors", file=sys.stderr)
            return
        windows = [build_window(monitor) for monitor in monitors]
        for win in windows:
            win.show_all()
        Gtk.main()
    finally:
        try:
            os.unlink(lock_path)
        except OSError:
            pass


if __name__ == "__main__":
    main()
