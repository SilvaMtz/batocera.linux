import QtQuick

// One mod in a list: icon (or its first letter), name, a line or two of
// detail, and badges on the right.
Rectangle {
    id: row

    property string name: ""
    property string subtitle: ""
    property string detail: ""
    property string iconUrl: ""
    property var badges: []  // [{text, color}]
    property bool selected: false
    signal clicked()

    height: Theme.px(detail ? 132 : 104)
    radius: Theme.px(14)
    color: selected ? Theme.panelHi : Theme.panel
    border.width: selected ? Theme.px(4) : 0
    border.color: Theme.accent

    Rectangle {
        id: iconBox
        x: Theme.px(20)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(row.detail ? 92 : 68)
        height: width
        radius: Theme.px(10)
        color: Theme.line

        Text {
            anchors.centerIn: parent
            visible: icon.status !== Image.Ready
            text: row.name.charAt(0).toUpperCase()
            color: Theme.dim
            font.pixelSize: parent.height * 0.5
            font.bold: true
        }
        Image {
            id: icon
            anchors.fill: parent
            source: row.iconUrl
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 128
            sourceSize.height: 128
            visible: status === Image.Ready
        }
    }

    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: Theme.px(24)
        anchors.right: badgeRow.left
        anchors.rightMargin: Theme.px(20)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        Text {
            width: parent.width
            text: row.name
            color: Theme.text
            font.pixelSize: Theme.px(32)
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            color: Theme.dim
            font.pixelSize: Theme.px(24)
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.detail
            color: Theme.dim
            font.pixelSize: Theme.px(24)
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    Row {
        id: badgeRow
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(24)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(10)

        Repeater {
            model: row.badges
            Rectangle {
                height: Theme.px(42)
                width: label.implicitWidth + Theme.px(30)
                radius: height / 2
                color: "transparent"
                border.width: Theme.px(2)
                border.color: modelData.color
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.text
                    color: modelData.color
                    font.pixelSize: Theme.px(22)
                    font.bold: true
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: row.clicked()
    }
}
