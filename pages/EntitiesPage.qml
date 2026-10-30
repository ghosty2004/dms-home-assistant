pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."
import "../components"

// Search across every entity, filtered by domain.
Item {
    id: root

    property string initialFilter: ""
    property string domainFilter: initialFilter
    property string query: ""

    readonly property int maxResults: 120

    signal moreInfo(string entityId)

    readonly property var pool: {
        Ha.index;
        if (domainFilter === "update") {
            const out = [];
            for (const id in HaService.states) {
                if (Ha.domainOf(id) === "update" && !Ha.isHiddenEntity(id))
                    out.push(id);
            }
            return out.sort((a, b) => (HaService.states[b].state === "on") - (HaService.states[a].state === "on"));
        }
        return Ha.visibleFilter(Ha.index.all);
    }
    readonly property var domainChips: {
        const counts = {};
        for (const id of Ha.visibleFilter(Ha.index.all)) {
            const d = Ha.domainOf(id);
            counts[d] = (counts[d] || 0) + 1;
        }
        const list = [
            {
                id: "",
                label: "All",
                icon: "mdi:select-all",
                count: Ha.visibleFilter(Ha.index.all).length
            }
        ];
        for (const d of Object.keys(counts).sort((a, b) => counts[b] - counts[a])) {
            list.push({
                id: d,
                label: Ha.capitalize(d),
                icon: Ha.fallbackIcons[d] ?? "mdi:bookmark",
                count: counts[d]
            });
        }
        list.push({
            id: "update",
            label: "Updates",
            icon: "mdi:package-up"
        });
        return list;
    }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        let ids = pool;
        if (domainFilter !== "" && domainFilter !== "update")
            ids = ids.filter(id => Ha.domainOf(id) === domainFilter);
        if (q !== "") {
            const terms = q.split(/\s+/);
            ids = ids.filter(id => {
                const st = HaService.states[id];
                const hay = (id + " " + Ha.entityName(id, st) + " " + Ha.areaName(HaService.areaIdOf(id))).toLowerCase();
                return terms.every(t => hay.includes(t));
            });
        }
        return ids;
    }
    readonly property var sections: {
        if (domainFilter === "update")
            return [
                {
                    title: "Updates",
                    icon: "mdi:package-up",
                    ids: results
                }
            ];
        return Ha.groupBySection(results.slice(0, root.maxResults));
    }

    Rectangle {
        id: search
        width: parent.width
        height: 42
        radius: height / 2
        color: DashMetrics.chipColor
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.primary

        MdiIcon {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            icon: "mdi:magnify"
            size: 20
            color: Theme.surfaceVariantText
        }

        TextInput {
            id: input
            anchors.left: searchIcon.right
            anchors.leftMargin: Theme.spacingS
            anchors.right: clearBtn.left
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSizeMedium
            font.family: Theme.fontFamily
            color: Theme.surfaceText
            selectionColor: Theme.primary
            selectedTextColor: Theme.onPrimary
            clip: true
            onTextChanged: debounce.restart()
            Keys.onEscapePressed: event => {
                if (text !== "") {
                    text = "";
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: "Search " + root.pool.length + " entities by name, area or id"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceVariantText, 0.8)
            }
        }

        MdiIcon {
            id: clearBtn
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            icon: "mdi:close-circle"
            size: 18
            visible: input.text !== ""
            color: Theme.surfaceVariantText

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: input.text = ""
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: input.forceActiveFocus()
        }
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: root.query = input.text
    }

    ChipBar {
        id: chips
        anchors.top: search.bottom
        anchors.topMargin: Theme.spacingS
        width: parent.width
        model: root.domainChips
        current: root.domainFilter
        onSelected: id => {
            root.domainFilter = id;
            flick.contentY = 0;
        }
    }

    DFlickable {
        id: flick
        anchors.top: chips.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: list.implicitHeight + Theme.spacingL + (more.visible ? more.height : 0)
        clip: true

        SectionList {
            id: list
            width: flick.width
            sections: root.sections
            onMoreInfo: id => root.moreInfo(id)
        }

        StyledText {
            id: more
            visible: root.results.length > root.maxResults
            y: list.implicitHeight + Theme.spacingM
            width: flick.width
            horizontalAlignment: Text.AlignHCenter
            text: "Showing " + root.maxResults + " of " + root.results.length + " — refine the search to see more"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            visible: root.results.length === 0
            y: 40
            width: flick.width
            horizontalAlignment: Text.AlignHCenter
            text: "No entities match"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
        }
    }
}
