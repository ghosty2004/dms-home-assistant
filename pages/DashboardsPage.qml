pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import ".."
import "../components"
import "../lovelace"

// The user's own Lovelace dashboards: dashboard and view chips, then the view
// rendered with the same card types and layout as in Home Assistant.
DFlickable {
    id: root

    property string initialPath: ""

    signal moreInfo(string entityId)
    signal openPage(string page, string arg)

    property string dashboard: ""
    property string viewKey: ""

    readonly property var config: {
        HaService.lovelaceRev;
        return dashboard ? HaService.lovelace[dashboard] : undefined;
    }
    readonly property var views: (config?.views ?? []).filter(v => Lovelace.viewVisible(v) && !v.subview)
    readonly property var allViews: config?.views ?? []
    readonly property int viewIndex: {
        const i = allViews.findIndex((v, idx) => root.keyOf(v, idx) === viewKey);
        return i >= 0 ? i : allViews.indexOf(views[0]);
    }
    readonly property var view: viewIndex >= 0 ? allViews[viewIndex] : null

    contentWidth: width
    contentHeight: column.implicitHeight + Theme.spacingL
    clip: true

    function keyOf(v, idx) {
        return v?.path ? String(v.path) : String(idx);
    }

    function selectDashboard(path) {
        dashboard = path;
        viewKey = "";
        HaService.lovelaceDashboard = path;
        if (HaService.lovelace[path] === undefined)
            HaService.loadLovelace(path);
        contentY = 0;
    }

    function selectView(key) {
        viewKey = key;
        HaService.lovelaceView = key;
        contentY = 0;
    }

    // "/dashboard-home/bedroom", "bedroom" or "/lovelace/0"; anything else opens in the browser
    property string _pendingPath: ""

    function openPath(path) {
        const p = String(path ?? "");
        if (!HaService.dashboardsLoaded) {
            _pendingPath = p;
            return;
        }
        const parts = p.replace(/^\/+/, "").split("/");
        if (!p.startsWith("/") && parts.length === 1) {
            selectView(parts[0]);
            return;
        }
        const dash = HaService.dashboards.find(d => d.urlPath === parts[0]);
        if (dash) {
            if (dash.urlPath !== dashboard)
                selectDashboard(dash.urlPath);
            if (parts[1])
                selectView(parts[1]);
            return;
        }
        Qt.openUrlExternally(HaService.baseUrl + (p.startsWith("/") ? p : "/" + p));
    }

    // Opens the last dashboard, or the first one that isn't the generated default.
    function ensureDashboard() {
        if (dashboard !== "" || !HaService.dashboards.length)
            return;
        const last = HaService.dashboards.find(d => d.urlPath === HaService.lovelaceDashboard);
        if (last) {
            const view = HaService.lovelaceView;
            selectDashboard(last.urlPath);
            viewKey = view;
            return;
        }
        const first = HaService.dashboards.find(d => d.urlPath !== "lovelace") ?? HaService.dashboards[0];
        selectDashboard(first.urlPath);
    }

    Component.onCompleted: {
        // refresh the list each time the page opens
        HaService.loadDashboards();
        if (initialPath !== "")
            Qt.callLater(() => root.openPath("/" + root.initialPath));
        else
            ensureDashboard();
    }

    onInitialPathChanged: {
        if (initialPath !== "")
            Qt.callLater(() => root.openPath("/" + root.initialPath));
    }

    Connections {
        target: HaService
        function onDashboardsChanged() {
            if (root._pendingPath !== "") {
                const p = root._pendingPath;
                root._pendingPath = "";
                root.openPath(p);
            }
            root.ensureDashboard();
        }
    }

    QtObject {
        id: lovelaceCtx
        function moreInfo(id) {
            root.moreInfo(id);
        }
        function navigate(path) {
            root.openPath(path);
        }
        function openPage(page, arg) {
            root.openPage(page, arg);
        }
        function openInBrowser() {
            const v = root.view ? "/" + root.keyOf(root.view, root.viewIndex) : "";
            Qt.openUrlExternally(HaService.baseUrl + "/" + root.dashboard + v);
        }
    }

    Column {
        id: column
        width: root.width
        spacing: Theme.spacingM

        ChipBar {
            width: parent.width
            visible: HaService.dashboards.length > 1
            model: HaService.dashboards.map(d => ({
                        id: d.urlPath,
                        label: d.title,
                        icon: d.icon
                    }))
            current: root.dashboard
            onSelected: id => root.selectDashboard(id)
        }

        ChipBar {
            width: parent.width
            visible: root.views.length > 1
            model: root.views.map(v => ({
                        id: root.keyOf(v, root.allViews.indexOf(v)),
                        label: v.title ?? "",
                        icon: v.icon ?? ""
                    }))
            current: root.view ? root.keyOf(root.view, root.viewIndex) : ""
            onSelected: id => root.selectView(id)
        }

        // loading, errors and generated dashboards
        Column {
            width: parent.width
            topPadding: Theme.spacingXL
            spacing: Theme.spacingM
            readonly property var strategy: root.config?.strategy ?? root.view?.strategy ?? null
            readonly property string message: {
                if (!HaService.dashboardsLoaded || (root.dashboard !== "" && root.config === undefined))
                    return "Loading dashboard…";
                if (root.config?.error)
                    return root.config.error;
                if (strategy?.type === "original-states")
                    return "This dashboard is generated by Home Assistant from your areas. The Areas page shows the same rooms and devices.";
                if (strategy?.type === "iframe")
                    return "This dashboard shows a web page.";
                if (strategy)
                    return "This dashboard is generated by the " + strategy.type + " strategy, which is only shown in Home Assistant.";
                if (root.config && root.views.length === 0)
                    return "This dashboard has no views.";
                return "";
            }
            visible: message !== ""

            MdiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: parent.strategy ? "mdi:auto-fix" : root.config?.error ? "mdi:alert-circle-outline" : "mdi:view-dashboard-outline"
                size: 44
                color: Theme.surfaceVariantText
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - Theme.spacingXL * 2, 420)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: parent.message
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
            FeatureButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!parent.strategy
                height: 38
                width: 200
                icon: parent.strategy?.type === "original-states" ? "mdi:sofa" : "mdi:open-in-new"
                text: parent.strategy?.type === "original-states" ? "Open Areas" : "Open"
                onClicked: {
                    const s = parent.strategy;
                    if (s.type === "original-states")
                        root.openPage("areas", "");
                    else if (s.type === "iframe" && s.url)
                        Qt.openUrlExternally(s.url);
                    else
                        lovelaceCtx.openInBrowser();
                }
            }
        }

        LovelaceView {
            width: parent.width
            visible: !!root.view && !root.config?.strategy && !root.view?.strategy
            view: visible ? root.view : null
            ctx: lovelaceCtx
        }
    }
}
