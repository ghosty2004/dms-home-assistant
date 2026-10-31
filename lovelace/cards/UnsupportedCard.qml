import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."

// Placeholder for custom cards and card types that are not rendered here.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string type: String(config?.type ?? "")
    readonly property bool custom: type.startsWith("custom:")
    readonly property string title: config?.title || config?.card_header || config?.name || ""

    implicitHeight: col.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadiusL
    color: "transparent"
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, 0.3)

    Column {
        id: col
        anchors.centerIn: parent
        width: parent.width - Theme.spacingL * 2
        spacing: Theme.spacingS

        MdiIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.custom ? "mdi:puzzle-outline" : "mdi:card-bulleted-off-outline"
            size: 28
            color: Theme.surfaceVariantText
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.title !== ""
            text: root.title
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.custom ? "Custom card " + root.type.slice(7) + " is only shown in Home Assistant" : "The " + (root.type || "unknown") + " card is not supported here yet"
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        FeatureButton {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 34
            width: 190
            icon: "mdi:open-in-new"
            text: "Open in Home Assistant"
            onClicked: {
                if (root.ctx)
                    root.ctx.openInBrowser();
            }
        }
    }
}
