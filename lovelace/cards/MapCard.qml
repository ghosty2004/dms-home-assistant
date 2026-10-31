pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."
import ".."

// Lovelace map card: the tracked entities with their zone, and a link to the
// same view in Home Assistant, where the map is drawn.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property var rows: Lovelace.entityRows(config?.entities).filter(e => !!e.entity && HaService.get(e.entity))

    implicitHeight: col.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    Column {
        id: col
        x: Theme.spacingL
        y: Theme.spacingM
        width: parent.width - Theme.spacingL * 2

        Item {
            width: parent.width
            height: 44

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                MdiIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "mdi:map"
                    size: 20
                    color: Theme.surfaceText
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.config?.title || "Map"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }
            }
            FeatureButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                icon: "mdi:open-in-new"
                text: "Open map"
                // the view this card is on: recent HA versions have no /map panel
                onClicked: {
                    if (root.ctx)
                        root.ctx.openInBrowser();
                    else
                        Qt.openUrlExternally(HaService.baseUrl);
                }
            }
        }

        Repeater {
            model: root.rows

            EntityRow {
                required property var modelData
                width: col.width
                height: implicitHeight
                config: modelData
                ctx: root.ctx
                stateColor: true
            }
        }
    }
}
