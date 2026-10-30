import QtQuick
import qs.Common
import ".."

Text {
    id: root

    property string icon: ""
    property real size: Theme.iconSize

    width: size
    height: size
    text: Ha.glyph(icon)
    font.family: Ha.iconFont
    font.pixelSize: size
    color: Theme.surfaceText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
        }
    }
}
