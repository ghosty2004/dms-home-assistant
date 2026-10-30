import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "homeAssistantDash"

    StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        text: "Leave URL and token empty to reuse the ones from the Home Assistant Monitor plugin. Create a token in Home Assistant → Profile → Security → Long-lived access tokens."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    StringSetting {
        settingKey: "hassUrl"
        label: "Home Assistant URL"
        description: "e.g. http://homeassistant.local:8123"
        placeholder: "https://homeassistant.example.com"
    }

    StringSetting {
        settingKey: "hassToken"
        label: "Long-lived access token"
        placeholder: "eyJhbGciOi…"
    }

    SelectionSetting {
        settingKey: "colorMode"
        label: "State colors"
        description: "Home Assistant colors (amber lights, orange heating…), the same meaning in your theme's accent hues, or only your theme accent"
        options: [
            {
                label: "Home Assistant",
                value: "ha"
            },
            {
                label: "Harmonized with theme",
                value: "harmonized"
            },
            {
                label: "Theme accent",
                value: "theme"
            }
        ]
        defaultValue: "ha"
    }

    ToggleSetting {
        settingKey: "showUnavailable"
        label: "Show unavailable entities"
        defaultValue: true
    }

    StringSetting {
        settingKey: "barEntity"
        label: "Bar entity"
        description: "Entity shown in the bar pill (e.g. sensor.living_room_temperature). Right click the pill toggles it. Empty = lights on count."
        placeholder: "sensor.outdoor_temperature"
    }
}
