pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtWebSockets
import Quickshell
import qs.Common
import qs.Services

// One Home Assistant WebSocket connection shared by every surface of the plugin.
Singleton {
    id: root

    readonly property string pluginId: "homeAssistantDash"
    readonly property string legacyPluginId: "homeAssistantMonitor"

    // Settings
    property string url: ""
    property string token: ""
    property string colorMode: "ha"
    property bool showUnavailable: true
    property string barEntity: ""
    property var favorites: []
    property var hiddenEntities: []

    // True while the Home tab is on screen; refresh timers only run then.
    property bool dashLive: false

    readonly property bool configured: url !== "" && token !== ""
    readonly property string baseUrl: url.replace(/\/+$/, "")
    readonly property string wsUrl: baseUrl.replace(/^http/, "ws") + "/api/websocket"

    // Connection
    property string status: "idle"
    property string errorText: ""
    readonly property bool connected: status === "connected"
    property bool statesLoaded: false
    property bool registryLoaded: false
    readonly property bool ready: statesLoaded && registryLoaded

    // Data
    property var states: ({})
    property var areas: []
    property var floors: []
    property var devices: ({})
    property var entityReg: ({})
    property var iconResources: ({})
    property var entityIconResources: ({})
    property var translations: ({})
    property var haConfig: ({})
    property var currentUser: null
    property var notifications: ({})

    // Revisions: bump instead of re-assigning big objects
    property int setRev: 0
    property int stateRev: 0
    property int registryRev: 0
    property int translationRev: 0

    signal entityUpdated(string entityId)
    signal pageRequested(string page, string arg)
    signal moreInfoRequested(string entityId)

    // Consumed by the dash tab when it is created after the request.
    property string pendingPage: ""
    property string pendingArg: ""
    property string pendingMoreInfo: ""

    function requestPage(page, arg) {
        pendingPage = page || "";
        pendingArg = arg || "";
        pageRequested(pendingPage, pendingArg);
    }

    function requestMoreInfo(entityId) {
        pendingMoreInfo = entityId || "";
        moreInfoRequested(pendingMoreInfo);
    }

    property int _msgId: 0
    property var _callbacks: ({})
    property var _subscriptions: ({})
    property int _retryDelay: 2000
    property bool _authFailed: false
    property var _loadedEntityPlatforms: ({})

    Component.onCompleted: {
        loadSettings();
        reconnect();
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.loadSettings();
        }
    }

    function setting(key, fallback) {
        return PluginService.loadPluginData(pluginId, key, fallback);
    }

    function loadSettings() {
        let newUrl = String(setting("hassUrl", "") || "").trim();
        let newToken = String(setting("hassToken", "") || "").trim();
        // Reuse the credentials of the older Home Assistant Monitor plugin when ours are empty.
        if (newUrl === "")
            newUrl = String(PluginService.loadPluginData(legacyPluginId, "hassUrl", "") || "").trim();
        if (newToken === "")
            newToken = String(PluginService.loadPluginData(legacyPluginId, "hassToken", "") || "").trim();
        colorMode = setting("colorMode", "ha") || "ha";
        showUnavailable = setting("showUnavailable", true) !== false;
        barEntity = setting("barEntity", "") || "";
        favorites = setting("favorites", []) || [];
        hiddenEntities = setting("hiddenEntities", []) || [];
        if (newUrl !== url || newToken !== token) {
            url = newUrl;
            token = newToken;
            _authFailed = false;
            reconnect();
        }
        setRev++;
    }

    function saveSetting(key, value) {
        PluginService.savePluginData(pluginId, key, value);
    }

    // ---------------------------------------------------------------- connection

    function reconnect() {
        retryTimer.stop();
        socket.active = false;
        _resetSession();
        if (!configured) {
            status = "unconfigured";
            return;
        }
        status = "connecting";
        errorText = "";
        Qt.callLater(() => {
            socket.url = root.wsUrl;
            socket.active = true;
        });
    }

    function _resetSession() {
        const pending = _callbacks;
        _callbacks = {};
        _subscriptions = {};
        for (const id in pending) {
            const cb = pending[id];
            if (cb)
                cb(null, {
                    code: "disconnected",
                    message: "Connection closed"
                });
        }
    }

    function _scheduleRetry() {
        if (_authFailed || !configured)
            return;
        retryTimer.interval = _retryDelay;
        retryTimer.restart();
        _retryDelay = Math.min(_retryDelay * 2, 30000);
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root.reconnect()
    }

    Timer {
        id: pingTimer
        interval: 30000
        repeat: true
        running: root.connected
        onTriggered: root.send({
            type: "ping"
        }, null)
    }

    WebSocket {
        id: socket
        active: false
        onTextMessageReceived: message => root._onMessage(message)
        onStatusChanged: {
            switch (socket.status) {
            case WebSocket.Open:
                root.status = "authenticating";
                break;
            case WebSocket.Error:
                root.errorText = socket.errorString;
                root.status = "error";
                socket.active = false;
                root._resetSession();
                root._scheduleRetry();
                break;
            case WebSocket.Closed:
                if (root.status === "connected" || root.status === "authenticating" || root.status === "connecting") {
                    root.status = root._authFailed ? "error" : "connecting";
                    root._resetSession();
                    root._scheduleRetry();
                }
                break;
            }
        }
    }

    function _sendRaw(obj) {
        if (socket.status !== WebSocket.Open)
            return false;
        socket.sendTextMessage(JSON.stringify(obj));
        return true;
    }

    // Sends a command; cb(result, error) is called once with the result.
    function send(msg, cb) {
        const id = ++_msgId;
        msg.id = id;
        if (cb)
            _callbacks[id] = cb;
        if (!_sendRaw(msg)) {
            delete _callbacks[id];
            if (cb)
                cb(null, {
                    code: "not_connected",
                    message: "Not connected to Home Assistant"
                });
            return -1;
        }
        return id;
    }

    function subscribe(msg, onEvent, cb) {
        const id = send(msg, cb);
        if (id > 0)
            _subscriptions[id] = onEvent;
        return id;
    }

    function _onMessage(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            console.warn("[HA] bad message", e);
            return;
        }
        const list = Array.isArray(data) ? data : [data];
        for (const msg of list)
            _handle(msg);
    }

    function _handle(msg) {
        switch (msg.type) {
        case "auth_required":
            _sendRaw({
                type: "auth",
                access_token: token
            });
            return;
        case "auth_ok":
            _retryDelay = 2000;
            status = "connected";
            errorText = "";
            haConfig = Object.assign({}, haConfig, {
                version: msg.ha_version
            });
            _bootstrap();
            return;
        case "auth_invalid":
            _authFailed = true;
            errorText = msg.message || "Invalid access token";
            status = "error";
            socket.active = false;
            return;
        case "result":
            {
                const cb = _callbacks[msg.id];
                if (cb) {
                    delete _callbacks[msg.id];
                    cb(msg.success ? msg.result : null, msg.success ? null : (msg.error || {
                            message: "Unknown error"
                        }));
                }
                return;
            }
        case "event":
            {
                const handler = _subscriptions[msg.id];
                if (handler)
                    handler(msg.event);
                return;
            }
        case "pong":
            {
                const cb = _callbacks[msg.id];
                if (cb) {
                    delete _callbacks[msg.id];
                    cb(true, null);
                }
                return;
            }
        }
    }

    // ---------------------------------------------------------------- bootstrap

    function _bootstrap() {
        statesLoaded = false;
        registryLoaded = false;
        _loadedEntityPlatforms = {};
        states = {};
        subscribe({
            type: "subscribe_entities"
        }, ev => _onEntities(ev), null);
        send({
            type: "get_config"
        }, res => {
            if (!res)
                return;
            haConfig = res;
            _loadTranslations("entity_component", null);
        });
        send({
            type: "auth/current_user"
        }, res => {
            if (res)
                currentUser = res;
        });
        send({
            type: "frontend/get_icons",
            category: "entity_component"
        }, res => {
            if (res?.resources) {
                iconResources = res.resources;
                registryRev++;
            }
        });
        _loadRegistries();
        for (const ev of ["area_registry_updated", "device_registry_updated", "entity_registry_updated", "floor_registry_updated"]) {
            subscribe({
                type: "subscribe_events",
                event_type: ev
            }, () => registryReload.restart(), null);
        }
        subscribe({
            type: "persistent_notification/subscribe"
        }, ev => _onNotifications(ev), null);
    }

    Timer {
        id: registryReload
        interval: 1500
        onTriggered: root._loadRegistries()
    }

    function _loadRegistries() {
        let pending = 4;
        const done = () => {
            if (--pending > 0)
                return;
            registryLoaded = true;
            registryRev++;
            setRev++;
            _loadEntityResources();
        };
        send({
            type: "config/area_registry/list"
        }, res => {
            if (res)
                areas = res.slice().sort((a, b) => a.name.localeCompare(b.name));
            done();
        });
        send({
            type: "config/floor_registry/list"
        }, res => {
            if (res)
                floors = res;
            done();
        });
        send({
            type: "config/device_registry/list"
        }, res => {
            if (res) {
                const map = {};
                for (const d of res)
                    map[d.id] = d;
                devices = map;
            }
            done();
        });
        send({
            type: "config/entity_registry/list_for_display"
        }, res => {
            if (res?.entities) {
                const map = {};
                for (const e of res.entities)
                    map[e.ei] = e;
                entityReg = map;
            }
            done();
        });
    }

    // Integration specific icons and names (translation_key based)
    function _loadEntityResources() {
        const platforms = [];
        for (const id in entityReg) {
            const e = entityReg[id];
            if (e.pl && !_loadedEntityPlatforms[e.pl] && !platforms.includes(e.pl))
                platforms.push(e.pl);
        }
        if (platforms.length === 0)
            return;
        for (const p of platforms)
            _loadedEntityPlatforms[p] = true;
        send({
            type: "frontend/get_icons",
            category: "entity",
            integration: platforms
        }, res => {
            if (!res?.resources)
                return;
            entityIconResources = Object.assign({}, entityIconResources, res.resources);
            registryRev++;
        });
        _loadTranslations("entity", platforms);
    }

    function _loadTranslations(category, integrations) {
        const msg = {
            type: "frontend/get_translations",
            language: haConfig.language || "en",
            category: category
        };
        if (integrations)
            msg.integration = integrations;
        send(msg, res => {
            if (!res?.resources)
                return;
            translations = Object.assign({}, translations, res.resources);
            translationRev++;
        });
    }

    // ---------------------------------------------------------------- states

    function _expand(id, c) {
        const lc = (c.lc ?? 0) * 1000;
        return {
            entity_id: id,
            state: c.s,
            attributes: c.a || {},
            last_changed: lc,
            last_updated: c.lu !== undefined ? c.lu * 1000 : lc
        };
    }

    function _onEntities(ev) {
        let setChanged = false;
        if (ev.a) {
            for (const id in ev.a) {
                if (!states[id])
                    setChanged = true;
                states[id] = _expand(id, ev.a[id]);
                if (statesLoaded)
                    entityUpdated(id);
            }
            if (!statesLoaded) {
                statesLoaded = true;
                setChanged = true;
            }
        }
        if (ev.c) {
            for (const id in ev.c) {
                const cur = states[id];
                if (!cur)
                    continue;
                const diff = ev.c[id];
                const next = {
                    entity_id: id,
                    state: cur.state,
                    attributes: cur.attributes,
                    last_changed: cur.last_changed,
                    last_updated: cur.last_updated
                };
                const add = diff["+"];
                if (add) {
                    if (add.s !== undefined)
                        next.state = add.s;
                    if (add.a)
                        next.attributes = Object.assign({}, next.attributes, add.a);
                    if (add.lc !== undefined) {
                        next.last_changed = add.lc * 1000;
                        next.last_updated = add.lc * 1000;
                    }
                    if (add.lu !== undefined)
                        next.last_updated = add.lu * 1000;
                }
                const rem = diff["-"];
                if (rem?.a) {
                    const attrs = Object.assign({}, next.attributes);
                    for (const k of rem.a)
                        delete attrs[k];
                    next.attributes = attrs;
                }
                states[id] = next;
                entityUpdated(id);
            }
        }
        if (ev.r) {
            for (const id of ev.r)
                delete states[id];
            setChanged = true;
        }
        if (setChanged)
            setRev++;
        stateThrottle.start();
    }

    Timer {
        id: stateThrottle
        interval: 350
        onTriggered: root.stateRev++
    }

    function _onNotifications(ev) {
        const next = ev.type === "current" ? {} : Object.assign({}, notifications);
        const items = ev.notifications || {};
        for (const id in items) {
            if (ev.type === "removed")
                delete next[id];
            else
                next[id] = items[id];
        }
        notifications = next;
    }

    // ---------------------------------------------------------------- lookups

    function get(entityId) {
        return states[entityId] ?? null;
    }

    function domainOf(entityId) {
        const i = entityId.indexOf(".");
        return i > 0 ? entityId.slice(0, i) : entityId;
    }

    function areaIdOf(entityId) {
        const reg = entityReg[entityId];
        if (!reg)
            return "";
        if (reg.ai)
            return reg.ai;
        if (reg.di)
            return devices[reg.di]?.area_id || "";
        return "";
    }

    function area(areaId) {
        return areas.find(a => a.area_id === areaId) ?? null;
    }

    function deviceOf(entityId) {
        const reg = entityReg[entityId];
        return reg?.di ? (devices[reg.di] ?? null) : null;
    }

    function tr(key) {
        return translations[key];
    }

    function mediaUrl(path) {
        if (!path)
            return "";
        if (/^https?:\/\//.test(path))
            return path;
        return baseUrl + path;
    }

    // ---------------------------------------------------------------- actions

    function callService(domain, service, data, target, cb) {
        const msg = {
            type: "call_service",
            domain: domain,
            service: service,
            service_data: data || {}
        };
        if (target)
            msg.target = typeof target === "string" ? {
                entity_id: target
            } : target;
        send(msg, (res, err) => {
            if (err) {
                console.warn("[HA] service", domain + "." + service, "failed:", err.message);
                ToastService.showError("Home Assistant: " + domain + "." + service + " failed", err.message || "");
            }
            if (cb)
                cb(res, err);
        });
    }

    function fetchHistory(entityIds, hours, cb) {
        const start = new Date(Date.now() - hours * 3600 * 1000);
        send({
            type: "history/history_during_period",
            start_time: start.toISOString(),
            entity_ids: entityIds,
            minimal_response: true,
            no_attributes: true,
            significant_changes_only: false
        }, (res, err) => cb(res || {}, err));
    }


    function isFavorite(entityId) {
        return favorites.includes(entityId);
    }

    function toggleFavorite(entityId) {
        const next = favorites.slice();
        const i = next.indexOf(entityId);
        if (i >= 0)
            next.splice(i, 1);
        else
            next.push(entityId);
        favorites = next;
        saveSetting("favorites", next);
    }

    function moveFavorite(entityId, delta) {
        const next = favorites.slice();
        const i = next.indexOf(entityId);
        const j = i + delta;
        if (i < 0 || j < 0 || j >= next.length)
            return;
        next.splice(i, 1);
        next.splice(j, 0, entityId);
        favorites = next;
        saveSetting("favorites", next);
    }

    function dismissNotification(id) {
        callService("persistent_notification", "dismiss", {
            notification_id: id
        });
    }
}
