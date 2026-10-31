import QtQuick
import "../../components"
import "../.."

// Lovelace media control card: the media card of the Media page.
Item {
    id: root

    property var config: ({})
    property var ctx: null

    implicitHeight: media.implicitHeight

    MediaCard {
        id: media
        anchors.left: parent.left
        anchors.right: parent.right
        entityId: Lovelace.entityOf(root.config)
        onMoreInfo: id => {
            if (root.ctx)
                root.ctx.moreInfo(id);
        }
    }
}
