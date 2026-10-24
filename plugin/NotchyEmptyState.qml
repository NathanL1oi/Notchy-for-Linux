import QtQuick
import qs.Common
import qs.Widgets

// 统一的空状态与轻量加载/错误展示。
Column {
    id: root

    required property string icon
    required property string title
    property string message: ""
    property string actionText: ""
    property bool compact: false

    signal actionClicked()

    spacing: compact ? 4 : 6

    DankIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: root.icon
        size: root.compact ? 24 : 32
        color: Theme.withAlpha(Theme.surfaceText, 0.3)
    }

    StyledText {
        width: parent.width
        text: root.title
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceTextMedium
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    StyledText {
        width: parent.width
        visible: root.message !== ""
        text: root.message
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.fontSizeSmall - 1
        color: Theme.withAlpha(Theme.surfaceTextMedium, 0.75)
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.actionText !== ""
        width: actionLabel.implicitWidth + 20
        height: 28
        radius: 14
        color: actionHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.primary, 0.1)

        StyledText {
            id: actionLabel
            anchors.centerIn: parent
            text: root.actionText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primary
        }

        MouseArea {
            id: actionHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }
    }
}
