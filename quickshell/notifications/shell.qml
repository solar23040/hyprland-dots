import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon + popups + history centre for Hyprland.
//
//   qs -d -n -c notifications      (started from hyprland.lua)
//   qs ipc -c notifications call notifications toggle
//
// Owning org.freedesktop.Notifications means no dunst / mako / swaync
// should run alongside this.
ShellRoot {
    id: root

    // Unread counter shown in the waybar badge; resets when the centre opens.
    property int unread: 0
    property bool dnd: false

    // Arrival timestamps by notification id (the spec does not expose one).
    property var arrivals: ({})

    readonly property string badgePath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-notif-unread"

    NotificationServer {
        id: server

        // Keep notifications across a config reload.
        keepOnReload: true

        // Advertise what the UI can actually render.
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: function(n) {
            // Tracked notifications make up the history centre.
            n.tracked = true;

            // Notifications re-emitted by keepOnReload are already old:
            // show them in the centre but don't count or toast them again.
            if (n.lastGeneration)
                return;

            const next = Object.assign({}, root.arrivals);
            next[n.id] = Date.now();
            root.arrivals = next;

            root.unread += 1;
            if (!root.dnd)
                toasts.push(n);
        }
    }

    ToastHost {
        id: toasts
        suspended: centre.shown
    }

    Centre {
        id: centre
        server: server
        dnd: root.dnd
        arrivals: root.arrivals
        onDndToggled: root.dnd = !root.dnd
        onOpened: root.unread = 0
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void { centre.toggle() }
        function open(): void { centre.openPanel() }
        function close(): void { centre.closePanel() }
        function dnd(): void { root.dnd = !root.dnd }
        function unread(): string { return String(root.unread) }
        function count(): string { return String(server.trackedNotifications.values.length) }
        function clear(): void { centre.clearAll() }
    }

    // ── waybar badge ────────────────────────────────────────────────
    // The badge module only renders when the file exists, so an empty
    // file would leave an empty box. Write a count, remove when zero,
    // then nudge waybar (RTMIN+8) so it updates immediately.
    Process {
        id: badgeWriter
    }

    function writeBadge() {
        const text = root.dnd ? "" : (root.unread > 0 ? String(root.unread) : "");
        const script = text === ""
              ? "rm -f " + shellQuote(root.badgePath)
              : "printf '%s' " + shellQuote(text) + " > " + shellQuote(root.badgePath);
        badgeWriter.command = ["sh", "-c",
            script + "; pkill -RTMIN+8 waybar 2>/dev/null || true"];
        badgeWriter.running = true;
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    onUnreadChanged: writeBadge()
    onDndChanged: writeBadge()
    Component.onCompleted: writeBadge()
}
