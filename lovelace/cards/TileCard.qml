pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."
import ".."

// Lovelace tile card (also used for the light card): name, icon, color,
// vertical layout, state_content, actions and features from the config.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config)
    property var st: HaService.get(entityId)

    readonly property bool unavailable: !st || st.state === "unavailable"
    readonly property bool active: Ha.isActive(entityId, st)
    readonly property bool vertical: config?.vertical === true
    readonly property var features: config?.type === "light" ? [
            {
                type: "light-brightness"
            }
        ] : (config?.features ?? []).filter(f => !!f)
    readonly property bool inlineFeature: config?.features_position === "inline" && features.length > 0
    readonly property var bottomFeatures: inlineFeature ? [] : features
    readonly property color stateColor: Ha.stateColor(entityId, st)
    readonly property color accent: active && config?.color && config.color !== "state" ? Lovelace.color(config.color, stateColor) : stateColor
    readonly property color featureAccent: unavailable || accent === Ha.inactiveColor ? Theme.primary : accent

    readonly property real pad: 8
    readonly property real featureH: 40
    readonly property real mainH: vertical ? 40 + 4 + 40 : 40

    implicitHeight: pad * 2 + mainH + bottomFeatures.length * (featureH + Theme.spacingS)
    radius: Theme.cornerRadiusL
    color: active && !unavailable ? Theme.blend(DashMetrics.cardColor, accent, 0.1) : DashMetrics.cardColor
    border.width: active && !unavailable ? 1 : 0
    border.color: Theme.withAlpha(accent, 0.25)

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
        }
    }

    Connections {
        target: HaService
        function onEntityUpdated(id) {
            if (id === root.entityId)
                root.st = HaService.get(id);
        }
        function onSetRevChanged() {
            root.st = HaService.get(root.entityId);
        }
    }
    onEntityIdChanged: st = HaService.get(entityId)

    function stateContent() {
        HaService.translationRev;
        if (config?.hide_state === true || !st)
            return st ? "" : "Not found";
        let list = config?.state_content;
        if (list === undefined || list === null)
            return Ha.secondaryText(entityId, st);
        if (!Array.isArray(list))
            list = [list];
        const parts = [];
        for (const key of list) {
            if (key === "state")
                parts.push(Ha.stateText(entityId, st));
            else if (key === "last_changed" || key === "last-changed")
                parts.push(Ha.relativeTime(st.last_changed));
            else if (key === "last_updated" || key === "last-updated")
                parts.push(Ha.relativeTime(st.last_updated));
            else if (st.attributes?.[key] !== undefined && st.attributes[key] !== null) {
                const v = st.attributes[key];
                parts.push(Ha.isNumeric(v) ? Ha.formatMeasure(v, 1) : Ha.translateAttribute(entityId, key, v));
            }
        }
        return parts.filter(p => p !== "").join(" · ");
    }

    // tap on the card (behind the icon)
    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse && mouse.button === Qt.RightButton)
                Lovelace.runAction(root.config?.hold_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx);
            else
                Lovelace.runAction(root.config?.tap_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx);
        }
    }

    Item {
        id: main
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        height: root.mainH

        IconBubble {
            id: bubble
            x: root.vertical ? (parent.width - width) / 2 : 0
            width: 40
            icon: root.config?.icon || Ha.iconName(root.entityId, root.st)
            accent: root.accent
            active: root.active || (!root.unavailable && root.accent !== Ha.inactiveColor)
            dimmed: root.unavailable
            clickable: !root.unavailable && (root.config?.icon_tap_action?.action ?? "") !== "none"
            onClicked: Lovelace.runAction(root.config?.icon_tap_action ?? Lovelace.defaultIconTapAction(root.entityId), root.entityId, root.ctx)
        }

        Column {
            id: texts
            x: root.vertical ? 0 : bubble.width + Theme.spacingM - 2
            y: root.vertical ? bubble.height + 4 : (bubble.height - height) / 2
            width: root.vertical ? parent.width : (inlineLoader.active ? inlineLoader.x - Theme.spacingS : parent.width) - x
            spacing: 1

            StyledText {
                width: parent.width
                horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
                text: Lovelace.nameOf(root.config, root.entityId)
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: root.unavailable ? Theme.withAlpha(Theme.surfaceText, 0.5) : Theme.surfaceText
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
                text: {
                    HaService.stateRev;
                    return root.stateContent();
                }
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Loader {
            id: inlineLoader
            active: root.inlineFeature && !root.vertical
            anchors.right: parent.right
            anchors.verticalCenter: bubble.verticalCenter
            width: root.features[0]?.type === "toggle" ? 64 : Math.min(parent.width * 0.5, 180)
            height: root.featureH
            sourceComponent: Feature {
                config: root.features[0]
                entityId: root.entityId
                st: root.st
                accent: root.featureAccent
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.pad
        // each feature sits in its own grid row, like HA
        spacing: root.bottomFeatures.length ? Math.max(Theme.spacingS, (root.height - root.pad * 2 - root.mainH - root.bottomFeatures.length * root.featureH) / root.bottomFeatures.length) : 0

        Repeater {
            model: root.bottomFeatures

            Feature {
                required property var modelData
                width: parent.width
                height: root.featureH
                config: modelData
                entityId: root.entityId
                st: root.st
                accent: root.featureAccent
            }
        }
    }
}
