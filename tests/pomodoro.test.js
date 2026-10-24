const test = require("node:test");
const assert = require("node:assert/strict");
const { pluginPath, installFunctions } = require("./helpers.js");

const daemonPath = pluginPath("NotchyDaemon.qml");

function createDaemon() {
    let now = 1700000000000;
    const FakeDate = { now: () => now };
    const notifications = [];
    const root = {
        pomoState: "idle",
        pomoRemainingSec: 0,
        pomoTotalSec: 0,
        pomoPhase: "work",
        pomoCycles: 0,
        pomoEndAt: 0,
        pomoWorkMin: 25,
        pomoBreakMin: 5,
        _notify: (title, body) => notifications.push({ title, body })
    };
    installFunctions(root, daemonPath, [
        "pomoStart",
        "pomoPause",
        "pomoResume",
        "pomoReset",
        "pomoSkip",
        "_pomoComplete",
        "_pomoTick",
        "_pomoCmd"
    ], { Date: FakeDate });
    return {
        root,
        notifications,
        advance(ms) { now += ms; }
    };
}

test("番茄钟按结束时间校正，延迟触发不会累计漂移", () => {
    const { root, notifications, advance } = createDaemon();
    root.pomoStart(1);
    assert.equal(root.pomoState, "running");
    assert.equal(root.pomoRemainingSec, 60);
    advance(10400);
    root._pomoTick();
    assert.equal(root.pomoRemainingSec, 50);
    advance(49600);
    root._pomoTick();
    assert.equal(root.pomoPhase, "break");
    assert.equal(root.pomoState, "running");
    assert.equal(root.pomoRemainingSec, 300);
    assert.equal(root.pomoCycles, 1);
    assert.equal(notifications.length, 1);
});

test("暂停保存真实剩余时间，恢复重新生成结束时间", () => {
    const { root, advance } = createDaemon();
    root.pomoStart(1);
    advance(20400);
    root.pomoPause();
    assert.equal(root.pomoState, "paused");
    assert.equal(root.pomoRemainingSec, 40);
    assert.equal(root.pomoEndAt, 0);
    advance(120000);
    root._pomoTick();
    assert.equal(root.pomoRemainingSec, 40);
    root.pomoResume();
    assert.equal(root.pomoState, "running");
    advance(39400);
    root._pomoTick();
    assert.equal(root.pomoRemainingSec, 1);
    advance(600);
    root._pomoTick();
    assert.equal(root.pomoPhase, "break");
});

test("重置清理状态，自然完成工作和休息仍发送通知", () => {
    const { root, notifications, advance } = createDaemon();
    root.pomoStart(1);
    advance(60000);
    root._pomoTick();
    advance(300000);
    root._pomoTick();
    assert.equal(root.pomoState, "idle");
    assert.equal(root.pomoPhase, "work");
    assert.equal(root.pomoEndAt, 0);
    assert.equal(root.pomoCycles, 1);
    assert.equal(notifications.length, 2);
    root.pomoReset();
    assert.equal(root.pomoRemainingSec, 0);
    assert.equal(root.pomoTotalSec, 0);
});

test("手动跳过不通知、不计轮数，空闲跳过为无操作", () => {
    const { root, notifications } = createDaemon();
    root.pomoSkip();
    assert.equal(root.pomoState, "idle");
    root.pomoStart(1);
    root.pomoSkip();
    assert.equal(root.pomoPhase, "break");
    assert.equal(root.pomoState, "running");
    assert.equal(root.pomoCycles, 0);
    assert.equal(notifications.length, 0);
    root.pomoSkip();
    assert.equal(root.pomoState, "idle");
    assert.equal(root.pomoPhase, "work");
    assert.equal(notifications.length, 0);
});

test("pomo IPC 支持开始、跳过和未知动作反馈", () => {
    const { root, notifications } = createDaemon();
    assert.equal(root._pomoCmd("start", "1"), "pomo:start");
    assert.equal(root._pomoCmd("skip", ""), "pomo:skip");
    assert.equal(root.pomoPhase, "break");
    assert.equal(root.pomoCycles, 0);
    assert.equal(notifications.length, 0);
    assert.equal(root._pomoCmd("unknown", ""), "unknown action: unknown");
});

test("默认开始读取工作和休息时长设置", () => {
    const { root, advance } = createDaemon();
    root.pomoWorkMin = 7;
    root.pomoBreakMin = 2;
    root.pomoStart(0);
    assert.equal(root.pomoTotalSec, 420);
    advance(420000);
    root._pomoTick();
    assert.equal(root.pomoTotalSec, 120);
    assert.equal(root.pomoPhase, "break");
});
