import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

// 灵动岛主窗口：Overlay 层顶部居中，三态（idle 收起 / peek 悬停 / open 展开）。
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    // ---- 由 daemon 注入的设置 ----
    property int hoverDelayMs: 60
    property bool blackPill: true
    property bool showSeconds: false
    property int openWidthPx: 560
    property int topMarginPx: 0

    // ---- 状态机 ----
    property string uiState: "idle"   // "idle" | "peek" | "open"

    function toggle() {
        uiState = uiState === "open" ? "idle" : "open";
    }

    // ---- 媒体数据 ----
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasMedia: player !== null
    readonly property bool _hoverPreview: MprisController.isFirefoxYoutubeHoverPreview(player)
    readonly property bool isPlaying: !!player && player.playbackState === MprisPlaybackState.Playing && !_hoverPreview
    readonly property string trackTitle: MprisController.stableTitle
    readonly property string trackArtist: MprisController.stableArtist
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property real trackLength: player?.length ?? 0
    property real trackPos: 0

    onPlayerChanged: trackPos = player?.position ?? 0

    Connections {
        target: win.player
        function onPositionChanged() {
            if (win.player)
                win.trackPos = win.player.position;
        }
    }

    Timer {
        interval: 1000
        running: win.isPlaying
        repeat: true
        onTriggered: {
            if (win.player)
                win.trackPos = win.player.position;
        }
    }

    function fmtTime(s) {
        s = Math.max(0, Math.round(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ---- 配色 ----
    readonly property color pillColor: blackPill ? "#000000" : Theme.surfaceContainer
    readonly property color pillBorder: blackPill ? Qt.rgba(1, 1, 1, 0.09) : Theme.withAlpha(Theme.outline, 0.25)
    readonly property color textPrimary: blackPill ? "#f5f5f7" : Theme.surfaceText
    readonly property color textSecondary: blackPill ? Qt.rgba(1, 1, 1, 0.55) : Theme.surfaceTextMedium
    readonly property color accent: Theme.primary
    readonly property color onAccent: Theme.background
    readonly property color trackBg: blackPill ? Qt.rgba(1, 1, 1, 0.18) : Theme.withAlpha(Theme.outlineVariant, 0.5)

    // ---- 尺寸 ----
    readonly property real idleW: hasMedia ? 240 : 150
    readonly property real idleH: 36
    readonly property real peekW: 420
    readonly property real peekH: 108
    readonly property real openW: openWidthPx
    readonly property real openH: 236
    readonly property real targetW: uiState === "open" ? openW : (uiState === "peek" ? peekW : idleW)
    readonly property real targetH: uiState === "open" ? openH : (uiState === "peek" ? peekH : idleH)

    // ---- 窗口配置 ----
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Math.ceil(island.y + island.height) + 2
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notchy"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    // 仅药丸区域接收输入，其余点击穿透
    mask: Region {
        item: island
    }

    // ---- 悬停状态切换 ----
    Timer {
        id: hoverInTimer
        interval: win.hoverDelayMs
        onTriggered: {
            if (win.uiState === "idle")
                win.uiState = "peek";
        }
    }

    Timer {
        id: hoverOutTimer
        interval: 300
        onTriggered: {
            if (win.uiState === "peek")
                win.uiState = "idle";
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 900
        onTriggered: {
            if (win.uiState === "open")
                win.uiState = "idle";
        }
    }

    // cava 仅在播放且可见时运行
    Loader {
        active: win.isPlaying
        sourceComponent: Ref {
            service: CavaService
        }
    }

    SystemClock {
        id: clock
        precision: win.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ---- 岛本体 ----
    Rectangle {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.topMarginPx
        width: win.targetW
        height: win.targetH
        radius: Math.min(height / 2, 28)
        color: win.pillColor
        border.color: win.pillBorder
        border.width: 1
        clip: true
        antialiasing: true

        Behavior on width {
            NumberAnimation {
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        HoverHandler {
            id: islandHover
            onHoveredChanged: {
                if (hovered) {
                    hoverOutTimer.stop();
                    autoCloseTimer.stop();
                    if (win.uiState === "idle")
                        hoverInTimer.restart();
                } else {
                    hoverInTimer.stop();
                    if (win.uiState === "peek")
                        hoverOutTimer.restart();
                    else if (win.uiState === "open")
                        autoCloseTimer.restart();
                }
            }
        }

        // 背景点击：切换 open / idle（内部控件有自己的 MouseArea，会优先消费事件）
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: win.uiState === "open" ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: win.toggle()
        }

        // ==================== IDLE：收起态 ====================
        Item {
            id: idleContent
            anchors.fill: parent
            opacity: win.uiState === "idle" ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Theme.standardEasing
                }
            }

            // 有媒体：频谱 + 曲名
            Row {
                visible: win.hasMedia
                anchors.centerIn: parent
                spacing: 8

                NotchyCavaBars {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 18
                    running: win.isPlaying
                    barColor: win.accent
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.trackTitle || win.player?.identity || ""
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: win.textPrimary
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, 160)
                }
            }

            // 无媒体：时钟
            Row {
                visible: !win.hasMedia
                anchors.centerIn: parent
                spacing: 6

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: clock.date?.toLocaleTimeString(Qt.locale(), win.showSeconds ? "HH:mm:ss" : "HH:mm") ?? ""
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: win.textPrimary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: clock.date?.toLocaleDateString(Qt.locale(), "M/d ddd") ?? ""
                    font.pixelSize: 12
                    color: win.textSecondary
                }
            }
        }

        // ==================== PEEK：悬停摘要 ====================
        Item {
            id: peekContent
            anchors.fill: parent
            opacity: win.uiState === "peek" ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Theme.standardEasing
                }
            }

            Row {
                visible: win.hasMedia
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                NotchyCover {
                    width: 76
                    height: 76
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    artUrl: win.artUrl
                    iconColor: win.textSecondary
                    bgColor: win.trackBg
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 76 - 14 - controlsPeek.width - 14
                    spacing: 4

                    StyledText {
                        width: parent.width
                        text: win.trackTitle
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: win.textPrimary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        width: parent.width
                        text: win.trackArtist || win.player?.identity || ""
                        font.pixelSize: 12
                        color: win.textSecondary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: (win.isPlaying ? "正在播放" : "已暂停") + " · " + (win.player?.identity ?? "")
                        font.pixelSize: 11
                        color: win.textSecondary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: parent.width
                    }
                }

                Row {
                    id: controlsPeek
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    NotchyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_previous"
                        size: 34
                        iconSize: 18
                        textColor: win.textPrimary
                        hoverColor: win.trackBg
                        enabled: win.player?.canGoPrevious ?? false
                        onClicked: MprisController.previousOrRewind()
                    }

                    NotchyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: win.isPlaying ? "pause" : "play_arrow"
                        size: 42
                        iconSize: 22
                        filled: true
                        bgColor: win.accent
                        textColor: win.onAccent
                        enabled: !!win.player
                        onClicked: if (win.player) win.player.togglePlaying()
                    }

                    NotchyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_next"
                        size: 34
                        iconSize: 18
                        textColor: win.textPrimary
                        hoverColor: win.trackBg
                        enabled: win.player?.canGoNext ?? false
                        onClicked: MprisController.next()
                    }
                }
            }

            // 无媒体：大时钟
            Column {
                visible: !win.hasMedia
                anchors.centerIn: parent
                spacing: 2

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clock.date?.toLocaleTimeString(Qt.locale(), "HH:mm") ?? ""
                    font.pixelSize: 34
                    font.weight: Font.Bold
                    color: win.textPrimary
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clock.date?.toLocaleDateString(Qt.locale(), "M月d日 dddd") ?? ""
                    font.pixelSize: 12
                    color: win.textSecondary
                }
            }
        }

        // ==================== OPEN：完整面板 ====================
        Item {
            id: openContent
            anchors.fill: parent
            opacity: win.uiState === "open" ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Theme.standardEasing
                }
            }

            Row {
                visible: win.hasMedia
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                NotchyCover {
                    width: 196
                    height: 196
                    radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    artUrl: win.artUrl
                    iconColor: win.textSecondary
                    bgColor: win.trackBg
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 196 - 20
                    spacing: 6

                    StyledText {
                        width: parent.width
                        text: win.trackTitle
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: win.textPrimary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        width: parent.width
                        text: win.trackArtist || win.player?.identity || ""
                        font.pixelSize: 13
                        color: win.textSecondary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Item {
                        width: 1
                        height: 18
                    }

                    // 进度条 + 时间
                    Item {
                        width: parent.width
                        height: 18

                        Rectangle {
                            id: progressTrack
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            radius: 2
                            color: win.trackBg

                            Rectangle {
                                height: parent.height
                                radius: 2
                                color: win.accent
                                width: win.trackLength > 0 ? parent.width * Math.min(1, win.trackPos / win.trackLength) : 0

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
                            cursorShape: (win.player?.canSeek ?? false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: mouse => {
                                if (win.player && win.player.canSeek && win.trackLength > 0) {
                                    win.player.position = (mouse.x / width) * win.trackLength;
                                    win.trackPos = win.player.position;
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        StyledText {
                            id: posText
                            text: win.fmtTime(win.trackPos)
                            font.pixelSize: 11
                            color: win.textSecondary
                        }

                        Item {
                            width: parent.width - posText.width - lenText.width
                            height: 1
                        }

                        StyledText {
                            id: lenText
                            text: win.fmtTime(win.trackLength)
                            font.pixelSize: 11
                            color: win.textSecondary
                        }
                    }

                    Item {
                        width: 1
                        height: 6
                    }

                    // 控制按钮
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        NotchyButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "skip_previous"
                            size: 40
                            iconSize: 22
                            textColor: win.textPrimary
                            hoverColor: win.trackBg
                            enabled: win.player?.canGoPrevious ?? false
                            onClicked: MprisController.previousOrRewind()
                        }

                        NotchyButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: win.isPlaying ? "pause" : "play_arrow"
                            size: 54
                            iconSize: 28
                            filled: true
                            bgColor: win.accent
                            textColor: win.onAccent
                            enabled: !!win.player
                            onClicked: if (win.player) win.player.togglePlaying()
                        }

                        NotchyButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "skip_next"
                            size: 40
                            iconSize: 22
                            textColor: win.textPrimary
                            hoverColor: win.trackBg
                            enabled: win.player?.canGoNext ?? false
                            onClicked: MprisController.next()
                        }
                    }
                }
            }

            // 无媒体
            Column {
                visible: !win.hasMedia
                anchors.centerIn: parent
                spacing: 6

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clock.date?.toLocaleTimeString(Qt.locale(), "HH:mm") ?? ""
                    font.pixelSize: 46
                    font.weight: Font.Bold
                    color: win.textPrimary
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: clock.date?.toLocaleDateString(Qt.locale(), "yyyy年M月d日 dddd") ?? ""
                    font.pixelSize: 14
                    color: win.textSecondary
                }

                Item {
                    width: 1
                    height: 6
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "播放媒体后，这里会显示控制面板"
                    font.pixelSize: 12
                    color: win.textSecondary
                }
            }
        }
    }
}
