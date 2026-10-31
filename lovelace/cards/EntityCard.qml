pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."

// Lovelace entity and sensor cards: name, icon and a large value. The sensor
// card adds a line graph of the last hours_to_show hours.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config)
    property var st: HaService.get(entityId)
    readonly property bool isSensor: config?.type === "sensor"
    readonly property bool showGraph: isSensor && (config?.graph ?? "line") !== "none"
    readonly property int hours: Number(config?.hours_to_show ?? 24)
    property var values: []

    implicitHeight: isSensor ? (showGraph ? 168 : 120) : 120
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
    onEntityIdChanged: {
        st = HaService.get(entityId);
        loadGraph();
    }
    Component.onCompleted: loadGraph()

    function loadGraph() {
        if (!showGraph || !entityId)
            return;
        const id = entityId;
        HaService.fetchHistory([id], hours, res => {
            if (id !== root.entityId)
                return;
            root.values = (res[id] || []).map(p => Number(p.s)).filter(v => !isNaN(v));
        });
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.showGraph && HaService.dashLive
        onTriggered: root.loadGraph()
    }

    readonly property string valueText: {
        HaService.translationRev;
        if (config?.attribute) {
            const v = st?.attributes?.[config.attribute];
            return v === undefined || v === null ? "" : (Ha.isNumeric(v) ? Ha.formatMeasure(v, 2) : Ha.translateAttribute(entityId, config.attribute, v));
        }
        if (st && Ha.isNumeric(st.state))
            return Ha.formatMeasure(st.state, HaService.entityReg[entityId]?.dp ?? 2);
        return Ha.stateText(entityId, st);
    }
    readonly property string unit: config?.unit ?? (config?.attribute ? "" : (st && Ha.isNumeric(st.state) ? (st.attributes?.unit_of_measurement ?? "") : ""))

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        onClicked: Lovelace.runAction(root.config?.tap_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx)
    }

    StyledText {
        id: nameText
        x: Theme.spacingL
        y: Theme.spacingM
        width: parent.width - x - icon.width - Theme.spacingL - Theme.spacingS
        text: Lovelace.nameOf(root.config, root.entityId)
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
    }

    MdiIcon {
        id: icon
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL
        y: Theme.spacingM
        icon: root.config?.icon || Ha.iconName(root.entityId, root.st)
        size: 24
        color: Ha.isActive(root.entityId, root.st) && root.config?.state_color !== false ? Ha.stateColor(root.entityId, root.st) : Theme.primary
    }

    Row {
        x: Theme.spacingL
        anchors.top: nameText.bottom
        anchors.topMargin: Theme.spacingXS
        spacing: 4

        StyledText {
            id: big
            text: root.valueText
            font.pixelSize: Theme.fontSizeXXLarge
            color: Theme.surfaceText
        }
        StyledText {
            anchors.baseline: big.baseline
            visible: root.unit !== ""
            text: root.unit
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
        }
    }

    DSparkline {
        visible: root.showGraph && root.values.length > 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 64
        values: root.values
        autoRange: true
        lineColor: Lovelace.color(root.config?.color, Ha.stateColor(root.entityId, root.st) === Ha.inactiveColor ? Theme.primary : Ha.stateColor(root.entityId, root.st))
    }
}
