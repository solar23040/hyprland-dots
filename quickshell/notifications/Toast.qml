import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// A single popup card. Expiry is handled by ToastHost so this stays a
// pure view.
Item {
    id: root

    required property var notification
    property real scaleFactor: 1

    signal dismissed()

    readonly property var n: notification
    readonly property Theme theme: Theme {}
    readonly property bool critical: n !== null && n.urgency === NotificationUrgency.Critical
    readonly property color accent: theme.urgencyColor(n ? n.urgency : 1)
    readonly property real pad: 12 * scaleFactor

    implicitHeight: card.implicitHeight
    opacity: 0
    y: -8

    Component.onCompleted: enter.start()

    ParallelAnimation {
        id: enter
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + root.pad * 2

        radius: 14 * root.scaleFactor
        color: Qt.rgba(root.theme.base.r, root.theme.base.g, root.theme.base.b, 0.96)
        border.width: 1
        border.color: root.critical ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                                    : Qt.rgba(1, 1, 1, 0.07)

        // Clicking the card dismisses it. Only the buttons below take
        // precedence over this.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismissed()
        }

        // Urgency accent on the inner edge.
        Rectangle {
            width: 3 * root.scaleFactor
            radius: width / 2
            color: root.accent
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                margins: root.pad * 0.6
            }
        }

        Column {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: root.pad + 6 * root.scaleFactor
                rightMargin: root.pad
                topMargin: root.pad
            }
            spacing: 4 * root.scaleFactor

            // ── app + close ─────────────────────────────────────────
            Item {
                width: parent.width
                height: 22 * root.scaleFactor

                IconImage {
                    id: appIcon
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    implicitSize: 18 * root.scaleFactor
                    source: root.theme.appIconSource(root.n ? root.n.appIcon : "")
                }

                Text {
                    anchors {
                        left: appIcon.right
                        leftMargin: 8 * root.scaleFactor
                        right: closeArea.left
                        rightMargin: 6 * root.scaleFactor
                        verticalCenter: parent.verticalCenter
                    }
                    text: (root.n ? root.n.appName : "") || "Notification"
                    color: root.theme.overlay1
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11 * root.scaleFactor
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: closeArea
                    width: 22 * root.scaleFactor
                    height: parent.height
                    anchors.right: parent.right
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.dismissed()

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeArea.containsMouse ? root.theme.text : root.theme.overlay0
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12 * root.scaleFactor
                    }
                }
            }

            // ── summary ─────────────────────────────────────────────
            Text {
                width: parent.width
                text: root.n ? root.n.summary : ""
                visible: text.length > 0
                color: root.theme.text
                font.family: root.theme.fontFamily
                font.pixelSize: 14 * root.scaleFactor
                font.bold: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            // ── body ────────────────────────────────────────────────
            Text {
                width: parent.width
                text: root.n ? root.n.body : ""
                visible: text.length > 0
                textFormat: Text.RichText
                color: root.theme.subtext0
                font.family: root.theme.fontFamily
                font.pixelSize: 12 * root.scaleFactor
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 5
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // ── actions ─────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 6 * root.scaleFactor
                visible: root.n !== null && root.n.actions.length > 0

                Repeater {
                    model: root.n ? root.n.actions : []

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool hovering: actionArea.containsMouse

                        width: actionText.implicitWidth + 20 * root.scaleFactor
                        height: 26 * root.scaleFactor
                        radius: 8 * root.scaleFactor
                        color: hovering ? Qt.rgba(root.theme.lavender.r, root.theme.lavender.g, root.theme.lavender.b, 0.22)
                                        : Qt.rgba(1, 1, 1, 0.06)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: modelData.text
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: 11 * root.scaleFactor
                            font.bold: true
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.invoke();
                                root.dismissed();
                            }
                        }
                    }
                }
            }
        }
    }
}
