pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."

// Lovelace weather forecast card: current conditions and a forecast row.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config)
    readonly property var st: {
        HaService.stateRev;
        return HaService.get(entityId);
    }
    readonly property var attrs: st?.attributes ?? {}
    readonly property bool showCurrent: config?.show_current !== false
    readonly property bool showForecast: config?.show_forecast !== false
    readonly property string tempUnit: attrs.temperature_unit || Ha.temperatureUnit()
    readonly property string forecastType: config?.forecast_type ?? "daily"
    readonly property int slots: Math.max(1, Math.min(Number(config?.forecast_slots ?? 5), Math.floor((width - Theme.spacingL * 2) / 52), source.forecast.length))

    function fmt(v) {
        return Ha.isNumeric(v) ? Ha.formatMeasure(v, 1) : "–";
    }

    implicitHeight: col.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    ForecastSource {
        id: source
        entityId: root.entityId
        type: root.forecastType
        live: root.showForecast && HaService.dashLive
    }

    StateLayer {
        anchors.fill: parent
        cornerRadius: root.radius
        onClicked: Lovelace.runAction(root.config?.tap_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx)
    }

    Column {
        id: col
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        spacing: Theme.spacingL

        Item {
            width: parent.width
            height: 64
            visible: root.showCurrent

            WeatherIcon {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                size: 60
                condition: root.st?.state ?? ""
                night: Ha.isNightAt()
            }
            Column {
                anchors.left: icon.right
                anchors.leftMargin: Theme.spacingM
                anchors.right: tempCol.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: Ha.stateText(root.entityId, root.st)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                }
                StyledText {
                    width: parent.width
                    text: Lovelace.nameOf(root.config, root.entityId)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
            Column {
                id: tempCol
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    anchors.right: parent.right
                    text: Ha.isNumeric(root.attrs.temperature) ? root.fmt(root.attrs.temperature) + " " + root.tempUnit : ""
                    font.pixelSize: Theme.fontSizeXXLarge
                    color: Theme.surfaceText
                }
                StyledText {
                    anchors.right: parent.right
                    readonly property string attr: root.config?.secondary_info_attribute ?? ""
                    visible: text !== ""
                    text: {
                        if (attr && root.attrs[attr] !== undefined)
                            return Ha.attributeName(root.entityId, attr) + " " + Ha.formatMeasure(root.attrs[attr], 1);
                        const hl = source.highLow;
                        return hl ? root.fmt(hl[0]) + "° / " + root.fmt(hl[1]) + "°" : "";
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }

        Row {
            width: parent.width
            visible: root.showForecast && source.forecast.length > 0

            Repeater {
                model: source.forecast.slice(0, root.slots)

                Column {
                    id: fc
                    required property var modelData
                    readonly property date when: new Date(modelData.datetime)
                    width: col.width / root.slots
                    spacing: 2

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.forecastType === "hourly" ? fc.when.toLocaleTimeString(Qt.locale(), Locale.ShortFormat).replace(/[\s  ]*(AM|PM|am|pm)$/, "") : fc.when.toLocaleDateString(Qt.locale(), "ddd")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                    WeatherIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 36
                        condition: fc.modelData.condition ?? ""
                        night: fc.modelData.is_daytime === false || (root.forecastType === "hourly" && Ha.isNightAt(fc.when.getTime()))
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.fmt(fc.modelData.temperature) + "°"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Ha.isNumeric(fc.modelData.templow)
                        text: root.fmt(fc.modelData.templow) + "°"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }
    }
}
