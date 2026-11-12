import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification in the history list.
Rectangle {
    id: root

    required property var notification
    property double stamp: 0
    property double now: Date.now()
    property real scaleFactor: 1

    readonly property var n: notification
    readonly property Theme theme: Theme {}
    readonly property real pad: 12 * scaleFactor
    readonly property bool critical: n !== null && n.urgency === NotificationUrgency.Critical
    readonly property color accent: theme.urgencyColor(n ? n.urgency : 1)

    width: ListView.view ? ListView.view.width : 0
    implicitHeight: content.implicitHeight + pad * 2
    height: implicitHeight

    radius: 12 * scaleFactor
    color: hover.containsMouse
           ? Qt.rgba(1, 1, 1, 0.06)
           : Qt.rgba(1, 1, 1, 0.025)
    border.width: 1
    border.color: critical
                  ? Qt.rgba(accent.r, accent.g, accent.b, 0.45)
                  : Qt.rgba(1, 1, 1, 0.05)

    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        // Let children (reply field, buttons) take their own events.
        propagateComposedEvents: true
        onClicked: mouse => mouse.accepted = false
    }

    Column {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: root.pad + 4 * root.scaleFactor
            rightMargin: root.pad
            topMargin: root.pad
        }
        spacing: 5 * root.scaleFactor

        // ── header ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 20 * root.scaleFactor

            IconImage {
                id: appIcon
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                implicitSize: 16 * root.scaleFactor
                source: root.theme.appIconSource(root.n ? root.n.appIcon : "")
            }

            Text {
                anchors {
                    left: appIcon.right
                    leftMargin: 8 * root.scaleFactor
                    right: timeText.left
                    rightMargin: 8 * root.scaleFactor
                    verticalCenter: parent.verticalCenter
                }
                text: (root.n ? root.n.appName : "") || "Notification"
                color: root.theme.overlay1
                font.family: root.theme.fontFamily
                font.pixelSize: 11 * root.scaleFactor
                elide: Text.ElideRight
            }

            Text {
                id: timeText
                anchors {
                    right: closeArea.left
                    rightMargin: 8 * root.scaleFactor
                    verticalCenter: parent.verticalCenter
                }
                text: root.theme.ago(root.stamp)
                color: root.theme.overlay0
                font.family: root.theme.fontFamily
                font.pixelSize: 10 * root.scaleFactor
            }

            MouseArea {
                id: closeArea
                width: 20 * root.scaleFactor
                height: parent.height
                anchors.right: parent.right
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: if (root.n) root.n.dismiss();

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeArea.containsMouse ? root.theme.red : root.theme.overlay0
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11 * root.scaleFactor
                }
            }
        }

        // ── summary ────────────────────────────────────────────────
        Text {
            width: parent.width
            text: root.n ? root.n.summary : ""
            visible: text.length > 0
            color: root.theme.text
            font.family: root.theme.fontFamily
            font.pixelSize: 13 * root.scaleFactor
            font.bold: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        // ── body ───────────────────────────────────────────────────
        Text {
            width: parent.width
            text: root.n ? root.n.body : ""
            visible: text.length > 0
            textFormat: Text.RichText
            color: root.theme.subtext0
            font.family: root.theme.fontFamily
            font.pixelSize: 12 * root.scaleFactor
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: 8
            elide: Text.ElideRight
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        // ── optional image ─────────────────────────────────────────
        ClippingRectangle {
            width: parent.width
            height: visible ? 110 * root.scaleFactor : 0
            radius: 8 * root.scaleFactor
            color: root.theme.surface0
            visible: root.n !== null && root.n.image.length > 0

            Image {
                anchors.fill: parent
                source: root.n ? root.n.image : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.height: 110 * root.scaleFactor
            }
        }

        // ── actions ────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 6 * root.scaleFactor
            visible: root.n !== null && root.n.actions.length > 0

            Repeater {
                model: root.n ? root.n.actions : []

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool hovering: actionArea.containsMouse

                    width: actionText.implicitWidth + 18 * root.scaleFactor
                    height: 24 * root.scaleFactor
                    radius: 7 * root.scaleFactor
                    color: hovering
                           ? Qt.rgba(root.theme.lavender.r, root.theme.lavender.g, root.theme.lavender.b, 0.22)
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
                        onClicked: modelData.invoke()
                    }
                }
            }
        }

        // ── inline reply ───────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 30 * root.scaleFactor
            radius: 8 * root.scaleFactor
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: reply.activeFocus ? 1 : 0
            border.color: root.theme.lavender
            visible: root.n !== null && root.n.hasInlineReply

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 10 * root.scaleFactor
                    verticalCenter: parent.verticalCenter
                }
                text: (root.n ? root.n.inlineReplyPlaceholder : "") || "Reply…"
                visible: reply.text.length === 0
                color: root.theme.overlay0
                font.family: root.theme.fontFamily
                font.pixelSize: 12 * root.scaleFactor
            }

            TextInput {
                id: reply
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10 * root.scaleFactor
                    rightMargin: 10 * root.scaleFactor
                }
                color: root.theme.text
                selectionColor: root.theme.lavender
                selectedTextColor: root.theme.base
                font.family: root.theme.fontFamily
                font.pixelSize: 12 * root.scaleFactor
                clip: true
                onAccepted: {
                    if (text.length === 0)
                        return;
                    if (root.n) root.n.sendInlineReply(text);
                    text = "";
                }
            }
        }
    }
}
