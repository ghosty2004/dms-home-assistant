import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../.."

// Lovelace gauge card: half ring with severity colors.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config)
    readonly property var st: {
        HaService.stateRev;
        return HaService.get(entityId);
    }
    readonly property real min: Number(config?.min ?? 0)
    readonly property real max: Number(config?.max ?? 100)
    readonly property real value: {
        const v = config?.attribute ? st?.attributes?.[config.attribute] : st?.state;
        return Ha.isNumeric(v) ? Number(v) : NaN;
    }
    readonly property string unit: config?.unit ?? st?.attributes?.unit_of_measurement ?? ""
    readonly property color gaugeColor: {
        const sev = config?.severity;
        if (sev && !isNaN(value)) {
            const steps = [["red", sev.red], ["yellow", sev.yellow], ["green", sev.green]].filter(s => s[1] !== undefined).sort((x, y) => Number(y[1]) - Number(x[1]));
            for (const s of steps)
                if (value >= Number(s[1]))
                    return Ha.palette[s[0]];
        }
        return Theme.primary;
    }

    implicitHeight: ringBox.height + nameText.implicitHeight + Theme.spacingL * 2 + Theme.spacingS
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        onClicked: Lovelace.runAction(root.config?.tap_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx)
    }

    Item {
        id: ringBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.spacingL
        width: Math.min(parent.width - Theme.spacingL * 2, 200)
        height: width / 2 + 8
        clip: true

        DRingGauge {
            width: ringBox.width
            height: ringBox.width
            startAngle: 180
            spanAngle: 180
            strokeWidth: Math.max(10, ringBox.width * 0.1)
            ringColor: root.gaugeColor
            value: isNaN(root.value) ? 0 : Math.max(0, Math.min(1, (root.value - root.min) / Math.max(0.0001, root.max - root.min)))
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: isNaN(root.value) ? Ha.stateText(root.entityId, root.st) : Ha.withUnit(Ha.formatMeasure(root.value, 1), root.unit)
            font.pixelSize: Theme.fontSizeXLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }
    }

    StyledText {
        id: nameText
        anchors.top: ringBox.bottom
        anchors.topMargin: Theme.spacingS
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, parent.width - Theme.spacingL * 2)
        text: Lovelace.nameOf(root.config, root.entityId)
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
}
