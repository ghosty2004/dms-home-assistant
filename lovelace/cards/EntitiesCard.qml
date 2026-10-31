pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."
import ".."

// Lovelace entities card: optional title, then one row per entity.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property var rows: Lovelace.entityRows(config?.entities).filter(r => r.type || Lovelace.isVisible(Object.assign({
            type: "row"
        }, r)))

    implicitHeight: col.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    Column {
        id: col
        x: Theme.spacingL
        y: Theme.spacingM
        width: parent.width - Theme.spacingL * 2

        Row {
            visible: !!root.config?.title
            height: 40
            spacing: Theme.spacingS

            MdiIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.config?.icon
                icon: root.config?.icon ?? ""
                size: 20
                color: Theme.surfaceText
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.config?.title ?? ""
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
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
                stateColor: root.config?.state_color === true || modelData.state_color === true
            }
        }
    }
}
