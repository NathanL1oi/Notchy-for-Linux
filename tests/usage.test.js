const test = require("node:test");
const assert = require("node:assert/strict");
const { pluginPath, installFunctions, mockTimer } = require("./helpers.js");

const controllerPath = pluginPath("NotchyUsageController.qml");

function createUsageController() {
    class MockXhr {
        static DONE = 4;
        static instances = [];

        constructor() {
            this.readyState = 0;
            this.status = 0;
            this.responseText = "";
            this.headers = {};
            this.aborted = false;
            this.onreadystatechange = null;
            MockXhr.instances.push(this);
        }
        open(method, url) {
            this.method = method;
            this.url = url;
        }
        setRequestHeader(name, value) {
            this.headers[name] = value;
        }
        send() {
            this.sent = true;
        }
        abort() {
            this.aborted = true;
        }
        respond(status, body) {
            this.status = status;
            this.responseText = body;
            this.readyState = MockXhr.DONE;
            if (this.onreadystatechange) this.onreadystatechange();
        }
    }

    const kimiRequestTimeout = mockTimer();
    const deepseekRequestTimeout = mockTimer();
    const root = {
        kimiUsage: null,
        deepseekUsage: null,
        kimiUsageLoading: false,
        deepseekUsageLoading: false,
        _kimiRequest: null,
        _deepseekRequest: null,
        _zcodeKimiKey: "",
        kimiKey: "sk-kimi-test",
        deepseekKey: "deepseek-test"
    };
    installFunctions(root, controllerPath, [
        "_parseZcodeKey",
        "fetchUsage",
        "_usageHttpError",
        "_cancelKimiUsageRequest",
        "_fetchKimiUsage",
        "_cancelDeepseekRequest",
        "_fetchDeepseek"
    ], {
        XMLHttpRequest: MockXhr,
        Qt: { formatTime: () => "12:34" },
        kimiRequestTimeout,
        deepseekRequestTimeout
    });
    return { root, MockXhr, kimiRequestTimeout, deepseekRequestTimeout };
}

test("用量刷新跳过活动请求，Kimi 成功响应正确映射", () => {
    const { root, MockXhr, kimiRequestTimeout } = createUsageController();
    root.deepseekKey = "";
    root._fetchKimiUsage();
    assert.equal(root.kimiUsageLoading, true);
    assert.equal(MockXhr.instances.length, 1);
    assert.equal(MockXhr.instances[0].headers.Authorization, "Bearer sk-kimi-test");
    root.fetchUsage();
    assert.equal(MockXhr.instances.length, 1);
    MockXhr.instances[0].respond(200, JSON.stringify({
        usages: {
            limit_5h: { used_ratio: 0.25, reset_time: "soon" },
            limit_7d: { used_ratio: 0.5, reset_time: "later" }
        },
        usage: { used: 1, limit: 4, remaining: 3, resetTime: "later" }
    }));
    assert.equal(root.kimiUsageLoading, false);
    assert.equal(root._kimiRequest, null);
    assert.equal(root.kimiUsage.r5h, 0.25);
    assert.equal(root.kimiUsage.r7d, 0.5);
    assert.equal(root.kimiUsage.when, "12:34");
    assert.equal(kimiRequestTimeout.restarts, 1);
});

test("被替换的 Kimi 请求不能覆盖新结果", () => {
    const { root, MockXhr } = createUsageController();
    root._fetchKimiUsage();
    const oldRequest = MockXhr.instances[0];
    const staleCallback = oldRequest.onreadystatechange;
    root._fetchKimiUsage();
    const newRequest = MockXhr.instances[1];
    assert.equal(oldRequest.aborted, true);
    newRequest.respond(200, JSON.stringify({ usages: { limit_5h: { used_ratio: 0.4 } } }));
    assert.equal(root.kimiUsage.r5h, 0.4);
    oldRequest.readyState = MockXhr.DONE;
    oldRequest.status = 200;
    oldRequest.responseText = JSON.stringify({ usages: { limit_5h: { used_ratio: 0.99 } } });
    staleCallback();
    assert.equal(root.kimiUsage.r5h, 0.4);
});

test("用量请求区分认证、解析、网络、限流和缺少 Key", () => {
    const { root, MockXhr } = createUsageController();
    root._fetchKimiUsage();
    MockXhr.instances[0].respond(401, JSON.stringify({ message: "bad key" }));
    assert.match(root.kimiUsage.error, /认证或权限失败/);
    root._fetchKimiUsage();
    MockXhr.instances[1].respond(200, "not json");
    assert.equal(root.kimiUsage.error, "响应解析失败");
    root._fetchKimiUsage();
    MockXhr.instances[2].respond(0, "");
    assert.equal(root.kimiUsage.error, "网络连接失败");
    root.kimiKey = "";
    root._fetchKimiUsage();
    assert.equal(root.kimiUsage.error, "nokey");
    assert.equal(root._usageHttpError(429, ""), "请求过于频繁（HTTP 429）");
    assert.match(root._usageHttpError(503, ""), /服务暂不可用/);
});

test("DeepSeek 正常余额和限流响应正确更新状态", () => {
    const { root, MockXhr } = createUsageController();
    root._fetchDeepseek();
    MockXhr.instances[0].respond(200, JSON.stringify({
        balance_infos: [{ total_balance: "12.34", granted_balance: "2.00", topped_up_balance: "10.34", currency: "CNY" }]
    }));
    assert.equal(root.deepseekUsage.balance, 12.34);
    assert.equal(root.deepseekUsage.granted, 2);
    assert.equal(root.deepseekUsageLoading, false);
    root._fetchDeepseek();
    MockXhr.instances[1].respond(429, JSON.stringify({ message: "slow down" }));
    assert.match(root.deepseekUsage.error, /请求过于频繁/);
    assert.match(root.deepseekUsage.error, /slow down/);
});

test("取消请求会 abort XHR 并清理加载状态", () => {
    const { root, MockXhr } = createUsageController();
    root._fetchKimiUsage();
    const request = MockXhr.instances[0];
    root._cancelKimiUsageRequest();
    assert.equal(request.aborted, true);
    assert.equal(root._kimiRequest, null);
    assert.equal(root.kimiUsageLoading, false);
});

test("ZCode 配置递归检测 Kimi Key，损坏 JSON 清除旧值", () => {
    const { root } = createUsageController();
    root._parseZcodeKey(JSON.stringify({ nested: [{ apiKey: "sk-kimi-auto" }] }));
    assert.equal(root._zcodeKimiKey, "sk-kimi-auto");
    root._parseZcodeKey("not json");
    assert.equal(root._zcodeKimiKey, "");
});
