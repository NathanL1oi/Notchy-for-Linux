const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { pluginPath, installFunctions, loadTabs } = require("./helpers.js");

const widgetPath = pluginPath("NotchyWidget.qml");

function createWidget() {
    const flashes = [];
    const root = {
        shelfFiles: [],
        savedFiles: null,
        _saveShelf(files) {
            this.savedFiles = files.slice();
            this.shelfFiles = files.slice();
        },
        flash(kind, text, icon) {
            flashes.push({ kind, text, icon });
        }
    };
    installFunctions(root, widgetPath, ["addToShelf", "removeFromShelfAt", "clearShelf"]);
    return { root, flashes };
}

test("暂存架去除空项和重复 URL，只提示实际新增数量", () => {
    const { root, flashes } = createWidget();
    root.shelfFiles = ["file:///a"];
    root.addToShelf(["file:///a", " file:///b ", "", "file:///a"]);
    assert.deepEqual(root.shelfFiles, ["file:///b", "file:///a"]);
    assert.equal(flashes.length, 1);
    assert.match(flashes[0].text, /1 个文件/);
    root.addToShelf([]);
    root.addToShelf(["file:///a"]);
    assert.equal(flashes.length, 1);
});

test("暂存架最多保留 30 个最新项目", () => {
    const { root } = createWidget();
    const urls = Array.from({ length: 35 }, (_, i) => `file:///${i}`);
    root.addToShelf(urls);
    assert.equal(root.shelfFiles.length, 30);
    assert.equal(root.shelfFiles[0], "file:///34");
    assert.equal(root.shelfFiles.includes("file:///4"), false);
});

test("暂存架支持按索引删除和清空", () => {
    const { root } = createWidget();
    root.addToShelf(["file:///a", "file:///b", "file:///c"]);
    root.removeFromShelfAt(1);
    assert.deepEqual(root.shelfFiles, ["file:///c", "file:///a"]);
    root.clearShelf();
    assert.deepEqual(root.shelfFiles, []);
});

test("共享模型包含六个稳定页面，弹层菜单和 IPC 均引用它", () => {
    const { tabs, indexOf } = loadTabs();
    assert.deepEqual(tabs.map(tab => tab.id), ["media", "notifications", "clipboard", "shelf", "focus", "usage"]);
    assert.equal(new Set(tabs.map(tab => tab.id)).size, 6);
    for (let i = 0; i < tabs.length; i++) {
        assert.equal(tabs[i].index, i);
        assert.equal(indexOf(tabs[i].id), i);
    }
    assert.equal(indexOf("missing"), -1);

    const widget = fs.readFileSync(widgetPath, "utf8");
    const popout = fs.readFileSync(pluginPath("NotchyPopout.qml"), "utf8");
    const menu = fs.readFileSync(pluginPath("NotchyMenu.qml"), "utf8");
    assert.match(widget, /NotchyTabs\.indexOf\(cmd\.substring\(4\)\)/);
    assert.match(popout, /model: NotchyTabs\.tabs/);
    assert.match(menu, /model: NotchyTabs\.tabs/);
});

test("主组件只保留代理，控制器和视图职责已分离", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");
    const usage = fs.readFileSync(pluginPath("NotchyUsageController.qml"), "utf8");
    const calendar = fs.readFileSync(pluginPath("NotchyCalendarController.qml"), "utf8");
    const pill = fs.readFileSync(pluginPath("NotchyPill.qml"), "utf8");
    const monitor = fs.readFileSync(pluginPath("NotchyMonitorBar.qml"), "utf8");
    const popout = fs.readFileSync(pluginPath("NotchyPopout.qml"), "utf8");

    assert.equal(widget.includes("XMLHttpRequest"), false);
    assert.equal(widget.includes("CalendarService"), false);
    assert.equal(widget.includes("DgopService"), false);
    assert.match(widget, /NotchyUsageController/);
    assert.match(widget, /NotchyCalendarController/);
    assert.match(widget, /readonly property var clockDate: clock\.date/);
    assert.match(widget, /readonly property var kimiUsage: usageController\.kimiUsage/);
    assert.match(widget, /readonly property var nextEvent: calendarController\.nextEvent/);
    assert.match(usage, /new XMLHttpRequest/);
    assert.equal(usage.includes("onCurrentTabChanged"), false);
    assert.match(calendar, /signal reminderRequested\(string text\)/);
    assert.match(pill, /required property var widgetRoot/);
    assert.match(monitor, /property bool monitorExpanded: false/);
    assert.match(popout, /NotchyMonitorBar/);

    for (const type of ["NotchyMediaTab", "NotchyNotifTab", "NotchyClipboardTab", "NotchyShelfTab", "NotchyFocusTab", "NotchyUsageTab"])
        assert.match(popout, new RegExp(type));
});
