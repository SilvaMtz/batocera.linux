import QtQuick
import QtQuick.Window

// A modal message with buttons: Left/Right picks, Select presses, Back
// cancels. open(title, message, [{label, color, action}]); no buttons = OK.
FocusScope {
    id: dlg

    property string title: ""
    property string message: ""
    property var buttons: []
    property int current: 0
    property Item returnTo: null

    function open(title, message, buttons) {
        dlg.title = title
        dlg.message = message
        dlg.buttons = buttons && buttons.length ? buttons : [{ label: "OK" }]
        current = 0
        if (!visible)
            returnTo = dlg.Window.activeFocusItem
        visible = true
        forceActiveFocus()
    }

    function close(index) {
        visible = false
        if (returnTo)
            returnTo.forceActiveFocus()
        const button = index >= 0 ? buttons[index] : null
        if (button && button.action)
            button.action()
    }

    anchors.fill: parent
    visible: false
    z: 100

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left)
            current = Math.max(0, current - 1)
        else if (event.key === Qt.Key_Right)
            current = Math.min(buttons.length - 1, current + 1)
        else if (event.key === Qt.Key_Select || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            close(current)
        else if (event.key === Qt.Key_Escape)
            close(-1)
        event.accepted = true  // modal
    }

    Rectangle {
        anchors.fill: parent
        color: "#b8000000"
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Theme.px(1080)
        height: content.implicitHeight + Theme.px(96)
        radius: Theme.px(22)
        color: Theme.panel
        border.width: Theme.px(2)
        border.color: Theme.line

        Column {
            id: content
            x: Theme.px(52)
            y: Theme.px(48)
            width: box.width - Theme.px(104)
            spacing: Theme.px(30)

            Text {
                width: parent.width
                text: dlg.title
                color: Theme.text
                font.pixelSize: Theme.px(42)
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: dlg.message
                color: Theme.dim
                font.pixelSize: Theme.px(28)
                lineHeight: 1.15
                wrapMode: Text.WordWrap
            }
            Row {
                spacing: Theme.px(18)
                Repeater {
                    model: dlg.buttons
                    Rectangle {
                        readonly property bool on: index === dlg.current
                        height: Theme.px(76)
                        width: Math.max(Theme.px(200), label.implicitWidth + Theme.px(64))
                        radius: Theme.px(14)
                        color: on ? (modelData.color || Theme.accent) : Theme.panelHi
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.on ? Theme.accentText : Theme.text
                            font.pixelSize: Theme.px(28)
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: dlg.close(index)
                        }
                    }
                }
            }
        }
    }
}
