import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "LayoutPreviewData.js" as LayoutPreviewData

PluginComponent {
    id: root

    property string mmsgCommand: "mmsg"
    readonly property real pillHorizontalPadding: Theme.spacingXS
    property string currentLayoutRaw: ""
    property string lastError: ""
    property string queryBuffer: ""
    property string pendingLayoutId: ""
    property bool mangoAvailable: false

    readonly property string currentLayoutCode: formatLayoutCode(currentLayoutRaw)
    readonly property string currentLayoutIcon: formatLayoutIcon(currentLayoutRaw)
    readonly property bool busy: queryProcess.running || setProcess.running
    readonly property var layoutOptions: LayoutPreviewData.options()
    readonly property string monitorName: root.parentScreen && root.parentScreen.name
        ? String(root.parentScreen.name)
        : ""

    popoutWidth: 560
    popoutHeight: 460

    Component.onCompleted: {
        refreshCurrentLayout();
        if (root.monitorName) {
            watchProcess.running = true;
        }
    }

    // mmsg has no monitor-agnostic query; every get/watch/dispatch is
    // addressed to a specific output name.
    onMonitorNameChanged: {
        if (root.monitorName && !watchProcess.running) {
            refreshCurrentLayout();
            watchProcess.running = true;
        }
    }

    function normalizeLayoutValue(value) {
        const raw = String(value === undefined || value === null ? "" : value).trim();
        return raw.replace(/^"+|"+$/g, "");
    }

    // `mmsg get monitor <name>` / `mmsg watch monitor <name>` each emit one
    // JSON object per line (watch pushes the initial state immediately,
    // then one line per change). The monitor's active layout is exposed as
    // the short "layout_symbol" code (e.g. "T", "VK", "DW").
    function extractLayoutSymbol(output) {
        const raw = String(output === undefined || output === null ? "" : output).trim();
        if (!raw) {
            return "";
        }

        const lines = raw.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0);
        if (lines.length === 0) {
            return "";
        }

        try {
            const data = JSON.parse(lines[lines.length - 1]);
            return data && data.layout_symbol ? String(data.layout_symbol) : "";
        } catch (e) {
            return "";
        }
    }

    function applyLayoutUpdate(output) {
        const symbol = extractLayoutSymbol(output);
        if (!symbol) {
            return;
        }

        currentLayoutRaw = symbol;
        mangoAvailable = true;
        lastError = "";
    }

    function lookupLayout(value) {
        const normalized = normalizeLayoutValue(value);
        if (!normalized) {
            return null;
        }

        return LayoutPreviewData.findOption(normalized);
    }

    function formatLayoutCode(value) {
        const option = lookupLayout(value);
        if (option) {
            return option.code;
        }

        const normalized = normalizeLayoutValue(value);
        if (!normalized) {
            return "?";
        }

        return normalized.length > 3 ? normalized.slice(0, 3).toUpperCase() : normalized.toUpperCase();
    }

    function formatLayoutIcon(value) {
        const option = lookupLayout(value);
        return option && option.icon ? option.icon : "grid_view";
    }

    function isCurrentLayout(layoutId) {
        const option = lookupLayout(currentLayoutRaw);
        return option ? option.id === layoutId : normalizeLayoutValue(currentLayoutRaw) === layoutId;
    }

    function refreshCurrentLayout() {
        if (queryProcess.running) {
            return;
        }

        if (!root.monitorName) {
            return;
        }

        queryBuffer = "";
        queryProcess.running = true;
    }

    function setLayout(layoutId) {
        if (setProcess.running) {
            return;
        }

        pendingLayoutId = layoutId;
        lastError = "";
        setProcess.command = [mmsgCommand, "dispatch", "setlayout," + layoutId];
        setProcess.running = true;
    }

    Process {
        id: queryProcess
        command: [root.mmsgCommand, "get", "monitor", root.monitorName]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.queryBuffer += (root.queryBuffer ? "\n" : "") + data;
            }
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.applyLayoutUpdate(root.queryBuffer);
            } else {
                root.mangoAvailable = false;
                root.lastError = "Failed to query MangoWC with mmsg get monitor.";
            }
        }
    }

    Process {
        id: watchProcess
        command: [root.mmsgCommand, "watch", "monitor", root.monitorName]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.applyLayoutUpdate(data);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = "Failed to watch MangoWC layout changes with mmsg watch monitor.";
                root.mangoAvailable = false;
            }
        }
    }

    Process {
        id: setProcess
        command: [root.mmsgCommand, "dispatch", ""]
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                root.mangoAvailable = true;
                root.lastError = "";
                root.currentLayoutRaw = root.pendingLayoutId;
                root.closePopout();
                Qt.callLater(root.refreshCurrentLayout);
            } else {
                root.lastError = "Failed to switch layout with mmsg dispatch setlayout,<layout>.";
            }

            root.pendingLayoutId = "";
        }
    }

    horizontalBarPill: Component {
        MangoLayoutPill {
            available: root.mangoAvailable
            code: root.currentLayoutCode
            iconName: root.currentLayoutIcon
            widgetThickness: root.widgetThickness
            horizontalPadding: root.pillHorizontalPadding
        }
    }

    verticalBarPill: Component {
        MangoLayoutPill {
            vertical: true
            available: root.mangoAvailable
            code: root.currentLayoutCode
            iconName: root.currentLayoutIcon
            widgetThickness: root.widgetThickness
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: chooser
            headerText: ""
            detailsText: ""
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Item {
                    width: parent.width
                    implicitHeight: titleRow.implicitHeight

                    Row {
                        id: titleRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: root.currentLayoutIcon
                            size: Theme.iconSize - 2
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "MangoWC Layout Manager"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    visible: root.lastError !== ""
                    width: parent.width
                    implicitHeight: visible ? statusColumn.implicitHeight + Theme.spacingM * 2 : 0
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Theme.outline
                    border.width: 1

                    Column {
                        id: statusColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: root.lastError
                            color: Theme.error
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                DankFlickable {
                    width: parent.width
                    height: Math.max(160, root.popoutHeight - chooser.headerHeight - chooser.detailsHeight - titleRow.implicitHeight - (root.lastError !== "" ? 132 : 72))
                    clip: true
                    contentWidth: width
                    contentHeight: buttonGrid.implicitHeight + Theme.spacingM * 2

                    Grid {
                        id: buttonGrid
                        x: Theme.spacingM
                        y: Theme.spacingM
                        width: parent.width - Theme.spacingM * 2 - 12
                        columns: 3
                        spacing: Theme.spacingS

                        Repeater {
                            model: root.layoutOptions

                            delegate: MangoLayoutTile {
                                required property var modelData
                                width: (buttonGrid.width - buttonGrid.spacing * (buttonGrid.columns - 1)) / buttonGrid.columns
                                layout: modelData
                                selected: root.isCurrentLayout(modelData.id)
                                busy: root.busy
                                onLayoutSelected: layoutId => root.setLayout(layoutId)
                            }
                        }
                    }
                }
            }
        }
    }
}
