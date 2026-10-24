import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// 剪贴板标签页：历史列表（可搜索）+ 点击复制 + 置顶 + 删除。
Column {
    id: tab

    required property var widgetRoot
    property var parentPopout: null

    spacing: Theme.spacingS

    readonly property var entries: ClipboardService.clipboardEntries

    // 图片条目缩略图缓存（id → base64 png）
    property var imgCache: ({})
    property var _imgPending: ({})

    function imageFor(entry) {
        if (!entry || !entry.isImage)
            return "";
        const id = entry.id;
        if (id === undefined || id === null)
            return "";
        if (imgCache[id] !== undefined)
            return imgCache[id];
        if (_imgPending[id])
            return "";
        _imgPending[id] = true;
        DMSService.sendRequest("clipboard.getEntry", {
            "id": id
        }, function (resp) {
            const data = resp?.result?.data ?? "";
            const updated = Object.assign({}, imgCache);
            updated[id] = data;
            imgCache = updated;
            const p = Object.assign({}, _imgPending);
            delete p[id];
            _imgPending = p;
        });
        return "";
    }

    // 页面可见时持有服务引用，历史才会填充
    Loader {
        active: true
        sourceComponent: Ref {
            service: ClipboardService
        }
    }

    Component.onCompleted: ClipboardService.refresh()

    // ---- 头部：标题 + 清空 ----
    Row {
        width: parent.width
        height: 22

        StyledText {
            id: clipTitle
            text: "剪贴板"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - clipTitle.width - clipClear.width
            height: 1
        }

        StyledText {
            id: clipClear
            visible: tab.entries.length > 0
            text: "清空"
            font.pixelSize: Theme.fontSizeSmall
            color: clipClearHover.containsMouse ? Theme.primary : Theme.surfaceTextMedium
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                id: clipClearHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ClipboardService.clearAll()
            }
        }
    }

    // ---- 搜索框 ----
    DankTextField {
        width: parent.width
        height: 34
        placeholderText: "搜索剪贴板历史…"
        leftIconName: "search"
        showClearButton: true
        onTextChanged: ClipboardService.searchText = text
    }

    // ---- 空状态 ----
    Column {
        width: parent.width
        spacing: 6
        visible: tab.entries.length === 0

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "content_paste_off"
            size: 32
            color: Theme.withAlpha(Theme.surfaceText, 0.3)
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClipboardService.clipboardAvailable ? "暂无剪贴板历史" : "剪贴板服务不可用"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
        }
    }

    // ---- 历史列表 ----
    ListView {
        id: clipList
        width: parent.width
        height: Math.min(contentHeight, 300)
        visible: tab.entries.length > 0
        clip: true
        spacing: 4
        model: tab.entries

        delegate: Rectangle {
            id: clipRow
            required property var modelData
            required property int index

            width: clipList.width
            height: 44
            radius: 10
            color: clipHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 8

                // 图片条目显示缩略图，其余显示类型图标
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 6
                    clip: true
                    color: Theme.withAlpha(Theme.surfaceText, 0.06)

                    property string imgData: clipRow.modelData.isImage ? tab.imageFor(clipRow.modelData) : ""

                    Image {
                        anchors.fill: parent
                        visible: parent.imgData !== ""
                        source: parent.imgData !== "" ? ("data:image/png;base64," + parent.imgData) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        visible: parent.imgData === ""
                        name: clipRow.modelData.isImage ? "image" : "notes"
                        size: 18
                        color: Theme.surfaceTextMedium
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 8 - 24 * 2 - 12
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: clipRow.modelData.isImage ? "图片" : (clipRow.modelData.preview || "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        width: parent.width
                        text: (clipRow.modelData.isImage ? "图像 · " : "") + _fmtSize(clipRow.modelData.size)
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.withAlpha(Theme.surfaceTextMedium, 0.75)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // 置顶/取消置顶
                NotchyButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: clipRow.modelData.pinned ? "keep" : "keep_off"
                    size: 24
                    iconSize: 14
                    textColor: clipRow.modelData.pinned ? Theme.primary : Theme.surfaceTextMedium
                    hoverColor: Theme.withAlpha(Theme.surfaceText, 0.1)
                    onClicked: {
                        if (clipRow.modelData.pinned)
                            ClipboardService.unpinEntry(clipRow.modelData);
                        else
                            ClipboardService.pinEntry(clipRow.modelData);
                    }
                }

                // 删除
                NotchyButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    size: 24
                    iconSize: 14
                    textColor: Theme.surfaceTextMedium
                    hoverColor: Theme.withAlpha(Theme.surfaceText, 0.1)
                    onClicked: ClipboardService.deleteEntry(clipRow.modelData)
                }
            }

            MouseArea {
                id: clipHover
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    ClipboardService.copyEntry(clipRow.modelData, null);
                    tab.widgetRoot.flash("shelf", "已复制", "content_paste");
                }
            }
        }
    }

    function _fmtSize(bytes) {
        if (!bytes || bytes <= 0)
            return "";
        if (bytes < 1024)
            return bytes + " B";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KB";
        return (bytes / 1024 / 1024).toFixed(1) + " MB";
    }
}
