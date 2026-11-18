pragma Singleton
import QtQuick

// Colors and sizes. Sizes are designed at 1920x1080; px() scales them.
QtObject {
    property real u: 1  // set by Main.qml from the window size

    readonly property color bg: "#14161b"
    readonly property color panel: "#1d2129"
    readonly property color panelHi: "#29303d"
    readonly property color line: "#323a48"
    readonly property color accent: "#6abf4b"
    readonly property color accentText: "#0e1a09"
    readonly property color text: "#eef1f5"
    readonly property color dim: "#9aa4b5"
    readonly property color warn: "#e9b048"
    readonly property color danger: "#e0605a"
    readonly property color info: "#62a8e5"

    function px(v) { return Math.round(v * u) }

    function count(n) {
        if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + "K"
        return String(n)
    }
}
