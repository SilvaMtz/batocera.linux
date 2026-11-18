import QtQuick

// A list driven by arrows and Select. Up on the first row emits leftTop()
// so the page can move focus to what's above the list.
ListView {
    id: list

    property string emptyText: ""
    signal activated(int index)
    signal leftTop()

    clip: true
    spacing: Theme.px(12)
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 120
    keyNavigationEnabled: true

    Keys.onUpPressed: {
        if (currentIndex <= 0)
            leftTop()
        else
            decrementCurrentIndex()
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Select || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (currentIndex >= 0)
                activated(currentIndex)
            event.accepted = true
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0 && list.emptyText !== ""
        text: list.emptyText
        color: Theme.dim
        font.pixelSize: Theme.px(30)
        horizontalAlignment: Text.AlignHCenter
        width: parent.width * 0.8
        wrapMode: Text.WordWrap
    }
}
