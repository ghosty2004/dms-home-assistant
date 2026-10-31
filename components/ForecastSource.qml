import QtQuick
import ".."

// Live weather forecast of one entity (weather/subscribe_forecast), subscribed
// only while `live`. Resubscribes after reconnects.
Item {
    id: root

    property string entityId: ""
    property string type: "daily"
    property bool live: false
    property var forecast: []
    property int _subId: -1

    visible: false

    // Today's high and low: first entry of a daily forecast, otherwise the
    // range of the entries on the first forecast day.
    readonly property var highLow: {
        const f = forecast;
        if (!f.length)
            return null;
        if (type === "daily" && Ha.isNumeric(f[0].temperature) && Ha.isNumeric(f[0].templow))
            return [f[0].temperature, f[0].templow];
        const day = new Date(f[0].datetime).toDateString();
        let hi = -Infinity;
        let lo = Infinity;
        for (let i = 0; i < f.length; i++) {
            if (new Date(f[i].datetime).toDateString() !== day)
                break;
            const vals = [f[i].temperature, f[i].templow].filter(v => Ha.isNumeric(v)).map(Number);
            for (let j = 0; j < vals.length; j++) {
                hi = Math.max(hi, vals[j]);
                lo = Math.min(lo, vals[j]);
            }
        }
        return isFinite(hi) ? [hi, lo] : null;
    }

    function _resubscribe() {
        HaService.unsubscribe(_subId);
        _subId = -1;
        forecast = [];
        if (!live || !entityId || !type || !HaService.connected)
            return;
        const t = type;
        _subId = HaService.subscribe({
            type: "weather/subscribe_forecast",
            entity_id: entityId,
            forecast_type: t
        }, ev => {
            if (ev.type === root.type)
                root.forecast = ev.forecast ?? [];
        }, (res, err) => {
            if (err)
                console.warn("[HA] forecast", err.message);
        });
    }

    onEntityIdChanged: Qt.callLater(_resubscribe)
    onTypeChanged: Qt.callLater(_resubscribe)
    onLiveChanged: Qt.callLater(_resubscribe)
    Component.onCompleted: _resubscribe()
    Component.onDestruction: HaService.unsubscribe(_subId)

    Connections {
        target: HaService
        function onConnectedChanged() {
            if (HaService.connected)
                Qt.callLater(root._resubscribe);
            else
                root._subId = -1;
        }
    }
}
