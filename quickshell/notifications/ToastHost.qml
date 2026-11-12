import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Popup stack for new notifications, shown on the monitor that was
// focused when the notification arrived.
//
// The 4K monitors have a 96px vertical waybar on the right edge, the
// laptop has a 40px horizontal bar, so the margins differ per screen.
PanelWindow {
    id: host

    // [{ n: Notification, until: number }] — until 0 means sticky.
    property var queue: []

    // Hidden while the history centre is open (it sits in the same place).
    property bool suspended: false

    readonly property bool big: targetName.startsWith("DP")
    readonly property real s: big ? 1.45 : 1.0

    property string targetName: ""

    readonly property var targetScreen:
        Quickshell.screens.find(sc => sc.name === host.targetName)
        ?? Quickshell.screens[0]
        ?? null

    screen: targetScreen

    anchors {
        top: true
        right: true
    }
    margins {
        top: host.big ? 16 : 56
        right: host.big ? 120 : 8
    }

    implicitWidth: 400 * host.s
    implicitHeight: column.implicitHeight

    exclusiveZone: 0
    aboveWindows: true
    color: "transparent"
    visible: host.queue.length > 0 && !host.suspended
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notif-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the cards themselves should catch pointer input.
    mask: Region { item: column }

    // Prune expired toasts. Deadlines live here (not in the cards) so a
    // re-render caused by a new notification does not restart timers.
    Timer {
        interval: 200
        repeat: true
        running: host.queue.length > 0
        onTriggered: {
            const now = Date.now();
            const keep = host.queue.filter(e => e.n !== null
                && (e.until === 0 || e.until > now));
            if (keep.length !== host.queue.length)
                host.queue = keep;
        }
    }

    function push(n) {
        // Critical notifications and anything with actions stay until
        // explicitly dismissed.
        const sticky = n.urgency === 2 || n.actions.length > 0;
        const secs = n.expireTimeout > 0 ? n.expireTimeout : 5;
        const timeout = Math.min(Math.max(secs * 1000, 3000), 9000);

        host.targetName = Hyprland.focusedMonitor?.name ?? host.targetName;

        const entry = { n: n, until: sticky ? 0 : Date.now() + timeout };
        host.queue = [entry, ...host.queue].slice(0, 3);

        // If it gets dismissed from the centre (or expires) while the
        // popup is still up, drop the popup too.
        n.closed.connect(function() { host.dismiss(n); });
    }

    function dismiss(n) {
        host.queue = host.queue.filter(e => e.n !== n);
    }

    Column {
        id: column
        width: parent.width
        spacing: 8 * host.s

        Repeater {
            model: host.queue

            delegate: Toast {
                required property var modelData

                width: column.width
                notification: modelData.n
                scaleFactor: host.s
                onDismissed: host.dismiss(modelData.n)
            }
        }
    }
}
