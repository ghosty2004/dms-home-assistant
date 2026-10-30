pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."

// HA media control card: artwork backdrop, title, transport and volume.
Rectangle {
    id: root

    property string entityId: ""
    property bool compact: false
    property var st: HaService.get(entityId)

    readonly property var a: st?.attributes ?? {}
    readonly property string s: st?.state ?? "unavailable"
    readonly property bool unavailable: s === "unavailable"
    readonly property bool off: s === "off" || s === "standby" || unavailable
    readonly property bool playing: s === "playing"
    readonly property string art: a.entity_picture ? HaService.mediaUrl(a.entity_picture) : ""
    readonly property int sf: a.supported_features ?? 0
    readonly property color accent: Ha.palette.lightBlue
    readonly property real progress: {
        if (!a.media_duration || a.media_position === undefined)
            return -1;
        let pos = a.media_position;
        if (playing && a.media_position_updated_at)
            pos += (now - Date.parse(a.media_position_updated_at)) / 1000;
        return Math.max(0, Math.min(1, pos / a.media_duration));
    }
    property real now: Date.now()

    signal moreInfo(string entityId)

    implicitHeight: compact ? 104 : 168
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor
    clip: true

    Connections {
        target: HaService
        function onEntityUpdated(id) {
            if (id === root.entityId)
                root.st = HaService.get(id);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.playing && root.visible && HaService.dashLive
        onTriggered: root.now = Date.now()
    }

    // Artwork backdrop
    Image {
        id: backdrop
        anchors.fill: parent
        source: root.art
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        sourceSize: Qt.size(64, 64)
        smooth: true
    }

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: backdrop
        visible: backdrop.status === Image.Ready
        opacity: 0.35
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Theme.withAlpha(DashMetrics.cardColor, 0.55)
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(DashMetrics.cardColor, 0.92)
            }
        }
    }

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        onClicked: root.moreInfo(root.entityId)
    }

    Rectangle {
        id: cover
        x: 12
        y: 12
        width: (root.compact ? root.height : 104) - 24
        height: width
        radius: Theme.cornerRadiusM
        color: Theme.withAlpha(root.accent, 0.16)
        clip: true

        MdiIcon {
            anchors.centerIn: parent
            visible: artImage.status !== Image.Ready
            icon: Ha.iconName(root.entityId, root.st)
            size: parent.width * 0.45
            color: root.off ? Theme.surfaceVariantText : root.accent
        }

        Image {
            id: artImage
            anchors.fill: parent
            source: root.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(256, 256)
            visible: status === Image.Ready
        }
    }

    Column {
        anchors.left: cover.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: transport.left
        anchors.rightMargin: Theme.spacingM
        y: 14
        spacing: 2

        StyledText {
            width: parent.width
            text: Ha.entityName(root.entityId, root.st) + " · " + Ha.stateText(root.entityId, root.st) + (root.a.source ? " · " + root.a.source : "")
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceVariantText
        }
        StyledText {
            width: parent.width
            text: root.a.media_title || (root.off ? "Nothing playing" : (root.a.app_name || "Idle"))
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightBold
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            text: [root.a.media_artist, root.a.media_album_name].filter(x => !!x).join(" · ")
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    Row {
        id: transport
        spacing: Theme.spacingXS
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: root.compact ? (root.height - height) / 2 : cover.y + (cover.height - height) / 2

        FeatureButton {
            visible: !root.compact || root.width > 420
            width: 40
            height: 40
            icon: "mdi:skip-previous"
            accent: root.accent
            enabled: !root.off && (root.sf & 16)
            onClicked: HaService.callService("media_player", "media_previous_track", {}, root.entityId)
        }
        FeatureButton {
            width: 52
            height: 40
            icon: root.off ? "mdi:power" : root.playing ? "mdi:pause" : "mdi:play"
            accent: root.accent
            highlighted: root.playing
            enabled: !root.unavailable
            onClicked: root.off ? HaService.callService("media_player", "turn_on", {}, root.entityId) : HaService.callService("media_player", "media_play_pause", {}, root.entityId)
        }
        FeatureButton {
            visible: !root.compact || root.width > 420
            width: 40
            height: 40
            icon: "mdi:skip-next"
            accent: root.accent
            enabled: !root.off && (root.sf & 32)
            onClicked: HaService.callService("media_player", "media_next_track", {}, root.entityId)
        }
    }

    // volume row (full card only)
    Row {
        visible: !root.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: Theme.spacingS
        height: 40

        FeatureButton {
            width: 40
            height: 40
            icon: root.a.is_volume_muted ? "mdi:volume-off" : "mdi:volume-high"
            accent: root.accent
            enabled: !root.off && (root.sf & 8)
            onClicked: HaService.callService("media_player", "volume_mute", {
                is_volume_muted: !root.a.is_volume_muted
            }, root.entityId)
        }
        HaSlider {
            width: parent.width - 40 - (powerBtn.visible ? 40 + parent.spacing : 0) - parent.spacing
            height: 40
            color: root.accent
            enabled: !root.off && (root.sf & 4)
            value: Math.round((root.a.volume_level ?? 0) * 100)
            label: "Volume"
            onCommitted: v => HaService.callService("media_player", "volume_set", {
                    volume_level: v / 100
                }, root.entityId)
        }
        FeatureButton {
            id: powerBtn
            visible: (root.sf & 128) || (root.sf & 256)
            width: 40
            height: 40
            icon: "mdi:power"
            accent: root.accent
            highlighted: !root.off
            enabled: !root.unavailable
            onClicked: HaService.callService("media_player", root.off ? "turn_on" : "turn_off", {}, root.entityId)
        }
    }

    // progress line
    Rectangle {
        visible: root.progress >= 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 3
        width: parent.width * root.progress
        color: root.accent
    }
}
