import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Notchy daemon：番茄钟状态机（常驻，弹层开关不影响计时）+ IPC 命令通道。
// 顶栏组件通过 PluginService.pluginDaemonInstances["notchy"] 读取本 daemon。
PluginComponent {
    id: root

    // ---- 番茄钟状态机 ----
    property string pomoState: "idle"   // "idle" | "running" | "paused"
    property int pomoRemainingSec: 0
    property int pomoTotalSec: 0
    property string pomoPhase: "work"   // "work" | "break"
    property int pomoCycles: 0
    property real pomoEndAt: 0

    readonly property int pomoWorkMin: pluginData.pomoWorkMin ?? 25
    readonly property int pomoBreakMin: pluginData.pomoBreakMin ?? 5

    function pomoStart(minutes) {
        const m = Math.round(minutes);
        if (m > 0) {
            pomoPhase = "work";
            pomoTotalSec = m * 60;
            pomoRemainingSec = pomoTotalSec;
        } else if (pomoTotalSec <= 0) {
            pomoPhase = "work";
            pomoTotalSec = pomoWorkMin * 60;
            pomoRemainingSec = pomoTotalSec;
        }
        if (pomoRemainingSec <= 0)
            pomoRemainingSec = pomoTotalSec;
        pomoEndAt = Date.now() + pomoRemainingSec * 1000;
        pomoState = "running";
    }

    function pomoPause() {
        if (pomoState !== "running")
            return;
        const remaining = Math.max(0, Math.ceil((pomoEndAt - Date.now()) / 1000));
        if (remaining <= 0) {
            _pomoComplete(true);
            return;
        }
        pomoRemainingSec = remaining;
        pomoEndAt = 0;
        pomoState = "paused";
    }

    function pomoResume() {
        if (pomoState !== "paused")
            return;
        if (pomoRemainingSec <= 0) {
            _pomoComplete(true);
            return;
        }
        pomoEndAt = Date.now() + pomoRemainingSec * 1000;
        pomoState = "running";
    }

    function pomoReset() {
        pomoState = "idle";
        pomoPhase = "work";
        pomoRemainingSec = 0;
        pomoTotalSec = 0;
        pomoEndAt = 0;
    }

    function pomoSkip() {
        if (pomoState !== "idle")
            _pomoComplete(false);
    }

    function _pomoComplete(naturalCompletion) {
        if (pomoPhase === "work") {
            if (naturalCompletion) {
                pomoCycles++;
                _notify("专注完成 🎉", "休息 " + pomoBreakMin + " 分钟吧");
            }
            pomoPhase = "break";
            pomoTotalSec = pomoBreakMin * 60;
            pomoRemainingSec = pomoTotalSec;
            pomoEndAt = Date.now() + pomoRemainingSec * 1000;
            pomoState = "running";
        } else {
            if (naturalCompletion)
                _notify("休息结束", "该开始下一段专注了");
            pomoState = "idle";
            pomoPhase = "work";
            pomoRemainingSec = 0;
            pomoTotalSec = 0;
            pomoEndAt = 0;
        }
    }

    function _notify(title, body) {
        Quickshell.execDetached(["/usr/bin/notify-send", "-a", "Notchy", title, body]);
    }

    function _pomoTick() {
        if (pomoState !== "running")
            return;
        // 以结束时间为准，避免系统休眠或主线程卡顿造成累计漂移。
        const remaining = Math.max(0, Math.ceil((pomoEndAt - Date.now()) / 1000));
        pomoRemainingSec = remaining;
        if (remaining <= 0)
            _pomoComplete(true);
    }

    Timer {
        id: pomoTimer
        interval: 1000
        repeat: true
        running: root.pomoState === "running"
        onTriggered: root._pomoTick()
    }

    // ---- IPC 命令通道（组件实例绑定 commandNonce） ----
    property int commandNonce: 0
    property string command: ""   // "toggle" | "open" | "close" | "menu" | "tab:media|notifications|clipboard|shelf|focus|usage"

    function _issue(cmd) {
        root.command = cmd;
        root.commandNonce++;
    }

    function _pomoCmd(action, minutes) {
        const m = parseInt(minutes) || 0;
        if (action === "start")
            root.pomoStart(m);
        else if (action === "pause")
            root.pomoPause();
        else if (action === "resume")
            root.pomoResume();
        else if (action === "reset")
            root.pomoReset();
        else if (action === "skip")
            root.pomoSkip();
        else
            return "unknown action: " + action;
        return "pomo:" + action;
    }

    IpcHandler {
        target: "notchy"

        function toggle(): string {
            root._issue("toggle");
            return "toggled";
        }

        function open(): string {
            root._issue("open");
            return "opened";
        }

        function close(): string {
            root._issue("close");
            return "closed";
        }

        // openTab("media"|"notifications"|"clipboard"|"shelf"|"focus"|"usage")
        function openTab(tab: string): string {
            root._issue("tab:" + tab);
            return "opened:" + tab;
        }

        // 右键快捷菜单
        function menu(): string {
            root._issue("menu");
            return "menu";
        }

        // 番茄钟：pomo("start"|"pause"|"resume"|"reset"|"skip")；自定义时长 pomoMin("45")
        function pomo(action: string): string {
            return root._pomoCmd(action, "");
        }

        function pomoMin(minutes: string): string {
            return root._pomoCmd("start", minutes);
        }

        // 转发唤起 DMS 启动器（不重复造轮子）
        function launcher(): string {
            Quickshell.execDetached(["qs", "-p", "/usr/share/quickshell/dms", "ipc", "call", "launcher", "toggle"]);
            return "launcher";
        }
    }

    Component.onCompleted: console.info("Notchy: daemon loaded")
}
