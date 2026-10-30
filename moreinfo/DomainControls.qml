pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"
import ".."

// More-info controls for every domain except light / climate / media / camera.
Item {
    id: root

    property string entityId: ""
    property var st: null
    readonly property var a: st?.attributes ?? {}
    readonly property string domain: Ha.domainOf(entityId)
    readonly property string s: st?.state ?? "unavailable"
    readonly property bool unavailable: s === "unavailable"
    readonly property color accent: {
        const c = Ha.stateColor(entityId, st);
        return c === Ha.inactiveColor ? Theme.primary : c;
    }
    readonly property int sf: a.supported_features ?? 0

    implicitHeight: loader.item?.implicitHeight ?? 0

    function call(service, data, d) {
        HaService.callService(d || domain, service, data || {}, entityId);
    }

    Loader {
        id: loader
        width: parent.width
        sourceComponent: {
            switch (root.domain) {
            case "switch":
            case "input_boolean":
            case "siren":
            case "remote":
            case "humidifier":
            case "automation":
            case "group":
                return toggleComp;
            case "fan":
                return fanComp;
            case "cover":
            case "valve":
                return coverComp;
            case "lock":
                return lockComp;
            case "scene":
            case "script":
            case "button":
            case "input_button":
                return runComp;
            case "select":
            case "input_select":
                return selectComp;
            case "number":
            case "input_number":
                return numberComp;
            case "alarm_control_panel":
                return alarmComp;
            case "vacuum":
            case "lawn_mower":
                return vacuumComp;
            case "update":
                return updateComp;
            case "person":
            case "device_tracker":
                return personComp;
            }
            return null;
        }
    }

    // ------------------------------------------------ switch-like
    Component {
        id: toggleComp
        Column {
            spacing: Theme.spacingL

            BigToggle {
                anchors.horizontalCenter: parent.horizontalCenter
                checked: root.s === "on"
                enabled: !root.unavailable
                accent: root.accent
                onIcon: Ha.iconName(root.entityId, {
                    state: "on",
                    attributes: root.a
                })
                offIcon: Ha.iconName(root.entityId, {
                    state: "off",
                    attributes: root.a
                })
                onToggled: on => root.call(on ? "turn_on" : "turn_off")
            }

            HaSlider {
                visible: root.domain === "humidifier"
                width: parent.width
                color: Ha.palette.blue
                label: "Target humidity"
                from: root.a.min_humidity ?? 0
                to: root.a.max_humidity ?? 100
                value: root.a.humidity ?? 0
                onCommitted: v => root.call("set_humidity", {
                        humidity: Math.round(v)
                    })
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.domain === "automation"
                spacing: Theme.spacingS
                FeatureButton {
                    icon: "mdi:play"
                    text: "Run actions"
                    accent: Theme.primary
                    onClicked: root.call("trigger", {
                        skip_condition: true
                    })
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.domain === "automation" && !!root.a.last_triggered
                text: "Last triggered " + Ha.relativeTime(Date.parse(root.a.last_triggered))
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    // ------------------------------------------------ fan
    Component {
        id: fanComp
        Column {
            spacing: Theme.spacingL

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingL

                HaSlider {
                    visible: root.sf & 1
                    vertical: true
                    width: 110
                    height: 260
                    color: root.accent
                    enabled: !root.unavailable
                    step: root.a.percentage_step ?? 1
                    value: root.s === "on" ? (root.a.percentage ?? 0) : 0
                    onCommitted: v => root.call("set_percentage", {
                            percentage: Math.round(v)
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
                    height: 260
                    checked: root.s === "on"
                    enabled: !root.unavailable
                    accent: root.accent
                    onIcon: "mdi:fan"
                    offIcon: "mdi:fan-off"
                    onToggled: on => root.call(on ? "turn_on" : "turn_off")
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingS

                FeatureButton {
                    visible: root.sf & 2
                    icon: "mdi:arrow-oscillating"
                    text: "Oscillate"
                    accent: root.accent
                    highlighted: root.a.oscillating === true
                    onClicked: root.call("oscillate", {
                        oscillating: !root.a.oscillating
                    })
                }
                FeatureButton {
                    visible: root.sf & 4
                    icon: root.a.direction === "reverse" ? "mdi:rotate-left" : "mdi:rotate-right"
                    text: root.a.direction === "reverse" ? "Reverse" : "Forward"
                    accent: root.accent
                    onClicked: root.call("set_direction", {
                        direction: root.a.direction === "reverse" ? "forward" : "reverse"
                    })
                }
            }

            OptionGroup {
                width: parent.width
                title: "Preset"
                icon: "mdi:tune-variant"
                options: (root.a.preset_modes ?? []).map(p => ({
                            value: p,
                            label: Ha.translateAttribute(root.entityId, "preset_mode", p)
                        }))
                current: root.a.preset_mode
                accent: root.accent
                onPicked: v => root.call("set_preset_mode", {
                        preset_mode: v
                    })
            }
        }
    }

    // ------------------------------------------------ cover / valve
    Component {
        id: coverComp
        Column {
            spacing: Theme.spacingL
            readonly property bool isValve: root.domain === "valve"
            readonly property bool hasPosition: root.a.current_position !== undefined

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingL

                HaSlider {
                    visible: parent.parent.hasPosition
                    vertical: true
                    width: 110
                    height: 260
                    color: root.accent
                    enabled: !root.unavailable
                    value: root.a.current_position ?? 0
                    onCommitted: v => root.call(parent.parent.isValve ? "set_valve_position" : "set_cover_position", {
                            position: Math.round(v)
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

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    FeatureButton {
                        width: 72
                        height: 72
                        radius: 24
                        icon: "mdi:arrow-up"
                        accent: root.accent
                        enabled: !root.unavailable && root.s !== "open"
                        tooltip: "Open"
                        onClicked: root.call(parent.parent.parent.isValve ? "open_valve" : "open_cover")
                    }
                    FeatureButton {
                        width: 72
                        height: 72
                        radius: 24
                        icon: "mdi:stop"
                        accent: root.accent
                        enabled: !root.unavailable
                        tooltip: "Stop"
                        onClicked: root.call(parent.parent.parent.isValve ? "stop_valve" : "stop_cover")
                    }
                    FeatureButton {
                        width: 72
                        height: 72
                        radius: 24
                        icon: "mdi:arrow-down"
                        accent: root.accent
                        enabled: !root.unavailable && root.s !== "closed"
                        tooltip: "Close"
                        onClicked: root.call(parent.parent.parent.isValve ? "close_valve" : "close_cover")
                    }
                }
            }

            HaSlider {
                visible: root.a.current_tilt_position !== undefined
                width: parent.width
                color: root.accent
                label: "Tilt"
                value: root.a.current_tilt_position ?? 0
                onCommitted: v => root.call("set_cover_tilt_position", {
                        tilt_position: Math.round(v)
                    })
            }
        }
    }

    // ------------------------------------------------ lock
    Component {
        id: lockComp
        Column {
            spacing: Theme.spacingL
            readonly property bool locked: root.s === "locked"

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 150
                height: 150
                radius: 75
                color: Theme.withAlpha(root.accent, 0.18)

                MdiIcon {
                    anchors.centerIn: parent
                    icon: Ha.iconName(root.entityId, root.st)
                    size: 72
                    color: root.accent
                }
                StateLayer {
                    anchors.fill: parent
                    cornerRadius: 75
                    enabled: !root.unavailable
                    onClicked: root.call(parent.parent.locked ? "unlock" : "lock")
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingS

                FeatureButton {
                    icon: parent.parent.locked ? "mdi:lock-open-variant" : "mdi:lock"
                    text: parent.parent.locked ? "Unlock" : "Lock"
                    accent: root.accent
                    highlighted: true
                    enabled: !root.unavailable
                    onClicked: root.call(parent.parent.locked ? "unlock" : "lock")
                }
                FeatureButton {
                    visible: root.sf & 1
                    icon: "mdi:door-open"
                    text: "Open"
                    accent: root.accent
                    enabled: !root.unavailable
                    onClicked: root.call("open")
                }
            }
        }
    }

    // ------------------------------------------------ scene / script / button
    Component {
        id: runComp
        Column {
            spacing: Theme.spacingL
            readonly property bool running: root.domain === "script" && root.s === "on"

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 150
                height: 150
                radius: 75
                color: Theme.withAlpha(parent.running ? Ha.palette.amber : Theme.primary, 0.16)

                MdiIcon {
                    anchors.centerIn: parent
                    icon: Ha.iconName(root.entityId, root.st)
                    size: 64
                    color: parent.parent.running ? Ha.palette.amber : Theme.primary
                }
                StateLayer {
                    anchors.fill: parent
                    cornerRadius: 75
                    enabled: !root.unavailable
                    onClicked: Ha.toggle(root.entityId)
                }
            }

            FeatureButton {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: parent.running ? "mdi:stop" : root.domain === "scene" ? "mdi:palette" : root.domain === "script" ? "mdi:play" : "mdi:gesture-tap"
                text: parent.running ? "Stop" : root.domain === "scene" ? "Activate" : root.domain === "script" ? "Run" : "Press"
                accent: Theme.primary
                highlighted: true
                enabled: !root.unavailable
                onClicked: Ha.toggle(root.entityId)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: {
                    const t = root.domain === "script" ? root.a.last_triggered : root.s;
                    const ms = Date.parse(t);
                    return isNaN(ms) ? "" : "Last run " + Ha.relativeTime(ms);
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    // ------------------------------------------------ select
    Component {
        id: selectComp
        OptionGroup {
            options: (root.a.options ?? []).map(o => ({
                        value: o,
                        label: Ha.translateState(root.entityId, root.st, o) || o
                    }))
            current: root.s
            accent: Theme.primary
            onPicked: v => root.call("select_option", {
                    option: v
                })
        }
    }

    // ------------------------------------------------ number
    Component {
        id: numberComp
        Column {
            spacing: Theme.spacingM

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Ha.stateText(root.entityId, root.st)
                font.pixelSize: Theme.fontSizeXLarge * 1.6
                font.weight: Theme.fontWeightBold
                color: Theme.surfaceText
            }
            HaSlider {
                width: parent.width
                height: 48
                color: Theme.primary
                enabled: !root.unavailable
                from: Number(root.a.min ?? 0)
                to: Number(root.a.max ?? 100)
                step: Number(root.a.step ?? 1)
                value: Number(root.s) || 0
                valueText: Ha.withUnit(Ha.formatNumber(shownValue), root.a.unit_of_measurement)
                onCommitted: v => root.call("set_value", {
                        value: v
                    })
            }
        }
    }

    // ------------------------------------------------ alarm
    Component {
        id: alarmComp
        Column {
            spacing: Theme.spacingL

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 140
                height: 140
                radius: 70
                color: Theme.withAlpha(root.accent, 0.18)
                MdiIcon {
                    anchors.centerIn: parent
                    icon: Ha.iconName(root.entityId, root.st)
                    size: 64
                    color: root.accent
                }
            }

            OptionGroup {
                width: parent.width
                title: "Mode"
                accent: root.accent
                current: root.s
                options: {
                    const all = [
                        {
                            value: "disarmed",
                            service: "alarm_disarm",
                            icon: "mdi:shield-off",
                            bit: 0
                        },
                        {
                            value: "armed_home",
                            service: "alarm_arm_home",
                            icon: "mdi:shield-home",
                            bit: 1
                        },
                        {
                            value: "armed_away",
                            service: "alarm_arm_away",
                            icon: "mdi:shield-lock",
                            bit: 2
                        },
                        {
                            value: "armed_night",
                            service: "alarm_arm_night",
                            icon: "mdi:shield-moon",
                            bit: 4
                        },
                        {
                            value: "armed_vacation",
                            service: "alarm_arm_vacation",
                            icon: "mdi:shield-airplane",
                            bit: 32
                        },
                        {
                            value: "armed_custom_bypass",
                            service: "alarm_arm_custom_bypass",
                            icon: "mdi:security",
                            bit: 16
                        }
                    ];
                    return all.filter(m => m.bit === 0 || (root.sf & m.bit)).map(m => ({
                                value: m.value,
                                icon: m.icon,
                                label: Ha.translateState(root.entityId, root.st, m.value) || Ha.capitalize(m.value)
                            }));
                }
                onPicked: v => {
                    const map = {
                        disarmed: "alarm_disarm",
                        armed_home: "alarm_arm_home",
                        armed_away: "alarm_arm_away",
                        armed_night: "alarm_arm_night",
                        armed_vacation: "alarm_arm_vacation",
                        armed_custom_bypass: "alarm_arm_custom_bypass"
                    };
                    root.call(map[v]);
                }
            }
        }
    }

    // ------------------------------------------------ vacuum / mower
    Component {
        id: vacuumComp
        Column {
            spacing: Theme.spacingL

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 140
                height: 140
                radius: 70
                color: Theme.withAlpha(root.accent, 0.18)
                MdiIcon {
                    anchors.centerIn: parent
                    icon: Ha.iconName(root.entityId, root.st)
                    size: 64
                    color: root.accent
                }
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: root.domain === "vacuum" ? [
                        {
                            icon: "mdi:play",
                            text: "Start",
                            service: "start"
                        },
                        {
                            icon: "mdi:pause",
                            text: "Pause",
                            service: "pause"
                        },
                        {
                            icon: "mdi:stop",
                            text: "Stop",
                            service: "stop"
                        },
                        {
                            icon: "mdi:home-map-marker",
                            text: "Dock",
                            service: "return_to_base"
                        },
                        {
                            icon: "mdi:map-marker",
                            text: "Locate",
                            service: "locate"
                        }
                    ] : [
                        {
                            icon: "mdi:play",
                            text: "Mow",
                            service: "start_mowing"
                        },
                        {
                            icon: "mdi:pause",
                            text: "Pause",
                            service: "pause"
                        },
                        {
                            icon: "mdi:home-import-outline",
                            text: "Dock",
                            service: "dock"
                        }
                    ]

                    FeatureButton {
                        required property var modelData
                        icon: modelData.icon
                        text: modelData.text
                        accent: root.accent
                        enabled: !root.unavailable
                        onClicked: root.call(modelData.service)
                    }
                }
            }
        }
    }

    // ------------------------------------------------ update
    Component {
        id: updateComp
        Column {
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingL
                Column {
                    StyledText {
                        text: "Installed"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        text: root.a.installed_version ?? "—"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                    }
                }
                Column {
                    StyledText {
                        text: "Latest"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        text: root.a.latest_version ?? "—"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Theme.fontWeightBold
                        color: root.s === "on" ? Ha.palette.orange : Theme.surfaceText
                    }
                }
            }
            StyledText {
                width: parent.width
                visible: !!root.a.release_summary
                text: root.a.release_summary ?? ""
                textFormat: Text.MarkdownText
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
            Row {
                spacing: Theme.spacingS
                FeatureButton {
                    visible: root.s === "on" && (root.sf & 1)
                    icon: "mdi:download"
                    text: root.a.in_progress ? "Installing…" : "Install"
                    accent: Ha.palette.orange
                    highlighted: true
                    enabled: !root.a.in_progress
                    onClicked: root.call("install", {}, "update")
                }
                FeatureButton {
                    visible: root.s === "on"
                    icon: "mdi:debug-step-over"
                    text: "Skip"
                    accent: Theme.primary
                    onClicked: root.call("skip", {}, "update")
                }
                FeatureButton {
                    visible: !!root.a.release_url
                    icon: "mdi:open-in-new"
                    text: "Release notes"
                    accent: Theme.primary
                    onClicked: Qt.openUrlExternally(root.a.release_url)
                }
            }
        }
    }

    // ------------------------------------------------ person
    Component {
        id: personComp
        Column {
            spacing: Theme.spacingM

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 120
                height: 120
                radius: 60
                color: Theme.withAlpha(root.accent, 0.18)
                clip: true
                border.width: 3
                border.color: root.accent

                MdiIcon {
                    anchors.centerIn: parent
                    visible: pic.status !== Image.Ready
                    icon: Ha.iconName(root.entityId, root.st)
                    size: 56
                    color: root.accent
                }
                Image {
                    id: pic
                    anchors.fill: parent
                    anchors.margins: 3
                    source: root.a.entity_picture ? HaService.mediaUrl(root.a.entity_picture) : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Ha.stateText(root.entityId, root.st)
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: Theme.fontWeightBold
                color: root.accent
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.a.latitude !== undefined
                text: root.a.latitude !== undefined ? Number(root.a.latitude).toFixed(4) + ", " + Number(root.a.longitude).toFixed(4) + (root.a.gps_accuracy ? " · ±" + root.a.gps_accuracy + " m" : "") : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
