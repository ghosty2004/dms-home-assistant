import QtQuick
import qs.Common

// Horizontal slider over a gradient track (color temperature, hue).
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property var stops: ["#ff0000", "#00ff00"]
    property color knobColor: "#ffffff"
    property bool dragging: false
    property real dragValue: value
    readonly property real shown: dragging ? dragValue : value
    readonly property real ratio: Math.max(0, Math.min(1, (shown - from) / Math.max(0.001, to - from)))

    signal committed(real value)

    implicitHeight: 40

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Math.min(height / 2.8, Theme.cornerRadiusL)
        gradient: Gradient {
            id: grad
            orientation: Gradient.Horizontal
        }

        Component.onCompleted: rebuild()

        function rebuild() {
            const list = [];
            const n = root.stops.length;
            for (let i = 0; i < n; i++)
                list.push(Qt.createQmlObject('import QtQuick; GradientStop { position: ' + (n === 1 ? 0 : i / (n - 1)) + '; color: "' + root.stops[i] + '" }', grad));
            grad.stops = list;
        }
    }

    Rectangle {
        width: 6
        height: parent.height * 0.62
        radius: 3
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(4, Math.min(parent.width - width - 4, root.ratio * parent.width - width / 2))
        color: "#ffffff"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.25)
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function valueAt(x) {
            return root.from + Math.max(0, Math.min(1, x / width)) * (root.to - root.from);
        }
        onPressed: mouse => {
            root.dragging = true;
            root.dragValue = valueAt(mouse.x);
        }
        onPositionChanged: mouse => {
            if (pressed)
                root.dragValue = valueAt(mouse.x);
        }
        onReleased: {
            root.committed(root.dragValue);
            hold.restart();
        }
    }

    Timer {
        id: hold
        interval: 1800
        onTriggered: root.dragging = false
    }
}
