import QtQuick
import qs.Widgets

// 圆角封面图：有 artwork 显示图片，否则显示音符占位图标。
Rectangle {
    id: cover

    property string artUrl: ""
    property color iconColor: Qt.rgba(1, 1, 1, 0.55)
    property color bgColor: Qt.rgba(1, 1, 1, 0.18)

    color: bgColor
    clip: true

    Image {
        id: img
        anchors.fill: parent
        source: cover.artUrl
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }

    DankIcon {
        anchors.centerIn: parent
        name: "music_note"
        size: Math.min(parent.width, parent.height) * 0.4
        color: cover.iconColor
        visible: img.status !== Image.Ready
    }
}
