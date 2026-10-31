pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../components"
import ".."

// HA "more info" dialog shown over the tab.
Item {
    id: root

    property string entityId: ""
    property string shownId: ""
    property var st: null
    readonly property bool open: entityId !== ""
    readonly property string domain: shownId ? Ha.domainOf(shownId) : ""
    readonly property color accent: {
        const c = Ha.stateColor(shownId, st);
        return c === Ha.inactiveColor ? Theme.primary : c;
    }
    readonly property bool active: Ha.isActive(shownId, st)
    readonly property var reg: shownId ? HaService.entityReg[shownId] : null
    readonly property var device: shownId ? HaService.deviceOf(shownId) : null
    readonly property string areaName: Ha.areaName(HaService.areaIdOf(shownId))
    readonly property var related: {
        if (!reg?.di)
            return [];
        const out = [];
        for (const id in HaService.entityReg) {
            const r = HaService.entityReg[id];
            if (r.di === reg.di && id !== shownId && !r.hb && HaService.states[id] !== undefined)
                out.push(id);
        }
        return out.sort((x, y) => (HaService.entityReg[x].ec !== undefined) - (HaService.entityReg[y].ec !== undefined));
    }
    readonly property bool showHistory: ["sensor", "binary_sensor", "number", "input_number", "person", "device_tracker", "switch", "input_boolean", "light", "lock", "cover", "fan", "media_player", "siren", "automation", "select", "input_select"].includes(domain)

    signal closeRequested
    signal moreInfo(string entityId)

    visible: opacity > 0
    opacity: open ? 1 : 0
    enabled: open
    z: 100

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    onEntityIdChanged: {
        if (entityId !== "") {
            shownId = entityId;
            st = HaService.get(entityId);
            flick.contentY = 0;
            attrsOpen = false;
        }
    }

    property bool attrsOpen: false

    Connections {
        target: HaService
        function onEntityUpdated(id) {
            if (id === root.shownId)
                root.st = HaService.get(id);
        }
    }

    // scrim
    Rectangle {
        anchors.fill: parent
        radius: DashMetrics.cardRadius
        color: Theme.withAlpha(Theme.scrimColor, Theme.scrimAlpha)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
            onWheel: wheel => wheel.accepted = true
        }
    }

    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.spacingL * 2, 580)
        height: parent.height - Theme.spacingM * 2
        radius: Theme.cornerRadiusXL
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        scale: root.open ? 1 : 0.94
        clip: true

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Easing.OutBack
                easing.overshoot: 0.6
            }
        }

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => wheel.accepted = false
        }

        // ------------------------------------------------ header
        Item {
            id: header
            x: Theme.spacingL
            y: Theme.spacingL
            width: parent.width - Theme.spacingL * 2
            height: 52

            IconBubble {
                id: bubble
                width: 52
                anchors.verticalCenter: parent.verticalCenter
                icon: Ha.iconName(root.shownId, root.st)
                accent: root.accent
                active: root.active || root.accent !== Theme.primary
                dimmed: !root.st || root.st.state === "unavailable"
                clickable: !dimmed && Ha.canToggle(root.shownId)
                onClicked: Ha.toggle(root.shownId)
            }

            Column {
                anchors.left: bubble.right
                anchors.leftMargin: Theme.spacingM
                anchors.right: actions.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                StyledText {
                    width: parent.width
                    text: [root.areaName, root.device?.name_by_user || root.device?.name].filter(x => !!x && x !== Ha.entityName(root.shownId, root.st)).join(" › ")
                    visible: text !== ""
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width: parent.width
                    text: Ha.entityName(root.shownId, root.st)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeLarge + 1
                    font.weight: Theme.fontWeightBold
                    color: Theme.surfaceText
                }
                StyledText {
                    width: parent.width
                    text: {
                        HaService.translationRev;
                        const changed = root.st?.last_changed ? Ha.relativeTime(root.st.last_changed) : "";
                        return Ha.stateText(root.shownId, root.st) + (changed ? " · " + changed : "");
                    }
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: root.active ? root.accent : Theme.surfaceVariantText
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                FeatureButton {
                    width: 40
                    height: 40
                    radius: 20
                    icon: HaService.favorites.includes(root.shownId) ? "mdi:star" : "mdi:star-outline"
                    accent: Ha.palette.amber
                    highlighted: HaService.favorites.includes(root.shownId)
                    tooltip: HaService.favorites.includes(root.shownId) ? "Remove from favorites" : "Add to favorites"
                    onClicked: HaService.toggleFavorite(root.shownId)
                }
                FeatureButton {
                    width: 40
                    height: 40
                    radius: 20
                    icon: "mdi:open-in-new"
                    tooltip: "Open history in Home Assistant"
                    onClicked: Qt.openUrlExternally(HaService.baseUrl + "/history?entity_id=" + root.shownId)
                }
                FeatureButton {
                    width: 40
                    height: 40
                    radius: 20
                    icon: "mdi:close"
                    tooltip: "Close"
                    onClicked: root.closeRequested()
                }
            }
        }

        // ------------------------------------------------ body
        DFlickable {
            id: flick
            anchors.top: header.bottom
            anchors.topMargin: Theme.spacingL
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            contentWidth: width
            contentHeight: body.implicitHeight + Theme.spacingL
            clip: true

            Column {
                id: body
                width: flick.width
                spacing: Theme.spacingL

                Loader {
                    id: controls
                    width: parent.width
                    active: root.shownId !== ""
                    sourceComponent: {
                        switch (root.domain) {
                        case "light":
                            return lightComp;
                        case "climate":
                        case "water_heater":
                            return climateComp;
                        case "media_player":
                            return mediaComp;
                        case "camera":
                            return cameraComp;
                        case "weather":
                            return weatherComp;
                        case "sensor":
                        case "binary_sensor":
                        case "sun":
                            return valueComp;
                        }
                        return domainComp;
                    }
                }

                HistoryGraph {
                    width: parent.width
                    visible: root.showHistory && root.open
                    entityId: root.showHistory && root.open ? root.shownId : ""
                    accent: root.accent
                }

                // related entities of the same device
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.related.length > 0

                    SectionHeader {
                        icon: "mdi:devices"
                        title: root.device?.name_by_user || root.device?.name || "Device"
                        subtitle: [root.device?.manufacturer, root.device?.model].filter(x => !!x).join(" ")
                    }
                    TileGrid {
                        width: parent.width
                        ids: root.related.slice(0, 12)
                        minTileWidth: 220
                        showFeatures: false
                        stripPrefixes: [root.device?.name_by_user || root.device?.name || ""]
                        onMoreInfo: id => root.moreInfo(id)
                    }
                }

                // attributes
                Rectangle {
                    width: parent.width
                    height: attrCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadiusL
                    color: DashMetrics.cardColor

                    Column {
                        id: attrCol
                        x: Theme.spacingM
                        y: Theme.spacingM
                        width: parent.width - Theme.spacingM * 2
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 24

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                MdiIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "mdi:information-outline"
                                    size: 16
                                    color: Theme.surfaceVariantText
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Attributes"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.surfaceText
                                }
                            }
                            MdiIcon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                icon: root.attrsOpen ? "mdi:chevron-up" : "mdi:chevron-down"
                                size: 18
                                color: Theme.surfaceVariantText
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.attrsOpen = !root.attrsOpen
                            }
                        }

                        Repeater {
                            id: attrRepeater
                            model: {
                                if (!root.attrsOpen)
                                    return [];
                                const skip = ["friendly_name", "icon", "entity_picture", "supported_features", "supported_color_modes", "attribution", "access_token", "entity_id", "unit_of_measurement", "device_class", "state_class", "editable", "id", "options", "effect_list", "hvac_modes", "preset_modes", "fan_modes", "swing_modes", "operation_list", "source_list", "sound_mode_list"];
                                const out = [["Entity ID", root.shownId]];
                                const a = root.st?.attributes ?? {};
                                for (const k of Object.keys(a)) {
                                    if (skip.includes(k))
                                        continue;
                                    let v = a[k];
                                    if (v === null || v === undefined)
                                        continue;
                                    if (typeof v === "object")
                                        v = JSON.stringify(v);
                                    out.push([Ha.attributeName(root.shownId, k), String(v)]);
                                }
                                if (root.st?.last_updated)
                                    out.push(["Last updated", new Date(root.st.last_updated).toLocaleString(Qt.locale(), Locale.ShortFormat)]);
                                return out;
                            }

                            Item {
                                id: attrRow
                                required property var modelData
                                width: attrCol.width
                                height: Math.max(keyText.implicitHeight, valText.implicitHeight) + 4

                                StyledText {
                                    id: keyText
                                    width: parent.width * 0.42
                                    text: attrRow.modelData[0]
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                StyledText {
                                    id: valText
                                    anchors.right: parent.right
                                    width: parent.width * 0.56
                                    horizontalAlignment: Text.AlignRight
                                    text: attrRow.modelData[1]
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------ control components
    Component {
        id: lightComp
        LightControls {
            entityId: root.shownId
            st: root.st
        }
    }

    Component {
        id: climateComp
        ClimateControls {
            entityId: root.shownId
            st: root.st
        }
    }

    Component {
        id: domainComp
        DomainControls {
            entityId: root.shownId
            st: root.st
        }
    }

    Component {
        id: weatherComp
        WeatherControls {
            entityId: root.shownId
            st: root.st
            live: root.open && HaService.dashLive
        }
    }

    Component {
        id: cameraComp
        CameraCard {
            entityId: root.shownId
            height: implicitHeight
            refreshInterval: 2000
            live: root.open && HaService.dashLive
        }
    }

    Component {
        id: mediaComp
        Column {
            spacing: Theme.spacingM

            MediaCard {
                width: parent.width
                entityId: root.shownId
            }
            OptionGroup {
                width: parent.width
                title: "Source"
                icon: "mdi:import"
                options: (root.st?.attributes?.source_list ?? []).map(s => ({
                            value: s,
                            label: s
                        }))
                current: root.st?.attributes?.source
                accent: Ha.palette.lightBlue
                onPicked: v => HaService.callService("media_player", "select_source", {
                        source: v
                    }, root.shownId)
            }
            OptionGroup {
                width: parent.width
                title: "Sound mode"
                icon: "mdi:equalizer"
                options: (root.st?.attributes?.sound_mode_list ?? []).map(s => ({
                            value: s,
                            label: s
                        }))
                current: root.st?.attributes?.sound_mode
                accent: Ha.palette.lightBlue
                onPicked: v => HaService.callService("media_player", "select_sound_mode", {
                        sound_mode: v
                    }, root.shownId)
            }
        }
    }

    Component {
        id: valueComp
        Item {
            implicitHeight: 110

            Column {
                anchors.centerIn: parent
                spacing: 4

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        HaService.translationRev;
                        return Ha.stateText(root.shownId, root.st);
                    }
                    font.pixelSize: Theme.fontSizeXLarge * 2
                    font.weight: Theme.fontWeightBold
                    color: root.active && root.domain === "binary_sensor" ? root.accent : Theme.surfaceText
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const a = root.st?.attributes ?? {};
                        const dc = a.device_class ? Ha.capitalize(a.device_class) : "";
                        const sc = a.state_class ? Ha.capitalize(a.state_class) : "";
                        return [dc, sc].filter(x => !!x).join(" · ");
                    }
                    visible: text !== ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
