import QtQuick
import qs.Widgets

// 圆形控制按钮：默认透明 + hover 底色；filled 时为实心主题色圆钮。
Rectangle {
    id: btn

    property string icon: ""
    property int size: 36
    property int iconSize: 18
    property bool filled: false
    property color bgColor: "transparent"
    property color textColor: "white"
    property color hoverColor: Qt.rgba(1, 1, 1, 0.12)

    signal clicked

    width: size
    height: size
    radius: size / 2
    color: filled ? bgColor : (hoverArea.containsMouse ? hoverColor : "transparent")
    opacity: enabled ? 1 : 0.35

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: btn.icon
        size: btn.iconSize
        color: btn.textColor
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: btn.clicked()
    }
}
