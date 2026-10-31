pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../components"
import ".."

// Weather more-info: current conditions, measurements and the forecast, like
// the HA weather dialog. The forecast is subscribed only while `live`.
Column {
    id: root

    property string entityId: ""
    property var st: null
    property bool live: false

    readonly property var attrs: st?.attributes ?? {}
    readonly property string tempUnit: attrs.temperature_unit || Ha.temperatureUnit()

    // weather.WeatherEntityFeature: 1 daily, 2 hourly, 4 twice daily
    readonly property var forecastTypes: {
        const f = attrs.supported_features ?? 0;
        const out = [];
        if (f & 1)
            out.push({
                type: "daily",
                text: "Daily"
            });
        if (f & 2)
            out.push({
                type: "hourly",
                text: "Hourly"
            });
        if (f & 4)
            out.push({
                type: "twice_daily",
                text: "Twice daily"
            });
        return out;
    }
    property int typeIndex: 0
    readonly property string forecastType: forecastTypes[Math.min(typeIndex, forecastTypes.length - 1)]?.type ?? ""

    ForecastSource {
        id: source
        entityId: root.entityId
        type: root.forecastType
        live: root.live
    }
    readonly property var forecast: source.forecast

    spacing: Theme.spacingL

    onEntityIdChanged: typeIndex = 0

    function fmtTemp(v) {
        return Ha.isNumeric(v) ? Ha.formatMeasure(v, 1) : "–";
    }

    readonly property var highLow: source.highLow

    // ------------------------------------------------ current conditions
    Item {
        width: parent.width
        height: 96

        WeatherIcon {
            id: bigIcon
            anchors.verticalCenter: parent.verticalCenter
            size: 88
            condition: root.st?.state ?? ""
            night: {
                HaService.stateRev;
                return Ha.isNightAt();
            }
        }

        Column {
            anchors.left: bigIcon.right
            anchors.leftMargin: Theme.spacingL
            anchors.right: tempCol.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: {
                    HaService.translationRev;
                    return Ha.stateText(root.entityId, root.st);
                }
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeXXLarge
                color: Theme.surfaceText
            }
            StyledText {
                width: parent.width
                text: root.st?.last_changed ? Ha.relativeTime(root.st.last_changed) : ""
                visible: text !== ""
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
        }

        Column {
            id: tempCol
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                anchors.right: parent.right
                text: Ha.isNumeric(root.attrs.temperature) ? root.fmtTemp(root.attrs.temperature) + " " + root.tempUnit : ""
                font.pixelSize: Theme.fontSizeXXLarge
                color: Theme.surfaceText
            }
            StyledText {
                anchors.right: parent.right
                visible: root.highLow !== null
                text: root.highLow ? root.fmtTemp(root.highLow[0]) + " " + root.tempUnit + " / " + root.fmtTemp(root.highLow[1]) + " " + root.tempUnit : ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
        }
    }

    // ------------------------------------------------ measurements
    Rectangle {
        width: parent.width
        height: measCol.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadiusL
        color: DashMetrics.cardColor
        visible: measRepeater.count > 0

        Column {
            id: measCol
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            Repeater {
                id: measRepeater
                model: {
                    const a = root.attrs;
                    const rows = [];
                    const add = (key, icon, value) => {
                        if (a[key] === undefined || a[key] === null || value === "")
                            return;
                        rows.push({
                            icon: icon,
                            label: Ha.attributeName(root.entityId, key),
                            value: value
                        });
                    };
                    const u = (v, unit, d) => Ha.withUnit(Ha.formatMeasure(v, d), unit);
                    add("pressure", "mdi:gauge", u(a.pressure, a.pressure_unit, 1));
                    add("humidity", "mdi:water-percent", u(a.humidity, "%", 0));
                    let wind = u(a.wind_speed, a.wind_speed_unit, 1);
                    if (a.wind_bearing !== undefined && a.wind_bearing !== null)
                        wind += " (" + Ha.windDirection(a.wind_bearing) + ")";
                    add("wind_speed", "mdi:weather-windy", wind);
                    add("wind_gust_speed", "mdi:weather-windy-variant", u(a.wind_gust_speed, a.wind_speed_unit, 1));
                    add("apparent_temperature", "mdi:thermometer", u(a.apparent_temperature, root.tempUnit, 1));
                    add("dew_point", "mdi:thermometer-water", u(a.dew_point, root.tempUnit, 1));
                    add("visibility", "mdi:eye-outline", u(a.visibility, a.visibility_unit, 1));
                    add("cloud_coverage", "mdi:weather-cloudy", u(a.cloud_coverage, "%", 0));
                    add("uv_index", "mdi:sun-wireless", Ha.formatMeasure(a.uv_index, 1));
                    add("ozone", "mdi:molecule", Ha.formatMeasure(a.ozone, 1));
                    return rows;
                }

                Item {
                    id: meas
                    required property var modelData
                    width: measCol.width
                    height: 28

                    MdiIcon {
                        id: measIcon
                        anchors.verticalCenter: parent.verticalCenter
                        icon: meas.modelData.icon
                        size: 22
                        color: Theme.primary
                    }
                    StyledText {
                        anchors.left: measIcon.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: measValue.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: meas.modelData.label
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        id: measValue
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: meas.modelData.value
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                }
            }
        }
    }

    // ------------------------------------------------ forecast
    Rectangle {
        width: parent.width
        height: fcCol.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadiusL
        color: DashMetrics.cardColor
        visible: root.forecastTypes.length > 0

        Column {
            id: fcCol
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingM

            SectionHeader {
                icon: "mdi:calendar-week"
                title: "Forecast"
            }

            DTabBar {
                id: tabs
                width: parent.width
                visible: root.forecastTypes.length > 1
                showIcons: false
                model: root.forecastTypes
                currentIndex: root.typeIndex
                onTabClicked: index => root.typeIndex = index
                Component.onCompleted: Qt.callLater(updateIndicator)
            }

            DFlickable {
                id: strip
                width: parent.width
                height: stripRow.implicitHeight + Theme.spacingM
                contentWidth: stripRow.implicitWidth
                contentHeight: height
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                showScrollBar: false
                wheelEnabled: false
                visible: root.forecast.length > 0

                readonly property bool fits: root.forecastType === "daily" && root.forecast.length <= 8
                readonly property real itemWidth: fits ? width / Math.max(1, root.forecast.length) : 70

                Row {
                    id: stripRow

                    Repeater {
                        model: root.forecast

                        Column {
                            id: fc
                            required property var modelData
                            required property int index
                            readonly property date when: new Date(modelData.datetime)
                            readonly property bool newDay: index === 0 || when.getHours() === 0 || root.forecastType !== "hourly"

                            width: strip.itemWidth
                            spacing: 4

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (!fc.newDay)
                                        return " ";
                                    const day = fc.when.toLocaleDateString(Qt.locale(), "ddd");
                                    if (root.forecastType === "twice_daily")
                                        return day + (fc.modelData.is_daytime === false ? " · Night" : "");
                                    return day;
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.forecastType === "hourly"
                                horizontalAlignment: Text.AlignHCenter
                                // "9:00 AM" on two lines, like the HA hourly forecast
                                text: fc.when.toLocaleTimeString(Qt.locale(), Locale.ShortFormat).replace(/[\s\u202f\u00a0]+(\D+)$/, "\n$1")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                            WeatherIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: 44
                                condition: fc.modelData.condition ?? ""
                                night: fc.modelData.is_daytime === false || (root.forecastType === "hourly" && Ha.isNightAt(fc.when.getTime()))
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.fmtTemp(fc.modelData.temperature) + "°"
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: Ha.isNumeric(fc.modelData.templow)
                                text: root.fmtTemp(fc.modelData.templow) + "°"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                readonly property real mm: Number(fc.modelData.precipitation ?? 0)
                                readonly property real pct: Number(fc.modelData.precipitation_probability ?? 0)
                                visible: mm > 0 || pct > 0
                                text: mm > 0 ? Ha.withUnit(Ha.formatMeasure(mm, 1), root.attrs.precipitation_unit) : Math.round(pct) + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Ha.weatherColors.rain
                            }
                        }
                    }
                }

                HorizontalWheel {
                    target: strip
                }

                ScrollBar.horizontal: DHorizontalScrollbar {
                    targetFlickable: strip
                }
            }

            StyledText {
                width: parent.width
                visible: root.forecast.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: HaService.connected ? "Loading forecast…" : "Not connected"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                visible: !!root.attrs.attribution
                horizontalAlignment: Text.AlignHCenter
                text: root.attrs.attribution ?? ""
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
