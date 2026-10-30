pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import ".."

// Inline controls under a tile, mirroring HA tile card features.
Item {
    id: root

    property string entityId: ""
    property var st: null
    property string kind: ""
    property color accent: Theme.primary
    readonly property var attrs: st?.attributes ?? {}
    readonly property bool unavailable: !st || st.state === "unavailable"

    implicitHeight: 40

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.kind) {
            case "brightness":
                return brightness;
            case "fan":
                return fan;
            case "number":
                return number;
            case "cover":
                return cover;
            case "target":
                return target;
            case "media":
                return media;
            }
            return null;
        }
    }

    Component {
        id: brightness
        HaSlider {
            color: root.accent
            enabled: !root.unavailable
            from: 0
            to: 100
            value: root.st?.state === "on" ? Math.max(1, Ha.brightnessPct(root.st)) : 0
            onCommitted: v => {
                if (v <= 0)
                    HaService.callService("light", "turn_off", {}, root.entityId);
                else
                    HaService.callService("light", "turn_on", {
                        brightness_pct: Math.round(v)
                    }, root.entityId);
            }
        }
    }

    Component {
        id: fan
        HaSlider {
            color: root.accent
            enabled: !root.unavailable
            from: 0
            to: 100
            step: root.attrs.percentage_step ?? 1
            value: root.st?.state === "on" ? (root.attrs.percentage ?? 0) : 0
            onCommitted: v => HaService.callService("fan", "set_percentage", {
                    percentage: Math.round(v)
                }, root.entityId)
        }
    }

    Component {
        id: number
        HaSlider {
            color: Theme.primary
            enabled: !root.unavailable
            from: Number(root.attrs.min ?? 0)
            to: Number(root.attrs.max ?? 100)
            step: Number(root.attrs.step ?? 1)
            value: Number(root.st?.state ?? 0)
            valueText: Ha.withUnit(Ha.formatNumber(shownValue), root.attrs.unit_of_measurement)
            onCommitted: v => HaService.callService(Ha.domainOf(root.entityId), "set_value", {
                    value: v
                }, root.entityId)
        }
    }

    Component {
        id: cover
        Row {
            id: coverRow
            spacing: Theme.spacingS
            readonly property real bw: (width - spacing * 2) / 3
            readonly property int sf: root.attrs.supported_features ?? 0

            FeatureButton {
                width: coverRow.bw
                height: parent.height
                icon: "mdi:arrow-up"
                accent: root.accent
                enabled: !root.unavailable && (coverRow.sf & 1) && root.st?.state !== "open"
                tooltip: "Open"
                onClicked: HaService.callService("cover", "open_cover", {}, root.entityId)
            }
            FeatureButton {
                width: coverRow.bw
                height: parent.height
                icon: "mdi:stop"
                accent: root.accent
                enabled: !root.unavailable && (coverRow.sf & 8)
                tooltip: "Stop"
                onClicked: HaService.callService("cover", "stop_cover", {}, root.entityId)
            }
            FeatureButton {
                width: coverRow.bw
                height: parent.height
                icon: "mdi:arrow-down"
                accent: root.accent
                enabled: !root.unavailable && (coverRow.sf & 2) && root.st?.state !== "closed"
                tooltip: "Close"
                onClicked: HaService.callService("cover", "close_cover", {}, root.entityId)
            }
        }
    }

    Component {
        id: target
        Row {
            id: targetRow
            spacing: Theme.spacingS
            readonly property real stepSize: Number(root.attrs.target_temp_step ?? (Ha.temperatureUnit() === "°F" ? 1 : 0.5))
            property real pending: NaN
            readonly property real shown: isNaN(pending) ? Number(root.attrs.temperature ?? 0) : pending

            function bump(dir) {
                const min = Number(root.attrs.min_temp ?? 7);
                const max = Number(root.attrs.max_temp ?? 35);
                pending = Math.max(min, Math.min(max, Math.round((shown + dir * stepSize) / stepSize) * stepSize));
                commit.restart();
            }

            Timer {
                id: commit
                interval: 700
                onTriggered: {
                    HaService.callService(Ha.domainOf(root.entityId), "set_temperature", {
                        temperature: targetRow.pending
                    }, root.entityId);
                    clear.restart();
                }
            }
            Timer {
                id: clear
                interval: 2500
                onTriggered: targetRow.pending = NaN
            }

            FeatureButton {
                width: 52
                height: parent.height
                icon: "mdi:minus"
                accent: root.accent
                enabled: !root.unavailable
                onClicked: targetRow.bump(-1)
            }
            Rectangle {
                width: targetRow.width - 52 * 2 - targetRow.spacing * 2
                height: parent.height
                radius: Math.min(height / 2.8, Theme.cornerRadiusL)
                color: Theme.withAlpha(root.accent, 0.1)

                StyledText {
                    anchors.centerIn: parent
                    text: Ha.withUnit(Ha.formatNumber(targetRow.shown, targetRow.stepSize < 1 ? 1 : 0), Ha.temperatureUnit())
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    color: isNaN(targetRow.pending) ? Theme.surfaceText : root.accent
                }
            }
            FeatureButton {
                width: 52
                height: parent.height
                icon: "mdi:plus"
                accent: root.accent
                enabled: !root.unavailable
                onClicked: targetRow.bump(1)
            }
        }
    }

    Component {
        id: media
        Row {
            id: mediaRow
            spacing: Theme.spacingS
            readonly property real bw: (width - spacing * 2) / 3
            readonly property bool playing: root.st?.state === "playing"
            readonly property bool off: root.st?.state === "off" || root.st?.state === "standby"

            FeatureButton {
                width: mediaRow.bw
                height: parent.height
                icon: "mdi:skip-previous"
                accent: root.accent
                enabled: !root.unavailable && !mediaRow.off
                onClicked: HaService.callService("media_player", "media_previous_track", {}, root.entityId)
            }
            FeatureButton {
                width: mediaRow.bw
                height: parent.height
                icon: mediaRow.off ? "mdi:power" : mediaRow.playing ? "mdi:pause" : "mdi:play"
                accent: root.accent
                highlighted: mediaRow.playing
                enabled: !root.unavailable
                onClicked: mediaRow.off ? HaService.callService("media_player", "turn_on", {}, root.entityId) : HaService.callService("media_player", "media_play_pause", {}, root.entityId)
            }
            FeatureButton {
                width: mediaRow.bw
                height: parent.height
                icon: "mdi:skip-next"
                accent: root.accent
                enabled: !root.unavailable && !mediaRow.off
                onClicked: HaService.callService("media_player", "media_next_track", {}, root.entityId)
            }
        }
    }
}
