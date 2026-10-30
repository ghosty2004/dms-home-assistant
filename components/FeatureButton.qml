import QtQuick
import qs.Common
import qs.DCommon.Widgets

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color accent: Theme.primary
    property bool highlighted: false
    property var tooltip: null

    signal clicked

    implicitHeight: 40
    implicitWidth: Math.max(implicitHeight, content.implicitWidth + Theme.spacingM * 2)
    radius: Math.min(height / 2.8, Theme.cornerRadiusL)
    color: highlighted ? accent : Theme.withAlpha(accent, enabled ? 0.18 : 0.06)
    opacity: enabled ? 1 : 0.5

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        MdiIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            icon: root.icon
            size: Theme.iconSizeSmall + 4
            color: root.highlighted ? Theme.background : Theme.surfaceText
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: root.highlighted ? Theme.background : Theme.surfaceText
        }
    }

    StateLayer {
        anchors.fill: parent
        enabled: root.enabled
        stateColor: root.highlighted ? Theme.background : Theme.surfaceText
        tooltipText: root.tooltip
        onClicked: root.clicked()
    }
}
