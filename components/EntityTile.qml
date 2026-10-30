import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."

// HA "tile card": icon bubble (tap = toggle), name + state (tap = more info), optional feature row.
Rectangle {
    id: root

    property string entityId: ""
    property var stripPrefixes: []
    property bool showFeature: true
    property var st: HaService.get(entityId)
    property string nameOverride: ""

    readonly property string domain: Ha.domainOf(entityId)
    readonly property bool unavailable: !st || st.state === "unavailable"
    readonly property bool active: Ha.isActive(entityId, st)
    readonly property color accent: Ha.stateColor(entityId, st)
    readonly property string featureKind: showFeature ? Ha.featureKind(entityId, st) : ""
    readonly property bool favorite: HaService.favorites.includes(entityId)

    signal moreInfo(string entityId)

    readonly property real pad: 12
    implicitHeight: featureKind !== "" ? pad * 2 + 40 + Theme.spacingS + 40 : pad * 2 + 40
    radius: Theme.cornerRadiusL
    color: {
        const base = DashMetrics.cardColor;
        if (!active || unavailable)
            return base;
        return Theme.blend(base, accent, 0.1);
    }
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

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.moreInfo(root.entityId)
    }

    IconBubble {
        id: bubble
        x: root.pad
        y: root.pad
        width: 40
        icon: Ha.iconName(root.entityId, root.st)
        accent: root.accent
        active: root.active || (!root.unavailable && root.accent !== Ha.inactiveColor)
        dimmed: root.unavailable
        clickable: !root.unavailable && Ha.canToggle(root.entityId)
        onClicked: Ha.toggle(root.entityId)
    }

    Column {
        anchors.left: bubble.right
        anchors.leftMargin: Theme.spacingM - 2
        anchors.right: star.visible ? star.left : parent.right
        anchors.rightMargin: root.pad
        anchors.verticalCenter: bubble.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            text: root.nameOverride || Ha.entityName(root.entityId, root.st, root.stripPrefixes)
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: root.unavailable ? Theme.withAlpha(Theme.surfaceText, 0.5) : Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: {
                HaService.translationRev;
                return Ha.secondaryText(root.entityId, root.st);
            }
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    MdiIcon {
        id: star
        visible: root.favorite
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.verticalCenter: bubble.verticalCenter
        icon: "mdi:star"
        size: Theme.iconSizeSmall
        color: Theme.withAlpha(Theme.primary, 0.7)
    }

    TileFeature {
        visible: root.featureKind !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.pad
        height: 40
        entityId: root.entityId
        st: root.st
        kind: root.featureKind
        accent: root.unavailable || root.accent === Ha.inactiveColor ? Theme.primary : root.accent
    }
}
