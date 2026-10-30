import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."

// Camera snapshot that refreshes while visible (HA picture entity card).
Rectangle {
    id: root

    property string entityId: ""
    property var st: HaService.get(entityId)
    property int refreshInterval: 10000
    property bool live: visible && HaService.dashLive
    property real stamp: Date.now()

    readonly property bool unavailable: !st || st.state === "unavailable"
    readonly property string picture: st?.attributes?.entity_picture ?? ""

    signal moreInfo(string entityId)

    implicitHeight: width * 9 / 16
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor
    clip: true

    Connections {
        target: HaService
        function onEntityUpdated(id) {
            if (id === root.entityId)
                root.st = HaService.get(id);
        }
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.live && !root.unavailable
        onTriggered: root.stamp = Date.now()
    }

    // Double buffered so the picture doesn't flash on refresh.
    Image {
        id: shown
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
    }

    Image {
        id: loading
        anchors.fill: parent
        visible: false
        asynchronous: true
        cache: false
        source: root.picture && !root.unavailable && root.live ? HaService.mediaUrl(root.picture) + (root.picture.includes("?") ? "&" : "?") + "_t=" + root.stamp : ""
        onStatusChanged: {
            if (status === Image.Ready)
                shown.source = source;
        }
    }

    Column {
        anchors.centerIn: parent
        visible: shown.status !== Image.Ready
        spacing: Theme.spacingS

        MdiIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.unavailable ? "mdi:video-off" : "mdi:video"
            size: 36
            color: Theme.surfaceVariantText
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.unavailable ? "Unavailable" : "Loading…"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 40
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(Theme.scrimColor, 0.65)
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 4
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: root.unavailable ? Ha.palette.grey : Ha.palette.red
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Ha.entityName(root.entityId, root.st)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.isLightMode ? Theme.background : Theme.surfaceText
            }
        }
    }

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        onClicked: root.moreInfo(root.entityId)
    }
}
