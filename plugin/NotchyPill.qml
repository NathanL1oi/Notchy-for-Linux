import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// 顶栏药丸：瞬态镜像 > 番茄钟 > 媒体 > 时钟，并接收文件拖入。
Item {
    id: pillWrap

    required property var widgetRoot

    readonly property bool showFlash: widgetRoot.flashKind !== ""
    readonly property bool showPomo: !showFlash && widgetRoot.pomoActive
    readonly property bool showMedia: !showFlash && !showPomo && widgetRoot.hasMedia
    readonly property bool showClock: !showFlash && !showPomo && !widgetRoot.hasMedia && widgetRoot.showClockIdle
    readonly property var activeContent: showFlash ? flashRow : (showPomo ? pomoRow : (showMedia ? mediaRow : (showClock ? clockRow : null)))

    implicitWidth: activeContent ? activeContent.implicitWidth : 0
    implicitHeight: 24

    Behavior on implicitWidth {
        NumberAnimation {
            duration: pillWrap.widgetRoot.animationsEnabled ? Theme.mediumDuration : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        }
    }

    component AnimatedRow: Row {
        required property bool active

        anchors.centerIn: parent
        spacing: 6
        opacity: active ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: pillWrap.widgetRoot.animationsEnabled ? 150 : 0
                easing.type: Easing.OutCubic
            }
        }

        transform: Translate {
            y: active ? 0 : 3
            Behavior on y {
                NumberAnimation {
                    duration: pillWrap.widgetRoot.animationsEnabled ? 150 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    component CompactClock: StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: {
            const d = pillWrap.widgetRoot.clockDate;
            return d ? "· " + d.toLocaleTimeString(Qt.locale(), "HH:mm") : "";
        }
        font.pixelSize: Theme.barTextSize(pillWrap.widgetRoot.barThickness, pillWrap.widgetRoot.barConfig?.fontScale, pillWrap.widgetRoot.barConfig?.maximizeWidgetText) - 1
        color: Theme.withAlpha(Theme.widgetTextColor, 0.65)
    }

    AnimatedRow {
        id: pomoRow
        active: pillWrap.showPomo

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: pillWrap.widgetRoot.pomoPhase === "break" ? "coffee" : "timer"
            size: 15
            color: pillWrap.widgetRoot.pomoState === "paused" ? Theme.widgetTextColor : Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pillWrap.widgetRoot.fmtPomo(pillWrap.widgetRoot.pomoRemaining)
            font.pixelSize: Theme.barTextSize(pillWrap.widgetRoot.barThickness, pillWrap.widgetRoot.barConfig?.fontScale, pillWrap.widgetRoot.barConfig?.maximizeWidgetText)
            font.weight: Font.DemiBold
            color: pillWrap.widgetRoot.pomoState === "paused" ? Theme.widgetTextColor : Theme.primary
        }

        CompactClock {}
    }

    AnimatedRow {
        id: flashRow
        active: pillWrap.showFlash

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: pillWrap.widgetRoot.flashIcon || "notifications"
            size: 15
            color: Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: pillWrap.widgetRoot.flashKind !== "volume"
            text: pillWrap.widgetRoot.flashText
            font.pixelSize: Theme.barTextSize(pillWrap.widgetRoot.barThickness, pillWrap.widgetRoot.barConfig?.fontScale, pillWrap.widgetRoot.barConfig?.maximizeWidgetText)
            color: Theme.widgetTextColor
            elide: Text.ElideRight
            maximumLineCount: 1
            width: visible ? Math.min(implicitWidth, 220) : 0
        }

        Rectangle {
            visible: pillWrap.widgetRoot.flashKind === "volume"
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 56 : 0
            height: 4
            radius: 2
            color: Theme.withAlpha(Theme.widgetTextColor, 0.2)

            Rectangle {
                height: parent.height
                radius: 2.5
                color: Theme.primary
                width: parent.width * Math.min(1, pillWrap.widgetRoot.volumePercent / 100)

                Behavior on width {
                    NumberAnimation {
                        duration: pillWrap.widgetRoot.animationsEnabled ? 150 : 0
                    }
                }
            }
        }

        StyledText {
            visible: pillWrap.widgetRoot.flashKind === "volume"
            anchors.verticalCenter: parent.verticalCenter
            text: pillWrap.widgetRoot.flashText
            font.pixelSize: Theme.barTextSize(pillWrap.widgetRoot.barThickness, pillWrap.widgetRoot.barConfig?.fontScale, pillWrap.widgetRoot.barConfig?.maximizeWidgetText)
            color: Theme.widgetTextColor
            width: visible ? implicitWidth : 0
        }
    }

    AnimatedRow {
        id: mediaRow
        active: pillWrap.showMedia

        NotchyCavaBars {
            running: pillWrap.widgetRoot.isPlaying
            width: 20
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            barColor: Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pillWrap.widgetRoot.trackTitle || pillWrap.widgetRoot.player?.identity || ""
            font.pixelSize: Theme.barTextSize(pillWrap.widgetRoot.barThickness, pillWrap.widgetRoot.barConfig?.fontScale, pillWrap.widgetRoot.barConfig?.maximizeWidgetText)
            color: Theme.widgetTextColor
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 180)
        }

        CompactClock {}

        // cava 仅在播放时运行
        Loader {
            active: pillWrap.widgetRoot.isPlaying
            sourceComponent: Ref {
                service: CavaService
            }
        }
    }

    AnimatedRow {
        id: clockRow
        active: pillWrap.showClock

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const d = pillWrap.widgetRoot.clockDate;
                if (!d)
                    return "";
                const dayPart = d.toLocaleDateString(Qt.locale(), "M月d日 ddd");
                const timePart = d.toLocaleTimeString(Qt.locale(), pillWrap.widgetRoot.showSecondsW ? "HH:mm:ss" : "HH:mm");
                return dayPart + " · " + timePart;
            }
            font.pixelSize: Theme.barTextSize(pillWrap.widgetRoot.barThickness, pillWrap.widgetRoot.barConfig?.fontScale, pillWrap.widgetRoot.barConfig?.maximizeWidgetText)
            font.weight: Font.Medium
            color: Theme.widgetTextColor
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
                pillWrap.widgetRoot.addToShelf(urls);
                pillWrap.widgetRoot.currentTab = 3;
                if (!(pillWrap.widgetRoot.popoutRef?.shouldBeVisible ?? false))
                    pillWrap.widgetRoot.triggerPopout();
                Qt.callLater(pillWrap.widgetRoot.fixPopoutPosition);
                drop.accept(Qt.CopyAction);
            }
        }
    }
}
