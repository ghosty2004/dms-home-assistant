pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DDash
import "components"
import "pages"
import "moreinfo"

DashTabComponent {
    id: root

    property int rowBudget: DashMetrics.minimumTabRows
    property string page: "home"
    property string pageArg: ""
    property string moreInfoId: ""

    readonly property var pages: [
        {
            id: "home",
            icon: "mdi:home-assistant",
            label: "Home",
            title: "Overview"
        },
        {
            id: "areas",
            icon: "mdi:sofa",
            label: "Areas",
            title: "Areas"
        },
        {
            id: "lights",
            icon: "mdi:lightbulb-group",
            label: "Lights",
            title: "Lights"
        },
        {
            id: "climate",
            icon: "mdi:thermostat",
            label: "Climate",
            title: "Climate"
        },
        {
            id: "security",
            icon: "mdi:shield-home",
            label: "Security",
            title: "Security"
        },
        {
            id: "media",
            icon: "mdi:play-box-multiple",
            label: "Media",
            title: "Media"
        },
        {
            id: "automations",
            icon: "mdi:robot",
            label: "Scenes",
            title: "Scenes & automations"
        },
        {
            id: "entities",
            icon: "mdi:format-list-bulleted-square",
            label: "Entities",
            title: "All entities"
        }
    ]
    readonly property var currentPage: pages.find(p => p.id === page) ?? pages[0]

    implicitHeight: DashMetrics.heightForRows(Math.max(DashMetrics.minimumTabRows, Math.min(rowBudget, 7)))
    focusTarget: rail
    menuActions: [
        {
            label: "Reconnect",
            iconName: "refresh",
            action: () => HaService.reconnect()
        },
        {
            label: "Open Home Assistant",
            iconName: "open_in_new",
            enabled: HaService.baseUrl !== "",
            action: () => Qt.openUrlExternally(HaService.baseUrl)
        }
    ]

    Component.onCompleted: {
        const saved = pluginService ? pluginService.loadPluginState(pluginId, "lastPage", "home") : "home";
        if (saved && pages.some(p => p.id === saved))
            page = saved;
        consumeRequests();
    }

    function consumeRequests() {
        if (HaService.pendingPage !== "") {
            navigate(HaService.pendingPage, HaService.pendingArg);
            HaService.pendingPage = "";
            HaService.pendingArg = "";
        }
        if (HaService.pendingMoreInfo !== "") {
            moreInfoId = HaService.pendingMoreInfo;
            HaService.pendingMoreInfo = "";
        }
    }

    Connections {
        target: HaService
        function onPageRequested() {
            root.consumeRequests();
        }
        function onMoreInfoRequested() {
            root.consumeRequests();
        }
    }

    function greeting() {
        const h = new Date().getHours();
        const who = HaService.currentUser?.name ? ", " + HaService.currentUser.name : "";
        if (h < 5)
            return "Good night" + who;
        if (h < 12)
            return "Good morning" + who;
        if (h < 18)
            return "Good afternoon" + who;
        return "Good evening" + who;
    }

    function navigate(target, arg) {
        page = target;
        pageArg = arg || "";
        if (pluginService)
            pluginService.savePluginState(pluginId, "lastPage", target);
    }

    function handleKeyEvent(event) {
        if (event.key === Qt.Key_Escape && moreInfoId !== "") {
            moreInfoId = "";
            return true;
        }
        return false;
    }

    NavRail {
        id: rail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 76
        model: root.pages
        current: root.page
        onSelected: id => root.navigate(id, "")
    }

    Item {
        id: body
        anchors.left: rail.right
        anchors.leftMargin: Theme.spacingS
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // ------------------------------------------------ header
        Item {
            id: header
            width: parent.width
            height: 40

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.page === "home" ? root.greeting() : root.currentPage.title
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: Theme.fontWeightBold
                color: Theme.surfaceText
            }

            Rectangle {
                id: statusPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 28
                width: statusRow.implicitWidth + 20
                radius: 14
                readonly property color tone: HaService.connected ? Ha.palette.green : HaService.status === "error" || HaService.status === "unconfigured" ? Theme.error : Ha.palette.orange
                color: Theme.withAlpha(tone, 0.14)

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: statusPill.tone
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            switch (HaService.status) {
                            case "connected":
                                return HaService.ready ? "Connected" : "Loading…";
                            case "connecting":
                                return "Connecting…";
                            case "authenticating":
                                return "Signing in…";
                            case "unconfigured":
                                return "Not configured";
                            case "error":
                                return "Offline";
                            }
                            return HaService.status;
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    cornerRadius: parent.radius
                    tooltipText: HaService.errorText || HaService.baseUrl
                    onClicked: HaService.reconnect()
                }
            }
        }

        // ------------------------------------------------ page
        Loader {
            id: pageLoader
            anchors.top: header.bottom
            anchors.topMargin: Theme.spacingS
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            active: HaService.ready
            sourceComponent: {
                switch (root.page) {
                case "areas":
                    return areasPage;
                case "lights":
                case "climate":
                case "security":
                case "media":
                case "automations":
                    return categoryPage;
                case "entities":
                    return entitiesPage;
                }
                return homePage;
            }
            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                }
            }
        }

        // ------------------------------------------------ empty / error state
        Column {
            anchors.centerIn: pageLoader
            visible: !HaService.ready
            spacing: Theme.spacingM
            width: Math.min(parent.width - Theme.spacingXL * 2, 360)

            MdiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: HaService.status === "unconfigured" ? "mdi:home-assistant" : HaService.status === "error" ? "mdi:lan-disconnect" : "mdi:home-assistant"
                size: 56
                color: HaService.status === "error" ? Theme.error : Ha.palette.lightBlue
            }
            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: HaService.status === "unconfigured" ? "Set your Home Assistant URL and a long-lived access token in Settings → Plugins → Home Assistant." : HaService.status === "error" ? ("Cannot reach Home Assistant" + (HaService.errorText ? ": " + HaService.errorText : "")) : "Connecting to Home Assistant…"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
            DButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: HaService.status === "error" || HaService.status === "unconfigured"
                text: HaService.status === "unconfigured" ? "Open settings" : "Retry"
                iconName: HaService.status === "unconfigured" ? "settings" : "refresh"
                onClicked: {
                    if (HaService.status === "unconfigured") {
                        PopoutService.closeDankDash();
                        PopoutService.openSettingsWithTab("plugins");
                    } else {
                        HaService.reconnect();
                    }
                }
            }
        }
    }

    Component {
        id: homePage
        HomePage {
            onMoreInfo: id => root.moreInfoId = id
            onNavigate: (p, arg) => root.navigate(p, arg)
        }
    }

    Component {
        id: areasPage
        AreasPage {
            areaId: root.pageArg
            onMoreInfo: id => root.moreInfoId = id
        }
    }

    Component {
        id: categoryPage
        CategoryPage {
            category: root.page
            onMoreInfo: id => root.moreInfoId = id
        }
    }

    Component {
        id: entitiesPage
        EntitiesPage {
            initialFilter: root.pageArg
            onMoreInfo: id => root.moreInfoId = id
        }
    }

    MoreInfo {
        anchors.fill: parent
        entityId: root.moreInfoId
        onCloseRequested: root.moreInfoId = ""
        onMoreInfo: id => root.moreInfoId = id
    }
}
