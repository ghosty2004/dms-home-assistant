pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "../components"
import ".."

// One Lovelace view: badges, then the cards laid out like the view type
// (sections, masonry, panel or sidebar).
Item {
    id: root

    property var view: null
    property var ctx: null

    readonly property string type: view?.type ?? (view?.sections ? "sections" : "masonry")
    readonly property var badges: (view?.badges ?? []).map(b => typeof b === "string" ? {
                type: "entity",
                entity: b
            } : b).filter(b => b && (b.type ?? "entity") === "entity" && Lovelace.isVisible(b) && HaService.get(b.entity))

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Theme.spacingL

        // view badges, centered like HA
        Item {
            width: parent.width
            height: badgeFlow.implicitHeight
            visible: root.badges.length > 0

            Flow {
                id: badgeFlow
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, implicitWidthHint)
                spacing: Theme.spacingS
                readonly property real implicitWidthHint: {
                    let w = 0;
                    for (let i = 0; i < badgeRep.count; i++)
                        w += (badgeRep.itemAt(i)?.width ?? 0) + spacing;
                    return Math.max(0, w - spacing);
                }

                Repeater {
                    id: badgeRep
                    model: root.badges

                    BadgeChip {
                        id: badge
                        required property var modelData
                        readonly property string entityId: modelData.entity
                        readonly property var st: {
                            HaService.stateRev;
                            return HaService.get(entityId);
                        }
                        icon: modelData.icon || Ha.iconName(entityId, st)
                        label: modelData.show_name === true ? Lovelace.nameOf(modelData, entityId) : ""
                        value: modelData.show_state === false ? (modelData.show_name === false ? "" : Lovelace.nameOf(modelData, entityId)) : Ha.stateText(entityId, st)
                        accent: Lovelace.color(modelData.color, Ha.stateColor(entityId, st))
                        onClicked: Lovelace.runAction(modelData.tap_action ?? Lovelace.defaultTapAction(entityId), entityId, root.ctx)
                    }
                }
            }
        }

        Loader {
            width: parent.width
            sourceComponent: root.type === "sections" ? sectionsView : root.type === "panel" ? panelView : masonryView
        }
    }

    // ------------------------------------------------ sections view
    Component {
        id: sectionsView

        Item {
            id: sv
            readonly property real minColumn: 320
            readonly property real colGap: Theme.spacingL
            readonly property int columns: Math.max(1, Math.min(root.view?.max_columns ?? 4, Math.floor((width + colGap) / (minColumn + colGap))))
            readonly property var sections: (root.view?.sections ?? []).filter(s => Lovelace.isVisible(Object.assign({
                    type: "section"
                }, s)))
            property real _height: 0

            implicitHeight: _height
            onWidthChanged: relayout()
            onColumnsChanged: relayout()
            onSectionsChanged: relayout()

            function relayout() {
                Qt.callLater(sv._layout);
            }

            // CSS grid: sections fill rows left to right, a row is as tall as its tallest section
            function _layout() {
                const cw = (width - colGap * (columns - 1)) / columns;
                let c = 0;
                let y = 0;
                let rowH = 0;
                for (let i = 0; i < secRep.count; i++) {
                    const it = secRep.itemAt(i);
                    if (!it)
                        continue;
                    const span = Math.min(columns, it.span);
                    if (c + span > columns) {
                        y += rowH + Theme.spacingXL;
                        c = 0;
                        rowH = 0;
                    }
                    it.x = c * (cw + colGap);
                    it.y = y;
                    it.width = span * cw + (span - 1) * colGap;
                    rowH = Math.max(rowH, it.implicitHeight);
                    c += span;
                }
                _height = y + rowH;
            }

            Repeater {
                id: secRep
                model: sv.sections

                CardGrid {
                    required property var modelData
                    readonly property int span: Math.max(1, modelData.column_span ?? 1)
                    cards: modelData.type === "grid" || modelData.cards ? (modelData.cards ?? []) : []
                    ctx: root.ctx
                    onImplicitHeightChanged: sv.relayout()
                }
            }
        }
    }

    // ------------------------------------------------ panel view: first card, full width
    Component {
        id: panelView

        LovelaceCard {
            config: (root.view?.cards ?? [])[0] ?? null
            ctx: root.ctx
            height: implicitHeight
        }
    }

    // ------------------------------------------------ masonry / sidebar: cards in balanced columns
    Component {
        id: masonryView

        Item {
            id: mv
            readonly property int columns: {
                let n = 1;
                for (const bp of [500, 1000, 1500, 1800])
                    if (width > bp)
                        n++;
                return Math.max(1, Math.min(root.view?.max_columns ?? 4, n));
            }
            readonly property var cards: (root.view?.cards ?? []).filter(c => !!c)
            property real _height: 0

            implicitHeight: _height
            onWidthChanged: relayout()
            onColumnsChanged: relayout()
            onCardsChanged: relayout()

            function relayout() {
                Qt.callLater(mv._layout);
            }

            function _layout() {
                const gap = Theme.spacingS;
                const cw = (width - gap * (columns - 1)) / columns;
                const heights = [];
                for (let k = 0; k < columns; k++)
                    heights.push(0);
                for (let i = 0; i < cardRep.count; i++) {
                    const it = cardRep.itemAt(i);
                    if (!it || !it.shown)
                        continue;
                    let best = 0;
                    for (let k = 1; k < columns; k++)
                        if (heights[k] < heights[best] - 1)
                            best = k;
                    it.x = best * (cw + gap);
                    it.y = heights[best];
                    it.width = cw;
                    it.height = it.implicitHeight;
                    heights[best] += it.implicitHeight + gap;
                }
                _height = Math.max(0, Math.max.apply(null, heights) - gap);
            }

            Repeater {
                id: cardRep
                model: mv.cards

                LovelaceCard {
                    required property var modelData
                    config: modelData
                    ctx: root.ctx
                    onImplicitHeightChanged: mv.relayout()
                    onShownChanged: mv.relayout()
                }
            }
        }
    }
}
