pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Material 3 navigation rail, like the HA sidebar.
Item {
    id: root

    property var model: []
    property string current: ""

    signal selected(string id)

    implicitWidth: 76

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Repeater {
            model: root.model

            Item {
                id: navItem
                required property var modelData
                readonly property bool isCurrent: root.current === modelData.id

                width: root.width
                height: 58

                Rectangle {
                    id: pill
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: navItem.isCurrent ? 56 : 40
                    height: 30
                    radius: height / 2
                    color: navItem.isCurrent ? Theme.secondaryContainer : "transparent"

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    MdiIcon {
                        anchors.centerIn: parent
                        icon: navItem.modelData.icon
                        size: 22
                        color: navItem.isCurrent ? Theme.onSecondaryContainer : Theme.surfaceVariantText
                    }

                    Rectangle {
                        visible: (navItem.modelData.badge ?? 0) > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: navItem.isCurrent ? 4 : -2
                        anchors.topMargin: -2
                        width: Math.max(16, badgeText.implicitWidth + 8)
                        height: 16
                        radius: 8
                        color: Theme.error

                        StyledText {
                            id: badgeText
                            anchors.centerIn: parent
                            text: navItem.modelData.badge ?? ""
                            font.pixelSize: 10
                            font.weight: Theme.fontWeightBold
                            color: Theme.onError
                        }
                    }
                }

                StyledText {
                    anchors.top: pill.bottom
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 4
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    text: navItem.modelData.label
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: navItem.isCurrent ? Theme.fontWeightBold : Theme.fontWeightMedium
                    color: navItem.isCurrent ? Theme.surfaceText : Theme.surfaceVariantText
                }

                StateLayer {
                    anchors.fill: pill
                    cornerRadius: pill.radius
                    onClicked: root.selected(navItem.modelData.id)
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: root.selected(navItem.modelData.id)
                }
            }
        }
    }
}
