import QtQuick
import qs.Common
import qs.DCommon.Widgets
import ".."

// HA style "big" slider: a tinted track with a filled part. Horizontal or vertical.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property color color: Theme.primary
    property bool vertical: false
    property bool enabled: true
    property string label: ""
    property string valueText: Math.round(shownValue) + "%"
    property bool showValue: true
    property real radius: vertical ? Math.min(width / 2.8, Theme.cornerRadiusXL) : Math.min(height / 2.8, Theme.cornerRadiusL)
    property real dragValue: value
    property bool dragging: false
    readonly property real shownValue: dragging ? dragValue : value
    readonly property real ratio: Math.max(0, Math.min(1, (shownValue - from) / Math.max(0.0001, to - from)))

    signal moved(real value)
    signal committed(real value)

    implicitHeight: vertical ? 280 : 40
    implicitWidth: vertical ? 110 : 200

    function valueAt(px, py) {
        let r = vertical ? 1 - py / height : px / width;
        r = Math.max(0, Math.min(1, r));
        const raw = from + r * (to - from);
        return Math.max(from, Math.min(to, Math.round(raw / step) * step));
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.radius
        color: Theme.withAlpha(root.color, root.enabled ? 0.2 : 0.08)

        Rectangle {
            id: fill
            visible: root.ratio > 0
            radius: root.radius
            color: root.enabled ? root.color : Theme.withAlpha(root.color, 0.3)
            x: 0
            width: root.vertical ? parent.width : Math.max(root.radius * 2, parent.width * root.ratio)
            height: root.vertical ? Math.max(root.radius * 2, parent.height * root.ratio) : parent.height
            y: root.vertical ? parent.height - height : 0

            Behavior on width {
                enabled: !root.dragging && !root.vertical
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !root.dragging && root.vertical
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Easing.OutCubic
                }
            }

            // Handle line like the HA control slider
            Rectangle {
                visible: root.enabled
                color: Theme.withAlpha(Ha.onAccent(root.color), 0.85)
                radius: 2
                width: root.vertical ? parent.width * 0.32 : 4
                height: root.vertical ? 4 : parent.height * 0.42
                anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
                anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
                x: root.vertical ? (parent.width - width) / 2 : parent.width - width - root.radius * 0.6
                y: root.vertical ? root.radius * 0.6 : (parent.height - height) / 2
            }
        }

        StyledText {
            visible: root.label !== "" && !root.vertical
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }

        StyledText {
            visible: root.showValue && !root.vertical
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: root.valueText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => {
            root.dragging = true;
            root.dragValue = root.valueAt(mouse.x, mouse.y);
            root.moved(root.dragValue);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const v = root.valueAt(mouse.x, mouse.y);
            if (v !== root.dragValue) {
                root.dragValue = v;
                root.moved(v);
            }
        }
        onReleased: {
            root.committed(root.dragValue);
            releaseHold.restart();
        }
        onCanceled: root.dragging = false
        onWheel: wheel => {
            const dir = (wheel.angleDelta.y || -wheel.angleDelta.x) > 0 ? 1 : -1;
            const base = root.dragging ? root.dragValue : root.value;
            root.dragValue = Math.max(root.from, Math.min(root.to, base + dir * Math.max(root.step, (root.to - root.from) / 20)));
            root.dragging = true;
            root.moved(root.dragValue);
            wheelCommit.restart();
        }
    }

    Timer {
        id: wheelCommit
        interval: 450
        onTriggered: {
            root.committed(root.dragValue);
            releaseHold.restart();
        }
    }

    // Keep showing the dragged value until HA reports the new state.
    Timer {
        id: releaseHold
        interval: 1500
        onTriggered: root.dragging = false
    }

    onValueChanged: {
        if (releaseHold.running && Math.abs(value - dragValue) <= step)
            dragging = false;
    }
}
