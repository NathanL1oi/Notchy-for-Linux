# Notchy for Linux — 复刻方案

> 目标：在 Fedora 44 + niri (Wayland) 上复刻 [Notchy for Mac](https://notchy.dev/zh-hans/) 的核心体验——屏幕顶部中央的"灵动岛"面板。
>
> 调研日期：2026-10-16

---

## 一、Notchy for Mac 是什么

Notchy 把 MacBook 刘海区域变成类似 iPhone"灵动岛"的交互中心（闭源、免费、SwiftUI 原生）。核心形态：

| 状态 | 表现 |
|---|---|
| 收起态 | 刘海/药丸本体，显示极简信息（正在播放、计时器、小图标、闲置动画） |
| Hover 态 | 鼠标悬停约 60ms 展开，显示摘要 |
| 展开态 | 点击打开完整标签页式面板，宽高可调，自动收起 |

交互手段：hover 展开、点击、快捷键（命令面板）、拖拽文件到刘海进入"暂存架"、拖窗口到刘海触发分屏、弹性展开动画。

功能共 120+ 项，按组归纳：

- **媒体**：Now Playing（封面/进度/控制）、同步歌词、音频频谱、音量 HUD、输出切换
- **专注**：番茄钟、倒计时/秒表、白噪音、日历下一日程、待办、快速笔记
- **文件/剪贴板**：剪贴板历史（搜索/置顶/智能识别）、文件暂存架 Drop Shelf、截图收纳、格式转换
- **系统**：CPU/内存/网络监控、音量/亮度 HUD、Wi-Fi 信息、天气
- **效率**：命令面板、应用启动器、Emoji 选择器、窗口分屏吸附
- **通知**：通知镜像到刘海、岛内快捷操作
- **macOS 绑定**（不可移植）：Face Unlock、HomeKit、AirDrop、Apple Shortcuts、Siri、iPhone 来电

## 二、本机环境结论（Fedora 44 + niri 26.04）

**好消息：本机已具备最理想的实现路径，无需引入新技术栈。**

| 条件 | 现状 |
|---|---|
| 合成器 | niri 26.04，完整支持 wlr-layer-shell（当前已有 3 个 layer 表面在跑） |
| **Overlay 层为空** | 刘海面板的理想位置（可覆盖在 DMS 顶栏之上展开） |
| Shell | **Quickshell 0.3.0 + DankMaterialShell (DMS) 正在运行**，QML 写 UI，原生 layer-shell |
| DMS 插件机制 | 已装 7 个插件（calculator、dankLauncherKeys 等），有现成分发通道 |
| 通知 | `org.freedesktop.Notifications` 由 quickshell 进程持有 → 通知数据与面板同进程 |
| 媒体 | playerctl 2.4.1 已装，MPRIS 实测有源；cava 已在跑（频谱可复用） |
| 音频 | PipeWire + WirePlumber + wpctl/pactl 全套正常 |
| 剪贴板 | cliphist 0.7.0 仓库可装（`sudo dnf install cliphist`） |
| 屏幕 | 台式机 + 27" 4K@120Hz（scale 1.5，逻辑 2560x1440），**无物理刘海** → 纯软件模拟（等同 Notchy 在无刘海 Mac 上的"浮动药丸"模式），顶部中央即逻辑 x≈1280 |
| Rust 工具链 | 未安装 → 不走 niri-notch-rs 的 Rust 路线 |

关键路径：
- niri 配置：`~/.config/niri/config.kdl`（已有 layer-rule 按 namespace 匹配的先例）
- DMS 源码参考：`/usr/share/quickshell/dms/Modules/`（大量面板/弹层写法可借鉴）
- DMS 插件目录：`~/.config/DankMaterialShell/plugins/`

## 三、推荐技术方案：Quickshell / DMS 插件（QML）

### 为什么是这个方案

1. **零新依赖**：Quickshell + DMS 已在运行，通知、音频、主题（matugen 配色）全部现成集成
2. **数据同进程**：通知守护进程就是 quickshell 本身，通知镜像功能几乎免费
3. **有先例**：niri-notch-rs（Rust+GTK3）已验证 niri 上做灵动岛可行；Quickshell 生态有 impasto、quickshell-dynamic-island 等参考
4. **可分发**：DMS 插件机制成熟，用户已熟练使用
5. 备选（Python + gtk4-layer-shell / Qt6）都需新装依赖且与现有 shell 割裂，不推荐

### 架构

```
niri Overlay 层 (layer-shell surface, namespace="notchy", 顶部居中)
└── Quickshell QML 插件（DMS plugin）
    ├── 收起态：药丸 ~200x32（逻辑像素），显示当前媒体/计时器/通知图标
    ├── Hover 态：悬停展开摘要卡（媒体封面+控制 / 通知预览）
    └── 展开态：标签页面板（媒体 / 通知 / 剪贴板 / 暂存架 / 番茄钟）
         ├── 媒体    → MPRIS (DMS 自带 Mpris service / playerctl)
         ├── 频谱    → cava（复用 DMS 现有管线）
         ├── 音量 HUD → wpctl / PipeWire (DMS Audio service)
         ├── 通知    → DMS Notifications service（同进程）
         ├── 剪贴板  → cliphist + wl-paste
         ├── 暂存架  → QML Drag&Drop + 本地文件列表持久化
         └── 番茄钟  → QML Timer + 通知提醒
```

niri 侧可加一条 layer-rule 做毛玻璃/动画配合：

```kdl
layer-rule {
    match namespace="^notchy$"
    // 需要时可加 place-within-backdrop / 阴影等
}
```

## 四、分期实施计划

### Phase 1 — MVP（核心形态 + 媒体岛）✅ 已完成 2026-10-16
- [x] 顶部中央 Overlay 层药丸，三态切换（收起 / hover 展开 / 点击面板）
- [x] 灵动岛式弹性展开动画（expressiveDefaultSpatial 过冲贝塞尔，420ms）
- [x] Now Playing：MPRIS 封面、标题、播放/暂停、上下曲、进度条（点击跳转）
- [x] cava 音频频谱可视化（收起态药丸内，仅播放时运行）
- [x] 无媒体播放时显示时钟/闲置状态
- [x] 附加：IPC（notchy toggle/open/peek/close）、设置页（悬停延迟/黑色药丸/面板宽度/顶部边距）

实现：DMS composite 插件，源码在 `plugin/`，已软链至 `~/.config/DankMaterialShell/plugins/notchy` 并启用。

**v0.2.0 更新（2026-10-17）**：新增顶栏组件形态（默认）——药丸嵌入 DankBar 中心，悬停/点击弹出媒体面板；原 Overlay 悬浮岛改为可选模式（`overlayMode` 设置）。已预置到顶栏中心（settings.json barConfigs.centerWidgets）。发现并绕过 DMS 1.5.3 插件弹层定位 bug（mapToItem 坐标解析错误 → 居中修正）。

### Phase 2 — 系统集成 ✅ 已完成 2026-10-17
- [x] 通知镜像：弹层"通知"标签页（活动通知列表、快捷操作按钮、单条关闭、全部清除、徽标计数）+ 药丸瞬态显示新通知摘要（4.2s）
- [x] 音量 HUD：媒体标签页音量滑块（点击图标静音）+ 药丸音量变化瞬态显示（图标+迷你进度条+百分比）
- [x] 剪贴板历史：搜索框 + 历史列表 + 点击复制 + 置顶/取消置顶 + 删除 + 清空（走 DMS ClipboardService）
- [x] 文件暂存架：拖到药丸或面板拖入区暂存（持久化到插件设置）、列表展示、点击 xdg-open 打开、拖出到其他应用（Wayland 外部拖拽）、单个移除、清空
- [x] 标签页面板：媒体/通知/剪贴板/暂存架四页 + 通知与暂存架数量徽标
- [x] IPC 扩展：`notchy toggle/open/close/openTab <tab>`（daemon 内存信号通道，组件经 PluginService.pluginDaemonInstances 绑定）

踩坑记录：notify-send 测试通知失败是 ZCode AppImage 的 LD_LIBRARY_PATH 污染了测试 shell（libnotify 符号错误），用 `env -u LD_LIBRARY_PATH -u LD_PRELOAD` 可解；DankSlider 初始化会发射 valueChanged 需守卫；DankPopout close 后 surface 有 1-2s 退出动画残留。

### Phase 3 — 效率与信息 ✅ 已完成 2026-10-17（v0.5.0）

- [x] **番茄钟 / 倒计时 Live Activity**：daemon 常驻状态机（弹层关闭不影响计时），work/break 自动轮转，完成发通知（走 DMS 通知系统 → 药丸同步闪）；药丸优先级 flash > 计时器 > 媒体 > 时钟；新增"专注"标签页（大倒计时/进度条/暂停/重置/跳过/预设 25/45/60 + 自定义滑块 + 轮数统计）
- [x] **系统监控条**：弹层底部常驻 CPU%/内存%/网络 ↓↑ 速率（DgopService，弹层可见时才 Ref 采样，3s 间隔，关闭零开销）
- [x] **日历下一日程**：CalendarService（auto 后端），媒体页显示"14:00 周会 · 还有 23 分钟"；临近 15 分钟药丸闪现提醒。**已实机打通**：用户安装 dankcal（Flatpak，本地日历账号），DMS socket 直连；测试日程"02:05 Notchy 番茄钟评审会"正确显示"还有 17 分钟"并触发临近提醒
- [x] **命令面板**：按方案不重复造轮子，`notchy launcher` IPC 转发唤起 DMS 启动器（实测通过）
- [x] 标签栏 5 页时自动切纯图标模式；设置页新增番茄钟默认时长/休息时长
- [x] IPC 全家桶：`toggle / open / close / openTab <tab> / pomo <action> / pomoMin <分钟> / launcher`

踩坑：QML 的 IpcHandler 函数不支持"类型标注 + 默认值"参数（`minutes: string = ""` 报 Type annotations are not supported），拆成两个函数解决。

### Phase 3.5 — AI 额度用量 ✅ 已完成 2026-10-20（v0.7.0）

- [x] **Kimi CodePlan 套餐额度**：5 小时/7 天窗口 used_ratio 进度条 + 本周期总量（已用/共/剩）+ 重置倒计时。接口 `https://api.kimi.com/coding/v1/usages`（Bearer `sk-kimi-...`），由用户提供的 kimi-code CLI 文档定位（其本地服务 `/api/v1/oauth/usage` 即代理此云端接口）
- [x] **Key 自动检测**：设置页手填优先；留空则 FileView 监听 `~/.zcode/v2/provider_config.json` 自动提取 `sk-kimi-` key（实测打通）
- [x] **DeepSeek API 余额**：`api.deepseek.com/user/balance`（总额/赠金/充值，用户已在设置页配置 Key，实测 ¥11.98）
- [x] 每 5 分钟自动刷新 + 切页即刷 + 手动刷新按钮；错误/未配置态友好提示

踩坑：Moonshot 官方无 CodePlan 公开 API（探测 404 了 codeplan/quota 等候选）；QML 里 `undefined` 赋值给 bool 属性会保持原值导致错误行常显（用 `!!` 强制布尔）；Row 内用 anchors 定位子项会丢失（改 spacer Item 模式）。

### 悬浮岛退役 ✅ 2026-10-20（v0.8.0）

顶栏组件形态已全面覆盖悬浮岛能力（且弹层还有更多标签页），双形态维护无意义。`NotchyIsland.qml` 移至 `archive/` 归档，daemon 瘦身（删除 Overlay 窗口管理与岛 IPC 分支），设置页移除全部岛设置项。若日后想要"纯黑刘海"形态，可基于归档代码加回。

### 明确不做（macOS 生态绑定）

Face Unlock（可用 howdy 替代但超出范围）、HomeKit、AirDrop（可用 LocalSend 替代）、Apple Shortcuts、Siri、iPhone 来电镜像（可用 KDE Connect 实现部分）。

## 五、参考项目

| 项目 | 借鉴点 |
|---|---|
| `mud-the-developer/niri-notch-rs` | **niri 专属灵动岛先例**：布局、hover/点击/滚轮交互、mako 通知拦截、弹簧动画思路（技术栈不同但交互设计可直接参考） |
| `andreumassanet/impasto` (Quickshell) | Quickshell 动态岛 QML 写法 |
| `lunanoir21/quickshell-dynamic-island` | MPRIS + cava 频谱的单色岛实现 |
| DMS 源码 `/usr/share/quickshell/dms/Modules/` | 面板/弹层/服务绑定的最佳实践，配色主题自动适配 |

## 六、风险与注意点

1. **无物理刘海**：面板需自行处理与 DMS 顶栏（Top 层）的视觉关系——放 Overlay 层可盖在 bar 之上展开，避免遮挡冲突；hover 区域要小心误触（Notchy 用 60ms 延迟，可借鉴）。
2. **Quickshell 0.3.0 仍快速迭代**：API 可能变动，插件需跟进 DMS 更新。
3. **台式机无背光/电池**：亮度 HUD 如需控制外接显示器要走 DDC/CI（ddcutil），优先级放低。
4. **不要贪多**：Notchy 有 120+ 功能是长期积累的结果，先把 Phase 1 的手感和动画打磨好（弹性动画、120Hz 流畅度是灵动岛体验的灵魂）。
