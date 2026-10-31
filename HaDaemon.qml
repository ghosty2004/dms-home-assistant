import QtQuick
import Quickshell.Io
import qs.Services

// Keeps the Home Assistant connection alive and exposes IPC for keybinds:
//   dms ipc call homeassistant open lights
//   dms ipc call homeassistant toggle light.kitchen
//   dms ipc call homeassistant more climate.living_room
//   dms ipc call homeassistant call scene.turn_on scene.movie
Item {
    id: root

    property var pluginService: null
    property string pluginId: ""

    readonly property string tabId: "plugin_homeAssistantDash"

    Component.onCompleted: console.info("[HA] daemon started, status:", HaService.status)

    // Same path as `dms ipc call dash open`, which also picks the right bar and screen.
    Process {
        id: opener
        command: ["dms", "ipc", "call", "dash", "open", root.tabId]
    }

    function openDash() {
        // Already open: just switch to our tab, a second `dash open` would toggle it closed.
        const dash = PopoutService.dankDashPopout;
        if (dash && dash.dashVisible) {
            dash.requestTab(root.tabId);
            return;
        }
        opener.running = false;
        opener.running = true;
    }

    IpcHandler {
        target: "homeassistant"

        function open(page: string): string {
            HaService.requestPage(page || "home", "");
            root.openDash();
            return "OK";
        }

        // Lovelace dashboard and view, e.g. "dashboard-home/bedroom"
        function dashboard(path: string): string {
            HaService.requestPage("dashboards", path || "");
            root.openDash();
            return "OK";
        }

        function area(areaId: string): string {
            HaService.requestPage("areas", areaId);
            root.openDash();
            return "OK";
        }

        function more(entityId: string): string {
            if (!HaService.get(entityId))
                return "ERROR: unknown entity " + entityId;
            HaService.requestMoreInfo(entityId);
            root.openDash();
            return "OK";
        }

        function toggle(entityId: string): string {
            if (!HaService.get(entityId))
                return "ERROR: unknown entity " + entityId;
            Ha.toggle(entityId);
            return "OK";
        }

        function call(service: string, entityId: string): string {
            const parts = service.split(".");
            if (parts.length !== 2)
                return "ERROR: service must look like domain.service";
            HaService.callService(parts[0], parts[1], {}, entityId || null);
            return "OK";
        }

        function state(entityId: string): string {
            const st = HaService.get(entityId);
            return st ? Ha.stateText(entityId, st) : "ERROR: unknown entity " + entityId;
        }

        function status(): string {
            return HaService.status + (HaService.errorText ? ": " + HaService.errorText : "");
        }

        function reconnect(): string {
            HaService.reconnect();
            return "OK";
        }
    }
}
