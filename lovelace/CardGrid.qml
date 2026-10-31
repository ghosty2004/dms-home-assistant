pragma ComponentBehavior: Bound

import QtQuick
import ".."

// 12-column section grid of the sections view. Cards span grid_options
// columns; fixed-row cards get rows * 56 px, "auto" cards their natural
// height, and rows grow to their content like the CSS grid in HA.
Item {
    id: root

    property var cards: []
    property var ctx: null
    property real _height: 0

    implicitHeight: _height

    onWidthChanged: relayout()
    onCardsChanged: relayout()
    Component.onCompleted: relayout()

    function relayout() {
        Qt.callLater(root._layout);
    }

    function _layout() {
        const W = width;
        if (W <= 0)
            return;
        const cols = Lovelace.gridColumns;
        const gap = Lovelace.gap;
        const cw = (W - gap * (cols - 1)) / cols;
        const occ = [];
        const free = (r, c, span, rows) => {
            for (let rr = r; rr < r + rows; rr++)
                for (let cc = c; cc < c + span; cc++)
                    if (occ[rr] && occ[rr][cc])
                        return false;
            return true;
        };
        const placed = [];
        let curR = 0;
        let curC = 0;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (!it || !it.shown)
                continue;
            const span = Math.min(cols, it.grid.columns);
            const fixed = it.grid.rows > 0;
            const rows = fixed ? it.grid.rows : 1;
            let r = curR;
            let c = curC;
            while (true) {
                if (c + span > cols) {
                    r++;
                    c = 0;
                    continue;
                }
                if (free(r, c, span, rows))
                    break;
                c++;
            }
            for (let rr = r; rr < r + rows; rr++) {
                if (!occ[rr])
                    occ[rr] = [];
                for (let cc = c; cc < c + span; cc++)
                    occ[rr][cc] = true;
            }
            placed.push({
                item: it,
                r: r,
                c: c,
                span: span,
                rows: rows,
                h: fixed ? Lovelace.rowsHeight(rows) : it.implicitHeight
            });
            curR = r;
            curC = c + span;
        }
        // row heights: single-row items first, then spread taller spans
        const rowH = [];
        for (let r = 0; r < occ.length; r++)
            rowH.push(0);
        for (const p of placed)
            if (p.rows === 1)
                rowH[p.r] = Math.max(rowH[p.r], p.h);
        for (const p of placed) {
            if (p.rows === 1)
                continue;
            let sum = gap * (p.rows - 1);
            for (let k = 0; k < p.rows; k++)
                sum += rowH[p.r + k];
            if (p.h > sum) {
                const extra = (p.h - sum) / p.rows;
                for (let k = 0; k < p.rows; k++)
                    rowH[p.r + k] += extra;
            }
        }
        const rowY = [];
        let y = 0;
        for (let r = 0; r < rowH.length; r++) {
            rowY.push(y);
            y += rowH[r] + (rowH[r] > 0 ? gap : 0);
        }
        for (const p of placed) {
            p.item.x = p.c * (cw + gap);
            p.item.y = rowY[p.r];
            p.item.width = p.span * cw + (p.span - 1) * gap;
            const spanH = rowY[p.r + p.rows - 1] + rowH[p.r + p.rows - 1] - rowY[p.r];
            p.item.height = p.item.grid.rows > 0 ? p.h : Math.max(p.h, spanH);
        }
        _height = Math.max(0, y - gap);
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
