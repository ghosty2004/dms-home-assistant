pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."
import "../components"

// Lights / Climate / Security / Media / Automations pages, like the HA built-in dashboards.
DFlickable {
    id: root

    property string category: "lights"

    signal moreInfo(string entityId)

    contentWidth: width
    contentHeight: column.implicitHeight + Theme.spacingL
    clip: true

    readonly property var ids: {
        Ha.index;
        return Ha.categoryIds(category);
    }
    readonly property var cameras: category === "security" ? ids.filter(id => Ha.domainOf(id) === "camera") : []
    readonly property var players: category === "media" ? ids : []
    readonly property var tileIds: ids.filter(id => !cameras.includes(id) && !players.includes(id))
    readonly property int onCount: {
        HaService.stateRev;
        return category === "lights" ? ids.filter(id => HaService.states[id]?.state === "on").length : 0;
    }

    readonly property var sections: {
        if (category === "automations") {
            const by = d => tileIds.filter(id => Ha.domainOf(id) === d);
            return [
                {
                    title: "Scenes",
                    icon: "mdi:palette",
                    ids: by("scene")
                },
                {
                    title: "Scripts",
                    icon: "mdi:script-text",
                    ids: by("script")
                },
                {
                    title: "Automations",
                    icon: "mdi:robot",
                    ids: by("automation")
                }
            ].filter(s => s.ids.length > 0);
        }
        if (category === "climate") {
            const devices = tileIds.filter(id => Ha.domainOf(id) !== "sensor");
            const sensors = tileIds.filter(id => Ha.domainOf(id) === "sensor");
            const out = [];
            if (devices.length)
                out.push({
                    title: "Thermostats & devices",
                    icon: "mdi:thermostat",
                    ids: devices
                });
            return out.concat(Ha.groupByArea(sensors).map(s => Object.assign({}, s, {
                    title: s.title + " · sensors",
                    stripPrefixes: [s.title]
                })));
        }
        return Ha.groupByArea(tileIds).map(s => {
            const extra = {
                stripPrefixes: [s.title]
            };
            if (category === "lights") {
                extra.actionIcon = "mdi:lightbulb-off-outline";
                extra.actionText = "Off";
            }
            return Object.assign({}, s, extra);
        });
    }

    Column {
        id: column
        width: root.width
        spacing: Theme.spacingL

        // Lights summary bar
        Rectangle {
            visible: root.category === "lights" && root.ids.length > 0
            width: parent.width
            height: 56
            radius: Theme.cornerRadiusL
            color: root.onCount > 0 ? Theme.blend(DashMetrics.cardColor, Ha.palette.amber, 0.1) : DashMetrics.cardColor

            IconBubble {
                id: allBubble
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                icon: root.onCount > 0 ? "mdi:lightbulb-group" : "mdi:lightbulb-group-off"
                accent: Ha.palette.amber
                active: root.onCount > 0
            }
            StyledText {
                anchors.left: allBubble.right
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                text: root.onCount > 0 ? root.onCount + " of " + root.ids.length + " lights on" : "All lights are off"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }
            FeatureButton {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 40
                icon: "mdi:power"
                text: "Turn all off"
                accent: Ha.palette.amber
                enabled: root.onCount > 0
                onClicked: HaService.callService("light", "turn_off", {}, {
                    entity_id: root.ids.filter(id => HaService.states[id]?.state === "on")
                })
            }
        }

        // Cameras
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.cameras.length > 0

            SectionHeader {
                icon: "mdi:cctv"
                title: "Cameras"
                subtitle: root.cameras.length + ""
            }

            Grid {
                id: camGrid
                width: parent.width
                columns: width > 560 ? 2 : 1
                columnSpacing: Theme.spacingS
                rowSpacing: Theme.spacingS

                Repeater {
                    model: root.cameras

                    CameraCard {
                        required property var modelData
                        width: (camGrid.width - camGrid.columnSpacing * (camGrid.columns - 1)) / camGrid.columns
                        height: implicitHeight
                        entityId: modelData
                        live: root.visible
                        onMoreInfo: id => root.moreInfo(id)
                    }
                }
            }
        }

        // Media players
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.players.length > 0

            Repeater {
                model: root.players

                MediaCard {
                    required property var modelData
                    width: column.width
                    entityId: modelData
                    onMoreInfo: id => root.moreInfo(id)
                }
            }
        }

        SectionList {
            width: parent.width
            sections: root.sections
            onMoreInfo: id => root.moreInfo(id)
            onSectionAction: section => {
                if (root.category === "lights")
                    HaService.callService("light", "turn_off", {}, {
                        entity_id: section.ids
                    });
            }
        }

        Column {
            visible: root.ids.length === 0
            width: parent.width
            spacing: Theme.spacingM
            topPadding: 60

            MdiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: "mdi:magnify-close"
                size: 44
                color: Theme.surfaceVariantText
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing here yet"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
        }
    }
}
