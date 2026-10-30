import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "components"

PluginComponent {
    id: root

    property var popoutService: null

    readonly property string barEntity: HaService.barEntity
    readonly property var barState: {
        HaService.stateRev;
        return barEntity ? HaService.states[barEntity] : null;
    }
    readonly property int lightsOn: {
        HaService.stateRev;
        let n = 0;
        for (const id of Ha.index.all) {
            if (Ha.domainOf(id) === "light" && HaService.states[id]?.state === "on")
                n++;
        }
        return n;
    }
    readonly property string label: {
        if (!HaService.connected)
            return "";
        if (barEntity && barState)
            return Ha.stateText(barEntity, barState);
        return lightsOn > 0 ? String(lightsOn) : "";
    }
    readonly property string icon: {
        if (!HaService.connected)
            return HaService.status === "error" ? "mdi:home-alert" : "mdi:home-assistant";
        if (barEntity && barState)
            return Ha.iconName(barEntity, barState);
        return lightsOn > 0 ? "mdi:home-lightbulb" : "mdi:home-assistant";
    }
    readonly property color iconColor: {
        if (HaService.status === "error")
            return Theme.error;
        if (barEntity && barState && Ha.isActive(barEntity, barState))
            return Ha.stateColor(barEntity, barState);
        return lightsOn > 0 && !barEntity ? Ha.palette.amber : Theme.widgetIconColor;
    }

    pillClickAction: (x, y, width, section, screen) => popoutService?.toggleDankDash("plugin_" + pluginId, x, y, width, section, screen)
    pillRightClickAction: () => {
        if (root.barEntity && Ha.canToggle(root.barEntity))
            Ha.toggle(root.barEntity);
        else
            HaService.reconnect();
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            MdiIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.icon
                size: root.iconSize
                color: root.iconColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.label !== ""
                text: root.label
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            MdiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.icon
                size: root.iconSize
                color: root.iconColor
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.label !== ""
                text: root.label
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
            }
        }
    }
}
