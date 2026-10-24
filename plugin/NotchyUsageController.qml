import QtQuick
import QtCore
import Quickshell.Io
import qs.Common

// Kimi CodePlan 与 DeepSeek 用量状态、请求和自动刷新。
QtObject {
    id: root

    property var pluginData: null

    property var kimiUsage: null
    property var deepseekUsage: null
    property bool kimiUsageLoading: false
    property bool deepseekUsageLoading: false
    property var _kimiRequest: null
    property var _deepseekRequest: null

    // Kimi CodePlan Key：设置页手填优先，否则自动读 ZCode 配置
    property string _zcodeKimiKey: ""
    readonly property string kimiKey: (pluginData?.kimiApiKey ?? "").trim() !== "" ? pluginData.kimiApiKey.trim() : _zcodeKimiKey
    readonly property bool kimiKeyFromZcode: (pluginData?.kimiApiKey ?? "").trim() === "" && _zcodeKimiKey !== ""
    readonly property string deepseekKey: (pluginData?.deepseekApiKey ?? "").trim()

    property var zcodeConfig: FileView {
        path: Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation)) + "/.zcode/v2/provider_config.json"
        blockWrites: true
        watchChanges: true
        onLoaded: root._parseZcodeKey(text())
        onFileChanged: root.zcodeConfig.reload()
    }

    function _parseZcodeKey(txt) {
        try {
            const d = JSON.parse(txt);
            let found = "";
            const walk = o => {
                if (found !== "" || !o || typeof o !== "object")
                    return;
                for (const k in o) {
                    if (k === "apiKey" && typeof o[k] === "string" && o[k].startsWith("sk-kimi")) {
                        found = o[k];
                        return;
                    }
                    walk(o[k]);
                }
            };
            walk(d);
            _zcodeKimiKey = found;
        } catch (e) {
            _zcodeKimiKey = "";
        }
    }

    function fetchUsage() {
        if (!kimiUsageLoading)
            _fetchKimiUsage();
        if (!deepseekUsageLoading)
            _fetchDeepseek();
    }

    function _usageHttpError(status, message) {
        let text = "HTTP " + status;
        if (status === 401 || status === 403)
            text = "认证或权限失败（HTTP " + status + "）";
        else if (status === 429)
            text = "请求过于频繁（HTTP 429）";
        else if (status >= 500)
            text = "服务暂不可用（HTTP " + status + "）";
        return text + (message ? " · " + message : "");
    }

    function _cancelKimiUsageRequest() {
        kimiRequestTimeout.stop();
        if (_kimiRequest) {
            const request = _kimiRequest;
            _kimiRequest = null;
            request.onreadystatechange = null;
            request.abort();
        }
        kimiUsageLoading = false;
    }

    function _fetchKimiUsage() {
        _cancelKimiUsageRequest();
        const key = root.kimiKey;
        if (!key) {
            kimiUsage = {
                "error": "nokey"
            };
            return;
        }

        const request = new XMLHttpRequest();
        root._kimiRequest = request;
        root.kimiUsageLoading = true;
        request.open("GET", "https://api.kimi.com/coding/v1/usages");
        request.setRequestHeader("Authorization", "Bearer " + key);
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE || root._kimiRequest !== request)
                return;
            kimiRequestTimeout.stop();
            root._kimiRequest = null;
            root.kimiUsageLoading = false;
            if (request.status === 0) {
                kimiUsage = {
                    "error": "网络连接失败"
                };
                return;
            }

            let resp;
            try {
                resp = JSON.parse(request.responseText);
            } catch (e) {
                kimiUsage = {
                    "error": "响应解析失败"
                };
                return;
            }

            const u = resp.usages ?? {};
            if (request.status === 200) {
                if (u.limit_5h || u.limit_7d || resp.usage) {
                    kimiUsage = {
                        r5h: u.limit_5h?.used_ratio ?? 0,
                        reset5h: u.limit_5h?.reset_time ?? "",
                        r7d: u.limit_7d?.used_ratio ?? 0,
                        reset7d: u.limit_7d?.reset_time ?? "",
                        used: resp.usage?.used ?? "",
                        limit: resp.usage?.limit ?? "",
                        remaining: resp.usage?.remaining ?? "",
                        resetTime: resp.usage?.resetTime ?? "",
                        when: Qt.formatTime(new Date(), "HH:mm")
                    };
                } else {
                    kimiUsage = {
                        "error": "响应格式不正确"
                    };
                }
            } else {
                kimiUsage = {
                    "error": root._usageHttpError(request.status, typeof resp.message === "string" ? resp.message : "")
                };
            }
        };
        request.send();
        kimiRequestTimeout.restart();
    }

    function _cancelDeepseekRequest() {
        deepseekRequestTimeout.stop();
        if (_deepseekRequest) {
            const request = _deepseekRequest;
            _deepseekRequest = null;
            request.onreadystatechange = null;
            request.abort();
        }
        deepseekUsageLoading = false;
    }

    function _fetchDeepseek() {
        _cancelDeepseekRequest();
        const key = root.deepseekKey;
        if (!key) {
            deepseekUsage = {
                "error": "nokey"
            };
            return;
        }

        const request = new XMLHttpRequest();
        root._deepseekRequest = request;
        root.deepseekUsageLoading = true;
        request.open("GET", "https://api.deepseek.com/user/balance");
        request.setRequestHeader("Authorization", "Bearer " + key);
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE || root._deepseekRequest !== request)
                return;
            deepseekRequestTimeout.stop();
            root._deepseekRequest = null;
            root.deepseekUsageLoading = false;
            if (request.status === 0) {
                deepseekUsage = {
                    "error": "网络连接失败"
                };
                return;
            }

            let resp;
            try {
                resp = JSON.parse(request.responseText);
            } catch (e) {
                deepseekUsage = {
                    "error": "响应解析失败"
                };
                return;
            }

            if (request.status === 200) {
                if (resp.balance_infos && resp.balance_infos.length > 0) {
                    const b = resp.balance_infos[0];
                    deepseekUsage = {
                        balance: parseFloat(b.total_balance),
                        granted: parseFloat(b.granted_balance),
                        toppedUp: parseFloat(b.topped_up_balance),
                        currency: b.currency || "CNY",
                        when: Qt.formatTime(new Date(), "HH:mm")
                    };
                } else {
                    deepseekUsage = {
                        "error": "响应格式不正确"
                    };
                }
            } else {
                deepseekUsage = {
                    "error": root._usageHttpError(request.status, typeof resp.message === "string" ? resp.message : "")
                };
            }
        };
        request.send();
        deepseekRequestTimeout.restart();
    }

    property var kimiRequestTimeout: Timer {
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root._kimiRequest)
                return;
            root._cancelKimiUsageRequest();
            root.kimiUsage = {
                "error": "请求超时"
            };
        }
    }

    property var deepseekRequestTimeout: Timer {
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root._deepseekRequest)
                return;
            root._cancelDeepseekRequest();
            root.deepseekUsage = {
                "error": "请求超时"
            };
        }
    }

    property var refreshTimer: Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: root.fetchUsage()
    }

    onKimiKeyChanged: root._fetchKimiUsage()
    onDeepseekKeyChanged: root._fetchDeepseek()
}
