# Notchy Island — DMS 插件

Mac 灵动岛风格面板：顶栏中心药丸 + 六标签页弹层（媒体 / 通知 / 剪贴板 / 暂存架 / 专注 / 用量）。

- **药丸**：播放媒体时显示 cava 频谱 + 曲名；无媒体时显示时钟；新通知摘要、音量变化会短暂闪现（瞬态镜像）；内容切换带淡入淡出与轻微位移动画
- **弹层**：悬停药丸弹出（transient，移开自动关闭）；点击固定（Esc / 点击外部关闭）。六个标签页（标签栏自动使用纯图标，悬停显示名称），带轻量展开动画：
  - **媒体**：封面、曲名/艺术家、可点击进度条、播放控制、系统音量滑块、下一日程（有日历源时）
  - **通知**：活动通知列表（最新在上）、快捷操作按钮、单条关闭、全部清除、徽标计数
  - **剪贴板**：可搜索历史、图片条目真缩略图、点击复制、置顶/删除、清空
  - **暂存架**：拖文件到药丸或面板暂存（重启不丢）、图片文件缩略图、整行拖出到其他应用、单击打开、复制路径、单个移除/清空
  - **专注**：番茄钟——大倒计时、工作/休息自动轮转、暂停/重置/跳过、预设 25/45/60 + 自定义滑块、轮数统计、自然完成通知（手动跳过不通知且不计完成轮数）
  - **用量**：Kimi CodePlan 套餐额度（5 小时/7 天窗口进度条 + 本周期总量 + 重置倒计时，Key 自动读取 ZCode 配置或设置页手填）+ DeepSeek API 余额（设置页填 Key）
- **弹层底部监控条**：CPU% / 内存% / 网络 ↓↑ 速率（仅弹层可见时采样）；**点击展开**各核 CPU 迷你条、内存明细、Top 3 进程
- **药丸**（优先级从高到低）：瞬态镜像（新通知/音量变化）→ 番茄钟倒计时（⏱ 工作 / ☕ 休息）→ cava 频谱+曲名 → 时钟（日期+星期+时间）
- **药丸右键菜单**：标签页直达图标行 + 番茄钟快操（开始/暂停/继续/重置，随状态变化）+ 插件设置；也可用 `notchy menu` IPC 触发

## 安装

```bash
ln -sfn "$(pwd)" ~/.config/DankMaterialShell/plugins/notchy
qs -p /usr/share/quickshell/dms ipc call plugins enable notchy
```

顶栏添加：DMS 设置 → 顶栏 → 组件 → 中心区域添加 "Notchy Island"
（或编辑 `settings.json` 的 `barConfigs[].centerWidgets`，插入 `{"id": "notchy", "enabled": true}`）。

## 交互

| 操作 | 效果 |
|---|---|
| 悬停顶栏药丸 | 弹出面板（需顶栏开启 hoverPopouts，移开自动收起） |
| 点击药丸 | 固定/关闭面板 |
| 拖文件到药丸 | 暂存文件，药丸闪现"已暂存 N 个文件" |
| Esc / 点击面板外 | 关闭固定面板 |

### IPC（可绑 niri 快捷键）

```bash
qs -p /usr/share/quickshell/dms ipc call notchy toggle              # 切换弹层
qs -p /usr/share/quickshell/dms ipc call notchy openTab focus       # 打开并切到指定标签页
qs -p /usr/share/quickshell/dms ipc call notchy close               # 关闭
qs -p /usr/share/quickshell/dms ipc call notchy pomo start          # 开始番茄钟（默认时长）
qs -p /usr/share/quickshell/dms ipc call notchy pomoMin 45          # 45 分钟自定义番茄钟
qs -p /usr/share/quickshell/dms ipc call notchy pomo pause          # 暂停（resume 继续 / reset 重置）
qs -p /usr/share/quickshell/dms ipc call notchy pomo skip           # 跳过当前阶段（不通知、不计完成轮数）
qs -p /usr/share/quickshell/dms ipc call notchy launcher            # 唤起 DMS 启动器
qs -p /usr/share/quickshell/dms ipc call notchy menu                # 右键快捷菜单
```

标签页参数：`media` / `notifications` / `clipboard` / `shelf` / `focus` / `usage`。

niri 绑定示例：

```kdl
binds {
    Mod+N { spawn "qs" "-p" "/usr/share/quickshell/dms" "ipc" "call" "notchy" "toggle"; }
    Mod+P { spawn "qs" "-p" "/usr/share/quickshell/dms" "ipc" "call" "notchy" "pomo" "start"; }
}
```

## 设置项

| 键 | 默认 | 说明 |
|---|---|---|
| showClockIdle | true | 顶栏药丸无媒体时显示日期与时间 |
| showSeconds | false | 时钟显示秒 |
| pillFlash | true | 药丸瞬态镜像（新通知/音量变化） |
| reduceMotion | false | 减少药丸与弹层动画；同时遵循 DMS 全局动画设置 |
| pomoWorkMin | 25 | 番茄钟默认专注时长（5–90 分钟） |
| pomoBreakMin | 5 | 番茄钟休息时长（1–30 分钟） |
| kimiApiKey | 空 | Kimi CodePlan Key；留空自动读 ZCode 配置 |
| deepseekApiKey | 空 | DeepSeek API Key |

> 悬浮岛模式（overlayMode）已于 v0.8.0 退役——顶栏组件已全面覆盖其能力。历史代码归档在 `../archive/NotchyIsland.qml`。

## 测试

从项目根目录运行：

```bash
bash tests/run-tests.sh
```

自动测试覆盖番茄钟、用量请求、暂存架、标签页、日历和 QML 结构。运行方式与人工回归清单见 `../tests/README.md`。

## 已知问题 / 实现注意

- **拖出功能（已解决，两个根因）**：① Qt Quick 外部拖拽在弹层 hover 关闭时会销毁拖拽源 item 导致 SIGSEGV → 拖拽期间挂起 `hoverDismissSuspended`；② DankPopout 的全屏 dismiss 背景窗与内容窗同属一个 Qt 进程，拖出内容窗先进入背景窗，拖拽会话永不离开本进程 → 拖拽期间临时 `backgroundInteractive = false` 撤除背景窗。拖拽图标用 `grabToImage` 在行悬停时预抓取文件卡片快照。
- **DMS 弹层定位偏差**：DMS 1.5.3 对插件组件内部 `mapToItem(null)` 的解析有误，插件弹层默认落在屏幕左上角。本插件对 center 区域弹层做居中修正（每次打开强制锚定到顶栏中心，正是灵动岛想要的位置）。上游修复后此修正无害。
- **插件数据写入必须走 `pluginService.savePluginData()`**：直接调 `SettingsData.setPluginSetting()` 只写文件不发 `pluginDataChanged` 信号，本组件不刷新（暂存架拖入不显示就是这个原因）。
- 修改 QML 后需 `dms restart` 生效（插件热重载命中 QML 引擎缓存）。
- 弹层关闭后其 layer surface 有 1–2s 退出动画残留，属正常现象。
- 顶栏药丸与内置 `music` 组件功能重复，建议在顶栏设置中移除 `music`。
- 测试时注意：在 ZCode 内嵌 shell 里运行 `notify-send` 会命中 AppImage 的 LD_LIBRARY_PATH 污染，需 `env -u LD_LIBRARY_PATH -u LD_PRELOAD /usr/bin/notify-send ...`。
