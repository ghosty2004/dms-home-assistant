pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import "assets/MdiMap.js" as Mdi

// Home Assistant frontend logic: icons, state colors, state text, grouping and actions.
Singleton {
    id: root

    readonly property string iconFont: mdiFont.name

    FontLoader {
        id: mdiFont
        source: Qt.resolvedUrl("assets/materialdesignicons-webfont.ttf")
    }

    function glyph(name) {
        return Mdi.glyph(name) || Mdi.glyph("mdi:help-circle-outline");
    }

    // ---------------------------------------------------------------- palette (HA color.globals)

    readonly property var palette: ({
            red: "#f44336",
            pink: "#e91e63",
            purple: "#926bc7",
            deepPurple: "#6e41ab",
            indigo: "#3f51b5",
            blue: "#2196f3",
            lightBlue: "#03a9f4",
            cyan: "#00bcd4",
            teal: "#009688",
            green: "#4caf50",
            lightGreen: "#8bc34a",
            lime: "#cddc39",
            yellow: "#ffeb3b",
            amber: "#ffc107",
            orange: "#ff9800",
            deepOrange: "#ff6f22",
            brown: "#795548",
            grey: "#9e9e9e"
        })

    readonly property color inactiveColor: Theme.surfaceVariantText
    readonly property bool themeColors: HaService.colorMode === "theme"

    // ---------------------------------------------------------------- domains

    readonly property var hiddenDomains: ["update", "tts", "stt", "conversation", "notify", "event", "zone", "ai_task", "wake_word", "tag", "image", "todo", "calendar", "assist_satellite", "device_tracker", "persistent_notification", "geo_location", "infrared", "radio_frequency", "text", "date", "datetime", "time", "sun", "weather", "group"]

    readonly property var fallbackIcons: ({
            ai_task: "mdi:star-four-points",
            air_quality: "mdi:air-filter",
            alarm_control_panel: "mdi:shield",
            alert: "mdi:alert",
            automation: "mdi:robot",
            binary_sensor: "mdi:radiobox-blank",
            button: "mdi:button-pointer",
            calendar: "mdi:calendar",
            camera: "mdi:video",
            climate: "mdi:thermostat",
            conversation: "mdi:forum-outline",
            counter: "mdi:counter",
            cover: "mdi:window-open",
            date: "mdi:calendar",
            datetime: "mdi:calendar-clock",
            device_tracker: "mdi:account",
            fan: "mdi:fan",
            group: "mdi:google-circles-communities",
            humidifier: "mdi:air-humidifier",
            image: "mdi:image",
            input_boolean: "mdi:toggle-switch-outline",
            input_button: "mdi:button-pointer",
            input_datetime: "mdi:calendar-clock",
            input_number: "mdi:ray-vertex",
            input_select: "mdi:format-list-bulleted",
            input_text: "mdi:form-textbox",
            lawn_mower: "mdi:robot-mower",
            light: "mdi:lightbulb",
            lock: "mdi:lock",
            media_player: "mdi:cast",
            notify: "mdi:comment-alert",
            number: "mdi:ray-vertex",
            person: "mdi:account",
            plant: "mdi:flower",
            remote: "mdi:remote",
            scene: "mdi:palette",
            schedule: "mdi:calendar-clock",
            script: "mdi:script-text",
            select: "mdi:format-list-bulleted",
            sensor: "mdi:eye",
            siren: "mdi:bullhorn",
            sun: "mdi:white-balance-sunny",
            switch: "mdi:toggle-switch-variant",
            text: "mdi:form-textbox",
            time: "mdi:clock",
            timer: "mdi:timer-outline",
            todo: "mdi:clipboard-list",
            update: "mdi:package-up",
            vacuum: "mdi:robot-vacuum",
            valve: "mdi:valve",
            water_heater: "mdi:thermometer",
            weather: "mdi:weather-partly-cloudy",
            zone: "mdi:map-marker-radius"
        })

    readonly property var toggleDomains: ["light", "switch", "fan", "input_boolean", "automation", "siren", "humidifier", "remote", "group", "valve", "cover", "lock", "media_player", "climate", "water_heater", "vacuum", "lawn_mower", "alarm_control_panel"]
    readonly property var runDomains: ["scene", "script", "button", "input_button"]

    function domainOf(entityId) {
        return HaService.domainOf(entityId);
    }

    // ---------------------------------------------------------------- icons

    function pickIcon(res, state, attrs) {
        if (!res)
            return "";
        if (res.state && state !== undefined && res.state[state])
            return res.state[state];
        if (res.range && state !== undefined && state !== "" && !isNaN(Number(state))) {
            const v = Number(state);
            let best = "";
            let bestKey = -Infinity;
            for (const k in res.range) {
                const n = Number(k);
                if (n <= v && n > bestKey) {
                    bestKey = n;
                    best = res.range[k];
                }
            }
            if (best)
                return best;
        }
        return res.default || "";
    }

    function batteryIcon(state) {
        const level = Number(state);
        if (state === "unavailable" || state === "unknown" || state === "" || isNaN(level))
            return "mdi:battery-unknown";
        const rounded = Math.round(level / 10) * 10;
        if (rounded >= 100)
            return "mdi:battery";
        if (rounded <= 0)
            return "mdi:battery-alert";
        return "mdi:battery-" + rounded;
    }

    function iconName(entityId, st) {
        HaService.registryRev;
        const reg = HaService.entityReg[entityId];
        if (reg?.ic)
            return reg.ic;
        const attrs = st?.attributes ?? {};
        if (attrs.icon)
            return attrs.icon;
        const domain = domainOf(entityId);
        const state = st?.state;
        if (domain === "sensor" && attrs.device_class === "battery")
            return batteryIcon(state);
        if (reg?.tk && reg.pl) {
            const icon = pickIcon(HaService.entityIconResources?.[reg.pl]?.[domain]?.[reg.tk], state, attrs);
            if (icon)
                return icon;
        }
        const component = HaService.iconResources?.[domain];
        if (component) {
            const icon = pickIcon(component[attrs.device_class] ?? component["_"], state, attrs) || pickIcon(component["_"], state, attrs);
            if (icon)
                return icon;
        }
        if (domain === "sensor" && attrs.unit_of_measurement && /°|K$/.test(attrs.unit_of_measurement))
            return "mdi:thermometer";
        return fallbackIcons[domain] || "mdi:bookmark";
    }

    function areaIcon(area) {
        if (area?.icon)
            return area.icon;
        const n = (area?.name || "").toLowerCase();
        const guesses = [[/bed/, "mdi:bed"], [/kitchen/, "mdi:countertop"], [/living|lounge/, "mdi:sofa"], [/bath|toilet/, "mdi:shower"], [/office|study/, "mdi:desk"], [/garage/, "mdi:garage"], [/garden|yard/, "mdi:flower"], [/entr|hall/, "mdi:door"], [/balcon|terrace/, "mdi:balcony"], [/kid|child/, "mdi:teddy-bear"], [/dining/, "mdi:silverware-fork-knife"], [/laundry/, "mdi:washing-machine"]];
        for (const g of guesses) {
            if (g[0].test(n))
                return g[1];
        }
        return "mdi:texture-box";
    }

    // ---------------------------------------------------------------- state logic

    function isUnavailable(st) {
        return !st || st.state === "unavailable" || st.state === "unknown";
    }

    function isActive(entityId, st) {
        if (!st)
            return false;
        const domain = domainOf(entityId);
        const s = st.state;
        if (["button", "event", "input_button", "scene"].includes(domain))
            return false;
        if (s === "unavailable" || s === "unknown")
            return false;
        if (s === "off" && domain !== "alert")
            return false;
        switch (domain) {
        case "alarm_control_panel":
            return s !== "disarmed";
        case "alert":
            return s !== "idle";
        case "cover":
        case "valve":
            return s !== "closed";
        case "device_tracker":
        case "person":
            return s !== "not_home";
        case "lawn_mower":
            return ["mowing", "error"].includes(s);
        case "lock":
            return s !== "locked";
        case "media_player":
            return s !== "standby" && s !== "idle";
        case "vacuum":
            return !["idle", "docked", "paused"].includes(s);
        case "plant":
            return s === "problem";
        case "group":
            return ["on", "home", "open", "locked", "problem"].includes(s);
        case "timer":
            return s === "active";
        case "camera":
            return s === "streaming" || s === "recording";
        case "sensor":
        case "number":
        case "input_number":
        case "select":
        case "input_select":
        case "input_text":
            return true;
        }
        return true;
    }

    function rgbToColor(rgb) {
        if (!rgb || rgb.length < 3)
            return null;
        // Lift very dark colors so the icon stays visible on the dark surface.
        let r = rgb[0], g = rgb[1], b = rgb[2];
        const max = Math.max(r, g, b, 1);
        if (max < 140) {
            const k = 140 / max;
            r *= k;
            g *= k;
            b *= k;
        }
        return Qt.rgba(Math.min(255, r) / 255, Math.min(255, g) / 255, Math.min(255, b) / 255, 1);
    }

    // Returns the HA state color of an entity, or the inactive color.
    function stateColor(entityId, st) {
        if (!st || st.state === "unavailable")
            return inactiveColor;
        const domain = domainOf(entityId);
        const s = st.state;
        const a = st.attributes ?? {};
        const dc = a.device_class;
        const active = isActive(entityId, st);
        const P = palette;

        // State specific colors that apply even when "inactive"
        if (domain === "lock")
            return s === "locked" ? P.green : s === "jammed" || s === "unlocked" || s === "open" ? P.red : s === "locking" || s === "unlocking" || s === "opening" ? P.orange : inactiveColor;
        if (domain === "sensor" && dc === "battery") {
            const v = Number(s);
            if (isNaN(v))
                return inactiveColor;
            return v >= 70 ? P.green : v >= 30 ? P.orange : P.red;
        }
        if (domain === "person" || domain === "device_tracker")
            return s === "home" ? P.green : s === "not_home" ? inactiveColor : P.blue;
        if (domain === "sun")
            return s === "above_horizon" ? P.amber : P.indigo;
        if (!active)
            return ["sensor", "number", "input_number", "select", "input_select"].includes(domain) ? Theme.primary : inactiveColor;
        if (themeColors) {
            if (domain === "light" && a.rgb_color)
                return rgbToColor(a.rgb_color);
            return Theme.primary;
        }
        switch (domain) {
        case "light":
            return rgbToColor(a.rgb_color) ?? P.amber;
        case "switch":
        case "input_boolean":
        case "remote":
        case "script":
        case "schedule":
        case "timer":
        case "calendar":
        case "group":
            return P.amber;
        case "automation":
            return Theme.primary;
        case "binary_sensor":
            return ["battery", "carbon_monoxide", "gas", "heat", "lock", "moisture", "problem", "safety", "smoke", "sound", "tamper"].includes(dc) ? P.red : P.amber;
        case "climate":
            return {
                auto: P.green,
                cool: P.blue,
                dry: P.orange,
                fan_only: P.cyan,
                heat: P.deepOrange,
                heat_cool: P.amber
            }[s] ?? P.amber;
        case "water_heater":
            return {
                eco: P.green,
                electric: P.orange,
                gas: P.orange,
                heat_pump: P.orange,
                high_demand: P.deepOrange,
                performance: P.deepOrange
            }[s] ?? P.orange;
        case "cover":
            return P.purple;
        case "valve":
            return P.blue;
        case "fan":
            return P.cyan;
        case "humidifier":
            return P.blue;
        case "media_player":
            return P.lightBlue;
        case "alarm_control_panel":
            return s === "triggered" ? P.red : s === "arming" || s === "pending" ? P.orange : P.green;
        case "alert":
        case "siren":
        case "plant":
            return P.red;
        case "update":
            return P.orange;
        case "vacuum":
        case "lawn_mower":
            return P.teal;
        case "camera":
            return P.blue;
        }
        return Theme.primary;
    }

    // ---------------------------------------------------------------- text

    function capitalize(s) {
        s = String(s ?? "");
        return s.length ? s.charAt(0).toUpperCase() + s.slice(1).replace(/_/g, " ") : s;
    }

    function isNumeric(v) {
        return v !== null && v !== "" && !isNaN(Number(v)) && isFinite(Number(v));
    }

    function formatNumber(value, precision) {
        const n = Number(value);
        if (precision !== undefined && precision !== null)
            return n.toLocaleString(Qt.locale(), "f", precision);
        if (Number.isInteger(n))
            return String(n);
        return String(Math.round(n * 100) / 100);
    }

    function withUnit(text, unit) {
        if (!unit)
            return text;
        return text + (unit === "%" ? "" : " ") + unit;
    }

    function relativeTime(ms) {
        if (!ms || isNaN(ms))
            return "";
        const diff = (ms - Date.now()) / 1000;
        const abs = Math.abs(diff);
        const units = [[60, "second", 1], [3600, "minute", 60], [86400, "hour", 3600], [86400 * 30, "day", 86400], [86400 * 365, "month", 86400 * 30], [Infinity, "year", 86400 * 365]];
        for (let i = 0; i < units.length; i++) {
            const limit = units[i][0], name = units[i][1], div = units[i][2];
            if (abs < limit) {
                const n = Math.max(1, Math.round(abs / div));
                if (name === "second" && abs < 45)
                    return diff < 0 ? "just now" : "now";
                const label = n + " " + name + (n === 1 ? "" : "s");
                return diff < 0 ? label + " ago" : "in " + label;
            }
        }
        return "";
    }

    function translateState(entityId, st, state) {
        HaService.translationRev;
        const domain = domainOf(entityId);
        const reg = HaService.entityReg[entityId];
        const dc = st?.attributes?.device_class;
        const t = HaService.translations;
        if (reg?.tk && reg.pl) {
            const v = t["component." + reg.pl + ".entity." + domain + "." + reg.tk + ".state." + state];
            if (v)
                return v;
        }
        if (dc) {
            const v = t["component." + domain + ".entity_component." + dc + ".state." + state];
            if (v)
                return v;
        }
        return t["component." + domain + ".entity_component._.state." + state] ?? "";
    }

    function translateAttribute(entityId, attribute, value) {
        HaService.translationRev;
        const domain = domainOf(entityId);
        const reg = HaService.entityReg[entityId];
        const t = HaService.translations;
        if (reg?.tk && reg.pl) {
            const v = t["component." + reg.pl + ".entity." + domain + "." + reg.tk + ".state_attributes." + attribute + ".state." + value];
            if (v)
                return v;
        }
        return t["component." + domain + ".entity_component._.state_attributes." + attribute + ".state." + value] ?? capitalize(value);
    }

    function attributeName(entityId, attribute) {
        HaService.translationRev;
        const domain = domainOf(entityId);
        return HaService.translations["component." + domain + ".entity_component._.state_attributes." + attribute + ".name"] ?? capitalize(attribute);
    }

    function stateText(entityId, st) {
        if (!st)
            return "Not found";
        const s = st.state;
        if (s === "unavailable")
            return "Unavailable";
        if (s === "unknown")
            return "Unknown";
        const domain = domainOf(entityId);
        const a = st.attributes ?? {};
        const reg = HaService.entityReg[entityId];
        if (["sensor", "number", "input_number", "counter"].includes(domain)) {
            if (a.device_class === "timestamp")
                return relativeTime(Date.parse(s));
            if (a.device_class === "date")
                return s;
            if (isNumeric(s))
                return withUnit(formatNumber(s, reg?.dp), a.unit_of_measurement);
        }
        if (["input_datetime", "datetime", "date", "time"].includes(domain))
            return s;
        if (domain === "button" || domain === "input_button" || domain === "scene" || domain === "event")
            return isNumeric(Date.parse(s)) && s.includes("T") ? relativeTime(Date.parse(s)) : s;
        if ((domain === "person" || domain === "device_tracker") && s !== "home" && s !== "not_home")
            return s;
        return translateState(entityId, st, s) || capitalize(s);
    }

    function brightnessPct(st) {
        const b = st?.attributes?.brightness;
        return b === undefined || b === null ? -1 : Math.round(b / 255 * 100);
    }

    function temperatureUnit() {
        return HaService.haConfig?.unit_system?.temperature ?? "°C";
    }

    // Secondary line of a tile, like the HA tile card.
    function secondaryText(entityId, st) {
        if (!st)
            return "";
        const domain = domainOf(entityId);
        const a = st.attributes ?? {};
        const base = stateText(entityId, st);
        if (isUnavailable(st))
            return base;
        switch (domain) {
        case "light":
            {
                const pct = brightnessPct(st);
                return st.state === "on" && pct >= 0 ? pct + "%" : base;
            }
        case "fan":
            return st.state === "on" && a.percentage ? a.percentage + "%" : base;
        case "cover":
            return a.current_position !== undefined && st.state !== "closed" ? base + " · " + a.current_position + "%" : base;
        case "climate":
            {
                const parts = [];
                parts.push(a.hvac_action ? translateAttribute(entityId, "hvac_action", a.hvac_action) : base);
                if (a.current_temperature !== undefined && a.current_temperature !== null)
                    parts.push(withUnit(formatNumber(a.current_temperature), temperatureUnit()));
                return parts.join(" · ");
            }
        case "water_heater":
            return a.current_temperature !== undefined && a.current_temperature !== null ? base + " · " + withUnit(formatNumber(a.current_temperature), temperatureUnit()) : base;
        case "humidifier":
            return st.state === "on" && a.humidity ? base + " · " + a.humidity + "%" : base;
        case "media_player":
            {
                if (a.media_title)
                    return a.media_artist ? a.media_title + " · " + a.media_artist : a.media_title;
                return base;
            }
        case "automation":
        case "script":
            return a.last_triggered ? base + " · " + relativeTime(Date.parse(a.last_triggered)) : base;
        case "scene":
            return st.state && st.state.includes("T") ? relativeTime(Date.parse(st.state)) : "Scene";
        }
        return base;
    }

    // ---------------------------------------------------------------- names

    function entityName(entityId, st, stripPrefixes) {
        const name = st?.attributes?.friendly_name || String(entityId || "").split(".").pop().replace(/_/g, " ");
        if (!stripPrefixes)
            return name;
        for (const prefix of stripPrefixes) {
            if (!prefix)
                continue;
            const lower = name.toLowerCase();
            const p = prefix.toLowerCase();
            if (lower.startsWith(p + " ") && name.length > prefix.length + 1) {
                const rest = name.slice(prefix.length + 1);
                return rest.charAt(0).toUpperCase() + rest.slice(1);
            }
        }
        return name;
    }

    function areaName(areaId) {
        return HaService.area(areaId)?.name ?? "";
    }

    // ---------------------------------------------------------------- index & categories

    function isHiddenEntity(entityId) {
        const reg = HaService.entityReg[entityId];
        if (reg && (reg.hb || reg.ec !== undefined))
            return true;
        return HaService.hiddenEntities.includes(entityId);
    }

    readonly property var index: {
        HaService.setRev;
        HaService.registryRev;
        return buildIndex();
    }

    function buildIndex() {
        const all = [];
        const byArea = {};
        const states = HaService.states;
        for (const id in states) {
            const domain = domainOf(id);
            if (hiddenDomains.includes(domain) || isHiddenEntity(id))
                continue;
            all.push(id);
            const aid = HaService.areaIdOf(id);
            (byArea[aid] = byArea[aid] || []).push(id);
        }
        const nameOf = id => entityName(id, states[id]).toLowerCase();
        all.sort((x, y) => nameOf(x).localeCompare(nameOf(y)));
        for (const k in byArea)
            byArea[k].sort((x, y) => nameOf(x).localeCompare(nameOf(y)));
        return {
            all: all,
            byArea: byArea
        };
    }

    function visibleFilter(ids) {
        if (HaService.showUnavailable)
            return ids;
        return ids.filter(id => HaService.states[id]?.state !== "unavailable");
    }

    readonly property var sectionOrder: ["Lights", "Climate", "Covers", "Media", "Security", "Switches", "Appliances", "Controls", "Actions", "Sensors", "Other"]
    readonly property var sectionIcons: ({
            Lights: "mdi:lightbulb-group",
            Climate: "mdi:thermostat",
            Covers: "mdi:window-shutter",
            Media: "mdi:play-box-multiple",
            Security: "mdi:shield-home",
            Switches: "mdi:toggle-switch-variant",
            Appliances: "mdi:washing-machine",
            Controls: "mdi:tune-variant",
            Actions: "mdi:gesture-tap-button",
            Sensors: "mdi:chart-line-variant",
            Other: "mdi:dots-horizontal-circle-outline"
        })

    function sectionOf(entityId) {
        const domain = domainOf(entityId);
        switch (domain) {
        case "light":
            return "Lights";
        case "climate":
        case "water_heater":
        case "humidifier":
        case "fan":
            return "Climate";
        case "cover":
        case "valve":
            return "Covers";
        case "media_player":
        case "remote":
            return "Media";
        case "lock":
        case "alarm_control_panel":
        case "camera":
        case "siren":
            return "Security";
        case "switch":
        case "input_boolean":
            return "Switches";
        case "vacuum":
        case "lawn_mower":
            return "Appliances";
        case "number":
        case "input_number":
        case "select":
        case "input_select":
        case "input_text":
        case "counter":
        case "timer":
            return "Controls";
        case "scene":
        case "script":
        case "automation":
        case "button":
        case "input_button":
            return "Actions";
        case "sensor":
        case "binary_sensor":
        case "person":
        case "air_quality":
            return "Sensors";
        }
        return "Other";
    }

    function groupBySection(ids) {
        const groups = {};
        for (const id of ids) {
            const s = sectionOf(id);
            (groups[s] = groups[s] || []).push(id);
        }
        return sectionOrder.filter(s => groups[s]).map(s => ({
                    title: s,
                    icon: sectionIcons[s],
                    ids: groups[s]
                }));
    }

    function groupByArea(ids) {
        const groups = {};
        for (const id of ids) {
            const a = HaService.areaIdOf(id);
            (groups[a] = groups[a] || []).push(id);
        }
        const result = [];
        for (const area of HaService.areas) {
            if (groups[area.area_id])
                result.push({
                    title: area.name,
                    icon: areaIcon(area),
                    areaId: area.area_id,
                    ids: groups[area.area_id]
                });
        }
        if (groups[""])
            result.push({
                title: "Unassigned",
                icon: "mdi:home-outline",
                areaId: "",
                ids: groups[""]
            });
        return result;
    }

    readonly property var securityBinaryClasses: ["door", "window", "garage_door", "opening", "motion", "occupancy", "presence", "smoke", "gas", "carbon_monoxide", "moisture", "tamper", "safety", "vibration", "lock", "problem", "sound"]

    function matchesCategory(category, entityId) {
        const domain = domainOf(entityId);
        const dc = HaService.states[entityId]?.attributes?.device_class;
        switch (category) {
        case "lights":
            return domain === "light";
        case "climate":
            return ["climate", "water_heater", "humidifier", "fan"].includes(domain) || (domain === "sensor" && ["temperature", "humidity"].includes(dc));
        case "security":
            return ["alarm_control_panel", "lock", "camera", "siren"].includes(domain) || (domain === "binary_sensor" && securityBinaryClasses.includes(dc)) || (domain === "cover" && ["garage", "gate", "door"].includes(dc));
        case "media":
            return domain === "media_player";
        case "automations":
            return ["scene", "script", "automation"].includes(domain);
        case "switches":
            return ["switch", "input_boolean"].includes(domain);
        case "sensors":
            return domain === "sensor" || domain === "binary_sensor";
        }
        return true;
    }

    function categoryIds(category) {
        return visibleFilter(index.all.filter(id => matchesCategory(category, id)));
    }

    // Inline control shown under a tile (HA tile "features").
    function featureKind(entityId, st) {
        if (!st || st.state === "unavailable")
            return "";
        const domain = domainOf(entityId);
        const a = st.attributes ?? {};
        const sf = a.supported_features ?? 0;
        switch (domain) {
        case "light":
            {
                const modes = a.supported_color_modes ?? [];
                return modes.length && !(modes.length === 1 && modes[0] === "onoff") ? "brightness" : "";
            }
        case "fan":
            return (sf & 1) ? "fan" : "";
        case "cover":
            return (sf & 3) ? "cover" : "";
        case "climate":
            return a.temperature !== undefined && a.temperature !== null ? "target" : "";
        case "water_heater":
            return a.temperature !== undefined && a.temperature !== null ? "target" : "";
        case "media_player":
            return "media";
        case "input_number":
        case "number":
            return a.mode === "box" ? "" : "number";
        }
        return "";
    }

    // ---------------------------------------------------------------- actions

    function canToggle(entityId) {
        const domain = domainOf(entityId);
        return toggleDomains.includes(domain) || runDomains.includes(domain);
    }

    function toggle(entityId) {
        const st = HaService.get(entityId);
        if (!st || st.state === "unavailable")
            return;
        const domain = domainOf(entityId);
        const s = st.state;
        const call = (d, svc, data) => HaService.callService(d, svc, data || {}, entityId);
        switch (domain) {
        case "scene":
            return call("scene", "turn_on");
        case "script":
            return call("script", s === "on" ? "turn_off" : "turn_on");
        case "button":
            return call("button", "press");
        case "input_button":
            return call("input_button", "press");
        case "lock":
            return call("lock", s === "locked" ? "unlock" : "lock");
        case "cover":
            return call("cover", "toggle");
        case "valve":
            return call("valve", "toggle");
        case "media_player":
            if (s === "playing" || s === "paused")
                return call("media_player", "media_play_pause");
            return call("media_player", s === "off" || s === "standby" ? "turn_on" : "turn_off");
        case "climate":
        case "water_heater":
            return call(domain, s === "off" ? "turn_on" : "turn_off");
        case "vacuum":
            return call("vacuum", isActive(entityId, st) ? "return_to_base" : "start");
        case "lawn_mower":
            return call("lawn_mower", s === "mowing" ? "dock" : "start_mowing");
        case "alarm_control_panel":
            return call("alarm_control_panel", s === "disarmed" ? "alarm_arm_home" : "alarm_disarm");
        case "automation":
        case "light":
        case "switch":
        case "fan":
        case "input_boolean":
        case "siren":
        case "humidifier":
        case "remote":
            return call(domain, "toggle");
        }
        return call("homeassistant", "toggle");
    }
}
