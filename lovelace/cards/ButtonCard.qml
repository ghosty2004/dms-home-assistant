import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."

// Lovelace button card: big icon, name and optional state; tap toggles.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config)
    readonly property var st: {
        HaService.stateRev;
        return entityId ? HaService.get(entityId) : null;
    }
    readonly property bool active: entityId !== "" && Ha.isActive(entityId, st)
    readonly property color accent: Lovelace.color(config?.color, entityId ? Ha.stateColor(entityId, st) : Theme.primary)

    implicitHeight: 120
    radius: Theme.cornerRadiusL
    color: active ? Theme.blend(DashMetrics.cardColor, accent, 0.1) : DashMetrics.cardColor

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse && mouse.button === Qt.RightButton)
                Lovelace.runAction(root.config?.hold_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx);
            else
                Lovelace.runAction(root.config?.tap_action ?? (Ha.canToggle(root.entityId) ? {
                    action: "toggle"
                } : Lovelace.defaultTapAction(root.entityId)), root.entityId, root.ctx);
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.spacingL * 2
        spacing: Theme.spacingXS

        MdiIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.config?.show_icon !== false
            icon: root.config?.icon || (root.entityId ? Ha.iconName(root.entityId, root.st) : "mdi:gesture-tap-button")
            size: Math.max(24, Math.min(56, root.height * 0.38))
            color: root.active || !root.entityId ? root.accent : Theme.surfaceVariantText
        }
        StyledText {
            width: parent.width
            visible: root.config?.show_name !== false
            horizontalAlignment: Text.AlignHCenter
            text: Lovelace.nameOf(root.config, root.entityId)
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            visible: root.config?.show_state === true && root.entityId !== ""
            horizontalAlignment: Text.AlignHCenter
            text: Ha.stateText(root.entityId, root.st)
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
