import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "notchy"

    StyledText {
        width: parent.width
        text: "顶栏药丸"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "将插件添加到顶栏中心：DMS 设置 → 顶栏 → 部件 → 中间区域添加 \"Notchy Island\"。悬停药丸弹出面板，点击固定；右键药丸打开快捷菜单。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceTextMedium
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    ToggleSetting {
        settingKey: "showClockIdle"
        label: "无媒体时显示时钟"
        description: "顶栏药丸在没有播放媒体时显示日期与时间；关闭则无媒体时隐藏药丸"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showSeconds"
        label: "时钟显示秒"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "pillFlash"
        label: "药丸瞬态镜像"
        description: "新通知摘要、音量变化时在顶栏药丸上短暂显示"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "reduceMotion"
        label: "减少动画"
        description: "关闭药丸内容切换和弹层的位移、缩放与淡入淡出动画；也会遵循 DMS 全局动画设置"
        defaultValue: false
    }

    StyledText {
        width: parent.width
        text: "番茄钟"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "pomoWorkMin"
        label: "默认专注时长"
        description: "番茄钟工作阶段的默认分钟数"
        defaultValue: 25
        minimum: 5
        maximum: 90
        unit: " 分钟"
        leftIcon: "timer"
    }

    SliderSetting {
        settingKey: "pomoBreakMin"
        label: "休息时长"
        description: "专注完成后的休息分钟数"
        defaultValue: 5
        minimum: 1
        maximum: 30
        unit: " 分钟"
        leftIcon: "coffee"
    }

    StyledText {
        width: parent.width
        text: "AI 额度用量"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "填入 API Key 后，用量页每 5 分钟自动查询。Key 明文保存在本机插件配置文件中。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceTextMedium
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    StringSetting {
        settingKey: "kimiApiKey"
        label: "Kimi CodePlan API Key"
        description: "sk-kimi-... 格式。留空则自动读取本机 ZCode 配置里的 Key"
        placeholder: "留空自动检测"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "deepseekApiKey"
        label: "DeepSeek API Key"
        description: "platform.deepseek.com → API keys"
        placeholder: "sk-..."
        defaultValue: ""
    }
}
