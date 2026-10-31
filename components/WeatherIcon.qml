pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import ".."

// Colored weather condition icon in the style of the HA frontend: a filled cloud
// with sun, moon, rain, snow or lightning composed around it.
Item {
    id: root

    property string condition: ""
    property bool night: false
    property real size: 64

    width: size
    height: size

    readonly property var colors: Ha.weatherColors
    readonly property var parts: {
        const s = size;
        const c = colors;
        const out = [];
        const cloud = (x, y, k, color) => out.push({
                kind: "glyph",
                icon: "mdi:cloud",
                x: x * s,
                y: y * s,
                size: k * s,
                color: color
            });
        const sun = (cx, cy, d) => {
            if (night) {
                out.push({
                    kind: "glyph",
                    icon: "mdi:moon-waning-crescent",
                    x: (cx - d * 0.7) * s,
                    y: (cy - d * 0.7) * s,
                    size: d * 1.4 * s,
                    color: c.moon
                });
            } else {
                out.push({
                    kind: "circle",
                    x: (cx - d / 2) * s,
                    y: (cy - d / 2) * s,
                    w: d * s,
                    h: d * s,
                    color: c.sun
                });
            }
        };
        const drops = (n, color) => {
            for (let i = 0; i < n; i++) {
                const x = n === 1 ? 0.5 : 0.3 + i * (0.4 / (n - 1));
                out.push({
                    kind: "drop",
                    x: (x - 0.035) * s,
                    y: (0.72 + (i % 2) * 0.05) * s,
                    w: 0.07 * s,
                    h: 0.16 * s,
                    color: color
                });
            }
        };
        const flakes = (xs, color, d) => {
            for (let i = 0; i < xs.length; i++)
                out.push({
                    kind: "circle",
                    x: (xs[i] - d / 2) * s,
                    y: (0.78 + (i % 2) * 0.08) * s,
                    w: d * s,
                    h: d * s,
                    color: color
                });
        };
        const front = (y) => cloud(0.08, y ?? 0.04, 0.84, c.cloudFront);
        const back = () => cloud(0.36, -0.06, 0.6, c.cloudBack);

        switch (condition) {
        case "sunny":
            sun(0.5, 0.5, 0.56);
            break;
        case "clear-night":
            out.push({
                kind: "glyph",
                icon: "mdi:moon-waning-crescent",
                x: 0.1 * s,
                y: 0.1 * s,
                size: 0.8 * s,
                color: c.moon
            });
            break;
        case "partlycloudy":
            sun(0.64, 0.3, 0.42);
            front(0.1);
            break;
        case "cloudy":
            back();
            front(0.1);
            break;
        case "fog":
            front(-0.04);
            out.push({
                kind: "bar",
                x: 0.14 * s,
                y: 0.7 * s,
                w: 0.72 * s,
                h: 0.07 * s,
                color: c.cloudBack
            });
            out.push({
                kind: "bar",
                x: 0.24 * s,
                y: 0.83 * s,
                w: 0.6 * s,
                h: 0.07 * s,
                color: c.cloudBack
            });
            break;
        case "rainy":
            front(-0.04);
            drops(3, c.rain);
            break;
        case "pouring":
            back();
            front(-0.02);
            drops(5, c.rain);
            break;
        case "snowy":
            front(-0.04);
            flakes([0.3, 0.5, 0.7], c.snow, 0.1);
            break;
        case "snowy-rainy":
            front(-0.04);
            drops(2, c.rain);
            flakes([0.5], c.snow, 0.1);
            break;
        case "hail":
            front(-0.04);
            flakes([0.32, 0.5, 0.68], c.snow, 0.13);
            break;
        case "lightning":
        case "lightning-rainy":
            if (condition === "lightning-rainy")
                drops(2, c.rain);
            front(-0.04);
            out.push({
                kind: "glyph",
                icon: "mdi:flash",
                x: 0.34 * s,
                y: 0.58 * s,
                size: 0.38 * s,
                color: c.sun
            });
            break;
        case "windy":
        case "windy-variant":
            if (condition === "windy-variant")
                cloud(0.2, -0.08, 0.6, c.cloudFront);
            out.push({
                kind: "glyph",
                icon: "mdi:weather-windy",
                x: 0.1 * s,
                y: (condition === "windy-variant" ? 0.24 : 0.1) * s,
                size: 0.8 * s,
                color: c.cloudBack
            });
            break;
        case "exceptional":
            out.push({
                kind: "glyph",
                icon: "mdi:alert-circle-outline",
                x: 0.1 * s,
                y: 0.1 * s,
                size: 0.8 * s,
                color: Ha.palette.red
            });
            break;
        default:
            out.push({
                kind: "glyph",
                icon: "mdi:weather-cloudy-alert",
                x: 0.1 * s,
                y: 0.1 * s,
                size: 0.8 * s,
                color: Theme.surfaceVariantText
            });
        }
        return out;
    }

    Repeater {
        model: root.parts

        Item {
            id: part
            required property var modelData

            x: modelData.x
            y: modelData.y
            width: modelData.kind === "glyph" ? modelData.size : modelData.w
            height: modelData.kind === "glyph" ? modelData.size : modelData.h
            rotation: modelData.kind === "drop" ? 18 : 0

            MdiIcon {
                visible: part.modelData.kind === "glyph"
                icon: part.modelData.icon ?? ""
                size: part.modelData.size ?? 0
                color: part.modelData.color
            }
            Rectangle {
                visible: part.modelData.kind !== "glyph"
                anchors.fill: parent
                radius: Math.min(width, height) / 2
                color: part.modelData.color
            }
        }
    }
}
