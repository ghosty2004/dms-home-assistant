pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../.."
import ".."

// Lovelace grid, vertical-stack and horizontal-stack cards.
Item {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string type: config?.type ?? "grid"
    readonly property var cards: (config?.cards ?? []).filter(c => !!c)
    readonly property int columns: type === "vertical-stack" ? 1 : type === "horizontal-stack" ? Math.max(1, cards.length) : Math.max(1, Number(config?.columns ?? 3))
    readonly property bool square: type === "grid" && config?.square !== false
    readonly property real gap: Lovelace.gap
    readonly property real titleHeight: config?.title ? 36 : 0
    property real _height: 0

    implicitHeight: titleHeight + _height

    onWidthChanged: relayout()
    onCardsChanged: relayout()
    Component.onCompleted: relayout()

    function relayout() {
        Qt.callLater(root._layout);
    }

    function _layout() {
        const cw = (width - gap * (columns - 1)) / columns;
        let idx = 0;
        let y = titleHeight;
        let rowItems = [];
        const flush = () => {
            let h = 0;
            for (const it of rowItems)
                h = Math.max(h, square ? cw : it.implicitHeight);
            for (const it of rowItems)
                it.height = h;
            if (rowItems.length)
                y += h + gap;
            rowItems = [];
        };
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (!it || !it.shown)
                continue;
            const c = idx % columns;
            if (c === 0)
                flush();
            for (const other of rowItems)
                other.y = y;
            it.x = c * (cw + gap);
            it.y = y;
            it.width = cw;
            rowItems.push(it);
            idx++;
        }
        flush();
        _height = Math.max(0, y - gap - titleHeight);
    }

    StyledText {
        visible: !!root.config?.title
        height: root.titleHeight
        verticalAlignment: Text.AlignVCenter
        text: root.config?.title ?? ""
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    Repeater {
        id: rep
        model: root.cards

        LovelaceCard {
            required property var modelData
            config: modelData
            ctx: root.ctx
            onImplicitHeightChanged: root.relayout()
            onShownChanged: root.relayout()
        }
    }
}
