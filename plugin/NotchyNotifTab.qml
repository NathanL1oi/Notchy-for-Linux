import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// 通知标签页：活动通知列表（最新在上），支持关闭与快捷操作。
Column {
    id: tab

    required property var widgetRoot
    property var parentPopout: null

    spacing: Theme.spacingS

    // 最新在列表尾部，显示时倒序
    readonly property var notifs: NotificationService.notifications

    function dismissAll() {
        const list = notifs.slice();
        for (let i = 0; i < list.length; i++)
            NotificationService.dismissNotification(list[i]);
    }

    // ---- 头部 ----
    Row {
        width: parent.width
        height: 22

        StyledText {
            id: headerTitle
            text: "通知"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - headerTitle.width - clearBtn.width
            height: 1
        }

        StyledText {
            id: clearBtn
            visible: tab.notifs.length > 0
            text: "全部清除"
            font.pixelSize: Theme.fontSizeSmall
            color: clearHover.containsMouse ? Theme.primary : Theme.surfaceTextMedium
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                id: clearHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tab.dismissAll()
            }
        }
    }

    // ---- 空状态 ----
    NotchyEmptyState {
        width: parent.width
        visible: tab.notifs.length === 0
        icon: "notifications_off"
        title: "没有活动通知"
        message: "新通知会在这里显示"
    }

    // ---- 通知列表 ----
    ListView {
        id: notifList
        width: parent.width
        height: Math.min(contentHeight, 300)
        visible: tab.notifs.length > 0
        clip: true
        spacing: 6
        model: tab.notifs.length

        delegate: Rectangle {
            id: notifRow
            required property int index
            readonly property var wrapper: tab.notifs[tab.notifs.length - 1 - index]

            width: notifList.width
            height: notifCol.implicitHeight + 14
            radius: 10
            color: rowHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.05) : "transparent"

            Column {
                id: notifCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 7
                anchors.topMargin: 7
                spacing: 4

                Row {
                    width: parent.width
                    spacing: 8

                    // 应用图标
                    Item {
                        width: 26
                        height: 26

                        IconImage {
                            anchors.fill: parent
                            source: notifRow.wrapper?.appIcon ? Quickshell.iconPath(notifRow.wrapper.appIcon, true) : ""
                            visible: source != ""
                        }

                        DankIcon {
                            anchors.fill: parent
                            name: "notifications"
                            size: 20
                            color: Theme.surfaceTextMedium
                            visible: !notifRow.wrapper?.appIcon
                        }
                    }

                    Column {
                        width: parent.width - 26 - 8 - 24 - 8
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: 6

                            StyledText {
                                text: notifRow.wrapper?.appName ?? ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: Math.min(implicitWidth, parent.width - timeText.implicitWidth - 12)
                            }

                            StyledText {
                                id: timeText
                                text: notifRow.wrapper?.timeStr ?? ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceTextMedium, 0.7)
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: notifRow.wrapper?.summary ?? ""
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: text.length > 0
                        }

                        StyledText {
                            width: parent.width
                            text: notifRow.wrapper?.body ?? ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            visible: text.length > 0
                        }
                    }

                    // 关闭按钮
                    NotchyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        size: 24
                        iconSize: 14
                        textColor: Theme.surfaceTextMedium
                        hoverColor: Theme.withAlpha(Theme.surfaceText, 0.1)
                        onClicked: NotificationService.dismissNotification(notifRow.wrapper)
                    }
                }

                // 快捷操作按钮
                Row {
                    spacing: 6
                    visible: actionRepeater.count > 0

                    Repeater {
                        id: actionRepeater
                        model: notifRow.wrapper?.actions ?? []

                        Rectangle {
                            required property var modelData
                            width: actionText.implicitWidth + 16
                            height: 24
                            radius: 12
                            color: actionHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.primary, 0.1)

                            StyledText {
                                id: actionText
                                anchors.centerIn: parent
                                text: modelData.text || "打开"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                            }

                            MouseArea {
                                id: actionHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    modelData.invoke();
                                    NotificationService.dismissNotification(notifRow.wrapper);
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                propagateComposedEvents: true
                onClicked: mouse => mouse.accepted = false
            }
        }
    }
}
