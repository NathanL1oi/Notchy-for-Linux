import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// 用量标签页：Kimi CodePlan 套餐额度（5h/7d 窗口 + 总量）+ DeepSeek API 余额。
Column {
    id: tab

    required property var widgetRoot
    property var parentPopout: null

    spacing: Theme.spacingS

    readonly property bool loading: widgetRoot.kimiUsageLoading || widgetRoot.deepseekUsageLoading

    function fmtReset(isoStr) {
        if (!isoStr)
            return "";
        const t = new Date(isoStr);
        if (isNaN(t.getTime()))
            return "";
        const mins = Math.round((t.getTime() - Date.now()) / 60000);
        if (mins <= 0)
            return "即将重置";
        if (mins < 60)
            return mins + " 分钟后重置";
        const h = Math.floor(mins / 60);
        if (h < 24)
            return h + " 小时 " + (mins % 60) + " 分后重置";
        return Math.floor(h / 24) + " 天 " + (h % 24) + " 小时后重置";
    }

    // 单窗口用量行：标签 + 百分比 + 进度条 + 重置时间
    component UsageRow: Column {
        required property string label
        required property real ratio   // 0-1
        required property string resetText

        width: parent.width
        spacing: 3

        Row {
            width: parent.width

            StyledText {
                id: rowLabel
                text: label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }

            Item {
                width: Math.max(1, parent.width - rowLabel.implicitWidth - rowPct.implicitWidth)
                height: 1
            }

            StyledText {
                id: rowPct
                text: Math.round(ratio * 100) + "%"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: ratio > 0.9 ? Theme.error : Theme.primary
            }
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.withAlpha(Theme.surfaceText, 0.1)

            Rectangle {
                height: parent.height
                radius: 2.5
                width: parent.width * Math.min(1, ratio)
                color: ratio > 0.9 ? Theme.error : Theme.primary

                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        StyledText {
            visible: resetText !== ""
            text: resetText
            font.pixelSize: Theme.fontSizeSmall - 1
            color: Theme.withAlpha(Theme.surfaceTextMedium, 0.75)
        }
    }

    // ---- 头部 ----
    Row {
        width: parent.width
        height: 22

        StyledText {
            id: usageTitle
            text: "AI 额度用量"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - usageTitle.width - refreshBtn.width
            height: 1
        }

        StyledText {
            id: refreshBtn
            text: tab.loading ? "刷新中…" : "刷新"
            font.pixelSize: Theme.fontSizeSmall
            color: !tab.loading && refreshHover.containsMouse ? Theme.primary : Theme.surfaceTextMedium
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                id: refreshHover
                anchors.fill: parent
                enabled: !tab.loading
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: tab.widgetRoot.fetchUsage()
            }
        }
    }

    // ---- Kimi CodePlan 卡片 ----
    Rectangle {
        width: parent.width
        height: kimiCol.implicitHeight + 20
        radius: 12
        color: Theme.withAlpha(Theme.surfaceText, 0.04)

        Column {
            id: kimiCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            Row {
                spacing: 6

                DankIcon {
                    name: "auto_awesome"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Kimi CodePlan"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 有数据：窗口用量
            Column {
                width: parent.width
                spacing: 8
                visible: tab.widgetRoot.kimiUsage && !tab.widgetRoot.kimiUsage.error

                UsageRow {
                    label: "5 小时窗口"
                    ratio: tab.widgetRoot.kimiUsage?.r5h ?? 0
                    resetText: tab.fmtReset(tab.widgetRoot.kimiUsage?.reset5h ?? "")
                }

                UsageRow {
                    label: "7 天窗口"
                    ratio: tab.widgetRoot.kimiUsage?.r7d ?? 0
                    resetText: tab.fmtReset(tab.widgetRoot.kimiUsage?.reset7d ?? "")
                }

                StyledText {
                    visible: (tab.widgetRoot.kimiUsage?.limit ?? "") !== ""
                    text: {
                        const u = tab.widgetRoot.kimiUsage;
                        return "本周期：已用 " + u.used + " / 共 " + u.limit + " · 剩 " + u.remaining + " · " + tab.fmtReset(u.resetTime);
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                }
            }

            // 加载 / 错误 / 未配置
            NotchyEmptyState {
                readonly property var u: tab.widgetRoot.kimiUsage
                width: parent.width
                compact: true
                visible: tab.widgetRoot.kimiUsageLoading && (!u || u.error)
                icon: "sync"
                title: "正在查询 Kimi 额度"
                message: "正在获取最新用量"
            }

            NotchyEmptyState {
                readonly property var u: tab.widgetRoot.kimiUsage
                width: parent.width
                compact: true
                visible: !tab.widgetRoot.kimiUsageLoading && (!u || !!u.error)
                icon: (!u || u.error === "nokey") ? "key_off" : "cloud_off"
                title: (!u || u.error === "nokey") ? "未配置 Kimi CodePlan Key" : "Kimi 额度查询失败"
                message: (!u || u.error === "nokey") ? "留空则自动读取 ZCode 配置" : (u.error ?? "")
                actionText: (!u || u.error === "nokey") ? "" : "重试"
                onActionClicked: tab.widgetRoot.fetchUsage()
            }

            StyledText {
                visible: tab.widgetRoot.kimiUsage && !tab.widgetRoot.kimiUsage.error
                text: "更新于 " + (tab.widgetRoot.kimiUsage?.when ?? "") + (tab.widgetRoot.kimiKeyFromZcode ? " · 已自动读取 ZCode 配置" : "")
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.withAlpha(Theme.surfaceTextMedium, 0.7)
            }
        }
    }

    // ---- DeepSeek 卡片 ----
    Rectangle {
        width: parent.width
        height: dsCol.implicitHeight + 20
        radius: 12
        color: Theme.withAlpha(Theme.surfaceText, 0.04)

        Column {
            id: dsCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 4

            Row {
                spacing: 6

                DankIcon {
                    name: "search"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "DeepSeek"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                readonly property var u: tab.widgetRoot.deepseekUsage
                visible: u && !u.error
                text: u ? ("¥ " + Number(u.balance).toFixed(2)) : ""
                font.pixelSize: 26
                font.weight: Font.Bold
                color: Theme.primary
            }

            NotchyEmptyState {
                readonly property var u: tab.widgetRoot.deepseekUsage
                width: parent.width
                compact: true
                visible: tab.widgetRoot.deepseekUsageLoading && (!u || u.error)
                icon: "sync"
                title: "正在查询 DeepSeek 余额"
            }

            NotchyEmptyState {
                readonly property var u: tab.widgetRoot.deepseekUsage
                width: parent.width
                compact: true
                visible: !tab.widgetRoot.deepseekUsageLoading && (!u || !!u.error)
                icon: (!u || u.error === "nokey") ? "key_off" : "cloud_off"
                title: (!u || u.error === "nokey") ? "未配置 DeepSeek API Key" : "DeepSeek 查询失败"
                message: (!u || u.error === "nokey") ? "可在插件设置中填入 Key" : (u.error ?? "")
                actionText: (!u || u.error === "nokey") ? "" : "重试"
                onActionClicked: tab.widgetRoot.fetchUsage()
            }

            StyledText {
                readonly property var u: tab.widgetRoot.deepseekUsage
                visible: u && !u.error
                text: u ? ("赠金 ¥" + Number(u.granted).toFixed(2) + " · 充值 ¥" + Number(u.toppedUp).toFixed(2) + " · 更新于 " + u.when) : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }
        }
    }
}
