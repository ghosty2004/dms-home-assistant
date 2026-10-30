pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DDash
import "components"

// Overview card: favorites as quick toggles, opens the Home tab on click.
DashCardComponent {
    id: root

    clickable: true

    readonly property var ids: {
        Ha.index;
        const fav = HaService.favorites.filter(id => HaService.states[id] !== undefined);
        if (fav.length)
            return fav;
        // No favorites yet: show lights and climate devices.
        return Ha.index.all.filter(id => ["light", "climate", "switch", "media_player"].includes(Ha.domainOf(id)) && HaService.states[id]?.state !== "unavailable").slice(0, 12);
    }
    readonly property bool tiny: height < 120
    readonly property int lightsOn: {
        HaService.stateRev;
        return Ha.index.all.filter(id => Ha.domainOf(id) === "light" && HaService.states[id]?.state === "on").length;
    }

    Item {
        anchors.fill: parent

        Row {
            id: head
            visible: !root.tiny
            spacing: Theme.spacingS
            height: 28

            MdiIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "mdi:home-assistant"
                size: 22
                color: Ha.palette.lightBlue
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: HaService.haConfig?.location_name || "Home"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightBold
                color: root.contentColor
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: !HaService.connected ? "· offline" : root.lightsOn > 0 ? "· " + root.lightsOn + " lights on" : ""
                font.pixelSize: Theme.fontSizeSmall
                color: root.mutedColor
            }
        }

        // tiny: a row of icon toggles
        Row {
            visible: root.tiny
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            Repeater {
                model: root.tiny ? root.ids.slice(0, Math.max(1, Math.floor((root.width - 16) / 52))) : []

                IconBubble {
                    id: tb
                    required property var modelData
                    property var st: HaService.get(modelData)
                    width: 44
                    icon: Ha.iconName(modelData, st)
                    accent: Ha.stateColor(modelData, st)
                    active: Ha.isActive(modelData, st)
                    dimmed: !st || st.state === "unavailable"
                    clickable: !dimmed
                    tooltip: Ha.entityName(modelData, st) + " · " + Ha.stateText(modelData, st)
                    onClicked: Ha.canToggle(modelData) ? Ha.toggle(modelData) : root.clicked()

                    Connections {
                        target: HaService
                        function onEntityUpdated(id) {
                            if (id === tb.modelData)
                                tb.st = HaService.get(id);
                        }
                    }
                }
            }
        }

        // regular: mini tiles
        Grid {
            id: grid
            visible: !root.tiny
            anchors.top: head.bottom
            anchors.topMargin: Theme.spacingS
            width: parent.width
            columns: Math.max(1, Math.floor((width + spacing) / (170 + spacing)))
            spacing: Theme.spacingS
            readonly property real cellW: (width - spacing * (columns - 1)) / columns
            readonly property int rows: Math.max(1, Math.floor((root.height - root.pad * 2 - 36 + spacing) / (52 + spacing)))

            Repeater {
                model: root.tiny ? [] : root.ids.slice(0, grid.columns * grid.rows)

                Rectangle {
                    id: mini
                    required property var modelData
                    property var st: HaService.get(modelData)
                    readonly property bool active: Ha.isActive(modelData, st)
                    readonly property color accent: Ha.stateColor(modelData, st)
                    width: grid.cellW
                    height: 52
                    radius: Theme.cornerRadiusM
                    color: active ? Theme.blend(root.chipColor, accent, 0.12) : root.chipColor

                    Connections {
                        target: HaService
                        function onEntityUpdated(id) {
                            if (id === mini.modelData)
                                mini.st = HaService.get(id);
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        cornerRadius: mini.radius
                        onClicked: root.clicked()
                    }

                    IconBubble {
                        id: mb
                        x: 7
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        icon: Ha.iconName(mini.modelData, mini.st)
                        accent: mini.accent
                        active: mini.active
                        dimmed: !mini.st || mini.st.state === "unavailable"
                        clickable: !dimmed && Ha.canToggle(mini.modelData)
                        onClicked: Ha.toggle(mini.modelData)
                    }
                    Column {
                        anchors.left: mb.right
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            width: parent.width
                            text: Ha.entityName(mini.modelData, mini.st)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightMedium
                            color: root.contentColor
                        }
                        StyledText {
                            width: parent.width
                            text: Ha.secondaryText(mini.modelData, mini.st)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: root.mutedColor
                        }
                    }
                }
            }
        }
    }
}
