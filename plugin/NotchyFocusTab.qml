import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// 专注标签页：番茄钟倒计时（状态在 daemon 常驻，弹层关闭不影响计时）。
Column {
    id: tab

    required property var widgetRoot
    property var parentPopout: null

    spacing: Theme.spacingM

    readonly property var daemon: widgetRoot.daemon
    readonly property string state: daemon?.pomoState ?? "idle"
    readonly property int remaining: daemon?.pomoRemainingSec ?? 0
    readonly property int total: daemon?.pomoTotalSec ?? 0
    readonly property string phase: daemon?.pomoPhase ?? "work"
    readonly property int cycles: daemon?.pomoCycles ?? 0

    property int customMinutes: 25

    function fmt(sec) {
        sec = Math.max(0, sec);
        return String(Math.floor(sec / 60)).padStart(2, "0") + ":" + String(sec % 60).padStart(2, "0");
    }

    // ---- 大号倒计时 ----
    Column {
        width: parent.width
        spacing: 2

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tab.state === "idle" ? tab.fmt(tab.customMinutes * 60) : tab.fmt(tab.remaining)
            font.pixelSize: 52
            font.weight: Font.Bold
            color: tab.phase === "break" ? Theme.primary : Theme.surfaceText
            font.family: "monospace"
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                if (tab.state === "running")
                    return tab.phase === "work" ? "专注中" : "休息中";
                if (tab.state === "paused")
                    return "已暂停";
                return "就绪";
            }
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceTextMedium
        }
    }

    // ---- 进度条 ----
    Rectangle {
        width: parent.width
        height: 6
        radius: 3
        color: Theme.withAlpha(Theme.surfaceText, 0.1)

        Rectangle {
            height: parent.height
            radius: 3
            color: Theme.primary
            width: tab.total > 0 ? parent.width * (1 - tab.remaining / tab.total) : 0

            Behavior on width {
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.Linear
                }
            }
        }
    }

    // ---- 主控制按钮 ----
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        NotchyButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "restart_alt"
            size: 38
            iconSize: 20
            textColor: Theme.surfaceText
            hoverColor: Theme.withAlpha(Theme.surfaceText, 0.08)
            enabled: tab.state !== "idle"
            onClicked: tab.daemon?.pomoReset()
        }

        NotchyButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: tab.state === "running" ? "pause" : "play_arrow"
            size: 52
            iconSize: 26
            filled: true
            bgColor: Theme.primary
            textColor: Theme.background
            onClicked: {
                if (!tab.daemon)
                    return;
                if (tab.state === "running")
                    tab.daemon.pomoPause();
                else if (tab.state === "paused")
                    tab.daemon.pomoResume();
                else
                    tab.daemon.pomoStart(tab.customMinutes);
            }
        }

        NotchyButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "skip_next"
            size: 38
            iconSize: 20
            textColor: Theme.surfaceText
            hoverColor: Theme.withAlpha(Theme.surfaceText, 0.08)
            enabled: tab.state !== "idle"
            onClicked: tab.daemon?.pomoSkip()
        }
    }

    // ---- 预设 ----
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Repeater {
            model: [25, 45, 60]

            Rectangle {
                required property int modelData
                readonly property bool active: tab.customMinutes === modelData

                width: presetText.implicitWidth + 20
                height: 28
                radius: 14
                color: active ? Theme.withAlpha(Theme.primary, 0.2) : (presetHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : Theme.withAlpha(Theme.surfaceText, 0.05))

                StyledText {
                    id: presetText
                    anchors.centerIn: parent
                    text: modelData + " 分钟"
                    font.pixelSize: Theme.fontSizeSmall
                    color: parent.active ? Theme.primary : Theme.surfaceTextMedium
                }

                MouseArea {
                    id: presetHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.customMinutes = parent.modelData
                }
            }
        }
    }

    // ---- 自定义滑块 ----
    Row {
        width: parent.width
        spacing: Theme.spacingS
        visible: tab.state === "idle"

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: tab.customMinutes + " 分钟"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            width: 52
        }

        DankSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 52 - Theme.spacingS
            height: 26
            minimum: 5
            maximum: 90
            value: tab.customMinutes
            showValue: false
            wheelEnabled: false
            onSliderValueChanged: newValue => {
                if (Math.abs(newValue - tab.customMinutes) >= 1)
                    tab.customMinutes = newValue;
            }
        }
    }

    // ---- 轮数统计 ----
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: tab.cycles > 0
        text: "本次会话已完成 " + tab.cycles + " 轮专注"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceTextMedium
    }
}
