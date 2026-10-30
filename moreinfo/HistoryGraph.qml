pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../components"
import ".."

// History chart: a line chart for numeric entities, a state timeline for everything else.
Rectangle {
    id: root

    property string entityId: ""
    property int hours: 24
    property color accent: Theme.primary

    property var points: []   // [{t, v}] numeric or [{t, s}] text
    property bool numeric: false
    property bool loading: false
    property int hoverIndex: -1
    readonly property real tEnd: Date.now()
    readonly property real tStart: tEnd - hours * 3600000
    readonly property var range: {
        if (!numeric || points.length === 0)
            return {
                min: 0,
                max: 1,
                avg: 0
            };
        let mn = Infinity, mx = -Infinity, sum = 0;
        for (const p of points) {
            mn = Math.min(mn, p.v);
            mx = Math.max(mx, p.v);
            sum += p.v;
        }
        if (mx - mn < 0.0001) {
            mn -= 1;
            mx += 1;
        }
        return {
            min: mn,
            max: mx,
            avg: sum / points.length
        };
    }
    readonly property string unit: HaService.get(entityId)?.attributes?.unit_of_measurement ?? ""

    implicitHeight: numeric ? 200 : 96
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    onEntityIdChanged: load()
    onHoursChanged: load()
    Component.onCompleted: load()

    function load() {
        if (!entityId)
            return;
        loading = true;
        const id = entityId;
        HaService.fetchHistory([id], hours, res => {
            if (id !== root.entityId)
                return;
            loading = false;
            const raw = res[id] || [];
            const parsed = raw.map(p => ({
                        t: (p.lu ?? p.lc ?? 0) * 1000,
                        s: p.s
                    }));
            const nums = parsed.filter(p => Ha.isNumeric(p.s));
            const isNum = parsed.length > 0 && nums.length >= parsed.filter(p => p.s !== "unavailable" && p.s !== "unknown").length && nums.length > 0;
            numeric = isNum;
            points = isNum ? nums.map(p => ({
                        t: Math.max(p.t, root.tStart),
                        v: Number(p.s)
                    })) : parsed.map(p => ({
                        t: Math.max(p.t, root.tStart),
                        s: p.s
                    }));
            canvas.requestPaint();
        });
    }

    function xFor(t, w) {
        return (t - tStart) / (tEnd - tStart) * w;
    }

    function yFor(v, h) {
        return h - (v - range.min) / (range.max - range.min) * h;
    }

    function formatTime(ms) {
        const d = new Date(ms);
        return d.toLocaleTimeString(Qt.locale(), "HH:mm");
    }

    Row {
        id: head
        x: 14
        y: 10
        spacing: Theme.spacingS

        MdiIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: "mdi:chart-line"
            size: 16
            color: Theme.surfaceVariantText
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hoverIndex >= 0 && root.hoverIndex < root.points.length ? (root.numeric ? Ha.withUnit(Ha.formatNumber(root.points[root.hoverIndex].v), root.unit) : Ha.translateState(root.entityId, HaService.get(root.entityId), root.points[root.hoverIndex].s) || root.points[root.hoverIndex].s) + " · " + root.formatTime(root.points[root.hoverIndex].t) : "Last " + root.hours + " hours"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 6
        spacing: 4

        Repeater {
            model: [6, 24, 72, 168]

            Rectangle {
                id: rangeBtn
                required property int modelData
                width: rangeText.implicitWidth + 14
                height: 24
                radius: 12
                color: root.hours === modelData ? Theme.withAlpha(root.accent, 0.22) : "transparent"

                StyledText {
                    id: rangeText
                    anchors.centerIn: parent
                    text: rangeBtn.modelData < 48 ? rangeBtn.modelData + "h" : (rangeBtn.modelData / 24) + "d"
                    font.pixelSize: 11
                    font.weight: Theme.fontWeightMedium
                    color: root.hours === rangeBtn.modelData ? Theme.surfaceText : Theme.surfaceVariantText
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.hours = rangeBtn.modelData
                }
            }
        }
    }

    Item {
        id: plot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: footer.top
        anchors.margins: 14
        anchors.topMargin: 10

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                const pts = root.points;
                if (pts.length === 0)
                    return;
                if (root.numeric) {
                    // grid
                    ctx.strokeStyle = Theme.withAlpha(Theme.outline, 0.15);
                    ctx.lineWidth = 1;
                    for (let i = 0; i <= 2; i++) {
                        const y = Math.round(h * i / 2) + 0.5;
                        ctx.beginPath();
                        ctx.moveTo(0, y);
                        ctx.lineTo(w, y);
                        ctx.stroke();
                    }
                    // stepped line like HA history
                    ctx.beginPath();
                    let lastY = root.yFor(pts[0].v, h);
                    ctx.moveTo(root.xFor(pts[0].t, w), lastY);
                    for (let i = 1; i < pts.length; i++) {
                        const x = root.xFor(pts[i].t, w);
                        const y = root.yFor(pts[i].v, h);
                        ctx.lineTo(x, y);
                        lastY = y;
                    }
                    ctx.lineTo(w, lastY);
                    ctx.strokeStyle = root.accent;
                    ctx.lineWidth = 2;
                    ctx.lineJoin = "round";
                    ctx.stroke();
                    ctx.lineTo(w, h);
                    ctx.lineTo(root.xFor(pts[0].t, w), h);
                    ctx.closePath();
                    const grad = ctx.createLinearGradient(0, 0, 0, h);
                    grad.addColorStop(0, Theme.withAlpha(root.accent, 0.28));
                    grad.addColorStop(1, Theme.withAlpha(root.accent, 0.0));
                    ctx.fillStyle = grad;
                    ctx.fill();
                } else {
                    const barH = Math.min(h, 34);
                    const y0 = (h - barH) / 2;
                    const st = HaService.get(root.entityId);
                    for (let i = 0; i < pts.length; i++) {
                        const x0 = root.xFor(pts[i].t, w);
                        const x1 = i + 1 < pts.length ? root.xFor(pts[i + 1].t, w) : w;
                        const fake = {
                            entity_id: root.entityId,
                            state: pts[i].s,
                            attributes: st?.attributes ?? {}
                        };
                        const active = Ha.isActive(root.entityId, fake);
                        const unavailable = pts[i].s === "unavailable" || pts[i].s === "unknown";
                        ctx.fillStyle = unavailable ? Theme.withAlpha(Theme.surfaceText, 0.06) : active ? Ha.stateColor(root.entityId, fake) : Theme.withAlpha(Theme.surfaceText, 0.18);
                        ctx.fillRect(x0, y0, Math.max(1, x1 - x0), barH);
                    }
                }
                if (root.hoverIndex >= 0 && root.hoverIndex < pts.length) {
                    const p = pts[root.hoverIndex];
                    const x = root.xFor(p.t, w);
                    ctx.strokeStyle = Theme.withAlpha(Theme.surfaceText, 0.5);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, h);
                    ctx.stroke();
                    if (root.numeric) {
                        ctx.fillStyle = root.accent;
                        ctx.beginPath();
                        ctx.arc(x, root.yFor(p.v, h), 4, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onExited: {
                root.hoverIndex = -1;
                canvas.requestPaint();
            }
            onPositionChanged: mouse => {
                const t = root.tStart + mouse.x / width * (root.tEnd - root.tStart);
                let idx = -1;
                for (let i = 0; i < root.points.length; i++) {
                    if (root.points[i].t <= t)
                        idx = i;
                    else
                        break;
                }
                if (idx !== root.hoverIndex) {
                    root.hoverIndex = idx;
                    canvas.requestPaint();
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.loading || root.points.length === 0
            text: root.loading ? "Loading history…" : "No history"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.bottomMargin: 8
        height: 16

        StyledText {
            anchors.left: parent.left
            text: root.formatTime(root.tStart)
            font.pixelSize: 10
            color: Theme.surfaceVariantText
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.numeric && root.points.length > 0
            text: "min " + Ha.formatNumber(root.range.min) + " · avg " + Ha.formatNumber(root.range.avg) + " · max " + Ha.formatNumber(root.range.max) + (root.unit ? " " + root.unit : "")
            font.pixelSize: 10
            color: Theme.surfaceVariantText
        }
        StyledText {
            anchors.right: parent.right
            text: "now"
            font.pixelSize: 10
            color: Theme.surfaceVariantText
        }
    }
}
