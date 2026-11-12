import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Slide-over history panel, anchored to the right edge of the monitor
// that is focused when it opens.
//
// The surface itself is full-screen (transparent) so that a click
// anywhere outside the card closes the panel — Hyprland does not do
// that for layer surfaces, and HyprlandFocusGrab proved unreliable
// here (it fired `cleared` on its own and closed the panel).
PanelWindow {
    id: panel

    property NotificationServer server
    property bool dnd: false
    property var arrivals: ({})

    // Bumped on a timer so relative timestamps refresh.
    property double now: Date.now()

    signal opened()
    signal dndToggled()

    property bool shown: false
    property string targetName: ""

    readonly property bool big: targetName.startsWith("DP")
    readonly property real s: big ? 1.35 : 1.0

    readonly property var targetScreen:
        Quickshell.screens.find(sc => sc.name === panel.targetName)
        ?? Quickshell.screens[0]
        ?? null

    // Newest first.
    readonly property var items: panel.server.trackedNotifications.values.slice().reverse()

    // Never grow past 76% of the monitor, scroll instead.
    readonly property real listCap:
        ((targetScreen ? targetScreen.height : 1080) * 0.76) - 74 * s

    screen: targetScreen
    visible: shown

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: 0
    aboveWindows: true
    color: "transparent"
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notif-centre"
    WlrLayershell.keyboardFocus: panel.shown ? WlrKeyboardFocus.Exclusive
                                             : WlrKeyboardFocus.None

    function openPanel() {
        if (panel.shown)
            return;
        panel.targetName = Hyprland.focusedMonitor?.name ?? panel.targetName;
        panel.now = Date.now();
        panel.shown = true;
        panel.opened();
    }

    function closePanel() {
        panel.shown = false;
    }

    function toggle() {
        if (panel.shown)
            panel.closePanel();
        else
            panel.openPanel();
    }

    function clearAll() {
        const all = panel.server.trackedNotifications.values.slice();
        for (let i = 0; i < all.length; i++)
            all[i].dismiss();
    }

    // Refresh "4m" -> "5m" while the panel is open.
    Timer {
        interval: 30000
        repeat: true
        running: panel.shown
        onTriggered: panel.now = Date.now()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: panel.closePanel()

        // Backdrop: any click that doesn't land on the card closes.
        MouseArea {
            anchors.fill: parent
            onClicked: panel.closePanel()
        }

        Rectangle {
            id: card

            readonly property real pad: 16 * panel.s

            anchors {
                top: parent.top
                right: parent.right
                topMargin: panel.big ? 16 : 56
                rightMargin: panel.big ? 120 : 8
            }
            width: 430 * panel.s
            height: header.height + list.height + card.pad * 2 + 14 * panel.s

            radius: 16 * panel.s
            color: Qt.rgba(0.117, 0.117, 0.180, 0.97)   // base @ 97%
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            // Swallow clicks on the card itself (children above still win).
            MouseArea { anchors.fill: parent }

            // ── header ─────────────────────────────────────────────
            Item {
                id: header
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: card.pad
                    rightMargin: card.pad
                    topMargin: card.pad
                }
                height: 26 * panel.s

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Notifications"
                    color: "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14 * panel.s
                    font.bold: true
                }

                // DND pill
                Rectangle {
                    id: dndPill
                    anchors { right: clearButton.left; rightMargin: 12 * panel.s; verticalCenter: parent.verticalCenter }
                    width: dndLabel.implicitWidth + 16 * panel.s
                    height: 22 * panel.s
                    radius: height / 2
                    color: panel.dnd
                           ? Qt.rgba(0.706, 0.745, 0.996, 0.85)
                           : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: panel.dnd
                                  ? "transparent"
                                  : Qt.rgba(1, 1, 1, 0.10)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: dndLabel
                        anchors.centerIn: parent
                        text: "DND"
                        color: panel.dnd ? "#1e1e2e" : "#a6adc8"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10 * panel.s
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.dndToggled()
                    }
                }

                // Clear all
                Text {
                    id: clearButton
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "Clear"
                    color: clearArea.containsMouse ? "#f38ba8" : "#7f849c"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10 * panel.s

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6 * panel.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.clearAll()
                    }
                }
            }

            // ── history ────────────────────────────────────────────
            ListView {
                id: list
                anchors {
                    left: parent.left
                    right: parent.right
                    top: header.bottom
                    leftMargin: 12 * panel.s
                    rightMargin: 12 * panel.s
                    topMargin: 14 * panel.s
                }
                height: Math.max(24 * panel.s, Math.min(contentHeight, panel.listCap))
                spacing: 8 * panel.s
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: panel.items

                delegate: NotifRow {
                    required property var modelData

                    notification: modelData
                    stamp: panel.arrivals[modelData.id] !== undefined ? panel.arrivals[modelData.id] : 0
                    now: panel.now
                    scaleFactor: panel.s
                }

                Text {
                    anchors.centerIn: parent
                    text: "You're all caught up"
                    visible: list.count === 0
                    color: "#6c7086"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11 * panel.s
                }
            }
        }
    }
}
