import QtQuick

// Subtabs under a tab (Mods, Resource Packs): underlined labels between the
// keys that switch them, L2 and R2 (PgUp and PgDn on a keyboard). The keys
// themselves are handled in Main.qml; this only shows them and takes clicks.
Row {
    id: bar

    property var labels: []
    property int current: 0
    signal picked(int index)

    spacing: Theme.px(34)
    height: Theme.px(58)

    component Key: Rectangle {
        property alias text: keyText.text
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.px(40)
        width: Math.max(height, keyText.implicitWidth + Theme.px(22))
        radius: height / 2
        color: Theme.panelHi
        Text {
            id: keyText
            anchors.centerIn: parent
            color: Theme.dim
            font.pixelSize: Theme.px(20)
            font.bold: true
        }
    }

    Key { text: gamepad.connected ? "L2" : "PgUp" }

    Repeater {
        model: bar.labels
        Item {
            readonly property bool on: index === bar.current
            width: label.implicitWidth
            height: bar.height
            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Theme.px(3)
                text: modelData
                color: parent.on ? Theme.text : Theme.dim
                font.pixelSize: Theme.px(30)
                font.bold: parent.on
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Theme.px(5)
                radius: height / 2
                color: Theme.accent
                visible: parent.on
            }
            MouseArea {
                anchors.fill: parent
                onClicked: bar.picked(index)
            }
        }
    }

    Key { text: gamepad.connected ? "R2" : "PgDn" }
}
