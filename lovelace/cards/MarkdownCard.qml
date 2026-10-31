import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../.."

// Lovelace markdown card. Templates are rendered live by HA (render_template);
// if that is not allowed for the user, the raw content is shown.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string content: String(config?.content ?? "")
    readonly property bool hasTemplate: content.includes("{{") || content.includes("{%")
    property string rendered: ""
    property int _subId: -1

    implicitHeight: col.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadiusL
    color: config?.text_only ? "transparent" : DashMetrics.cardColor

    function _resubscribe() {
        HaService.unsubscribe(_subId);
        _subId = -1;
        rendered = content;
        if (!hasTemplate || !HaService.connected || !HaService.dashLive)
            return;
        _subId = HaService.subscribe({
            type: "render_template",
            template: content,
            strict: false,
            report_errors: false
        }, ev => {
            if (ev.result !== undefined)
                root.rendered = String(ev.result);
        }, (res, err) => {
            if (err)
                root.rendered = root.content;
        });
    }

    onContentChanged: Qt.callLater(_resubscribe)
    Component.onCompleted: _resubscribe()
    Component.onDestruction: HaService.unsubscribe(_subId)

    Connections {
        target: HaService
        function onConnectedChanged() {
            if (HaService.connected)
                Qt.callLater(root._resubscribe);
            else
                root._subId = -1;
        }
        function onDashLiveChanged() {
            Qt.callLater(root._resubscribe);
        }
    }

    Column {
        id: col
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        spacing: Theme.spacingS

        StyledText {
            visible: !!root.config?.title
            text: root.config?.title ?? ""
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            // HA markdown may contain <ha-icon> and other custom tags: drop them
            text: root.rendered.replace(/<ha-[^>]*>(<\/ha-[^>]*>)?/g, "").replace(/!\[[^\]]*\]\([^)]*\)/g, "")
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            onLinkActivated: link => Qt.openUrlExternally(/^https?:/.test(link) ? link : HaService.baseUrl + link)
        }
    }
}
