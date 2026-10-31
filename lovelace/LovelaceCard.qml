import QtQuick
import ".."

// One Lovelace card: loads the renderer for config.type. The parent sets the
// size; implicitHeight is the card's natural height.
Item {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string type: String(config?.type ?? "")
    readonly property bool shown: Lovelace.isVisible(config)
    readonly property var grid: Lovelace.gridSize(config)

    visible: shown
    implicitHeight: shown && loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader
        anchors.fill: parent
        active: root.shown
        source: Lovelace.cardSource(root.type)
        onLoaded: {
            item.config = Qt.binding(() => root.config);
            item.ctx = Qt.binding(() => root.ctx);
        }
    }
}
