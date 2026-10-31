pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../../moreinfo"
import "../.."
import ".."

// Lovelace thermostat card: the dial from the climate dialog plus features.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config)
    property var st: HaService.get(entityId)
    readonly property var a: st?.attributes ?? {}
    readonly property string domain: Ha.domainOf(entityId)
    readonly property bool off: st?.state === "off" || st?.state === "unavailable"
    readonly property bool hasTarget: a.temperature !== undefined && a.temperature !== null
    readonly property color accent: off ? Theme.surfaceVariantText : Ha.stateColor(entityId, st)
    readonly property var features: (config?.features ?? []).filter(f => !!f)

    implicitHeight: col.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    Connections {
        target: HaService
        function onEntityUpdated(id) {
            if (id === root.entityId)
                root.st = HaService.get(id);
        }
    }
    onEntityIdChanged: st = HaService.get(entityId)

    Column {
        id: col
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        spacing: Theme.spacingM

        Item {
            width: parent.width
            height: 28

            StyledText {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 64)
                text: Lovelace.nameOf(root.config, root.entityId)
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }
            FeatureButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                icon: "mdi:dots-vertical"
                tooltip: "More info"
                onClicked: {
                    if (root.ctx)
                        root.ctx.moreInfo(root.entityId);
                }
            }
        }

        ClimateDial {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 260)
            height: width * 0.92
            enabled: !root.off && root.hasTarget
            value: Number(root.a.temperature ?? 20)
            current: root.a.current_temperature !== undefined && root.a.current_temperature !== null ? Number(root.a.current_temperature) : NaN
            from: Number(root.a.min_temp ?? 7)
            to: Number(root.a.max_temp ?? 35)
            step: Number(root.a.target_temp_step ?? (Ha.temperatureUnit() === "°F" ? 1 : 0.5))
            color: root.off ? Ha.palette.deepOrange : root.accent
            action: root.a.hvac_action ? Ha.translateAttribute(root.entityId, "hvac_action", root.a.hvac_action) : Ha.stateText(root.entityId, root.st)
            onCommitted: v => HaService.callService(root.domain, "set_temperature", {
                    temperature: v
                }, root.entityId)
        }

        Repeater {
            model: root.features

            Feature {
                required property var modelData
                width: col.width
                height: 40
                config: modelData
                entityId: root.entityId
                st: root.st
                accent: root.off ? Theme.primary : root.accent
            }
        }
    }
}
