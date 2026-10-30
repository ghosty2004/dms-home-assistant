pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// Masonry grid of entity tiles: each tile goes to the shortest column.
Item {
    id: root

    property var ids: []
    property var stripPrefixes: []
    property real minTileWidth: 200
    property int maxColumns: 4
    property real gap: Theme.spacingS
    property bool showFeatures: true

    signal moreInfo(string entityId)

    property var _model: []
    readonly property int columns: Math.max(1, Math.min(maxColumns, Math.floor((width + gap) / (minTileWidth + gap))))
    readonly property real tileWidth: Math.max(0, (width - gap * (columns - 1)) / columns)

    implicitHeight: 0

    onIdsChanged: {
        const next = ids || [];
        if (JSON.stringify(next) !== JSON.stringify(_model))
            _model = next.slice();
    }
    Component.onCompleted: _model = (ids || []).slice()
    onWidthChanged: relayout()
    onColumnsChanged: relayout()

    function relayout() {
        Qt.callLater(doLayout);
    }

    function doLayout() {
        const heights = new Array(columns).fill(0);
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (!item)
                continue;
            let col = 0;
            for (let c = 1; c < columns; c++) {
                if (heights[c] < heights[col] - 0.5)
                    col = c;
            }
            item.x = col * (tileWidth + gap);
            item.y = heights[col];
            heights[col] += item.implicitHeight + gap;
        }
        implicitHeight = Math.max(0, heights.reduce((m, h) => Math.max(m, h), 0) - gap);
    }

    Repeater {
        id: repeater
        model: root._model
        onCountChanged: root.relayout()

        EntityTile {
            required property var modelData
            entityId: modelData
            width: root.tileWidth
            height: implicitHeight
            stripPrefixes: root.stripPrefixes
            showFeature: root.showFeatures
            onImplicitHeightChanged: root.relayout()
            onMoreInfo: id => root.moreInfo(id)
            Component.onCompleted: root.relayout()
        }
    }
}
