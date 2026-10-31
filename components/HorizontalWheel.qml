import QtQuick

// Scrolls a horizontal Flickable with the mouse wheel or touchpad. At either
// end the event passes through, so the page around it keeps scrolling.
MouseArea {
    id: root

    property Flickable target: null
    property real step: 72

    anchors.fill: parent
    acceptedButtons: Qt.NoButton

    onWheel: wheel => {
        const f = root.target;
        const max = f ? f.contentWidth - f.width : 0;
        const px = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.pixelDelta.y;
        const ang = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
        const delta = px !== 0 ? px : ang / 120 * root.step;
        if (!f || max <= 0 || delta === 0) {
            wheel.accepted = false;
            return;
        }
        const next = Math.max(0, Math.min(max, f.contentX - delta));
        if (next === f.contentX) {
            wheel.accepted = false;
            return;
        }
        f.contentX = next;
        wheel.accepted = true;
    }
}
