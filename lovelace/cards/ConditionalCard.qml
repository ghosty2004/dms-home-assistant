import QtQuick
import ".."

// Lovelace conditional card. Lovelace.isVisible checks the conditions, so this
// only renders the inner card.
Item {
    id: root

    property var config: ({})
    property var ctx: null

    implicitHeight: inner.implicitHeight

    LovelaceCard {
        id: inner
        anchors.fill: parent
        config: root.config?.card ?? null
        ctx: root.ctx
    }
}
