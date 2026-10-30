pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."
import "../components"

Item {
    id: root

    property string areaId: ""

    signal moreInfo(string entityId)

    readonly property var chips: {
        Ha.index;
        const list = HaService.areas.map(a => ({
                    id: a.area_id,
                    label: a.name,
                    icon: Ha.areaIcon(a),
                    count: Ha.visibleFilter(Ha.index.byArea[a.area_id] ?? []).length
                }));
        const un = Ha.visibleFilter(Ha.index.byArea[""] ?? []);
        if (un.length)
            list.push({
                id: "__none",
                label: "Unassigned",
                icon: "mdi:home-outline",
                count: un.length
            });
        return list;
    }
    property string current: areaId !== "" ? areaId : (chips[0]?.id ?? "")
    readonly property var area: HaService.area(current)
    readonly property var ids: Ha.visibleFilter(Ha.index.byArea[current === "__none" ? "" : current] ?? [])
    readonly property var sections: Ha.groupBySection(ids).map(s => {
        if (s.title === "Lights")
            return Object.assign({}, s, {
                actionIcon: "mdi:lightbulb-off-outline",
                actionText: "All off"
            });
        return s;
    })

    ChipBar {
        id: chipBar
        width: parent.width
        model: root.chips
        current: root.current
        onSelected: id => {
            root.current = id;
            flick.contentY = 0;
        }
    }

    DFlickable {
        id: flick
        anchors.top: chipBar.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: list.implicitHeight + Theme.spacingL
        clip: true

        SectionList {
            id: list
            width: flick.width
            sections: root.sections
            stripPrefixes: root.area ? [root.area.name] : []
            onMoreInfo: id => root.moreInfo(id)
            onSectionAction: section => {
                if (section.title === "Lights")
                    HaService.callService("light", "turn_off", {}, {
                        entity_id: section.ids
                    });
            }
        }

        StyledText {
            visible: root.ids.length === 0
            width: flick.width
            horizontalAlignment: Text.AlignHCenter
            y: 40
            text: "No devices in this area"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }
    }
}
