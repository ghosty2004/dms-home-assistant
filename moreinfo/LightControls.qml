pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"
import ".."

Column {
    id: root

    property string entityId: ""
    property var st: null
    readonly property var a: st?.attributes ?? {}
    readonly property bool on: st?.state === "on"
    readonly property bool unavailable: !st || st.state === "unavailable"
    readonly property var modes: a.supported_color_modes ?? []
    readonly property bool dimmable: modes.length > 0 && !(modes.length === 1 && modes[0] === "onoff")
    readonly property bool hasTemp: modes.includes("color_temp")
    readonly property bool hasColor: modes.some(m => ["hs", "rgb", "rgbw", "rgbww", "xy"].includes(m))
    readonly property color accent: on ? Ha.stateColor(entityId, st) : Ha.palette.amber

    function turnOn(data) {
        HaService.callService("light", "turn_on", data || {}, entityId);
    }

    spacing: Theme.spacingL

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingL

        HaSlider {
            visible: root.dimmable
            vertical: true
            width: 110
            height: 280
            color: root.accent
            enabled: !root.unavailable
            value: root.on ? Math.max(1, Ha.brightnessPct(root.st)) : 0
            onCommitted: v => v <= 0 ? HaService.callService("light", "turn_off", {}, root.entityId) : root.turnOn({
                    brightness_pct: Math.round(v)
                })

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 14
                text: Math.round(parent.shownValue) + "%"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightBold
                color: parent.ratio > 0.88 ? "#ffffff" : Theme.surfaceText
            }
        }

        BigToggle {
            visible: !root.dimmable
            height: 280
            checked: root.on
            enabled: !root.unavailable
            accent: root.accent
            onIcon: "mdi:lightbulb"
            offIcon: "mdi:lightbulb-off"
            onToggled: on => HaService.callService("light", on ? "turn_on" : "turn_off", {}, root.entityId)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM
            visible: root.dimmable

            FeatureButton {
                width: 64
                height: 64
                radius: 22
                icon: root.on ? "mdi:lightbulb-on" : "mdi:lightbulb-outline"
                accent: root.accent
                highlighted: root.on
                enabled: !root.unavailable
                tooltip: root.on ? "Turn off" : "Turn on"
                onClicked: HaService.callService("light", "toggle", {}, root.entityId)
            }

            Repeater {
                // quick brightness presets
                model: [100, 50, 10]

                FeatureButton {
                    required property int modelData
                    width: 64
                    height: 40
                    text: modelData + "%"
                    accent: root.accent
                    enabled: !root.unavailable
                    onClicked: root.turnOn({
                        brightness_pct: modelData
                    })
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.hasTemp

        StyledText {
            text: "Color temperature" + (root.a.color_temp_kelvin ? " · " + root.a.color_temp_kelvin + " K" : "")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceVariantText
        }
        GradientSlider {
            width: parent.width
            from: root.a.min_color_temp_kelvin ?? 2000
            to: root.a.max_color_temp_kelvin ?? 6500
            value: root.a.color_temp_kelvin ?? ((from + to) / 2)
            stops: ["#ff9d3c", "#ffd2a1", "#fff4e6", "#dbe8ff", "#a9c8ff"]
            onCommitted: v => root.turnOn({
                    color_temp_kelvin: Math.round(v)
                })
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.hasColor

        StyledText {
            text: "Color"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceVariantText
        }
        GradientSlider {
            width: parent.width
            from: 0
            to: 360
            value: root.a.hs_color ? root.a.hs_color[0] : 0
            stops: ["#ff0000", "#ffff00", "#00ff00", "#00ffff", "#0000ff", "#ff00ff", "#ff0000"]
            onCommitted: v => root.turnOn({
                    hs_color: [Math.round(v), root.a.hs_color ? Math.max(40, root.a.hs_color[1]) : 100]
                })
        }
        Row {
            spacing: Theme.spacingS

            Repeater {
                model: [[255, 147, 41], [255, 214, 170], [255, 255, 255], [255, 60, 40], [255, 140, 0], [255, 230, 0], [80, 230, 80], [0, 200, 255], [40, 80, 255], [160, 60, 255], [255, 60, 180]]

                Rectangle {
                    id: swatch
                    required property var modelData
                    width: 30
                    height: 30
                    radius: 15
                    color: Qt.rgba(modelData[0] / 255, modelData[1] / 255, modelData[2] / 255, 1)
                    border.width: 2
                    border.color: Theme.withAlpha(Theme.surfaceText, 0.15)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.turnOn({
                            rgb_color: swatch.modelData
                        })
                    }
                }
            }
        }
    }

    OptionGroup {
        width: parent.width
        title: "Effect"
        icon: "mdi:creation"
        options: (root.a.effect_list ?? []).slice(0, 40).map(e => ({
                    value: e,
                    label: e
                }))
        current: root.a.effect
        accent: root.accent
        onPicked: v => root.turnOn({
                effect: v
            })
    }
}
