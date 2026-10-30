import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string actionIcon: ""
    property string actionText: ""

    signal actionClicked

    width: parent?.width ?? 0
    implicitHeight: Math.max(Theme.buttonHeightXS, row.implicitHeight) + Theme.spacingXS

    Row {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        MdiIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: Theme.iconSizeSmall + 2
            color: Theme.surfaceVariantText
            visible: root.icon !== ""
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.subtitle
            visible: text !== ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    Rectangle {
        id: action
        visible: root.actionText !== "" || root.actionIcon !== ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.buttonHeightXS
        width: actionRow.implicitWidth + Theme.spacingM * 2
        radius: height / 2
        color: Theme.withAlpha(Theme.primary, 0.14)

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            MdiIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.actionIcon
                visible: root.actionIcon !== ""
                size: Theme.iconSizeSmall
                color: Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.actionText
                visible: text !== ""
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.primary
            }
        }

        StateLayer {
            anchors.fill: parent
            stateColor: Theme.primary
            onClicked: root.actionClicked()
        }
    }
}
