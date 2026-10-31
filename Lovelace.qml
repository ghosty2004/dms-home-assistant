pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

// Lovelace helpers: card visibility conditions, grid sizes, actions and colors,
// following the HA frontend.
Singleton {
    id: root

    // Section grid of the sections view
    readonly property int gridColumns: 12
    readonly property real rowHeight: 56
    readonly property real gap: 8

    // Card types rendered by lovelace/cards; anything else is a placeholder.
    readonly property var cardFiles: ({
            "tile": "TileCard.qml",
            "heading": "HeadingCard.qml",
            "entities": "EntitiesCard.qml",
            "entity": "EntityCard.qml",
            "sensor": "EntityCard.qml",
            "button": "ButtonCard.qml",
            "glance": "GlanceCard.qml",
            "grid": "GridCard.qml",
            "vertical-stack": "GridCard.qml",
            "horizontal-stack": "GridCard.qml",
            "conditional": "ConditionalCard.qml",
            "weather-forecast": "WeatherForecastCard.qml",
            "thermostat": "ThermostatCard.qml",
            "light": "TileCard.qml",
            "media-control": "MediaControlCard.qml",
            "picture-entity": "PictureCard.qml",
            "picture-glance": "PictureCard.qml",
            "picture": "PictureCard.qml",
            "todo-list": "TodoListCard.qml",
            "shopping-list": "TodoListCard.qml",
            "markdown": "MarkdownCard.qml",
            "gauge": "GaugeCard.qml",
            "history-graph": "HistoryGraphCard.qml",
            "statistics-graph": "HistoryGraphCard.qml",
            "area": "AreaCardWrapper.qml",
            "map": "MapCard.qml"
        })

    function cardSource(type) {
        return "cards/" + (cardFiles[type] ?? "UnsupportedCard.qml");
    }

    // ---------------------------------------------------------------- entities

    function entityOf(cfg) {
        if (!cfg)
            return "";
        if (typeof cfg === "string")
            return cfg;
        return typeof cfg.entity === "string" ? cfg.entity : "";
    }

    // Entity list of entities/glance/map/history cards: strings or objects.
    function entityRows(list) {
        return (list ?? []).map(e => typeof e === "string" ? {
                    entity: e
                } : e).filter(e => !!e);
    }

    function nameOf(cfg, entityId) {
        const n = cfg?.name;
        if (typeof n === "string" && n !== "")
            return n;
        if (!entityId)
            return "";
        return Ha.entityName(entityId, HaService.get(entityId));
    }

    // ---------------------------------------------------------------- visibility

    function _stateValue(entityId, attribute) {
        const st = HaService.get(entityId);
        if (!st)
            return undefined;
        return attribute ? st.attributes?.[attribute] : st.state;
    }

    function _matches(value, expected) {
        if (Array.isArray(expected))
            return expected.map(String).includes(String(value));
        return String(value) === String(expected);
    }

    function _ref(v) {
        // numeric_state limits and states may point at another entity
        if (typeof v === "string" && /^[a-z_]+\.[a-z0-9_]+$/.test(v) && HaService.get(v))
            return HaService.get(v).state;
        return v;
    }

    function checkCondition(c) {
        if (!c)
            return true;
        const type = c.condition ?? (c.entity ? "state" : "");
        switch (type) {
        case "state":
            {
                const v = _stateValue(c.entity, c.attribute);
                if (c.state !== undefined && !_matches(v, _ref(c.state)))
                    return false;
                if (c.state_not !== undefined && _matches(v, _ref(c.state_not)))
                    return false;
                return true;
            }
        case "numeric_state":
            {
                const v = Number(_stateValue(c.entity, c.attribute));
                if (isNaN(v))
                    return false;
                if (c.above !== undefined && !(v > Number(_ref(c.above))))
                    return false;
                if (c.below !== undefined && !(v < Number(_ref(c.below))))
                    return false;
                return true;
            }
        case "user":
            return (c.users ?? []).includes(HaService.currentUser?.id);
        case "and":
            return checkConditions(c.conditions);
        case "or":
            return (c.conditions ?? []).some(x => checkCondition(x));
        case "not":
            return !checkConditions(c.conditions);
        }
        // screen, location, time and unknown conditions don't hide anything
        return true;
    }

    function checkConditions(list) {
        return (list ?? []).every(c => checkCondition(c));
    }

    function isVisible(cfg) {
        HaService.stateRev;
        if (!cfg || typeof cfg !== "object")
            return false;
        if (cfg.type === "conditional" && !checkConditions(cfg.conditions))
            return false;
        return checkConditions(cfg.visibility);
    }

    function viewVisible(view) {
        const v = view?.visible;
        if (v === undefined || v === true)
            return true;
        if (v === false)
            return false;
        if (Array.isArray(v))
            return v.some(u => u.user === HaService.currentUser?.id);
        return true;
    }

    // ---------------------------------------------------------------- grid sizes

    // {columns: 1..12, rows: n or 0 for auto} like getGridOptions() of each card.
    function gridSize(cfg) {
        const type = cfg?.type ?? "";
        if (type === "conditional" && cfg.card)
            return gridSize(Object.assign({}, cfg.card, cfg.grid_options ? {
                grid_options: cfg.grid_options
            } : {}));
        let cols = 12;
        let rows = 0;
        switch (type) {
        case "tile":
        case "light":
            {
                cols = 6;
                const inline = cfg.features_position === "inline";
                const n = type === "light" ? 1 : (cfg.features ?? []).length;
                rows = (cfg.vertical ? 2 : 1) + (inline ? 0 : n);
                break;
            }
        case "button":
        case "entity":
            cols = 6;
            rows = 2;
            break;
        case "sensor":
        case "gauge":
            cols = 6;
            break;
        }
        const go = cfg?.grid_options ?? {};
        if (go.columns === "full")
            cols = 12;
        else if (go.columns !== undefined && !isNaN(Number(go.columns)))
            cols = Math.max(1, Math.min(12, Number(go.columns)));
        if (go.rows === "auto")
            rows = 0;
        else if (go.rows !== undefined && !isNaN(Number(go.rows)))
            rows = Math.max(1, Number(go.rows));
        return {
            columns: cols,
            rows: rows
        };
    }

    function rowsHeight(rows) {
        return rows * rowHeight + (rows - 1) * gap;
    }

    // ---------------------------------------------------------------- colors

    function color(name, fallback) {
        if (!name || name === "state" || name === "none")
            return fallback;
        if (typeof name === "string" && name.startsWith("#"))
            return name;
        const key = String(name).replace(/-([a-z])/g, (m, c) => c.toUpperCase());
        switch (key) {
        case "primary":
            return Theme.primary;
        case "accent":
            return Theme.secondary;
        case "disabled":
        case "lightGrey":
        case "darkGrey":
        case "blueGrey":
            return Theme.surfaceVariantText;
        case "black":
        case "white":
            return Theme.surfaceText;
        }
        return Ha.palette[key] ?? fallback;
    }

    // ---------------------------------------------------------------- actions

    function defaultTapAction(entityId) {
        return {
            action: "more-info"
        };
    }

    function defaultIconTapAction(entityId) {
        return {
            action: Ha.canToggle(entityId) ? "toggle" : "more-info"
        };
    }

    // ctx: { moreInfo(id), navigate(path) } from the dashboards page
    function runAction(action, entityId, ctx) {
        if (!action)
            return;
        const kind = action.action ?? "more-info";
        if (action.confirmation)
            console.info("[HA] action without confirmation dialog:", kind);
        switch (kind) {
        case "none":
            return;
        case "more-info":
            {
                const id = action.entity || entityId;
                if (id && ctx)
                    ctx.moreInfo(id);
                return;
            }
        case "toggle":
            if (entityId)
                Ha.toggle(entityId);
            return;
        case "navigate":
            if (ctx && action.navigation_path)
                ctx.navigate(action.navigation_path);
            return;
        case "url":
            if (action.url_path)
                Qt.openUrlExternally(/^https?:/.test(action.url_path) ? action.url_path : HaService.baseUrl + action.url_path);
            return;
        case "perform-action":
        case "call-service":
            {
                const svc = String(action.perform_action ?? action.service ?? "");
                const dot = svc.indexOf(".");
                if (dot < 0)
                    return;
                const data = action.data ?? action.service_data ?? {};
                const target = action.target && Object.keys(action.target).length ? action.target : null;
                HaService.callService(svc.slice(0, dot), svc.slice(dot + 1), data, target);
                return;
            }
        }
    }
}
