pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."
import "../components"

DFlickable {
    id: root

    signal moreInfo(string entityId)
    signal navigate(string page, string arg)

    contentWidth: width
    contentHeight: column.implicitHeight + Theme.spacingL
    clip: true

    readonly property var all: Ha.index.all
    readonly property var persons: all.filter(id => Ha.domainOf(id) === "person")
    readonly property var climates: Ha.visibleFilter(all.filter(id => Ha.domainOf(id) === "climate" || Ha.domainOf(id) === "water_heater"))
    readonly property var lights: all.filter(id => Ha.domainOf(id) === "light")
    readonly property var playing: {
        HaService.stateRev;
        return all.filter(id => Ha.domainOf(id) === "media_player" && ["playing", "paused"].includes(HaService.states[id]?.state));
    }
    readonly property int lightsOn: {
        HaService.stateRev;
        return lights.filter(id => HaService.states[id]?.state === "on").length;
    }
    readonly property var openings: {
        HaService.stateRev;
        return all.filter(id => Ha.domainOf(id) === "binary_sensor" && ["door", "window", "garage_door", "opening"].includes(HaService.states[id]?.attributes?.device_class) && HaService.states[id]?.state === "on");
    }
    readonly property var updates: {
        HaService.stateRev;
        const out = [];
        for (const id in HaService.states) {
            if (Ha.domainOf(id) === "update" && HaService.states[id].state === "on" && !Ha.isHiddenEntity(id))
                out.push(id);
        }
        return out;
    }
    readonly property var weatherId: {
        HaService.setRev;
        for (const id in HaService.states) {
            if (Ha.domainOf(id) === "weather")
                return id;
        }
        return "";
    }
    readonly property var notificationList: Object.values(HaService.notifications).sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))

    function greeting() {
        const h = new Date().getHours();
        const who = HaService.currentUser?.name ? ", " + HaService.currentUser.name : "";
        if (h < 5)
            return "Good night" + who;
        if (h < 12)
            return "Good morning" + who;
        if (h < 18)
            return "Good afternoon" + who;
        return "Good evening" + who;
    }

    Column {
        id: column
        width: root.width
        spacing: Theme.spacingL

        // ------------------------------------------------ hero + badges
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Column {
                spacing: 2

                StyledText {
                    text: (HaService.haConfig?.location_name || "Home") + (HaService.haConfig?.version ? " · Home Assistant " + HaService.haConfig.version : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: root.persons

                    BadgeChip {
                        id: personChip
                        required property var modelData
                        readonly property var st: {
                            HaService.stateRev;
                            return HaService.states[modelData];
                        }
                        icon: Ha.iconName(modelData, st)
                        image: st?.attributes?.entity_picture ? HaService.mediaUrl(st.attributes.entity_picture) : ""
                        label: Ha.entityName(modelData, st)
                        value: Ha.stateText(modelData, st)
                        accent: Ha.stateColor(modelData, st)
                        onClicked: root.moreInfo(modelData)
                    }
                }

                BadgeChip {
                    visible: root.weatherId !== ""
                    readonly property var st: {
                        HaService.stateRev;
                        return HaService.states[root.weatherId];
                    }
                    icon: Ha.iconName(root.weatherId, st)
                    label: Ha.stateText(root.weatherId, st)
                    value: st?.attributes?.temperature !== undefined ? Ha.withUnit(Ha.formatNumber(st.attributes.temperature), st.attributes.temperature_unit ?? Ha.temperatureUnit()) : ""
                    accent: Ha.palette.amber
                    onClicked: root.moreInfo(root.weatherId)
                }

                BadgeChip {
                    visible: root.lights.length > 0
                    icon: root.lightsOn > 0 ? "mdi:lightbulb-group" : "mdi:lightbulb-group-off"
                    label: "Lights"
                    value: root.lightsOn > 0 ? root.lightsOn + " on" : "All off"
                    accent: root.lightsOn > 0 ? Ha.palette.amber : Theme.surfaceVariantText
                    onClicked: root.navigate("lights", "")
                }

                Repeater {
                    model: root.climates

                    BadgeChip {
                        required property var modelData
                        readonly property var st: {
                            HaService.stateRev;
                            return HaService.states[modelData];
                        }
                        icon: Ha.iconName(modelData, st)
                        label: Ha.entityName(modelData, st)
                        value: st?.attributes?.current_temperature !== undefined && st?.attributes?.current_temperature !== null ? Ha.withUnit(Ha.formatNumber(st.attributes.current_temperature), Ha.temperatureUnit()) : Ha.stateText(modelData, st)
                        accent: Ha.stateColor(modelData, st)
                        onClicked: root.moreInfo(modelData)
                    }
                }

                BadgeChip {
                    visible: root.openings.length > 0
                    icon: "mdi:door-open"
                    label: "Open"
                    value: root.openings.length + (root.openings.length === 1 ? " opening" : " openings")
                    accent: Ha.palette.amber
                    onClicked: root.navigate("security", "")
                }

                BadgeChip {
                    visible: root.updates.length > 0
                    icon: "mdi:package-up"
                    label: "Updates"
                    value: root.updates.length + " available"
                    accent: Ha.palette.orange
                    onClicked: root.navigate("entities", "update")
                }
            }
        }

        // ------------------------------------------------ notifications
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.notificationList.length > 0

            SectionHeader {
                icon: "mdi:bell"
                title: "Notifications"
                subtitle: root.notificationList.length + ""
            }

            Repeater {
                model: root.notificationList

                Rectangle {
                    id: note
                    required property var modelData
                    width: column.width
                    height: noteCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadiusL
                    color: DashMetrics.cardColor

                    Rectangle {
                        width: 4
                        height: parent.height - Theme.spacingM * 2
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 2
                        color: Theme.primary
                    }

                    Column {
                        id: noteCol
                        anchors.left: parent.left
                        anchors.right: dismiss.left
                        anchors.leftMargin: Theme.spacingL
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            width: parent.width
                            text: note.modelData.title || "Notification"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Theme.fontWeightMedium
                            color: Theme.surfaceText
                            wrapMode: Text.Wrap
                        }
                        StyledText {
                            width: parent.width
                            // drop inline images (e.g. HomeKit pairing QR codes)
                            text: String(note.modelData.message || "").replace(/!\[[^\]]*\]\([^)]*\)/g, "").replace(/<img[^>]*>/gi, "").trim()
                            textFormat: Text.MarkdownText
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            onLinkActivated: link => Qt.openUrlExternally(link.startsWith("/") ? HaService.baseUrl + link : link)
                        }
                        StyledText {
                            text: Ha.relativeTime(Date.parse(note.modelData.created_at))
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.8)
                        }
                    }

                    FeatureButton {
                        id: dismiss
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        icon: "mdi:close"
                        tooltip: "Dismiss"
                        onClicked: HaService.dismissNotification(note.modelData.notification_id)
                    }
                }
            }
        }

        // ------------------------------------------------ favorites
        Column {
            width: parent.width
            spacing: Theme.spacingS

            SectionHeader {
                icon: "mdi:star"
                title: "Favorites"
                subtitle: HaService.favorites.length > 0 ? HaService.favorites.length + "" : ""
            }

            TileGrid {
                width: parent.width
                visible: HaService.favorites.length > 0
                ids: HaService.favorites.filter(id => HaService.states[id] !== undefined || !HaService.statesLoaded)
                onMoreInfo: id => root.moreInfo(id)
            }

            Rectangle {
                visible: HaService.favorites.length === 0
                width: parent.width
                height: 72
                radius: Theme.cornerRadiusL
                color: "transparent"
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline, 0.35)

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    MdiIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "mdi:star-plus-outline"
                        size: 26
                        color: Theme.primary
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, column.width - 80)
                        wrapMode: Text.Wrap
                        text: "Open any device and tap the star to pin it here."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }

        // ------------------------------------------------ now playing
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.playing.length > 0

            SectionHeader {
                icon: "mdi:play-circle"
                title: "Now playing"
                actionText: "Media"
                actionIcon: "mdi:chevron-right"
                onActionClicked: root.navigate("media", "")
            }

            Repeater {
                model: root.playing

                MediaCard {
                    required property var modelData
                    width: column.width
                    entityId: modelData
                    compact: true
                    onMoreInfo: id => root.moreInfo(id)
                }
            }
        }

        // ------------------------------------------------ areas
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: HaService.areas.length > 0

            SectionHeader {
                icon: "mdi:floor-plan"
                title: "Areas"
                actionText: "All rooms"
                actionIcon: "mdi:chevron-right"
                onActionClicked: root.navigate("areas", "")
            }

            Grid {
                id: areaGrid
                width: parent.width
                columns: width >= 620 ? 3 : 2
                columnSpacing: Theme.spacingS
                rowSpacing: Theme.spacingS
                readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

                Repeater {
                    model: HaService.areas

                    AreaCard {
                        required property var modelData
                        width: areaGrid.cellWidth
                        area: modelData
                        onOpen: id => root.navigate("areas", id)
                    }
                }
            }
        }
    }
}
