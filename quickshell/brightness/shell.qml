import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Always-on brightness rail for the laptop panel (eDP-1).
// Finger up = brighter, finger down = dimmer.
PanelWindow {
    id: win

    // ── Target screen ───────────────────────────────────────────────
    // Brightness is panel specific, so the rail lives on the laptop
    // screen even when an external monitor is connected.
    screen: {
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === "eDP-1") return list[i];
        return list.length > 0 ? list[0] : null;
    }

    // ── Geometry: right edge, below the waybar ──────────────────────
    anchors { top: true; bottom: true; right: true }
    margins { top: 8; bottom: 8; right: 0 }
    implicitWidth: 56
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "brightness"
    focusable: false
    color: "transparent"
    visible: bright.ready

    // Only the rail strip receives pointer/touch input; the rest of
    // the window is click-through.
    mask: Region { item: hitArea }

    // ── Interaction state ───────────────────────────────────────────
    property bool pressed: false
    property bool hovered: hitArea.containsMouse
    property bool recentlyUsed: false
    readonly property bool active: pressed || hovered || recentlyUsed
    readonly property int railWidth: active ? 16 : 5

    readonly property color trackColor: "#1e1e2e"
    readonly property color fillBottom: "#89b4fa"
    readonly property color fillTop: "#b4befe"
    readonly property color textColor: "#cdd6f4"
    readonly property color dimColor: "#6c7086"

    function pctFromY(y) {
        if (trackArea.height <= 0)
            return bright.pct;
        const rel = (y - trackArea.y) / trackArea.height;
        return bright.clampPct((1 - rel) * 100);
    }

    // ── Backlight state + throttled writes ──────────────────────────
    QtObject {
        id: bright

        property string device: ""
        property int maxRaw: 0
        property int raw: 0
        property int pct: 50
        property int want: 50
        property int sent: -1
        property bool ready: false
        property bool synced: false

        function clampPct(v) {
            return Math.max(1, Math.min(100, Math.round(v)));
        }

        function setPct(v, immediate) {
            v = clampPct(v);
            pct = v;
            want = v;
            if (immediate)
                send();
        }

        function nudge(delta) {
            setPct(pct + delta, false);
        }

        function send() {
            if (!ready || !synced)
                return;
            if (writer.running)
                return;
            if (want === sent)
                return;
            sent = want;
            writer.command = [
                "/home/solar/.config/hypr/scripts/brightness.sh",
                "set", String(want), "quiet"
            ];
            writer.running = true;
        }

        function updateFromFile() {
            if (maxRaw <= 0)
                return;
            const value = parseInt(curFile.text());
            if (isNaN(value))
                return;
            raw = value;
            const p = clampPct(value * 100 / maxRaw);
            if (!synced) {
                // First read: adopt the real hardware value instead of
                // pushing the default 50% onto the panel at startup.
                synced = true;
                sent = p;
                if (!win.pressed) {
                    pct = p;
                    want = p;
                }
                return;
            }
            if (win.pressed)
                return;
            pct = p;
        }
    }

    FileView {
        id: maxFile
        path: bright.device.length > 0
              ? "/sys/class/backlight/" + bright.device + "/max_brightness" : ""
        printErrors: false
        onLoaded: {
            const m = parseInt(maxFile.text());
            if (!isNaN(m) && m > 0) {
                bright.maxRaw = m;
                bright.ready = true;
                curFile.reload();
            }
        }
    }

    FileView {
        id: curFile
        path: bright.device.length > 0
              ? "/sys/class/backlight/" + bright.device + "/brightness" : ""
        printErrors: false
        watchChanges: true
        onFileChanged: curFile.reload()
        onLoaded: bright.updateFromFile()
    }

    // Find the first usable backlight device (same rule as brightness.sh).
    Process {
        id: probe
        running: true
        command: [
            "sh", "-c",
            "for d in /sys/class/backlight/*; do " +
            "[ -r \"$d/max_brightness\" ] || continue; " +
            "m=$(cat \"$d/max_brightness\" 2>/dev/null) || continue; " +
            "if [ \"${m:-0}\" -gt 0 ]; then basename \"$d\"; break; fi; done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim();
                if (name.length > 0)
                    bright.device = name;
            }
        }
    }

    Process {
        id: writer
    }

    // Throttle (not debounce): keeps brightness moving with the finger
    // during a continuous drag, ~12 writes/sec while values change.
    Timer {
        id: flushTimer
        interval: 80
        repeat: true
        running: true
        onTriggered: bright.send()
    }

    // Keep the rail in sync when brightness is changed elsewhere
    // (XF86 keys, other scripts). Very cheap sysfs reads.
    Timer {
        interval: 500
        repeat: true
        running: bright.ready && !win.pressed
        onTriggered: curFile.reload()
    }

    Timer {
        id: idleTimer
        interval: 1500
        onTriggered: win.recentlyUsed = false
    }

    // ── Rail visuals ────────────────────────────────────────────────
    Item {
        id: trackArea
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        width: win.railWidth

        Behavior on width {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: trackBg
            anchors.fill: parent
            radius: width / 2
            color: win.trackColor
            opacity: win.active ? 0.85 : 0.55
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Behavior on opacity { NumberAnimation { duration: 140 } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bright.ready
                        ? Math.max(0, parent.height * bright.pct / 100) : 0
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: win.fillTop }
                    GradientStop { position: 1.0; color: win.fillBottom }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: win.pressed ? 0 : 110
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }

        Rectangle {
            id: knob
            width: win.active ? 12 : 0
            height: width
            radius: width / 2
            x: (parent.width - width) / 2
            y: Math.max(0, Math.min(parent.height - height,
                    parent.height * (1 - bright.pct / 100) - height / 2))
            color: win.textColor
            opacity: win.active ? 1 : 0
            visible: bright.ready

            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on y { NumberAnimation { duration: 80 } }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.top: parent.top
        width: trackArea.width
        horizontalAlignment: Text.AlignHCenter
        text: "☀"
        font.pixelSize: 11
        color: win.active ? win.fillTop : win.dimColor

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.bottom: parent.bottom
        width: trackArea.width
        horizontalAlignment: Text.AlignHCenter
        text: "☾"
        font.pixelSize: 11
        color: win.active ? win.textColor : win.dimColor

        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Rectangle {
        id: label
        anchors.right: trackArea.left
        anchors.rightMargin: 6
        y: Math.max(0, Math.min(win.height - height,
                trackArea.y + trackArea.height * (1 - bright.pct / 100)
                - height / 2))
        width: labelText.implicitWidth + 12
        height: labelText.implicitHeight + 8
        radius: height / 2
        color: win.trackColor
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        opacity: win.active ? 0.95 : 0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: 140 } }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: bright.ready ? bright.pct + "%" : "--"
            color: win.textColor
            font.pixelSize: 11
            font.bold: true
        }
    }

    // ── Input: touch, pen, touchpad and mouse ───────────────────────
    MouseArea {
        id: hitArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: win.pressed ? win.width : 22
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        onPressed: function(mouse) {
            win.pressed = true;
            win.recentlyUsed = true;
            idleTimer.stop();
            bright.setPct(win.pctFromY(mouse.y), false);
        }

        onPositionChanged: function(mouse) {
            if (pressed)
                bright.setPct(win.pctFromY(mouse.y), false);
        }

        onReleased: {
            win.pressed = false;
            idleTimer.restart();
            bright.setPct(bright.pct, true);
        }

        onCanceled: {
            win.pressed = false;
            idleTimer.restart();
            bright.setPct(bright.pct, true);
        }

        onWheel: function(wheel) {
            win.recentlyUsed = true;
            idleTimer.restart();
            bright.nudge(wheel.angleDelta.y > 0 ? 3 : -3);
        }
    }
}
