pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."

// HA area card: name, climate summary, active count and quick toggles.
Rectangle {
    id: root

    property var area: null
    readonly property string areaId: area?.area_id ?? ""
    readonly property var ids: {
        Ha.index;
        return Ha.visibleFilter(Ha.index.byArea[areaId] ?? []);
    }
    readonly property var controls: ids.filter(id => ["light", "switch", "fan", "cover", "media_player", "climate", "lock", "input_boolean"].includes(Ha.domainOf(id))).slice(0, 6)
    readonly property string temperatureId: area?.temperature_entity_id || ids.find(id => HaService.states[id]?.attributes?.device_class === "temperature" && Ha.domainOf(id) === "sensor") || ""
    readonly property string humidityId: area?.humidity_entity_id || ids.find(id => HaService.states[id]?.attributes?.device_class === "humidity" && Ha.domainOf(id) === "sensor") || ""
    readonly property int activeCount: {
        HaService.stateRev;
        return controls.filter(id => Ha.isActive(id, HaService.states[id])).length;
    }
    readonly property string summary: {
        HaService.stateRev;
        const parts = [];
        if (temperatureId)
            parts.push(Ha.stateText(temperatureId, HaService.states[temperatureId]));
        if (humidityId)
            parts.push(Ha.stateText(humidityId, HaService.states[humidityId]));
        parts.push(ids.length + " entities");
        return parts.join(" · ");
    }

    signal open(string areaId)
    signal moreInfo(string entityId)

    implicitHeight: 128
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor
    clip: true

    // soft accent glow in the corner
    Rectangle {
        width: parent.width * 0.7
        height: width
        radius: width / 2
        x: parent.width - width * 0.45
        y: -height * 0.55
        color: Theme.withAlpha(Theme.primary, root.activeCount > 0 ? 0.12 : 0.05)
    }

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        onClicked: root.open(root.areaId)
    }

    Row {
        id: head
        x: 14
        y: 14
        width: parent.width - 28
        spacing: Theme.spacingM

        Rectangle {
            width: 44
            height: 44
            radius: Theme.cornerRadiusM
            color: Theme.withAlpha(Theme.primary, 0.16)

            MdiIcon {
                anchors.centerIn: parent
                icon: Ha.areaIcon(root.area)
                size: 26
                color: Theme.primary
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 44 - Theme.spacingM - (countPill.visible ? countPill.width + Theme.spacingS : 0)
            spacing: 2

            StyledText {
                width: parent.width
                text: root.area?.name ?? ""
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: root.summary
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    Rectangle {
        id: countPill
        visible: root.activeCount > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        height: 22
        width: countText.implicitWidth + 16
        radius: 11
        color: Theme.primary

        StyledText {
            id: countText
            anchors.centerIn: parent
            text: root.activeCount + " on"
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Theme.fontWeightBold
            color: Theme.onPrimary
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 14
        spacing: Theme.spacingS

        Repeater {
            model: root.controls

            IconBubble {
                id: ctl
                required property var modelData
                property var st: HaService.get(modelData)
                width: 38
                icon: Ha.iconName(modelData, st)
                accent: Ha.stateColor(modelData, st)
                active: Ha.isActive(modelData, st)
                dimmed: !st || st.state === "unavailable"
                clickable: !dimmed
                tooltip: Ha.entityName(modelData, st, [root.area?.name]) + " · " + Ha.stateText(modelData, st)
                onClicked: Ha.toggle(modelData)

                Connections {
                    target: HaService
                    function onEntityUpdated(id) {
                        if (id === ctl.modelData)
                            ctl.st = HaService.get(id);
                    }
                }
            }
        }
    }
}
