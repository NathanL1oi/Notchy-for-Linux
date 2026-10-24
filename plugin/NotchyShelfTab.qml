import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// 暂存架标签页：拖入文件暂存，点击用默认应用打开，按住每行右侧拖手柄可拖出到其他应用，可单个移除。
Column {
    id: tab

    required property var widgetRoot
    property var parentPopout: null

    spacing: Theme.spacingS

    readonly property var files: widgetRoot.shelfFiles

    // ---- 拖出状态（拖拽期间挂起弹层 hover 自动关闭，防止窗口在拖拽会话中销毁） ----
    property bool dragging: false

    // 拖拽期间：1) 挂起弹层 hover 自动关闭，防止窗口在拖拽会话中销毁（崩溃根因）
    //           2) 移除弹层的 dismiss 背景窗，否则拖出内容窗会进入同进程背景窗，
    //              Qt 拖拽会话永远不离开本进程，无法转为外部拖拽（无法拖出的根因）
    onDraggingChanged: {
        const p = widgetRoot.popoutRef;
        if (!p)
            return;
        if (dragging) {
            if (p.cancelHoverDismiss)
                p.cancelHoverDismiss();
            p.hoverDismissSuspended = true;
            p.backgroundInteractive = false;
        } else {
            p.hoverDismissSuspended = false;
            p.backgroundInteractive = true;
        }
    }

    function fileName(urlStr) {
        let s = String(urlStr);
        if (s.startsWith("file://"))
            s = s.substring(7);
        s = decodeURIComponent(s);
        const parts = s.split("/");
        return parts[parts.length - 1] || s;
    }

    function filePath(urlStr) {
        let s = String(urlStr);
        if (s.startsWith("file://"))
            s = s.substring(7);
        return decodeURIComponent(s);
    }

    function isImageFile(urlStr) {
        return /\.(png|jpe?g|gif|webp|svg|bmp|heic)$/.test(fileName(urlStr).toLowerCase());
    }

    function fileIcon(urlStr) {
        const n = fileName(urlStr).toLowerCase();
        if (/\.(png|jpe?g|gif|webp|svg|bmp|heic)$/.test(n))
            return "image";
        if (/\.(mp3|flac|wav|ogg|m4a)$/.test(n))
            return "audio_file";
        if (/\.(mp4|mkv|webm|mov|avi)$/.test(n))
            return "video_file";
        if (/\.(zip|tar|gz|xz|7z|rar)$/.test(n))
            return "folder_zip";
        if (/\.(pdf)$/.test(n))
            return "picture_as_pdf";
        if (/\.(txt|md|json|js|ts|py|c|cpp|h|rs|qml|css|html|xml|ya?ml)$/.test(n))
            return "description";
        return "draft";
    }

    // ---- 头部 ----
    Row {
        width: parent.width
        height: 22

        StyledText {
            id: shelfTitle
            text: "暂存架"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - shelfTitle.width - shelfClear.width
            height: 1
        }

        StyledText {
            id: shelfClear
            visible: tab.files.length > 0
            text: "清空"
            font.pixelSize: Theme.fontSizeSmall
            color: shelfClearHover.containsMouse ? Theme.primary : Theme.surfaceTextMedium
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                id: shelfClearHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tab.widgetRoot.clearShelf()
            }
        }
    }

    // ---- 拖入区 / 空状态 ----
    Rectangle {
        width: parent.width
        height: tab.files.length === 0 ? 110 : 44
        radius: 12
        color: dropZone.containsDrag ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.04)
        border.color: dropZone.containsDrag ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.15)
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 4

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "upload_file"
                size: tab.files.length === 0 ? 30 : 20
                color: dropZone.containsDrag ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.4)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dropZone.containsDrag ? "松开以暂存" : (tab.files.length === 0 ? "拖拽文件到这里暂存" : "继续拖入以添加")
                font.pixelSize: Theme.fontSizeSmall
                color: dropZone.containsDrag ? Theme.primary : Theme.surfaceTextMedium
            }
        }

        DropArea {
            id: dropZone
            anchors.fill: parent
            keys: ["text/uri-list", "text/plain"]
            onDropped: drop => {
                let urls = [];
                if (drop.urls && drop.urls.length > 0) {
                    urls = drop.urls;
                } else if (drop.hasText) {
                    const lines = String(drop.text).split("\n");
                    for (const line of lines) {
                        const t = line.trim();
                        if (t.startsWith("file://"))
                            urls.push(t);
                    }
                }
                if (urls.length > 0) {
                    tab.widgetRoot.addToShelf(urls);
                    drop.accept(Qt.CopyAction);
                }
            }
        }
    }

    // ---- 文件列表 ----
    ListView {
        id: shelfList
        width: parent.width
        height: Math.min(contentHeight, 280)
        visible: tab.files.length > 0
        clip: true
        spacing: 4
        model: tab.files

        delegate: Item {
            id: fileRow
            required property var modelData
            required property int index

            width: shelfList.width
            height: 42

            // ---- 整行拖拽：按下移动超阈值=拖出到外部应用；未移动松手=打开（点击） ----
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({
                    "text/uri-list": String(fileRow.modelData),
                    "text/plain": tab.filePath(fileRow.modelData)
                })
            Drag.active: rowDrag.active

            DragHandler {
                id: rowDrag
                target: null
                onActiveChanged: tab.dragging = active
            }

            // 悬停时预抓取"文件信息区"快照作为拖拽跟随图标（需抓取可见内容）
            HoverHandler {
                id: grabHover
                onHoveredChanged: {
                    if (hovered && fileRow.Drag.imageSource === "")
                        rowContent.grabToImage(res => {
                            if (res)
                                fileRow.Drag.imageSource = res.url;
                        });
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rowDrag.active ? Theme.withAlpha(Theme.primary, 0.14) : (grabHover.hovered ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 4

                    // 抓取目标：图标 + 文件名/路径（不含按钮）
                    Item {
                        id: rowContent
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24 * 2 - 12
                        height: 40

                        // 点击打开（TapHandler 与整行 DragHandler 是官方共存组合，互不冲突）
                        TapHandler {
                            id: tapOpen
                            cursorShape: Qt.PointingHandCursor
                            onTapped: Quickshell.execDetached(["xdg-open", tab.filePath(fileRow.modelData)])
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: grabHover.hovered ? Theme.withAlpha(Theme.surfaceText, 0.09) : Theme.withAlpha(Theme.surfaceText, 0.05)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 8

                            // 图片文件显示真缩略图，其余显示类型图标
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 30
                                radius: 7
                                clip: true
                                color: Theme.withAlpha(Theme.surfaceText, 0.05)

                                Image {
                                    anchors.fill: parent
                                    visible: tab.isImageFile(fileRow.modelData)
                                    source: visible ? String(fileRow.modelData) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                DankIcon {
                                    anchors.centerIn: parent
                                    visible: !tab.isImageFile(fileRow.modelData)
                                    name: tab.fileIcon(fileRow.modelData)
                                    size: 20
                                    color: Theme.primary
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20 - 8
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: tab.fileName(fileRow.modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }

                                StyledText {
                                    width: parent.width
                                    text: tab.filePath(fileRow.modelData)
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.withAlpha(Theme.surfaceTextMedium, 0.75)
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }
                            }
                        }
                    }

                    // 复制路径
                    NotchyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "link"
                        size: 24
                        iconSize: 14
                        textColor: Theme.surfaceTextMedium
                        hoverColor: Theme.withAlpha(Theme.surfaceText, 0.1)
                        onClicked: {
                            Quickshell.execDetached(["wl-copy", tab.filePath(fileRow.modelData)]);
                            tab.widgetRoot.flash("shelf", "路径已复制", "link");
                        }
                    }

                    NotchyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        size: 24
                        iconSize: 14
                        textColor: Theme.surfaceTextMedium
                        hoverColor: Theme.withAlpha(Theme.surfaceText, 0.1)
                        onClicked: tab.widgetRoot.removeFromShelfAt(fileRow.index)
                    }
                }
            }
        }
    }
}
