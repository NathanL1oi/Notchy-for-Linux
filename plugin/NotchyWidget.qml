import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "NotchyTabs.js" as NotchyTabs

// Notchy 顶栏组件：聚合共享状态、IPC 与各子组件。
PluginComponent {
    id: root

    // ---- 设置 ----
    readonly property bool showClockIdle: pluginData.showClockIdle ?? true
    readonly property bool showSecondsW: pluginData.showSeconds ?? false
    readonly property bool pillFlashEnabled: pluginData.pillFlash ?? true
    readonly property bool reduceMotion: pluginData.reduceMotion ?? false
    readonly property bool animationsEnabled: !reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None

    // ---- 媒体状态 ----
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
        target: root.player
        function onPositionChanged() {
            if (root.player)
                root.trackPos = root.player.position;
        }
    }

    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.player)
                root.trackPos = root.player.position;
        }
    }

    SystemClock {
        id: clock
        precision: root.showSecondsW ? SystemClock.Seconds : SystemClock.Minutes
    }

    // 供药丸与标签页使用的响应式时钟
    readonly property var clockDate: clock.date
    readonly property string clockTimeText: clock.date?.toLocaleTimeString(Qt.locale(), "HH:mm") ?? ""
    readonly property string clockDateText: clock.date?.toLocaleDateString(Qt.locale(), "M月d日 dddd") ?? ""

    function fmtTime(s) {
        s = Math.max(0, Math.round(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ---- 音量 ----
    readonly property var sinkAudio: AudioService.sink?.audio ?? null
    readonly property int volumePercent: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
    readonly property bool volumeMuted: sinkAudio?.muted ?? false

    // ---- 药丸瞬态镜像 ----
    // flashKind: "" | "notif" | "volume" | "shelf"
    property string flashKind: ""
    property string flashText: ""
    property string flashIcon: ""

    function flash(kind, text, icon) {
        if (!pillFlashEnabled)
            return;
        flashKind = kind;
        flashText = text;
        flashIcon = icon;
        flashTimer.restart();
    }

    Timer {
        id: flashTimer
        interval: root.flashKind === "notif" ? 4200 : 1800
        onTriggered: root.flashKind = ""
    }

    // 新通知监听（allWrappers 含弹层通知，notifications 只含通知中心保留项）
    property var _knownNotifIds: ({})

    function _checkNewNotifs() {
        const list = NotificationService.allWrappers;
        const now = {};
        let newest = null;
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            const nid = w?.notification?.id;
            if (nid === undefined)
                continue;
            now[nid] = true;
            if (!(nid in root._knownNotifIds))
                newest = w;
        }
        root._knownNotifIds = now;
        if (newest)
            root.flash("notif", newest.summary || newest.appName || "新通知", newest.appIcon || "notifications");
    }

    Connections {
        target: NotificationService
        function onAllWrappersChanged() {
            root._checkNewNotifs();
        }
        function onGroupedPopupsChanged() {
            root._checkNewNotifs();
        }
        function onVisibleNotificationsChanged() {
            root._checkNewNotifs();
        }
    }

    Connections {
        target: root.sinkAudio
        ignoreUnknownSignals: true
        property bool ready: false
        // sink 初始同步会触发一次 volumeChanged，忽略之
        function onVolumeChanged() {
            if (!ready) {
                ready = true;
                return;
            }
            root.flash("volume", Math.round(root.sinkAudio.volume * 100) + "%", root.sinkAudio.muted ? "volume_off" : "volume_up");
        }
        function onMutedChanged() {
            if (!ready)
                return;
            root.flash("volume", root.sinkAudio.muted ? "已静音" : Math.round(root.sinkAudio.volume * 100) + "%", root.sinkAudio.muted ? "volume_off" : "volume_up");
        }
    }

    Component.onCompleted: {
        // 启动时把现有通知标记为已知，避免一开机就闪
        const list = NotificationService.allWrappers;
        const now = {};
        for (let i = 0; i < list.length; i++) {
            const nid = list[i]?.notification?.id;
            if (nid !== undefined)
                now[nid] = true;
        }
        root._knownNotifIds = now;
        Qt.callLater(root._refreshNextEvent);
    }

    // ---- 暂存架数据（存插件设置，跨重启持久） ----
    readonly property var shelfFiles: pluginData.shelfFiles ?? []

    // 必须走 PluginService.savePluginData（它会同步内存并发出 pluginDataChanged），
    // 直接调 SettingsData.setPluginSetting 只写文件，本组件不会收到刷新信号。
    function _saveShelf(files) {
        if (pluginService && pluginService.savePluginData)
            pluginService.savePluginData("notchy", "shelfFiles", files);
        else
            SettingsData.setPluginSetting("notchy", "shelfFiles", files);
    }

    function addToShelf(urls) {
        if (!urls || urls.length === 0)
            return;
        let files = root.shelfFiles.slice();
        let added = 0;
        for (let i = 0; i < urls.length; i++) {
            const u = String(urls[i]).trim();
            if (u.length === 0 || files.indexOf(u) !== -1)
                continue;
            files.unshift(u);
            added++;
        }
        files = files.slice(0, 30);
        root._saveShelf(files);
        if (added > 0)
            root.flash("shelf", "已暂存 " + added + " 个文件", "inventory_2");
    }

    function removeFromShelfAt(idx) {
        const files = root.shelfFiles.slice();
        files.splice(idx, 1);
        root._saveShelf(files);
    }

    function clearShelf() {
        root._saveShelf([]);
    }

    // ---- AI 额度用量 ----
    NotchyUsageController {
        id: usageController
        pluginData: root.pluginData
    }

    readonly property var kimiUsage: usageController.kimiUsage
    readonly property var deepseekUsage: usageController.deepseekUsage
    readonly property bool kimiUsageLoading: usageController.kimiUsageLoading
    readonly property bool deepseekUsageLoading: usageController.deepseekUsageLoading
    readonly property bool kimiKeyFromZcode: usageController.kimiKeyFromZcode

    function fetchUsage() {
        usageController.fetchUsage();
    }

    // 切到用量页时刷新
    onCurrentTabChanged: {
        if (root.currentTab === NotchyTabs.indexOf("usage"))
            root.fetchUsage();
    }

    // ---- 日历下一日程 ----
    NotchyCalendarController {
        id: calendarController
    }

    readonly property var nextEvent: calendarController.nextEvent

    function _refreshNextEvent() {
        calendarController._refreshNextEvent();
    }

    Connections {
        target: calendarController
        function onReminderRequested(text) {
            root.flash("notif", text, "event");
        }
    }

    function fmtEventWhen(d) {
        return Qt.formatTime(d, "HH:mm");
    }

    function fmtEventIn(d) {
        const mins = Math.max(0, Math.round((d.getTime() - Date.now()) / 60000));
        if (mins < 60)
            return "还有 " + mins + " 分钟";
        return "还有 " + Math.floor(mins / 60) + " 小时 " + (mins % 60) + " 分";
    }

    // ---- 番茄钟（状态在 daemon） ----
    readonly property bool pomoActive: (daemon?.pomoState ?? "idle") !== "idle"
    readonly property int pomoRemaining: daemon?.pomoRemainingSec ?? 0
    readonly property string pomoState: daemon?.pomoState ?? "idle"
    readonly property string pomoPhase: daemon?.pomoPhase ?? "work"

    function fmtPomo(sec) {
        sec = Math.max(0, sec);
        return String(Math.floor(sec / 60)).padStart(2, "0") + ":" + String(sec % 60).padStart(2, "0");
    }

    // ---- IPC 桥：绑定 daemon 的 commandNonce（内存信号通道，无启动竞态） ----
    readonly property var daemon: PluginService.pluginDaemonInstances["notchy"] ?? null
    readonly property int daemonCmdNonce: daemon?.commandNonce ?? 0
    property int lastCmdNonce: 0
    property var popoutRef: null
    property int currentTab: 0

    // daemon 就绪时同步初值（绑定初值可能不触发 change 信号）
    onDaemonChanged: root.lastCmdNonce = root.daemonCmdNonce

    onDaemonCmdNonceChanged: {
        if (root.daemonCmdNonce === root.lastCmdNonce)
            return;
        root.lastCmdNonce = root.daemonCmdNonce;

        const cmd = root.daemon?.command ?? "toggle";
        const isOpen = root.popoutRef?.shouldBeVisible ?? false;

        if (cmd === "menu") {
            notchyMenu.toggle();
            return;
        }

        if (cmd === "toggle") {
            root.triggerPopout();
        } else if (cmd === "open") {
            if (!isOpen)
                root.triggerPopout();
        } else if (cmd === "close") {
            if (isOpen && root.popoutRef?.close)
                root.popoutRef.close();
        } else if (cmd.startsWith("tab:")) {
            const idx = NotchyTabs.indexOf(cmd.substring(4));
            if (idx >= 0)
                root.currentTab = idx;
            if (!isOpen)
                root.triggerPopout();
        }
        Qt.callLater(root.fixPopoutPosition);
    }

    // DMS 1.5.3 插件弹层定位 bug 绕过：弹层打开时强制锚定到顶栏中心。
    function fixPopoutPosition() {
        if (!popoutRef || !popoutRef.setTriggerPosition)
            return;
        if (root.section !== "center")
            return;
        const scr = root.parentScreen;
        if (!scr)
            return;
        const pillW = root.width > 0 ? root.width : 60;
        const pos = SettingsData.getPopupTriggerPosition(Qt.point(scr.width / 2 - pillW / 2, 0), scr, root.barThickness, pillW, root.barSpacing, 0, root.barConfig);
        popoutRef.setTriggerPosition(pos.x, pos.y, pos.width, root.section, scr, 0, root.barThickness, root.barSpacing, root.barConfig);
        if (popoutRef.updateSurfacePosition)
            popoutRef.updateSurfacePosition();
    }

    popoutWidth: 470

    // 右键药丸 → 快捷菜单
    pillRightClickAction: function () {
        notchyMenu.toggle();
    }

    NotchyMenu {
        id: notchyMenu
        widgetRoot: root
    }

    horizontalBarPill: barPillComponent
    popoutContent: popoutComponent

    Component {
        id: barPillComponent
        NotchyPill {
            widgetRoot: root
        }
    }

    Component {
        id: popoutComponent
        NotchyPopout {
            widgetRoot: root
        }
    }
}
