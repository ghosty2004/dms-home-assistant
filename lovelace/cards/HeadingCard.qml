pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../components"
import "../.."

// Lovelace heading card: title or subtitle, icon, entity badges on the right.
Item {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property bool isTitle: (config?.heading_style ?? "title") === "title"
    readonly property bool hasAction: (config?.tap_action?.action ?? "none") !== "none"
    readonly property var badges: (config?.badges ?? config?.entities ?? []).map(b => typeof b === "string" ? {
                entity: b
            } : b).filter(b => b && b.entity && Lovelace.isVisible(Object.assign({
                type: "badge"
            }, b)))

    implicitHeight: isTitle ? 40 : 30

    Row {
        id: headRow
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.right: badgeRow.left
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingS

        MdiIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.config?.icon
            icon: root.config?.icon ?? ""
            size: root.isTitle ? 22 : 18
            color: root.isTitle ? Theme.surfaceText : Theme.surfaceVariantText
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, headRow.width - x - (chevron.visible ? chevron.width + headRow.spacing : 0))
            text: root.config?.heading ?? ""
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: root.isTitle ? Theme.fontSizeXLarge : Theme.fontSizeMedium
            font.weight: root.isTitle ? Theme.fontWeightMedium : Font.Normal
            color: root.isTitle ? Theme.surfaceText : Theme.surfaceVariantText
        }
        MdiIcon {
            id: chevron
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasAction
            icon: "mdi:chevron-right"
            size: 20
            color: Theme.surfaceVariantText
        }
    }

    StateLayer {
        anchors.fill: headRow
        visible: root.hasAction
        cornerRadius: Theme.cornerRadiusS
        onClicked: Lovelace.runAction(root.config.tap_action, "", root.ctx)
    }

    Row {
        id: badgeRow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: Theme.spacingM

        Repeater {
            model: root.badges

            Item {
                id: hb
                required property var modelData
                readonly property string entityId: modelData.entity
                readonly property var st: {
                    HaService.stateRev;
                    return HaService.get(entityId);
                }
                width: hbRow.implicitWidth
                height: 24

                Row {
                    id: hbRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    MdiIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: hb.modelData.show_icon !== false
                        icon: hb.modelData.icon || Ha.iconName(hb.entityId, hb.st)
                        size: 16
                        color: Lovelace.color(hb.modelData.color, Ha.stateColor(hb.entityId, hb.st))
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: hb.modelData.show_state !== false
                        text: Ha.stateText(hb.entityId, hb.st)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    anchors.margins: -4
                    cornerRadius: Theme.cornerRadiusS
                    onClicked: Lovelace.runAction(hb.modelData.tap_action ?? Lovelace.defaultTapAction(hb.entityId), hb.entityId, root.ctx)
                }
            }
        }
    }
}
