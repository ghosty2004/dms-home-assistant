pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"
import ".."

// climate and water_heater more-info.
Column {
    id: root

    property string entityId: ""
    property var st: null
    readonly property var a: st?.attributes ?? {}
    readonly property string domain: Ha.domainOf(entityId)
    readonly property bool isClimate: domain === "climate"
    readonly property bool off: st?.state === "off" || st?.state === "unavailable"
    readonly property color accent: off ? Theme.surfaceVariantText : Ha.stateColor(entityId, st)
    readonly property bool hasTarget: a.temperature !== undefined && a.temperature !== null

    readonly property var hvacIcons: ({
            off: "mdi:power",
            heat: "mdi:fire",
            cool: "mdi:snowflake",
            heat_cool: "mdi:sun-snowflake-variant",
            auto: "mdi:thermostat-auto",
            dry: "mdi:water-percent",
            fan_only: "mdi:fan"
        })

    function options(list, attribute, icons) {
        return (list ?? []).map(v => ({
                    value: v,
                    label: attribute === "__state" ? (Ha.translateState(entityId, st, v) || Ha.capitalize(v)) : Ha.translateAttribute(entityId, attribute, v),
                    icon: icons ? icons[v] : undefined
                }));
    }

    spacing: Theme.spacingL

    ClimateDial {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 300)
        height: 290
        visible: root.hasTarget || root.off
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

    // Two-setpoint thermostats (heat_cool)
    Row {
        visible: !root.hasTarget && root.a.target_temp_low !== undefined && root.a.target_temp_low !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingXL

        Repeater {
            model: [
                {
                    key: "target_temp_low",
                    label: "Low",
                    color: Ha.palette.deepOrange
                },
                {
                    key: "target_temp_high",
                    label: "High",
                    color: Ha.palette.blue
                }
            ]

            Column {
                id: sp
                required property var modelData
                spacing: Theme.spacingS
                readonly property real val: Number(root.a[modelData.key] ?? 0)

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sp.modelData.label
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
                Row {
                    spacing: Theme.spacingS
                    FeatureButton {
                        icon: "mdi:minus"
                        accent: sp.modelData.color
                        onClicked: {
                            const d = {
                                target_temp_low: root.a.target_temp_low,
                                target_temp_high: root.a.target_temp_high
                            };
                            d[sp.modelData.key] = sp.val - Number(root.a.target_temp_step ?? 0.5);
                            HaService.callService("climate", "set_temperature", d, root.entityId);
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Ha.withUnit(Ha.formatNumber(sp.val), Ha.temperatureUnit())
                        font.pixelSize: Theme.fontSizeXLarge
                        color: Theme.surfaceText
                    }
                    FeatureButton {
                        icon: "mdi:plus"
                        accent: sp.modelData.color
                        onClicked: {
                            const d = {
                                target_temp_low: root.a.target_temp_low,
                                target_temp_high: root.a.target_temp_high
                            };
                            d[sp.modelData.key] = sp.val + Number(root.a.target_temp_step ?? 0.5);
                            HaService.callService("climate", "set_temperature", d, root.entityId);
                        }
                    }
                }
            }
        }
    }

    OptionGroup {
        width: parent.width
        visible: root.isClimate && options.length > 0
        title: "Mode"
        icon: "mdi:thermostat"
        options: root.options(root.a.hvac_modes, "__state", root.hvacIcons)
        current: root.st?.state
        accent: root.accent === Theme.surfaceVariantText ? Theme.primary : root.accent
        onPicked: v => HaService.callService("climate", "set_hvac_mode", {
                hvac_mode: v
            }, root.entityId)
    }

    OptionGroup {
        width: parent.width
        visible: !root.isClimate && options.length > 0
        title: "Operation"
        icon: "mdi:water-boiler"
        options: root.options(root.a.operation_list, "__state", null)
        current: root.a.operation_mode ?? root.st?.state
        accent: Theme.primary
        onPicked: v => HaService.callService("water_heater", "set_operation_mode", {
                operation_mode: v
            }, root.entityId)
    }

    OptionGroup {
        width: parent.width
        title: "Preset"
        icon: "mdi:tune-variant"
        options: root.options(root.a.preset_modes, "preset_mode", null)
        current: root.a.preset_mode
        accent: Theme.primary
        onPicked: v => HaService.callService("climate", "set_preset_mode", {
                preset_mode: v
            }, root.entityId)
    }

    OptionGroup {
        width: parent.width
        title: "Fan"
        icon: "mdi:fan"
        options: root.options(root.a.fan_modes, "fan_mode", null)
        current: root.a.fan_mode
        accent: Ha.palette.cyan
        onPicked: v => HaService.callService("climate", "set_fan_mode", {
                fan_mode: v
            }, root.entityId)
    }

    OptionGroup {
        width: parent.width
        title: "Swing"
        icon: "mdi:arrow-oscillating"
        options: root.options(root.a.swing_modes, "swing_mode", null)
        current: root.a.swing_mode
        accent: Theme.primary
        onPicked: v => HaService.callService("climate", "set_swing_mode", {
                swing_mode: v
            }, root.entityId)
    }

    Row {
        visible: root.a.current_humidity !== undefined && root.a.current_humidity !== null
        spacing: Theme.spacingS

        MdiIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: "mdi:water-percent"
            size: 18
            color: Ha.palette.blue
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Humidity " + root.a.current_humidity + "%" + (root.a.humidity ? " · target " + root.a.humidity + "%" : "")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
