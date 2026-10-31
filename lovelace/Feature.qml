pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"
import ".."

// One tile card feature from its Lovelace config (features: [{type: ...}]).
Item {
    id: root

    property var config: ({})
    property string entityId: ""
    property var st: null
    property color accent: Theme.primary

    readonly property string type: config?.type ?? ""
    readonly property var attrs: st?.attributes ?? {}
    readonly property string domain: Ha.domainOf(entityId)
    readonly property bool unavailable: !st || st.state === "unavailable"

    implicitHeight: 40

    // Mode features: attribute with the list, current value, service and data key.
    readonly property var modeSpecs: ({
            "climate-hvac-modes": {
                list: "hvac_modes",
                current: "__state",
                service: "set_hvac_mode",
                key: "hvac_mode",
                filter: "hvac_modes",
                style: "icons"
            },
            "climate-preset-modes": {
                list: "preset_modes",
                current: "preset_mode",
                service: "set_preset_mode",
                key: "preset_mode",
                filter: "preset_modes",
                style: "dropdown"
            },
            "climate-fan-modes": {
                list: "fan_modes",
                current: "fan_mode",
                service: "set_fan_mode",
                key: "fan_mode",
                filter: "fan_modes",
                style: "dropdown"
            },
            "climate-swing-modes": {
                list: "swing_modes",
                current: "swing_mode",
                service: "set_swing_mode",
                key: "swing_mode",
                filter: "swing_modes",
                style: "dropdown"
            },
            "climate-swing-horizontal-modes": {
                list: "swing_horizontal_modes",
                current: "swing_horizontal_mode",
                service: "set_swing_horizontal_mode",
                key: "swing_horizontal_mode",
                filter: "swing_horizontal_modes",
                style: "dropdown"
            },
            "water-heater-operation-modes": {
                list: "operation_list",
                current: "__state",
                service: "set_operation_mode",
                key: "operation_mode",
                filter: "operation_modes",
                style: "icons"
            },
            "fan-preset-modes": {
                list: "preset_modes",
                current: "preset_mode",
                service: "set_preset_mode",
                key: "preset_mode",
                filter: "preset_modes",
                style: "dropdown"
            },
            "humidifier-modes": {
                list: "available_modes",
                current: "mode",
                service: "set_mode",
                key: "mode",
                filter: "modes",
                style: "dropdown"
            },
            "select-options": {
                list: "options",
                current: "__state",
                service: "select_option",
                key: "option",
                filter: "options",
                style: "dropdown"
            }
        })

    readonly property var modeIcons: ({
            off: "mdi:power",
            heat: "mdi:fire",
            cool: "mdi:snowflake",
            heat_cool: "mdi:sun-snowflake-variant",
            auto: "mdi:thermostat-auto",
            dry: "mdi:water-percent",
            fan_only: "mdi:fan",
            eco: "mdi:leaf",
            electric: "mdi:lightning-bolt",
            gas: "mdi:fire-circle",
            heat_pump: "mdi:heat-wave",
            high_demand: "mdi:finance",
            performance: "mdi:rocket-launch"
        })

    readonly property var spec: modeSpecs[type] ?? null

    readonly property var modeOptions: {
        if (!spec)
            return [];
        let list = attrs[spec.list] ?? [];
        const only = config?.[spec.filter];
        if (Array.isArray(only) && only.length)
            list = only.filter(v => list.includes(v));
        return list.map(v => ({
                    value: v,
                    label: spec.current === "__state" ? (Ha.translateState(entityId, st, v) || Ha.capitalize(v)) : Ha.translateAttribute(entityId, spec.current, v),
                    icon: modeIcons[v] ?? ""
                }));
    }
    readonly property string modeCurrent: spec ? String(spec.current === "__state" ? (st?.state ?? "") : (attrs[spec.current] ?? "")) : ""

    function setMode(value) {
        const data = {};
        data[spec.key] = value;
        HaService.callService(domain, spec.service, data, entityId);
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.type) {
            case "light-brightness":
            case "fan-speed":
            case "cover-open-close":
            case "target-temperature":
            case "media-player-media-controls":
            case "media-player-playback":
                return legacy;
            case "numeric-input":
                return (root.config?.style ?? "buttons") === "slider" ? legacy : stepper;
            case "toggle":
                return root.width < 120 ? toggleSwitch : toggle;
            case "button":
                return button;
            }
            if (root.spec)
                return (root.config?.style ?? root.spec.style) === "icons" && root.modeOptions.every(o => o.icon !== "") ? icons : dropdown;
            return null;
        }
    }

    // features the plain tiles already have
    Component {
        id: legacy
        TileFeature {
            entityId: root.entityId
            st: root.st
            accent: root.accent
            kind: {
                switch (root.type) {
                case "light-brightness":
                    return "brightness";
                case "fan-speed":
                    return "fan";
                case "cover-open-close":
                    return "cover";
                case "target-temperature":
                    return "target";
                case "numeric-input":
                    return "number";
                }
                return "media";
            }
        }
    }

    Component {
        id: stepper
        Row {
            id: stepRow
            spacing: Theme.spacingS
            readonly property real min: Number(root.attrs.min ?? 0)
            readonly property real max: Number(root.attrs.max ?? 100)
            readonly property real step: Number(root.attrs.step ?? 1)
            property real pending: NaN
            readonly property real shown: isNaN(pending) ? Number(root.st?.state ?? 0) : pending
            readonly property bool known: !isNaN(pending) || Ha.isNumeric(root.st?.state)

            function bump(dir) {
                pending = Math.max(min, Math.min(max, Math.round((shown + dir * step) / step) * step));
                commit.restart();
            }

            Timer {
                id: commit
                interval: 700
                onTriggered: {
                    HaService.callService(root.domain, "set_value", {
                        value: stepRow.pending
                    }, root.entityId);
                    clear.restart();
                }
            }
            Timer {
                id: clear
                interval: 2500
                onTriggered: stepRow.pending = NaN
            }

            FeatureButton {
                width: 44
                height: parent.height
                icon: "mdi:minus"
                accent: root.accent
                enabled: !root.unavailable && stepRow.known && stepRow.shown > stepRow.min
                onClicked: stepRow.bump(-1)
            }
            Rectangle {
                width: stepRow.width - 44 * 2 - stepRow.spacing * 2
                height: parent.height
                radius: Math.min(height / 2.8, Theme.cornerRadiusL)
                color: Theme.withAlpha(root.accent, 0.1)

                StyledText {
                    anchors.centerIn: parent
                    text: stepRow.known ? Ha.withUnit(Ha.formatMeasure(stepRow.shown, 2), root.attrs.unit_of_measurement) : "–"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    color: isNaN(stepRow.pending) ? Theme.surfaceText : root.accent
                }
            }
            FeatureButton {
                width: 44
                height: parent.height
                icon: "mdi:plus"
                accent: root.accent
                enabled: !root.unavailable && stepRow.known && stepRow.shown < stepRow.max
                onClicked: stepRow.bump(1)
            }
        }
    }

    Component {
        id: toggle
        Row {
            id: toggleRow
            spacing: Theme.spacingXS
            readonly property bool on: root.st?.state === "on"

            Repeater {
                model: [false, true]

                FeatureButton {
                    required property bool modelData
                    width: (toggleRow.width - toggleRow.spacing) / 2
                    height: toggleRow.height
                    text: Ha.translateState(root.entityId, root.st, modelData ? "on" : "off") || (modelData ? "On" : "Off")
                    accent: root.accent
                    highlighted: toggleRow.on === modelData
                    enabled: !root.unavailable
                    onClicked: HaService.callService(root.domain, modelData ? "turn_on" : "turn_off", {}, root.entityId)
                }
            }
        }
    }

    // narrow places (inline features): a switch, like the HA control switch
    Component {
        id: toggleSwitch
        Item {
            DToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                hideText: true
                enabled: !root.unavailable
                checked: root.st?.state === "on"
                onToggled: checked => HaService.callService(root.domain, checked ? "turn_on" : "turn_off", {}, root.entityId)
            }
        }
    }

    Component {
        id: button
        FeatureButton {
            text: {
                switch (root.domain) {
                case "script":
                    return "Run";
                case "scene":
                    return "Activate";
                case "automation":
                    return "Run actions";
                }
                return "Press";
            }
            accent: root.accent
            enabled: !root.unavailable
            onClicked: {
                switch (root.domain) {
                case "button":
                case "input_button":
                    HaService.callService(root.domain, "press", {}, root.entityId);
                    break;
                case "automation":
                    HaService.callService("automation", "trigger", {}, root.entityId);
                    break;
                default:
                    HaService.callService(root.domain, "turn_on", {}, root.entityId);
                }
            }
        }
    }

    Component {
        id: icons
        Row {
            id: iconRow
            spacing: Theme.spacingXS

            Repeater {
                model: root.modeOptions

                FeatureButton {
                    required property var modelData
                    width: (iconRow.width - iconRow.spacing * (root.modeOptions.length - 1)) / Math.max(1, root.modeOptions.length)
                    height: iconRow.height
                    icon: modelData.icon
                    tooltip: modelData.label
                    accent: root.accent
                    highlighted: root.modeCurrent === modelData.value
                    enabled: !root.unavailable
                    onClicked: root.setMode(modelData.value)
                }
            }
        }
    }

    Component {
        id: dropdown
        DDropdown {
            compactMode: true
            triggerHeight: 40
            dropdownWidth: width
            enabled: !root.unavailable
            options: root.modeOptions.map(o => o.label)
            currentValue: root.modeOptions.find(o => o.value === root.modeCurrent)?.label ?? root.modeCurrent
            emptyText: Ha.attributeName(root.entityId, root.spec?.current === "__state" ? "state" : root.spec?.current ?? "")
            onValueChanged: label => {
                const opt = root.modeOptions.find(o => o.label === label);
                if (opt && opt.value !== root.modeCurrent)
                    root.setMode(opt.value);
            }
        }
    }
}
