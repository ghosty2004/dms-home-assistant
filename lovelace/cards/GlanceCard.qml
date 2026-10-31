pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."

// Lovelace glance card: a grid of entities with name, icon and state.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property var items: Lovelace.entityRows(config?.entities).filter(e => Lovelace.isVisible(Object.assign({
            type: "glance-entity"
        }, e)))
    readonly property int columns: Math.max(1, Number(config?.columns ?? Math.min(items.length, 5)))

    implicitHeight: col.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    Column {
        id: col
        x: Theme.spacingM
        y: Theme.spacingM
        width: parent.width - Theme.spacingM * 2
        spacing: Theme.spacingS

        StyledText {
            visible: !!root.config?.title
            x: Theme.spacingS
            text: root.config?.title ?? ""
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }

        Grid {
            columns: root.columns
            width: parent.width

            Repeater {
                model: root.items

                Item {
                    id: g
                    required property var modelData
                    readonly property string entityId: modelData.entity ?? ""
                    readonly property var st: {
                        HaService.stateRev;
                        return HaService.get(entityId);
                    }
                    width: col.width / root.columns
                    height: gCol.implicitHeight + Theme.spacingS * 2

                    StateLayer {
                        anchors.fill: parent
                        cornerRadius: Theme.cornerRadiusM
                        onClicked: Lovelace.runAction(g.modelData.tap_action ?? root.config?.tap_action ?? Lovelace.defaultTapAction(g.entityId), g.entityId, root.ctx)
                    }

                    Column {
                        id: gCol
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingXS * 2
                        spacing: 4

                        StyledText {
                            width: parent.width
                            visible: root.config?.show_name !== false && g.modelData.show_name !== false
                            horizontalAlignment: Text.AlignHCenter
                            text: Lovelace.nameOf(g.modelData, g.entityId)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                        MdiIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.config?.show_icon !== false && g.modelData.show_icon !== false
                            icon: g.modelData.icon || Ha.iconName(g.entityId, g.st)
                            size: 26
                            color: root.config?.state_color !== false && Ha.isActive(g.entityId, g.st) ? Ha.stateColor(g.entityId, g.st) : Theme.primary
                        }
                        StyledText {
                            width: parent.width
                            visible: root.config?.show_state !== false && g.modelData.show_state !== false
                            horizontalAlignment: Text.AlignHCenter
                            text: Ha.stateText(g.entityId, g.st)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }
}
