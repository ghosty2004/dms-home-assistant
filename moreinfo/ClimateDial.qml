import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"
import ".."

// HA thermostat card dial: 270° arc, draggable target, current temperature marker.
Item {
    id: root

    property real value: 20
    property real current: NaN
    property real from: 7
    property real to: 35
    property real step: 0.5
    property color color: Ha.palette.deepOrange
    property bool enabled: true
    property string label: ""
    property string action: ""

    property real dragValue: value
    property bool dragging: false
    readonly property real shown: dragging ? dragValue : value

    signal committed(real value)

    implicitWidth: 260
    implicitHeight: 240

    function ratioOf(v) {
        return Math.max(0, Math.min(1, (v - from) / Math.max(0.001, to - from)));
    }

    function snap(v) {
        return Math.max(from, Math.min(to, Math.round(v / step) * step));
    }

    function bump(dir) {
        dragValue = snap((dragging ? dragValue : value) + dir * step);
        dragging = true;
        commitTimer.restart();
    }

    onShownChanged: canvas.requestPaint()
    onCurrentChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onEnabledChanged: canvas.requestPaint()
    onValueChanged: {
        if (hold.running && Math.abs(value - dragValue) < step / 2)
            dragging = false;
    }

    Timer {
        id: commitTimer
        interval: 800
        onTriggered: {
            root.committed(root.dragValue);
            hold.restart();
        }
    }
    Timer {
        id: hold
        interval: 2500
        onTriggered: root.dragging = false
    }

    readonly property real size: Math.min(width, height / 0.92)
    readonly property real thickness: Math.max(14, size * 0.075)
    readonly property real radius: size / 2 - thickness

    Canvas {
        id: canvas
        width: root.size
        height: root.size
        anchors.horizontalCenter: parent.horizontalCenter
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, r = root.radius;
            const a0 = Math.PI * 0.75, span = Math.PI * 1.5;
            ctx.lineCap = "round";
            ctx.lineWidth = root.thickness;
            ctx.strokeStyle = Theme.withAlpha(root.enabled ? root.color : Theme.surfaceText, 0.16);
            ctx.beginPath();
            ctx.arc(cx, cy, r, a0, a0 + span, false);
            ctx.stroke();
            if (root.enabled) {
                ctx.strokeStyle = root.color;
                ctx.beginPath();
                ctx.arc(cx, cy, r, a0, a0 + span * root.ratioOf(root.shown), false);
                ctx.stroke();
            }
            // current temperature marker
            if (!isNaN(root.current)) {
                const ac = a0 + span * root.ratioOf(root.current);
                ctx.fillStyle = Theme.surfaceText;
                ctx.beginPath();
                ctx.arc(cx + Math.cos(ac) * r, cy + Math.sin(ac) * r, root.thickness * 0.18, 0, Math.PI * 2);
                ctx.fill();
            }
            // handle
            const at = a0 + span * root.ratioOf(root.shown);
            ctx.fillStyle = Ha.onAccent(root.color);
            ctx.beginPath();
            ctx.arc(cx + Math.cos(at) * r, cy + Math.sin(at) * r, root.thickness * 0.62, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = root.enabled ? root.color : Theme.withAlpha(Theme.surfaceText, 0.4);
            ctx.beginPath();
            ctx.arc(cx + Math.cos(at) * r, cy + Math.sin(at) * r, root.thickness * 0.34, 0, Math.PI * 2);
            ctx.fill();
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            preventStealing: true
            cursorShape: Qt.PointingHandCursor

            function valueAt(mx, my) {
                const dx = mx - width / 2, dy = my - height / 2;
                let deg = Math.atan2(dy, dx) * 180 / Math.PI;
                if (deg < 0)
                    deg += 360;
                let rel = (deg - 135 + 360) % 360;
                if (rel > 270)
                    rel = rel > 315 ? 0 : 270;
                return root.snap(root.from + rel / 270 * (root.to - root.from));
            }

            onPressed: mouse => {
                const dx = mouse.x - width / 2, dy = mouse.y - height / 2;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < root.radius - root.thickness * 1.6) {
                    mouse.accepted = false;
                    return;
                }
                commitTimer.stop();
                root.dragging = true;
                root.dragValue = valueAt(mouse.x, mouse.y);
            }
            onPositionChanged: mouse => {
                if (pressed)
                    root.dragValue = valueAt(mouse.x, mouse.y);
            }
            onReleased: commitTimer.restart()
            onWheel: wheel => root.bump(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }

    Column {
        anchors.horizontalCenter: canvas.horizontalCenter
        anchors.verticalCenter: canvas.verticalCenter
        anchors.verticalCenterOffset: -4
        spacing: 0

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.action
            visible: text !== ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: root.enabled ? root.color : Theme.surfaceVariantText
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter

            StyledText {
                text: root.enabled ? Ha.formatNumber(Math.floor(root.shown)) : "Off"
                font.pixelSize: Theme.fontSizeDisplayLarge
                font.weight: Font.Normal
                color: Theme.surfaceText
            }
            Column {
                visible: root.enabled
                anchors.top: parent.top
                anchors.topMargin: root.size * 0.04
                StyledText {
                    text: Ha.temperatureUnit()
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                }
                StyledText {
                    visible: root.step < 1
                    text: "." + Math.round((root.shown - Math.floor(root.shown)) * 10)
                    font.pixelSize: Theme.fontSizeXLarge
                    color: Theme.surfaceText
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            visible: !isNaN(root.current)

            MdiIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "mdi:thermometer"
                size: 15
                color: Theme.surfaceVariantText
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Ha.withUnit(Ha.formatNumber(root.current), Ha.temperatureUnit())
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    Row {
        anchors.horizontalCenter: canvas.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: Theme.spacingXL * 1.5
        visible: root.enabled

        FeatureButton {
            width: 48
            height: 48
            radius: 24
            icon: "mdi:minus"
            accent: root.color
            onClicked: root.bump(-1)
        }
        FeatureButton {
            width: 48
            height: 48
            radius: 24
            icon: "mdi:plus"
            accent: root.color
            onClicked: root.bump(1)
        }
    }
}
