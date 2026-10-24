import QtQuick
import qs.Services

// cava 频谱条（6 根），running 时跟随 CavaService.values 跳动，否则收平。
Item {
    id: viz

    property bool running: false
    property color barColor: "white"

    implicitWidth: 20
    implicitHeight: 16

    Row {
        anchors.centerIn: parent
        spacing: 2.5

        Repeater {
            model: 6

            Rectangle {
                required property int index

                readonly property real level: {
                    if (!viz.running || !CavaService.cavaAvailable)
                        return 0;
                    const v = CavaService.values[index] ?? 0;
                    const clamped = v <= 0 ? 0 : (v >= 100 ? 1 : Math.sqrt(v * 0.01));
                    return Math.round(clamped * 24) / 24;
                }

                width: 3
                radius: 1.5
                height: 3 + level * (viz.height - 4)
                color: viz.barColor

                Behavior on height {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
