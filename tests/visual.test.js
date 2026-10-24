const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { pluginPath } = require("./helpers.js");

function read(name) {
    return fs.readFileSync(pluginPath(name), "utf8");
}

test("药丸与弹层动画受插件和 DMS 全局动画设置控制", () => {
    const widget = read("NotchyWidget.qml");
    const pill = read("NotchyPill.qml");
    const popout = read("NotchyPopout.qml");
    const settings = read("NotchySettings.qml");
    assert.match(widget, /pluginData\.reduceMotion \?\? false/);
    assert.match(widget, /Theme\.currentAnimationSpeed !== SettingsData\.AnimationSpeed\.None/);
    assert.match(settings, /settingKey: "reduceMotion"/);
    assert.match(pill, /component AnimatedRow: Row/);
    assert.match(pill, /Behavior on opacity/);
    assert.match(pill, /activeContent \? activeContent\.implicitWidth : 0/);
    assert.match(popout, /scale: popoutVisible \? 1 : 0\.97/);
    assert.match(popout, /y: panel\.popoutVisible \? 0 : -6/);
});

test("六页和右键菜单使用延迟 Tooltip，关闭时清理提示", () => {
    const popout = read("NotchyPopout.qml");
    const menu = read("NotchyMenu.qml");
    for (const source of [popout, menu]) {
        assert.match(source, /DankTooltipV2/);
        assert.match(source, /interval: 400/);
        assert.match(source, /\.hide\(\)/);
    }
});

test("通知、剪贴板和用量页复用统一状态组件", () => {
    for (const name of ["NotchyNotifTab.qml", "NotchyClipboardTab.qml", "NotchyUsageTab.qml"]) {
        const source = read(name);
        assert.match(source, /NotchyEmptyState/);
    }
    const usage = read("NotchyUsageTab.qml");
    assert.match(usage, /actionText:.*"重试"/);
    assert.match(read("NotchyEmptyState.qml"), /signal actionClicked\(\)/);
});
