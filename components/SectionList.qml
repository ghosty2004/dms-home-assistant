pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// A list of titled sections, each one a tile grid.
Column {
    id: root

    property var sections: []
    property var stripPrefixes: []

    signal moreInfo(string entityId)
    signal sectionAction(var section)

    spacing: Theme.spacingL

    Repeater {
        model: root.sections

        Column {
            id: sectionCol
            required property var modelData
            width: root.width
            spacing: Theme.spacingS

            SectionHeader {
                icon: sectionCol.modelData.icon ?? ""
                title: sectionCol.modelData.title
                subtitle: sectionCol.modelData.subtitle ?? (sectionCol.modelData.ids.length + "")
                actionIcon: sectionCol.modelData.actionIcon ?? ""
                actionText: sectionCol.modelData.actionText ?? ""
                onActionClicked: root.sectionAction(sectionCol.modelData)
            }

            TileGrid {
                width: parent.width
                ids: sectionCol.modelData.ids
                stripPrefixes: (sectionCol.modelData.stripPrefixes ?? []).concat(root.stripPrefixes)
                onMoreInfo: id => root.moreInfo(id)
            }
        }
    }
}
