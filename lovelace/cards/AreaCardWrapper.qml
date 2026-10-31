import QtQuick
import "../../components"
import "../.."

// Lovelace area card: the area card of the Areas page.
Item {
    id: root

    property var config: ({})
    property var ctx: null

    implicitHeight: card.implicitHeight

    AreaCard {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        area: HaService.areas.find(a => a.area_id === root.config?.area) ?? null
        onOpen: areaId => {
            if (root.ctx)
                root.ctx.openPage("areas", areaId);
        }
        onMoreInfo: id => {
            if (root.ctx)
                root.ctx.moreInfo(id);
        }
    }
}
