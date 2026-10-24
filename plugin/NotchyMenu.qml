import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "NotchyTabs.js" as NotchyTabs

// 药丸右键菜单：标签页直达 + 番茄钟快操 + 插件设置。
// 独立 Overlay 小窗口，居中于顶栏下方；移开 600ms 或 Esc 关闭。
PanelWindow {
    id: menu

    required property var widgetRoot

    function toggle() {
        visible = !visible;
    }

    visible: false
    screen: widgetRoot?.parentScreen ?? null
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: menuRect.y + menuRect.implicitHeight + 4
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notchy-menu"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"

    mask: Region {
        item: menuRect
    }

    onVisibleChanged: {
        if (visible) {
            leaveTimer.stop();
            Qt.callLater(() => menuRect.forceActiveFocus());
        }
    }

    Timer {
        id: leaveTimer
        interval: 600
        onTriggered: menu.visible = false
    }

    Rectangle {
        id: menuRect
        anchors.horizontalCenter: parent.horizontalCenter
        y: (widgetRoot?.barThickness ?? 48) + 6
        width: 240
        implicitHeight: menuCol.implicitHeight + 14
        radius: 14
        color: Theme.surfaceContainer
        border.color: Theme.withAlpha(Theme.outline, 0.25)
        border.width: 1
        focus: true

        HoverHandler {
            id: menuHover
            onHoveredChanged: {
                if (hovered)
                    leaveTimer.stop();
                else
                    leaveTimer.restart();
            }
        }

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) {
                menu.visible = false;
                e.accepted = true;
            }
        }

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7
            spacing: 2

            // ---- 标签页直达（图标行） ----
            Row {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: NotchyTabs.tabs

                    Rectangle {
                        required property var modelData
                        width: 36
                        height: 32
                        radius: 8
                        color: tabBtnHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: parent.modelData.icon
                            size: 17
                            color: parent.modelData.index === widgetRoot.currentTab ? Theme.primary : Theme.surfaceTextMedium
                        }

                        MouseArea {
                            id: tabBtnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                widgetRoot.currentTab = parent.modelData.index;
                                menu.visible = false;
                                if (!(widgetRoot.popoutRef?.shouldBeVisible ?? false))
                                    widgetRoot.triggerPopout();
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.2)
            }

            // ---- 番茄钟快操（按状态） ----
            Repeater {
                model: {
                    const d = widgetRoot.daemon;
                    const st = d?.pomoState ?? "idle";
                    if (st === "idle")
                        return [{
                                    "icon": "play_arrow",
                                    "label": "开始专注（" + (d?.pomoWorkMin ?? 25) + " 分钟）",
                                    "act": "start"
                                }];
                    if (st === "running")
                        return [{
                                    "icon": "pause",
                                    "label": "暂停",
                                    "act": "pause"
                                }, {
                                    "icon": "restart_alt",
                                    "label": "重置",
                                    "act": "reset"
                                }];
                    return [{
                                "icon": "play_arrow",
                                "label": "继续",
                                "act": "resume"
                            }, {
                                "icon": "restart_alt",
                                "label": "重置",
                                "act": "reset"
                            }];
                }

                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 34
                    radius: 8
                    color: pomoItemHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.07) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: parent.parent.modelData.icon
                            size: 16
                            color: Theme.primary
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.label
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: pomoItemHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const d = widgetRoot.daemon;
                            if (d) {
                                const act = parent.modelData.act;
                                if (act === "start")
                                    d.pomoStart(0);
                                else if (act === "pause")
                                    d.pomoPause();
                                else if (act === "resume")
                                    d.pomoResume();
                                else if (act === "reset")
                                    d.pomoReset();
                            }
                            menu.visible = false;
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.2)
            }

            // ---- 插件设置 ----
            Rectangle {
                width: parent.width
                height: 34
                radius: 8
                color: settingsHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.07) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "settings"
                        size: 16
                        color: Theme.surfaceTextMedium
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "插件设置"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }
                }

                MouseArea {
                    id: settingsHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["qs", "-p", "/usr/share/quickshell/dms", "ipc", "call", "settings", "focusOrToggleWith", "plugins"]);
                        menu.visible = false;
                    }
                }
            }
        }
    }
}
