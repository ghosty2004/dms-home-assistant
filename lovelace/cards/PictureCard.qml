import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."

// Lovelace picture-entity, picture-glance and picture cards. Cameras use the
// camera card (live video with camera_view: live), other entities their picture.
Item {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config)
    readonly property string cameraId: {
        const c = config?.camera_image;
        if (typeof c === "string" && c.startsWith("camera.") && HaService.get(c))
            return c;
        return Ha.domainOf(entityId) === "camera" ? entityId : "";
    }
    readonly property var st: {
        HaService.stateRev;
        return HaService.get(entityId);
    }
    readonly property string image: {
        const img = config?.image;
        if (typeof img === "string" && img !== "")
            return HaService.mediaUrl(img);
        const pic = st?.attributes?.entity_picture;
        return pic ? HaService.mediaUrl(pic) : "";
    }
    readonly property real ratio: {
        const r = String(config?.aspect_ratio ?? "");
        const m = r.match(/^(\d+(?:\.\d+)?)\s*[:x]\s*(\d+(?:\.\d+)?)$/);
        if (m)
            return Number(m[2]) / Number(m[1]);
        if (r.endsWith("%"))
            return Number(r.slice(0, -1)) / 100;
        return 9 / 16;
    }

    implicitHeight: cameraId !== "" ? camera.implicitHeight : width * ratio

    CameraCard {
        id: camera
        visible: root.cameraId !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: width * root.ratio
        height: implicitHeight
        entityId: root.cameraId
        stream: root.config?.camera_view === "live"
        live: visible && HaService.dashLive
        onMoreInfo: id => {
            if (root.ctx)
                Lovelace.runAction(root.config?.tap_action ?? Lovelace.defaultTapAction(root.entityId || id), root.entityId || id, root.ctx);
        }
    }

    Rectangle {
        visible: root.cameraId === ""
        anchors.fill: parent
        radius: Theme.cornerRadiusL
        color: DashMetrics.cardColor
        clip: true

        Image {
            anchors.fill: parent
            source: root.image
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            visible: root.entityId !== "" && (root.config?.show_name !== false || root.config?.show_state !== false)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 40
            color: Theme.withAlpha(Theme.scrimColor, 0.55)

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: root.config?.show_name !== false
                text: Lovelace.nameOf(root.config, root.entityId)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.isLightMode ? Theme.background : Theme.surfaceText
            }
            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: root.config?.show_state !== false
                text: Ha.stateText(root.entityId, root.st)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.isLightMode ? Theme.background : Theme.surfaceText
            }
        }

        StateLayer {
            anchors.fill: parent
            cornerRadius: Theme.cornerRadiusL
            onClicked: Lovelace.runAction(root.config?.tap_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx)
        }
    }
}
