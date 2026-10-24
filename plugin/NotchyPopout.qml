import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "NotchyTabs.js" as NotchyTabs

// 标签页弹层及页面容器；功能页仍通过 widgetRoot 读取共享状态。
Column {
    id: panel

    required property var widgetRoot
    property var parentPopout: null
    property var closePopout: null
    property var tabTooltip: DankTooltipV2 {}
    readonly property bool popoutVisible: parentPopout?.shouldBeVisible ?? false

    spacing: Theme.spacingM
    opacity: popoutVisible ? 1 : 0
    scale: popoutVisible ? 1 : 0.97
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation {
            duration: panel.widgetRoot.animationsEnabled ? 180 : 0
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: panel.widgetRoot.animationsEnabled ? 180 : 0
            easing.type: Easing.OutCubic
        }
    }

    transform: Translate {
        y: panel.popoutVisible ? 0 : -6
        Behavior on y {
            NumberAnimation {
                duration: panel.widgetRoot.animationsEnabled ? 180 : 0
                easing.type: Easing.OutCubic
            }
        }
    }

    onParentPopoutChanged: {
        if (parentPopout) {
            widgetRoot.popoutRef = parentPopout;
            Qt.callLater(widgetRoot.fixPopoutPosition);
        }
    }
    onPopoutVisibleChanged: {
        if (popoutVisible)
            Qt.callLater(widgetRoot.fixPopoutPosition);
        else
            tabTooltip.hide();
    }

    // ---- 标签栏 ----
    Row {
        id: tabBar
        spacing: 4

        // 超过 4 个标签页时自动纯图标模式（省宽度）
        readonly property bool iconOnly: tabRepeater.count > 4

        Repeater {
            id: tabRepeater
            model: NotchyTabs.tabs

            Rectangle {
                id: tabDelegate
                required property int index
                required property var modelData

                readonly property bool active: panel.widgetRoot.currentTab === index
                readonly property int badge: modelData.id === "notifications" ? NotificationService.notifications.length : (modelData.id === "shelf" ? panel.widgetRoot.shelfFiles.length : 0)

                width: tabContent.implicitWidth + (tabBar.iconOnly ? 16 : 20)
                height: 30
                radius: 15
                color: active ? Theme.withAlpha(Theme.primary, 0.18) : (tabHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                Row {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: 5

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: tabDelegate.modelData.icon
                        size: 15
                        color: tabDelegate.active ? Theme.primary : Theme.surfaceTextMedium
                    }

                    StyledText {
                        visible: !tabBar.iconOnly
                        anchors.verticalCenter: parent.verticalCenter
                        text: tabDelegate.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: tabDelegate.active ? Font.DemiBold : Font.Normal
                        color: tabDelegate.active ? Theme.primary : Theme.surfaceTextMedium
                    }

                    // 数量徽标
                    Rectangle {
                        visible: tabDelegate.badge > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: badgeText.implicitWidth + 8
                        height: 15
                        radius: 7.5
                        color: tabDelegate.active ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.15)

                        StyledText {
                            id: badgeText
                            anchors.centerIn: parent
                            text: tabDelegate.badge > 99 ? "99+" : tabDelegate.badge
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: tabDelegate.active ? Theme.background : Theme.surfaceTextMedium
                        }
                    }
                }

                Timer {
                    id: tabTooltipTimer
                    interval: 400
                    repeat: false
                    onTriggered: panel.tabTooltip.show(tabDelegate.modelData.label, tabDelegate, 0, 0, "bottom")
                }

                MouseArea {
                    id: tabHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: tabTooltipTimer.restart()
                    onExited: {
                        tabTooltipTimer.stop();
                        panel.tabTooltip.hide();
                    }
                    onClicked: {
                        tabTooltipTimer.stop();
                        panel.tabTooltip.hide();
                        panel.widgetRoot.currentTab = tabDelegate.index;
                    }
                }
            }
        }
    }

    // ---- 标签页内容 ----
    Loader {
        id: tabLoader
        width: parent.width
        sourceComponent: {
            const pages = {
                "media": mediaTabComp,
                "notifications": notifTabComp,
                "clipboard": clipTabComp,
                "shelf": shelfTabComp,
                "focus": focusTabComp,
                "usage": usageTabComp
            };
            return pages[NotchyTabs.tabs[panel.widgetRoot.currentTab]?.id] || mediaTabComp;
        }
    }

    NotchyMonitorBar {
        width: parent.width
        popoutVisible: panel.popoutVisible
    }

    Component {
        id: mediaTabComp
        NotchyMediaTab {
            widgetRoot: panel.widgetRoot
        }
    }

    Component {
        id: notifTabComp
        NotchyNotifTab {
            widgetRoot: panel.widgetRoot
        }
    }

    Component {
        id: clipTabComp
        NotchyClipboardTab {
            widgetRoot: panel.widgetRoot
        }
    }

    Component {
        id: shelfTabComp
        NotchyShelfTab {
            widgetRoot: panel.widgetRoot
        }
    }

    Component {
        id: focusTabComp
        NotchyFocusTab {
            widgetRoot: panel.widgetRoot
        }
    }

    Component {
        id: usageTabComp
        NotchyUsageTab {
            widgetRoot: panel.widgetRoot
        }
    }
}
