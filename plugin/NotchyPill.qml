import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// 顶栏药丸：瞬态镜像 > 番茄钟 > 媒体 > 时钟，并接收文件拖入。
Item {
    id: pillWrap

    required property var widgetRoot

    implicitWidth: pillRow.implicitWidth
    implicitHeight: 24

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        }
    }

    Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 6

        readonly property bool showFlash: widgetRoot.flashKind !== ""
        readonly property bool showPomo: !showFlash && widgetRoot.pomoActive
        readonly property bool showMedia: !showFlash && !showPomo && widgetRoot.hasMedia
        readonly property bool showClock: !showFlash && !showPomo && !widgetRoot.hasMedia && widgetRoot.showClockIdle

        // --- 番茄钟（Live Activity 常驻倒计时） ---
        DankIcon {
            visible: pillRow.showPomo
            anchors.verticalCenter: parent.verticalCenter
            name: widgetRoot.pomoPhase === "break" ? "coffee" : "timer"
            size: 15
            color: widgetRoot.pomoState === "paused" ? Theme.widgetTextColor : Theme.primary
        }

        StyledText {
            visible: pillRow.showPomo
            anchors.verticalCenter: parent.verticalCenter
            text: widgetRoot.fmtPomo(widgetRoot.pomoRemaining)
            font.pixelSize: Theme.barTextSize(widgetRoot.barThickness, widgetRoot.barConfig?.fontScale, widgetRoot.barConfig?.maximizeWidgetText)
            font.weight: Font.DemiBold
            color: widgetRoot.pomoState === "paused" ? Theme.widgetTextColor : Theme.primary
        }

        // --- 瞬态镜像（通知/音量/暂存） ---
        DankIcon {
            visible: pillRow.showFlash
            anchors.verticalCenter: parent.verticalCenter
            name: widgetRoot.flashIcon || "notifications"
            size: 15
            color: Theme.primary
        }

        StyledText {
            visible: pillRow.showFlash && widgetRoot.flashKind !== "volume"
            anchors.verticalCenter: parent.verticalCenter
            text: widgetRoot.flashText
            font.pixelSize: Theme.barTextSize(widgetRoot.barThickness, widgetRoot.barConfig?.fontScale, widgetRoot.barConfig?.maximizeWidgetText)
            color: Theme.widgetTextColor
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 220)
        }

        // 音量：迷你进度条
        Rectangle {
            visible: pillRow.showFlash && widgetRoot.flashKind === "volume"
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 4
            radius: 2
            color: Theme.withAlpha(Theme.widgetTextColor, 0.2)

            Rectangle {
                height: parent.height
                radius: 2.5
                color: Theme.primary
                width: parent.width * Math.min(1, widgetRoot.volumePercent / 100)

                Behavior on width {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }

        StyledText {
            visible: pillRow.showFlash && widgetRoot.flashKind === "volume"
            anchors.verticalCenter: parent.verticalCenter
            text: widgetRoot.flashText
            font.pixelSize: Theme.barTextSize(widgetRoot.barThickness, widgetRoot.barConfig?.fontScale, widgetRoot.barConfig?.maximizeWidgetText)
            color: Theme.widgetTextColor
        }

        // --- 媒体 ---
        NotchyCavaBars {
            visible: pillRow.showMedia
            running: widgetRoot.isPlaying
            width: visible ? 20 : 0
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            barColor: Theme.primary
        }

        StyledText {
            visible: pillRow.showMedia
            anchors.verticalCenter: parent.verticalCenter
            text: widgetRoot.trackTitle || widgetRoot.player?.identity || ""
            font.pixelSize: Theme.barTextSize(widgetRoot.barThickness, widgetRoot.barConfig?.fontScale, widgetRoot.barConfig?.maximizeWidgetText)
            color: Theme.widgetTextColor
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 180)
        }

        // 媒体/番茄钟态下合并显示紧凑时间（不带日期，省宽度）
        StyledText {
            visible: pillRow.showMedia || pillRow.showPomo
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const d = widgetRoot.clockDate;
                return d ? "· " + d.toLocaleTimeString(Qt.locale(), "HH:mm") : "";
            }
            font.pixelSize: Theme.barTextSize(widgetRoot.barThickness, widgetRoot.barConfig?.fontScale, widgetRoot.barConfig?.maximizeWidgetText) - 1
            color: Theme.withAlpha(Theme.widgetTextColor, 0.65)
        }

        // --- 时钟（日期 + 星期 + 时间） ---
        StyledText {
            visible: pillRow.showClock
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const d = widgetRoot.clockDate;
                if (!d)
                    return "";
                const dayPart = d.toLocaleDateString(Qt.locale(), "M月d日 ddd");
                const timePart = d.toLocaleTimeString(Qt.locale(), widgetRoot.showSecondsW ? "HH:mm:ss" : "HH:mm");
                return dayPart + " · " + timePart;
            }
            font.pixelSize: Theme.barTextSize(widgetRoot.barThickness, widgetRoot.barConfig?.fontScale, widgetRoot.barConfig?.maximizeWidgetText)
            font.weight: Font.Medium
            color: Theme.widgetTextColor
        }

        // cava 仅在播放时运行
        Loader {
            active: widgetRoot.isPlaying
            sourceComponent: Ref {
                service: CavaService
            }
        }
    }

    // 拖到药丸上 = 暂存文件（并展开到暂存架页，给出可见反馈）
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]
        onDropped: drop => {
            let urls = [];
            if (drop.urls && drop.urls.length > 0) {
                urls = drop.urls;
            } else if (drop.hasText) {
                const lines = String(drop.text).split("\n");
                for (const line of lines) {
                    const t = line.trim();
                    if (t.startsWith("file://"))
                        urls.push(t);
                }
            }
            if (urls.length > 0) {
                widgetRoot.addToShelf(urls);
                widgetRoot.currentTab = 3;
                if (!(widgetRoot.popoutRef?.shouldBeVisible ?? false))
                    widgetRoot.triggerPopout();
                Qt.callLater(widgetRoot.fixPopoutPosition);
                drop.accept(Qt.CopyAction);
            }
        }
    }
}
