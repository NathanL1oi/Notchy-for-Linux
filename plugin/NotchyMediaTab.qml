import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// 媒体标签页：封面/曲名/艺术家 + 进度条 + 播放控制 + 系统音量滑块。
Column {
    id: tab

    required property var widgetRoot
    property var parentPopout: null

    spacing: Theme.spacingM

    // ---- 有媒体 ----
    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: tab.widgetRoot.hasMedia

        Row {
            width: parent.width
            spacing: Theme.spacingM

            NotchyCover {
                width: 64
                height: 64
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                artUrl: tab.widgetRoot.artUrl
                iconColor: Theme.withAlpha(Theme.surfaceText, 0.5)
                bgColor: Theme.withAlpha(Theme.surfaceText, 0.08)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64 - Theme.spacingM
                spacing: 3

                StyledText {
                    width: parent.width
                    text: tab.widgetRoot.trackTitle
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    width: parent.width
                    text: tab.widgetRoot.trackArtist || tab.widgetRoot.player?.identity || ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceTextMedium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    width: parent.width
                    text: (tab.widgetRoot.isPlaying ? "正在播放" : "已暂停") + " · " + (tab.widgetRoot.player?.identity ?? "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        // 进度条 + 时间
        Item {
            width: parent.width
            height: 16

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Theme.withAlpha(Theme.surfaceText, 0.12)

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: Theme.primary
                    width: tab.widgetRoot.trackLength > 0 ? parent.width * Math.min(1, tab.widgetRoot.trackPos / tab.widgetRoot.trackLength) : 0

                    Behavior on width {
                        NumberAnimation {
                            duration: 1000
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: (tab.widgetRoot.player?.canSeek ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => {
                    const p = tab.widgetRoot.player;
                    if (p && p.canSeek && tab.widgetRoot.trackLength > 0) {
                        p.position = (mouse.x / width) * tab.widgetRoot.trackLength;
                        tab.widgetRoot.trackPos = p.position;
                    }
                }
            }
        }

        Row {
            width: parent.width

            StyledText {
                id: posTextW
                text: tab.widgetRoot.fmtTime(tab.widgetRoot.trackPos)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }

            Item {
                width: parent.width - posTextW.width - lenTextW.width
                height: 1
            }

            StyledText {
                id: lenTextW
                text: tab.widgetRoot.fmtTime(tab.widgetRoot.trackLength)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }
        }

        // 控制按钮
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            NotchyButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_previous"
                size: 38
                iconSize: 20
                textColor: Theme.surfaceText
                hoverColor: Theme.withAlpha(Theme.surfaceText, 0.08)
                enabled: tab.widgetRoot.player?.canGoPrevious ?? false
                onClicked: MprisController.previousOrRewind()
            }

            NotchyButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: tab.widgetRoot.isPlaying ? "pause" : "play_arrow"
                size: 50
                iconSize: 26
                filled: true
                bgColor: Theme.primary
                textColor: Theme.background
                enabled: !!tab.widgetRoot.player
                onClicked: if (tab.widgetRoot.player) tab.widgetRoot.player.togglePlaying()
            }

            NotchyButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                size: 38
                iconSize: 20
                textColor: Theme.surfaceText
                hoverColor: Theme.withAlpha(Theme.surfaceText, 0.08)
                enabled: tab.widgetRoot.player?.canGoNext ?? false
                onClicked: MprisController.next()
            }
        }
    }

    // ---- 无媒体：时钟 ----
    Column {
        width: parent.width
        spacing: 4
        visible: !tab.widgetRoot.hasMedia

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tab.widgetRoot.clockTimeText
            font.pixelSize: 36
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tab.widgetRoot.clockDateText
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceTextMedium
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "播放媒体后，这里会显示控制面板"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
        }
    }

    // ---- 下一日程（无日历源时隐藏） ----
    Row {
        width: parent.width
        spacing: 6
        visible: tab.widgetRoot.nextEvent !== null

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "event"
            size: 15
            color: Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const ev = tab.widgetRoot.nextEvent;
                if (!ev)
                    return "";
                return tab.widgetRoot.fmtEventWhen(ev.start) + " " + ev.title + " · " + tab.widgetRoot.fmtEventIn(ev.start);
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            elide: Text.ElideRight
            maximumLineCount: 1
            width: parent.width - 21
        }
    }

    // ---- 系统音量 ----
    Row {
        width: parent.width
        spacing: Theme.spacingS
        visible: tab.widgetRoot.sinkAudio !== null

        NotchyButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: tab.widgetRoot.volumeMuted ? "volume_off" : "volume_up"
            size: 30
            iconSize: 17
            textColor: Theme.surfaceText
            hoverColor: Theme.withAlpha(Theme.surfaceText, 0.08)
            onClicked: {
                if (tab.widgetRoot.sinkAudio)
                    tab.widgetRoot.sinkAudio.muted = !tab.widgetRoot.sinkAudio.muted;
            }
        }

        DankSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 30 - Theme.spacingS
            height: 28
            value: tab.widgetRoot.volumePercent
            minimum: 0
            maximum: 100
            showValue: false
            wheelEnabled: true
            // 守卫：初始化/回显不写入 PipeWire，否则加载即触发幻影音量变化
            onSliderValueChanged: newValue => {
                const sink = tab.widgetRoot.sinkAudio;
                if (!sink)
                    return;
                if (Math.abs(newValue - tab.widgetRoot.volumePercent) < 0.5)
                    return;
                sink.volume = newValue / 100;
            }
        }
    }
}
