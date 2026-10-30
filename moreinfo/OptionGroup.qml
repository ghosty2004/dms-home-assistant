pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"

// Titled group of selectable chips (HVAC modes, presets, effects, select options).
Column {
    id: root

    property string title: ""
    property string icon: ""
    property var options: []     // [{value, label, icon}]
    property var current: null
    property color accent: Theme.primary

    signal picked(var value)

    spacing: Theme.spacingS
    visible: options.length > 0

    Row {
        spacing: 6
        visible: root.title !== ""

        MdiIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            icon: root.icon
            size: 16
            color: Theme.surfaceVariantText
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceVariantText
        }
    }

    Flow {
        width: root.width
        spacing: Theme.spacingS

        Repeater {
            model: root.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool selected: root.current === modelData.value

                height: 36
                width: optRow.implicitWidth + 24
                radius: Theme.cornerRadiusM
                color: selected ? root.accent : Theme.withAlpha(Theme.surfaceText, 0.07)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }

                Row {
                    id: optRow
                    anchors.centerIn: parent
                    spacing: 6

                    MdiIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!opt.modelData.icon
                        icon: opt.modelData.icon ?? ""
                        size: 18
                        color: opt.selected ? "#ffffff" : Theme.surfaceText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: opt.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: opt.selected ? "#ffffff" : Theme.surfaceText
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    cornerRadius: opt.radius
                    stateColor: opt.selected ? "#ffffff" : Theme.surfaceText
                    onClicked: root.picked(opt.modelData.value)
                }
            }
        }
    }
}
