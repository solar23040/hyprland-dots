import QtQuick
import Quickshell

// Shared Catppuccin Mocha palette + small helpers for the notification
// centre. Instantiated as a cheap QtObject wherever it is needed instead
// of using a QML singleton (no qmldir juggling).
QtObject {
    readonly property color base:     "#1e1e2e"
    readonly property color mantle:   "#181825"
    readonly property color crust:    "#11111b"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color subtext0: "#a6adc8"
    readonly property color text:     "#cdd6f4"
    readonly property color lavender: "#b4befe"
    readonly property color blue:     "#89b4fa"
    readonly property color sapphire: "#74c7ec"
    readonly property color teal:     "#94e2d5"
    readonly property color green:    "#a6e3a1"
    readonly property color yellow:   "#f9e2af"
    readonly property color peach:    "#fab387"
    readonly property color maroon:   "#eba0ac"
    readonly property color red:      "#f38ba8"
    readonly property color mauve:    "#cba6f7"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // NotificationUrgency: 0 = Low, 1 = Normal, 2 = Critical
    function urgencyColor(urgency) {
        if (urgency === 2)
            return red;
        if (urgency === 0)
            return overlay1;
        return blue;
    }

    // App icons are theme lookups, an absolute path, or nothing at all.
    // Falls back to a generic info icon when the name isn't installed.
    function appIconSource(appIcon) {
        if (appIcon && appIcon.startsWith("/"))
            return "file://" + appIcon;
        if (appIcon && Quickshell.hasThemeIcon(appIcon))
            return Quickshell.iconPath(appIcon);
        return Quickshell.iconPath("dialog-information");
    }

    // Compact relative time ("now", "4m", "2h", "3d").
    function ago(stamp) {
        if (!stamp)
            return "";
        const secs = Math.max(0, (Date.now() - stamp) / 1000);
        if (secs < 45)
            return "now";
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return mins + "m";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + "h";
        return Math.floor(hours / 24) + "d";
    }
}
