// version: 0.2.0
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "LayoutPreviewData.js" as LayoutPreviewData

PluginSettings {
    id: root
    pluginId: "DMSMangoWMLayoutManager"

    StyledText {
        width: parent.width
        text: "MangoWM Layout Manager"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "rightClickTarget"
        label: "Right-click toggle target"
        description: "Right-clicking the bar widget switches to this layout, or back to the previous one if it's already active."
        options: LayoutPreviewData.options().map(option => ({
                value: option.id,
                label: option.label
            }))
        defaultValue: "monocle"
    }

    ListSetting {
        id: scrollList
        settingKey: "scrollCycleLayouts"
        label: "Scroll cycle"
        description: "Layouts the scroll wheel (or two-finger swipe) cycles through on the bar widget, in this order. Use the eye to include or exclude a layout, and the arrows to reorder."
        defaultValue: LayoutPreviewData.options().map(option => ({
                id: option.id,
                label: option.label,
                enabled: true
            }))

        function moveItem(index, delta) {
            const newIndex = index + delta;
            if (newIndex < 0 || newIndex >= scrollList.items.length) {
                return;
            }
            const reordered = scrollList.items.slice();
            const moved = reordered.splice(index, 1)[0];
            reordered.splice(newIndex, 0, moved);
            scrollList.items = reordered;
        }

        function toggleItemEnabled(index) {
            const updated = scrollList.items.slice();
            updated[index] = Object.assign({}, updated[index], {
                enabled: !updated[index].enabled
            });
            scrollList.items = updated;
        }

        delegate: Component {
            StyledRect {
                id: row
                required property var modelData
                required property int index

                width: parent.width
                height: 40
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankIcon {
                        name: row.modelData.enabled ? "visibility" : "visibility_off"
                        size: Theme.iconSize - 6
                        color: row.modelData.enabled ? Theme.primary : Theme.outline
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: scrollList.toggleItemEnabled(row.index)
                        }
                    }

                    StyledText {
                        text: row.modelData.label
                        color: row.modelData.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankActionButton {
                        buttonSize: 28
                        iconName: "arrow_upward"
                        iconSize: 16
                        iconColor: row.index === 0 ? Theme.outline : Theme.surfaceText
                        enabled: row.index > 0
                        onClicked: scrollList.moveItem(row.index, -1)
                    }

                    DankActionButton {
                        buttonSize: 28
                        iconName: "arrow_downward"
                        iconSize: 16
                        iconColor: row.index === scrollList.items.length - 1 ? Theme.outline : Theme.surfaceText
                        enabled: row.index < scrollList.items.length - 1
                        onClicked: scrollList.moveItem(row.index, 1)
                    }
                }
            }
        }
    }

    SliderSetting {
        settingKey: "scrollCooldownMs"
        label: "Scroll speed"
        description: "Minimum time between layout changes while scrolling or swiping the bar widget. Raise this if a trackpad swipe jumps through several layouts at once; lower it for a snappier response with a mouse wheel."
        defaultValue: 250
        minimum: 0
        maximum: 1000
        unit: "ms"
        leftIcon: "speed"
    }
}
