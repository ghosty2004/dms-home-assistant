pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.DDash
import "../../components"
import "../.."

// Lovelace to-do list card: live items, check off, add, clear completed.
Rectangle {
    id: root

    property var config: ({})
    property var ctx: null

    readonly property string entityId: Lovelace.entityOf(config) || (config?.type === "shopping-list" ? "todo.shopping_list" : "")
    readonly property var st: {
        HaService.stateRev;
        return HaService.get(entityId);
    }
    // TodoListEntityFeature: 1 create, 2 delete, 4 update
    readonly property int features: st?.attributes?.supported_features ?? 0
    property var items: []
    property int _subId: -1
    property bool showCompleted: false
    readonly property var open: items.filter(i => i.status !== "completed")
    readonly property var done: items.filter(i => i.status === "completed")

    implicitHeight: col.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadiusL
    color: DashMetrics.cardColor

    function _resubscribe() {
        HaService.unsubscribe(_subId);
        _subId = -1;
        if (!entityId || !HaService.connected || !HaService.dashLive)
            return;
        _subId = HaService.subscribe({
            type: "todo/item/subscribe",
            entity_id: entityId
        }, ev => root.items = ev.items ?? [], (res, err) => {
            if (err)
                console.warn("[HA] todo", err.message);
        });
    }

    // Adds the typed item; with an empty field it just focuses the field.
    function addItem() {
        const t = addField.text.trim();
        if (t === "") {
            addField.forceActiveFocus();
            return;
        }
        HaService.callService("todo", "add_item", {
            item: t
        }, entityId);
        addField.text = "";
        addField.forceActiveFocus();
    }

    function setStatus(item, completed) {
        HaService.callService("todo", "update_item", {
            item: item.uid,
            status: completed ? "completed" : "needs_action"
        }, entityId);
    }

    onEntityIdChanged: Qt.callLater(_resubscribe)
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
        function onDashLiveChanged() {
            Qt.callLater(root._resubscribe);
        }
    }

    Column {
        id: col
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        spacing: Theme.spacingS

        StyledText {
            width: parent.width
            text: root.config?.title || Lovelace.nameOf(root.config, root.entityId)
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }

        // text field and add button, like the HA to-do card
        Item {
            width: parent.width
            height: addField.height
            visible: (root.features & 1) !== 0 && root.config?.hide_create !== true

            DTextField {
                id: addField
                anchors.left: parent.left
                anchors.right: addButton.left
                anchors.rightMargin: Theme.spacingS
                placeholderText: "Add item"
                onAccepted: root.addItem()
            }
            FeatureButton {
                id: addButton
                anchors.right: parent.right
                anchors.verticalCenter: addField.verticalCenter
                width: 44
                height: 44
                radius: 22
                icon: "mdi:plus"
                tooltip: "Add item"
                accent: Theme.primary
                highlighted: addField.text.trim() !== ""
                onClicked: root.addItem()
            }
        }

        Repeater {
            model: root.open

            TodoItem {
                required property var modelData
                width: col.width
                item: modelData
                onToggled: root.setStatus(modelData, true)
            }
        }

        StyledText {
            visible: root.open.length === 0 && root.done.length === 0
            text: "No items"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        // completed section
        Item {
            width: parent.width
            height: 36
            visible: root.done.length > 0

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MdiIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.showCompleted ? "mdi:chevron-down" : "mdi:chevron-right"
                    size: 18
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Completed (" + root.done.length + ")"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceVariantText
                }
            }
            StateLayer {
                anchors.fill: parent
                cornerRadius: Theme.cornerRadiusS
                onClicked: root.showCompleted = !root.showCompleted
            }
            FeatureButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: (root.features & 2) !== 0
                width: 32
                height: 32
                radius: 16
                icon: "mdi:broom"
                tooltip: "Clear completed"
                onClicked: HaService.callService("todo", "remove_completed_items", {}, root.entityId)
            }
        }

        Repeater {
            model: root.showCompleted ? root.done : []

            TodoItem {
                required property var modelData
                width: col.width
                item: modelData
                onToggled: root.setStatus(modelData, false)
            }
        }
    }

    component TodoItem: Item {
        id: ti
        property var item: null
        readonly property bool completed: item?.status === "completed"
        signal toggled

        height: Math.max(36, tiCol.implicitHeight + 8)

        MdiIcon {
            id: check
            anchors.verticalCenter: parent.verticalCenter
            icon: ti.completed ? "mdi:checkbox-marked-circle" : "mdi:checkbox-blank-circle-outline"
            size: 22
            color: ti.completed ? Theme.primary : Theme.surfaceVariantText
        }
        Column {
            id: tiCol
            anchors.left: check.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: ti.item?.summary ?? ""
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeMedium
                font.strikeout: ti.completed
                color: ti.completed ? Theme.surfaceVariantText : Theme.surfaceText
            }
            StyledText {
                width: parent.width
                visible: !!ti.item?.due
                text: ti.item?.due ? new Date(ti.item.due).toLocaleDateString(Qt.locale(), Locale.ShortFormat) : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
        StateLayer {
            anchors.fill: parent
            cornerRadius: Theme.cornerRadiusS
            onClicked: ti.toggled()
        }
    }
}
