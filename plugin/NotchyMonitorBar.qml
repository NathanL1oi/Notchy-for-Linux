import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// 弹层底部监控条：可见时持有服务引用，展开时显示详细采样。
Column {
    id: root

    property bool popoutVisible: false
    property bool monitorExpanded: false

    spacing: Theme.spacingM

    onPopoutVisibleChanged: {
        if (!popoutVisible)
            monitorExpanded = false;
    }

    onMonitorExpandedChanged: {
        if (monitorExpanded)
            DgopService.addRef(["processes", "cpu", "memory"]);
        else
            DgopService.removeRef(["processes", "cpu", "memory"]);
    }

    function _fmtKB(kb) {
        const v = Math.max(0, kb || 0);
        if (v < 1024 * 1024)
            return (v / 1024).toFixed(0) + "M";
        return (v / 1024 / 1024).toFixed(1) + "G";
    }

    function _procName(cmd) {
        const base = String(cmd || "").split("/").pop();
        return base.length > 18 ? base.substring(0, 17) + "…" : base;
    }

    function _fmtRate(bytesPerSec) {
        const b = Math.max(0, bytesPerSec || 0);
        if (b < 1024)
            return Math.round(b) + "B/s";
        if (b < 1024 * 1024)
            return (b / 1024).toFixed(0) + "K/s";
        return (b / 1024 / 1024).toFixed(1) + "M/s";
    }

    Loader {
        active: root.popoutVisible
        sourceComponent: Ref {
            service: DgopService
        }
    }

    Rectangle {
        id: monitorStrip
        width: parent.width
        height: 22
        radius: 8
        visible: DgopService.dgopAvailable
        color: monitorHover.hovered ? Theme.withAlpha(Theme.surfaceText, 0.05) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "memory"
                size: 13
                color: Theme.surfaceTextMedium
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(DgopService.cpuUsage) + "%"
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceTextMedium
            }

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "database"
                size: 13
                color: Theme.surfaceTextMedium
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(DgopService.memoryUsage) + "%"
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceTextMedium
            }

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "swap_vert"
                size: 13
                color: Theme.surfaceTextMedium
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "↓" + root._fmtRate(DgopService.networkRxRate) + " ↑" + root._fmtRate(DgopService.networkTxRate)
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceTextMedium
            }
        }

        DankIcon {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            name: root.monitorExpanded ? "expand_less" : "expand_more"
            size: 15
            color: Theme.surfaceTextMedium
        }

        HoverHandler {
            id: monitorHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.monitorExpanded = !root.monitorExpanded
        }
    }

    // ---- 监控详情（展开时） ----
    Column {
        width: parent.width
        spacing: 6
        visible: root.monitorExpanded && DgopService.dgopAvailable

        // 各核 CPU 迷你条
        Flow {
            width: parent.width
            spacing: 3

            Repeater {
                model: DgopService.perCoreCpuUsage

                Rectangle {
                    required property real modelData
                    width: (parent.width - 3 * 7) / 8
                    height: 5
                    radius: 2.5
                    color: Theme.withAlpha(Theme.surfaceText, 0.1)

                    Rectangle {
                        height: parent.height
                        radius: 2.5
                        color: Theme.primary
                        width: parent.width * Math.min(1, parent.modelData / 100)

                        Behavior on width {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        // 内存明细
        StyledText {
            text: "内存 已用 " + root._fmtKB((DgopService.totalMemoryMB - DgopService.availableMemoryMB) * 1024) + " / 共 " + root._fmtKB(DgopService.totalMemoryMB * 1024)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
        }

        // Top 3 进程
        Repeater {
            model: (DgopService.processes || []).slice(0, 3)

            Row {
                required property var modelData
                width: parent.width
                spacing: 8

                StyledText {
                    text: root._procName(modelData.command)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: parent.width - 70
                }

                StyledText {
                    anchors.right: parent.right
                    text: (modelData.cpu ?? 0).toFixed(1) + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.primary
                }
            }
        }
    }
}
