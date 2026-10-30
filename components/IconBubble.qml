import QtQuick
import qs.Common
import qs.DCommon.Widgets

// The round, state tinted icon container of a HA tile.
Rectangle {
    id: root

    property string icon: ""
    property color accent: Theme.primary
    property bool active: false
    property bool dimmed: false
    property bool clickable: false
    property real iconSize: Math.round(width * 0.56)
    property var tooltip: null

    signal clicked

    implicitWidth: 40
    implicitHeight: implicitWidth
    radius: width / 2
    color: dimmed ? Theme.withAlpha(Theme.surfaceText, 0.05) : active ? Theme.withAlpha(accent, 0.22) : Theme.withAlpha(Theme.surfaceText, 0.08)

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
        }
    }

    MdiIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        color: root.dimmed ? Theme.withAlpha(Theme.surfaceText, 0.35) : root.active ? root.accent : Theme.withAlpha(Theme.surfaceText, 0.75)
    }

    StateLayer {
        anchors.fill: parent
        visible: root.clickable
        enabled: root.clickable
        cornerRadius: root.radius
        stateColor: root.active ? root.accent : Theme.surfaceText
        tooltipText: root.tooltip
        onClicked: root.clicked()
    }
}
