pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash

// Horizontally scrolling filter chips with MDI icons.
Flickable {
    id: root

    property var model: []
    property string current: ""

    signal selected(string id)

    height: 36
    contentWidth: row.implicitWidth
    contentHeight: height
    clip: true
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: event => {
            root.contentX = Math.max(0, Math.min(root.contentWidth - root.width, root.contentX - event.angleDelta.y));
        }
    }

    Row {
        id: row
        spacing: Theme.spacingS

        Repeater {
            model: root.model

            Rectangle {
                id: chip
                required property var modelData
                readonly property bool isCurrent: root.current === modelData.id

                height: 34
                width: chipRow.implicitWidth + 24
                radius: Theme.cornerRadiusS + 2
                color: isCurrent ? Theme.secondaryContainer : "transparent"
                border.width: isCurrent ? 0 : 1
                border.color: Theme.withAlpha(Theme.outline, 0.4)

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6

                    MdiIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!chip.modelData.icon
                        icon: chip.modelData.icon ?? ""
                        size: 17
                        color: chip.isCurrent ? Theme.onSecondaryContainer : Theme.surfaceVariantText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: chip.isCurrent ? Theme.onSecondaryContainer : Theme.surfaceText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: chip.modelData.count !== undefined
                        text: chip.modelData.count ?? ""
                        font.pixelSize: 11
                        color: chip.isCurrent ? Theme.withAlpha(Theme.onSecondaryContainer, 0.7) : Theme.surfaceVariantText
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    cornerRadius: chip.radius
                    onClicked: root.selected(chip.modelData.id)
                }
            }
        }
    }
}
