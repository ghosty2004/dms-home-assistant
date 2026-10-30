import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"
import ".."

// HA more-info vertical switch.
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property color accent: Ha.palette.amber
    property string onIcon: "mdi:power"
    property string offIcon: "mdi:power-off"

    signal toggled(bool on)

    implicitWidth: 110
    implicitHeight: 260

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Math.min(width / 2.8, Theme.cornerRadiusXL)
        color: Theme.withAlpha(root.checked ? root.accent : Theme.surfaceText, root.enabled ? 0.16 : 0.06)

        Rectangle {
            id: thumb
            x: 6
            width: parent.width - 12
            height: parent.height / 2 - 6
            y: root.checked ? 6 : parent.height / 2
            radius: parent.radius - 4
            color: root.enabled ? (root.checked ? root.accent : Theme.withAlpha(Theme.surfaceText, 0.35)) : Theme.withAlpha(Theme.surfaceText, 0.12)

            Behavior on y {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.8
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                }
            }
        }

        MdiIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 4 - height / 2 + 3
            icon: root.onIcon
            size: 30
            color: root.checked ? Ha.onAccent(root.accent) : Theme.surfaceVariantText
        }
        MdiIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 3 / 4 - height / 2 - 3
            icon: root.offIcon
            size: 30
            color: root.checked ? Theme.surfaceVariantText : Theme.surfaceText
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.toggled(mouse.y < height / 2)
    }
}
