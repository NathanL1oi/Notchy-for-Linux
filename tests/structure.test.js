const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { pluginDir, pluginPath, assertBalancedQml } = require("./helpers.js");

const qmlFiles = fs.readdirSync(pluginDir).filter(name => name.endsWith(".qml")).sort();

test("所有活动 QML 文件的括号、注释和字符串结构完整", () => {
    for (const name of qmlFiles)
        assertBalancedQml(pluginPath(name));
});

test("本地 QML 类型和 JavaScript 导入均有对应文件", () => {
    const types = new Set(qmlFiles.map(name => name.slice(0, -4)));
    for (const name of qmlFiles) {
        const filePath = pluginPath(name);
        const source = fs.readFileSync(filePath, "utf8");
        const localTypes = source.match(/\bNotchy[A-Z][A-Za-z0-9]*\b/g) || [];
        for (const type of new Set(localTypes)) {
            if (type !== "NotchyTabs")
                assert.equal(types.has(type), true, `${name} references missing type ${type}`);
        }
        for (const match of source.matchAll(/import\s+"([^"]+\.js)"\s+as\s+/g))
            assert.equal(fs.existsSync(path.join(pluginDir, match[1])), true, `${name} missing import ${match[1]}`);
    }
});

test("插件清单中的 daemon、widget 和设置入口存在", () => {
    const manifest = JSON.parse(fs.readFileSync(pluginPath("plugin.json"), "utf8"));
    for (const file of [manifest.components.daemon, manifest.components.widget, manifest.settings])
        assert.equal(fs.existsSync(path.join(pluginDir, file)), true, `missing manifest entry ${file}`);
});

test("音量只有一组监听，专注页只调用公开跳过接口", () => {
    const widget = fs.readFileSync(pluginPath("NotchyWidget.qml"), "utf8");
    const focus = fs.readFileSync(pluginPath("NotchyFocusTab.qml"), "utf8");
    assert.equal((widget.match(/target: root\.sinkAudio/g) || []).length, 1);
    assert.match(focus, /pomoSkip\(\)/);
    assert.equal(focus.includes("_pomoComplete"), false);
});
