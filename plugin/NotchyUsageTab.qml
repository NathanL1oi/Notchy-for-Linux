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

            // 错误 / 未配置
            StyledText {
                readonly property var u: tab.widgetRoot.kimiUsage
                visible: !u || !!u.error
                width: parent.width
                text: {
                    if (tab.widgetRoot.kimiUsageLoading && (!u || u.error))
                        return "正在查询…";
                    if (!u || u.error === "nokey")
                        return "未配置 Kimi CodePlan Key（留空则自动读取 ZCode 配置）";
                    return "查询失败：" + (u.error ?? "");
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
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
                text: {
                    if (tab.widgetRoot.deepseekUsageLoading && (!u || u.error))
                        return "正在查询…";
                    if (!u || u.error === "nokey")
                        return "未配置 API Key";
                    if (u.error)
                        return "查询失败：" + u.error;
                    return "¥ " + Number(u.balance).toFixed(2);
                }
                font.pixelSize: (tab.widgetRoot.deepseekUsage && !tab.widgetRoot.deepseekUsage.error) ? 26 : Theme.fontSizeMedium
                font.weight: Font.Bold
                color: (tab.widgetRoot.deepseekUsage && !tab.widgetRoot.deepseekUsage.error) ? Theme.primary : Theme.surfaceTextMedium
            }

            StyledText {
                readonly property var u: tab.widgetRoot.deepseekUsage
                visible: u && !u.error
                text: u ? ("赠金 ¥" + Number(u.granted).toFixed(2) + " · 充值 ¥" + Number(u.toppedUp).toFixed(2) + " · 更新于 " + u.when) : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }

            StyledText {
                readonly property var u: tab.widgetRoot.deepseekUsage
                visible: !tab.widgetRoot.deepseekUsageLoading && (!u || u.error === "nokey")
                text: "在插件设置中填入 DeepSeek API Key（platform.deepseek.com → API keys）"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                width: parent.width
            }
        }
    }
}
