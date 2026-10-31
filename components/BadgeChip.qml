import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash

// HA "badge": a pill with an icon, optional label and value.
Rectangle {
    id: root

    property string icon: ""
    property string image: ""
    property string label: ""
    property string value: ""
    property color accent: Theme.primary
    property bool clickable: true

    signal clicked

    implicitHeight: Math.max(36, textCol.implicitHeight + Theme.spacingS * 2)
    implicitWidth: row.implicitWidth + Theme.spacingS + Theme.spacingM
    radius: height / 2
    color: DashMetrics.cardColor
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, 0.18)

    Row {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingXS + 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: Theme.withAlpha(root.accent, 0.2)
            clip: true

            MdiIcon {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                icon: root.icon
                size: 17
                color: root.accent
            }

            Image {
                id: avatar
                anchors.fill: parent
                visible: status === Image.Ready
                source: root.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(56, 56)
                layer.enabled: true
            }
        }

        Column {
            id: textCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                visible: root.label !== ""
                text: root.label
                font.pixelSize: Theme.fontSizeSmall - 2
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceVariantText
            }

            StyledText {
                text: root.value
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }
        }
    }

    StateLayer {
        anchors.fill: parent
        visible: root.clickable
        cornerRadius: root.radius
        onClicked: root.clicked()
    }
}
