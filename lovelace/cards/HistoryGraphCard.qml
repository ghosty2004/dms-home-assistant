pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../../moreinfo"
import "../.."

// Lovelace history-graph and statistics-graph cards: one history chart per entity.
Column {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property var ids: Lovelace.entityRows(config?.entities).map(e => e.entity).filter(id => !!id && HaService.get(id))
    readonly property int hours: Number(config?.hours_to_show ?? (config?.days_to_show ? config.days_to_show * 24 : 24))

    spacing: Theme.spacingS

    StyledText {
        visible: !!root.config?.title
        text: root.config?.title ?? ""
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    Repeater {
        model: root.ids

        HistoryGraph {
            required property string modelData
            width: root.width
            entityId: modelData
            hours: root.hours
            accent: Ha.stateColor(modelData, HaService.get(modelData)) === Ha.inactiveColor ? Theme.primary : Ha.stateColor(modelData, HaService.get(modelData))
        }
    }
}
