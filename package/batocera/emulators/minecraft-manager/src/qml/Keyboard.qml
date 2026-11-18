import QtQuick
import QtQuick.Window

// On-screen keyboard for searching with a controller. Arrows move, Select
// types the key, X (Backspace) deletes, Y or Enter searches, Back cancels.
// A physical keyboard types directly. open(text, function(text) {...}).
FocusScope {
    id: kb

    property string text: ""
    property int row: 1
    property int col: 0
    property var onDone: null
    property Item returnTo: null

    readonly property var rows: [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "'"],
        ["z", "x", "c", "v", "b", "n", "m", "-", ".", "&"],
        ["Space", "Delete", "Clear", "Search"]
    ]

    function open(initial, done) {
        text = initial
        onDone = done
        row = 1
        col = 0
        returnTo = kb.Window.activeFocusItem
        visible = true
        forceActiveFocus()
    }

    function finish(accepted) {
        visible = false
        if (returnTo)
            returnTo.forceActiveFocus()
        if (accepted && onDone)
            onDone(text.trim())
    }

    function press(key) {
        if (key === "Space")
            text += " "
        else if (key === "Delete")
            text = text.slice(0, -1)
        else if (key === "Clear")
            text = ""
        else if (key === "Search")
            finish(true)
        else
            text += key
    }

    function moveRow(delta) {
        const next = Math.max(0, Math.min(rows.length - 1, row + delta))
        if (next === row)
            return
        // rows have different lengths: keep the same position across
        const from = rows[row].length - 1, to = rows[next].length - 1
        col = Math.round(col * to / Math.max(1, from))
        row = next
    }

    anchors.fill: parent
    visible: false
    z: 90

    Keys.onPressed: (event) => {
        const k = event.key
        if (k === Qt.Key_Up) moveRow(-1)
        else if (k === Qt.Key_Down) moveRow(1)
        else if (k === Qt.Key_Left) col = Math.max(0, col - 1)
        else if (k === Qt.Key_Right) col = Math.min(rows[row].length - 1, col + 1)
        else if (k === Qt.Key_Select) press(rows[row][col])
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Search) finish(true)
        else if (k === Qt.Key_Backspace) text = text.slice(0, -1)
        else if (k === Qt.Key_Escape) finish(false)
        else if (event.text.length === 1 && event.text >= " ") text += event.text
        event.accepted = true  // modal
    }

    Rectangle {
        anchors.fill: parent
        color: "#b8000000"
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(70)
        width: Theme.px(1240)
        height: column.implicitHeight + Theme.px(80)
        radius: Theme.px(22)
        color: Theme.panel
        border.width: Theme.px(2)
        border.color: Theme.line

        Column {
            id: column
            x: Theme.px(40)
            y: Theme.px(40)
            width: panel.width - Theme.px(80)
            spacing: Theme.px(14)

            Rectangle {
                width: parent.width
                height: Theme.px(84)
                radius: Theme.px(14)
                color: Theme.bg
                border.width: Theme.px(3)
                border.color: Theme.accent
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.px(26)
                    width: parent.width - Theme.px(52)
                    text: kb.text + "▏"
                    color: Theme.text
                    font.pixelSize: Theme.px(34)
                    elide: Text.ElideLeft
                }
            }

            Repeater {
                model: kb.rows.length
                Row {
                    id: keyRow
                    readonly property int r: index
                    readonly property var keys: kb.rows[index]
                    spacing: Theme.px(10)
                    Repeater {
                        model: keyRow.keys
                        Rectangle {
                            readonly property bool on: kb.row === keyRow.r && kb.col === index
                            width: (column.width - keyRow.spacing * (keyRow.keys.length - 1)) / keyRow.keys.length
                            height: Theme.px(76)
                            radius: Theme.px(12)
                            color: on ? (modelData === "Search" ? Theme.accent : Theme.text) : Theme.panelHi
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: parent.on ? Theme.bg : Theme.text
                                font.pixelSize: Theme.px(modelData.length > 1 ? 28 : 34)
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    kb.row = keyRow.r
                                    kb.col = index
                                    kb.press(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
