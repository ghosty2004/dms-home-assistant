pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../components"
import ".."

// One row of an entities card: entity rows with a toggle, button, value or
// dropdown, plus the special rows (section, divider, weblink, attribute, text).
Item {
    id: root

    property var config: ({})
    property var ctx: null
    property bool stateColor: false

    readonly property string rowType: config?.type ?? ""
    readonly property string entityId: Lovelace.entityOf(config)
    property var st: HaService.get(entityId)
    readonly property string domain: Ha.domainOf(entityId)
    readonly property bool unavailable: !st || st.state === "unavailable"
    readonly property bool isSpecial: ["section", "divider", "weblink", "text"].includes(rowType)

    implicitHeight: rowType === "divider" ? 17 : rowType === "section" ? 36 : 44

    Connections {
        target: HaService
        function onEntityUpdated(id) {
            if (id === root.entityId)
                root.st = HaService.get(id);
        }
    }
    onEntityIdChanged: st = HaService.get(entityId)

    function secondary() {
        const info = config?.secondary_info;
        if (!info || !st)
            return "";
        switch (info) {
        case "last-changed":
            return Ha.relativeTime(st.last_changed);
        case "last-updated":
            return Ha.relativeTime(st.last_updated);
        case "entity-id":
            return entityId;
        case "brightness":
            return Ha.brightnessPct(st) >= 0 ? Ha.brightnessPct(st) + "%" : "";
        case "position":
            return st.attributes?.current_position !== undefined ? st.attributes.current_position + "%" : "";
        }
        return "";
    }

    Rectangle {
        visible: root.rowType === "divider"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: Theme.withAlpha(Theme.outline, 0.25)
    }

    StyledText {
        visible: root.rowType === "section"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: root.config?.label ?? ""
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Theme.fontWeightMedium
        color: Theme.primary
    }

    // icon + name (entity, weblink, attribute, text, button rows)
    Item {
        anchors.fill: parent
        visible: root.rowType !== "divider" && root.rowType !== "section"

        StateLayer {
            anchors.fill: parent
            cornerRadius: Theme.cornerRadiusS
            enabled: root.rowType === "weblink" || (!root.isSpecial && root.entityId !== "")
            onClicked: {
                if (root.rowType === "weblink")
                    Qt.openUrlExternally(/^https?:/.test(root.config.url ?? "") ? root.config.url : HaService.baseUrl + (root.config.url ?? ""));
                else
                    Lovelace.runAction(root.config?.tap_action ?? Lovelace.defaultTapAction(root.entityId), root.entityId, root.ctx);
            }
        }

        MdiIcon {
            id: rowIcon
            anchors.verticalCenter: parent.verticalCenter
            icon: root.config?.icon || (root.rowType === "weblink" ? "mdi:link" : root.entityId ? Ha.iconName(root.entityId, root.st) : "mdi:information-outline")
            size: 22
            color: root.stateColor && Ha.isActive(root.entityId, root.st) ? Ha.stateColor(root.entityId, root.st) : root.unavailable && !root.isSpecial ? Theme.withAlpha(Theme.surfaceText, 0.4) : Theme.primary
        }

        Column {
            anchors.left: rowIcon.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: control.left
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: root.config?.name || (root.entityId ? Ha.entityName(root.entityId, root.st) : root.config?.url ?? "")
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeMedium
                color: root.unavailable && !root.isSpecial ? Theme.withAlpha(Theme.surfaceText, 0.5) : Theme.surfaceText
            }
            StyledText {
                width: parent.width
                text: root.secondary()
                visible: text !== ""
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Loader {
            id: control
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: {
                if (root.rowType === "weblink")
                    return null;
                if (root.rowType === "text")
                    return valueText;
                if (root.rowType === "button")
                    return actionButton;
                if (root.rowType === "attribute" || root.unavailable)
                    return valueText;
                if (["light", "switch", "fan", "input_boolean", "automation", "siren", "humidifier", "remote"].includes(root.domain))
                    return toggle;
                if (["button", "input_button", "scene", "script"].includes(root.domain))
                    return actionButton;
                if (["select", "input_select"].includes(root.domain))
                    return dropdown;
                return valueText;
            }
        }
    }

    Component {
        id: valueText
        StyledText {
            text: {
                HaService.translationRev;
                if (root.rowType === "text")
                    return root.config?.text ?? "";
                if (root.rowType === "attribute") {
                    const v = root.st?.attributes?.[root.config.attribute];
                    const s = v === undefined || v === null ? "" : (Ha.isNumeric(v) ? Ha.formatMeasure(v, 2) : Ha.translateAttribute(root.entityId, root.config.attribute, v));
                    return (root.config.prefix ?? "") + s + (root.config.suffix ?? "");
                }
                if (root.domain === "event")
                    return Ha.relativeTime(Date.parse(root.st?.state ?? ""));
                return Ha.stateText(root.entityId, root.st);
            }
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }
    }

    Component {
        id: toggle
        DToggle {
            hideText: true
            checked: root.st?.state === "on"
            onToggled: checked => HaService.callService(root.domain, checked ? "turn_on" : "turn_off", {}, root.entityId)
        }
    }

    Component {
        id: actionButton
        FeatureButton {
            width: Math.max(72, implicitWidth)
            height: 34
            text: root.config?.action_name || (root.domain === "script" ? "Run" : root.domain === "scene" ? "Activate" : "Press")
            accent: Theme.primary
            onClicked: {
                if (root.rowType === "button" && root.config.tap_action)
                    Lovelace.runAction(root.config.tap_action, root.entityId, root.ctx);
                else if (root.domain === "button" || root.domain === "input_button")
                    HaService.callService(root.domain, "press", {}, root.entityId);
                else
                    HaService.callService(root.domain, "turn_on", {}, root.entityId);
            }
        }
    }

    Component {
        id: dropdown
        DDropdown {
            compactMode: true
            dropdownWidth: Math.min(200, root.width * 0.5)
            readonly property var opts: root.st?.attributes?.options ?? []
            options: opts.map(o => Ha.translateState(root.entityId, root.st, o) || o)
            currentValue: Ha.translateState(root.entityId, root.st, root.st?.state ?? "") || (root.st?.state ?? "")
            onValueChanged: label => {
                const i = options.indexOf(label);
                if (i >= 0 && opts[i] !== root.st?.state)
                    HaService.callService(root.domain, "select_option", {
                        option: opts[i]
                    }, root.entityId);
            }
        }
    }
}
