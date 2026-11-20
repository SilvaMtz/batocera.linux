import QtQuick
import QtQuick.Window

// Manage Minecraft. Every change goes through batocera-minecraft-mods
// (context property "backend"), which installs into both P1 and P2.
Window {
    id: win

    width: 1280
    height: 720
    visible: true
    visibility: fullScreen ? Window.FullScreen : Window.Windowed
    title: "Manage Minecraft"
    color: Theme.bg

    Binding {
        target: Theme
        property: "u"
        value: Math.min(win.width / 1920, win.height / 1080)
    }

    readonly property var tabs: [
        { key: "installed", label: "Installed" },
        { key: "browse", label: "Browse Modrinth" },
        { key: "updates", label: "Updates" }
    ]
    property int page: Math.max(0, ["installed", "browse", "updates"].indexOf(startPage))

    // Subtabs of Installed and Browse Modrinth (L2/R2). One choice for both
    // tabs: Resource Packs on Installed opens Browse on resource packs too.
    // key: Modrinth's project type. tip and status: how to use one in the game.
    readonly property var kinds: [
        { key: "mod", label: "Mods", one: "mod", many: "mods", tip: "", status: "" },
        { key: "resourcepack", label: "Resource Packs", one: "resource pack", many: "resource packs",
          tip: "To use a resource pack, turn it on in Minecraft: Options, Resource Packs. Each player picks their own.",
          status: "Turn them on in Minecraft: Options, Resource Packs" },
        { key: "shader", label: "Shaders", one: "shader", many: "shaders",
          tip: "To use a shader, pick it in Minecraft: Options, Video Settings, Shader Packs. Each player picks their own.",
          status: "Pick one in Minecraft: Options, Video Settings, Shader Packs" }
    ]
    function kindOf(type) { return kinds.find((k) => k.key === type) || kinds[0] }
    readonly property var kindLabels: kinds.map((k) => k.label)
    property int kind: 0
    readonly property string kindKey: kinds[kind].key

    property string gameInfo: ""
    property string gameVersion: ""
    property var installed: []        // mods and resource packs
    readonly property var installedShown: installed.filter((m) => m.type === kindKey)
    property bool installedLoaded: false
    property var installedIds: ({})
    property var updates: []
    property var updateById: ({})
    property bool updatesChecked: false
    property string updatesError: ""

    // ------------------------------------------------------------ backend
    property var pending: ({})

    function call(args, done) {
        pending[backend.run(args)] = done
    }

    Connections {
        target: backend
        function onFinished(id, result) {
            const done = win.pending[id]
            delete win.pending[id]
            if (done)
                done(result)
        }
    }

    function refreshInstalled() {
        call(["list", "--icons"], (r) => {
            if (r.error) {
                dialog.open("Couldn't read the installed mods", r.error)
                return
            }
            const ids = {}
            for (const m of r.mods)
                if (m.id)
                    ids[m.id] = m
            installedIds = ids
            installed = r.mods
            installedLoaded = true
            browse.markInstalled()
        })
    }

    function refreshUpdates() {
        call(["updates"], (r) => {
            updatesChecked = true
            updatesError = r.error || ""
            const list = r.error ? [] : r.updates
            const by = {}
            for (const u of list)
                by[u.id] = u
            updateById = by
            updates = list
        })
    }

    // Runs a change with the busy overlay, then reports and refreshes
    function change(args, what) {
        busy.show(what)
        call(args, (r) => {
            busy.hide()
            if (r.error)
                dialog.open("That didn't work", r.error)
            else
                dialog.open("Done", summary(args[0], r))
            refreshInstalled()
            refreshUpdates()
        })
    }

    function summary(command, r) {
        const lines = []
        const tips = []
        if (command === "install" || command === "update") {
            for (const m of (r.installed || r.updated || [])) {
                const tip = kindOf(m.type).tip
                if (command === "install" && tip && !tips.includes(tip))
                    tips.push(tip)
                if (m.required_by)
                    lines.push("Also installed " + m.name + " " + m.version + ", needed by " + m.required_by)
                else if (command === "install")
                    lines.push("Installed " + m.name + " " + m.version)
                else
                    lines.push("Updated " + m.name + " to " + m.version)
            }
            for (const name of (r.already_installed || []))
                lines.push(name + " was already installed")
        } else if (command === "remove") {
            for (const m of r.removed)
                lines.push("Removed " + m.name)
        }
        if (!lines.length)
            lines.push("Nothing needed changing.")
        lines.push("")
        lines.push("Player 1 and Player 2 both get this the next time Minecraft starts.")
        for (const tip of tips)
            lines.push(tip)
        return lines.join("\n")
    }

    // ------------------------------------------------------------ actions
    function openInstalled(m) {
        if (m.system) {
            dialog.open(m.name, "Comes with the system: Minecraft on this console needs it, and system updates keep it current.")
            return
        }
        if (!m.managed) {
            dialog.open(m.name, "This file was added by hand, without Modrinth details, so it can't be managed here.")
            return
        }
        const up = updateById[m.id]
        const buttons = []
        if (up)
            buttons.push({ label: "Update to " + up.new_version,
                           action: () => change(["update", m.id], "Updating " + m.name + "…") })
        buttons.push({ label: "Remove", color: Theme.danger, action: () => confirmRemove(m) })
        buttons.push({ label: "Cancel", color: Theme.dim })
        const notes = ["Version " + m.version]
        if (!m.in_sync)
            notes.push("Player 1 and Player 2 have different copies of it.")
        if (kindOf(m.type).tip)
            notes.push("", kindOf(m.type).tip)
        dialog.open(m.name, notes.join("\n"), buttons)
    }

    function confirmRemove(m) {
        dialog.open("Remove " + m.name + "?", "It will be removed for Player 1 and Player 2.", [
            { label: "Remove", color: Theme.danger, action: () => change(["remove", m.id], "Removing " + m.name + "…") },
            { label: "Cancel", color: Theme.dim }
        ])
    }

    function openHit(h) {
        if (h.installed && installedIds[h.id]) {
            openInstalled(installedIds[h.id])
            return
        }
        dialog.open(h.name, h.description + "\n\nBy " + h.author + "  ·  " + Theme.count(h.downloads) + " downloads", [
            { label: "Install", action: () => change(["install", h.slug], "Installing " + h.name + "…") },
            { label: "Cancel", color: Theme.dim }
        ])
    }

    function setPage(index) {
        page = index
        pages[index].takeFocus()
    }
    readonly property var pages: [installedPage, browse, updatesPage]

    // Mods / Resource Packs, on the tabs that have them
    function setKind(index) {
        index = (index + kinds.length) % kinds.length  // L2/R2 wrap around, like LB/RB
        if (page > 1 || index === kind)
            return
        kind = index
        browse.reset()
        installedList.currentIndex = 0
        pages[page].takeFocus()
    }

    Component.onCompleted: {
        call(["info"], (r) => {
            if (!r.error) {
                gameVersion = "Minecraft " + r.minecraft
                gameInfo = gameVersion + " with " + r.loader.charAt(0).toUpperCase() + r.loader.slice(1)
            }
        })
        refreshInstalled()
        refreshUpdates()
        setPage(page)
    }

    // ------------------------------------------------------------ screen
    Item {
        id: root
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Tab) {
                setPage((page + 1) % tabs.length)
            } else if (event.key === Qt.Key_Backtab) {
                setPage((page + tabs.length - 1) % tabs.length)
            } else if (event.key === Qt.Key_PageUp) {
                setKind(kind - 1)
            } else if (event.key === Qt.Key_PageDown) {
                setKind(kind + 1)
            } else if (event.key === Qt.Key_Search || event.text === "/") {
                setPage(1)
                browse.openKeyboard()
            } else if (event.key === Qt.Key_Escape) {
                Qt.quit()
            } else {
                return
            }
            event.accepted = true
        }

        // Header: title, game version, tabs
        Item {
            id: header
            x: Theme.px(80)
            y: Theme.px(50)
            width: parent.width - Theme.px(160)
            height: Theme.px(124)

            Text {
                id: title
                text: "Manage Minecraft"
                color: Theme.text
                font.pixelSize: Theme.px(58)
                font.bold: true
            }
            Text {
                anchors.top: title.bottom
                anchors.topMargin: Theme.px(4)
                text: (gameInfo ? gameInfo + "  ·  " : "") + "Everything is installed for Player 1 and Player 2"
                color: Theme.dim
                font.pixelSize: Theme.px(26)
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: title.verticalCenter
                spacing: Theme.px(12)
                Repeater {
                    model: win.tabs
                    Rectangle {
                        readonly property bool on: index === win.page
                        height: Theme.px(66)
                        width: tabLabel.implicitWidth + Theme.px(60)
                        radius: height / 2
                        color: on ? Theme.accent : Theme.panel
                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData.label + (modelData.key === "updates" && win.updates.length ? "  (" + win.updates.length + ")" : "")
                            color: parent.on ? Theme.accentText : Theme.text
                            font.pixelSize: Theme.px(27)
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: win.setPage(index)
                        }
                    }
                }
            }
        }

        Item {
            id: content
            anchors.top: header.bottom
            anchors.topMargin: Theme.px(36)
            anchors.bottom: footer.top
            anchors.bottomMargin: Theme.px(28)
            anchors.left: parent.left
            anchors.leftMargin: Theme.px(80)
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(80)

            // ---------------------------------------------- Installed
            FocusScope {
                id: installedPage
                anchors.fill: parent
                visible: win.page === 0

                function takeFocus() { installedList.forceActiveFocus() }

                SubTabs {
                    id: installedKinds
                    labels: win.kindLabels
                    current: win.kind
                    onPicked: (index) => win.setKind(index)
                }
                Text {
                    id: installedStatus
                    anchors.top: installedKinds.bottom
                    anchors.topMargin: Theme.px(22)
                    width: parent.width
                    elide: Text.ElideRight
                    text: {
                        const shown = win.installedShown
                        if (!win.installedLoaded)
                            return ""
                        const k = win.kinds[win.kind]
                        if (k.key === "mod") {
                            const system = shown.filter((m) => m.system).length
                            return shown.length + " mods  ·  " + system + " come with the system"
                        }
                        return shown.length + " " + (shown.length === 1 ? k.one : k.many) + "  ·  " + k.status
                    }
                    color: Theme.dim
                    font.pixelSize: Theme.px(26)
                }
                ModList {
                    id: installedList
                    anchors.top: installedStatus.bottom
                    anchors.topMargin: Theme.px(20)
                    anchors.bottom: parent.bottom
                    width: parent.width
                    model: win.installedShown
                    emptyText: !win.installedLoaded ? "Reading what's installed…"
                             : "No " + win.kinds[win.kind].many + " installed yet.\nFind some in Browse Modrinth (RB)."
                    delegate: ModRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        selected: ListView.isCurrentItem && installedList.activeFocus
                        name: modelData.name
                        iconUrl: modelData.icon_url || ""
                        subtitle: modelData.managed ? "Version " + modelData.version
                                : modelData.system ? "Opens Split Screen worlds to Player 2" : modelData.filename
                        badges: {
                            const b = []
                            const up = win.updateById[modelData.id]
                            if (up)
                                b.push({ text: "Update " + up.new_version, color: Theme.warn })
                            if (modelData.system)
                                b.push({ text: "System", color: Theme.info })
                            if (!modelData.managed && !modelData.system) {
                                const only = Object.keys(modelData.instances)
                                if (only.length === 1)
                                    b.push({ text: only[0] === "P1" ? "Player 1 only" : "Player 2 only", color: Theme.warn })
                                b.push({ text: "Added by hand", color: Theme.dim })
                            }
                            else if (modelData.managed && !modelData.in_sync)
                                b.push({ text: "Not the same in P1 and P2", color: Theme.danger })
                            return b
                        }
                        onClicked: {
                            installedList.currentIndex = index
                            installedList.forceActiveFocus()
                            win.openInstalled(modelData)
                        }
                    }
                    onActivated: (index) => win.openInstalled(win.installedShown[index])
                }
            }

            // ---------------------------------------------- Browse
            FocusScope {
                id: browse
                anchors.fill: parent
                visible: win.page === 1

                property string query: ""
                property int sortIndex: 0
                readonly property var sorts: [
                    ["downloads", "Most downloaded"], ["relevance", "Best match"],
                    ["newest", "Newest"], ["updated", "Recently updated"]
                ]
                property var hits: []
                property int total: 0
                property int pageNo: 0
                property int searchSeq: 0
                property bool loading: false
                property bool loaded: false
                property string error: ""
                property int topIndex: 0  // 0: search box, 1: sort

                function takeFocus() {
                    if (!loaded && !loading)
                        search(true)
                    if (hits.length)
                        browseList.forceActiveFocus()
                    else
                        top.forceActiveFocus()
                }

                // The subtab changed: the next visit searches the other kind
                // (same words and sort); a search under way is ignored
                function reset() {
                    searchSeq++
                    hits = []
                    total = 0
                    error = ""
                    loading = false
                    loaded = false
                }

                function search(reset) {
                    if (reset) {
                        pageNo = 0
                        searchSeq++
                    } else {
                        if (loading || hits.length >= total)
                            return
                        pageNo++
                    }
                    const seq = searchSeq
                    loading = true
                    error = ""
                    win.call(["search", query, "--type", win.kindKey, "--sort", sorts[sortIndex][0],
                              "--page", String(pageNo)], (r) => {
                        if (seq !== searchSeq)
                            return  // an older search
                        loading = false
                        loaded = true
                        if (r.error) {
                            error = r.error
                            if (reset)
                                hits = []
                            return
                        }
                        total = r.total
                        hits = reset ? r.hits : hits.concat(r.hits)
                        if (reset)
                            browseList.currentIndex = 0
                    })
                }

                function markInstalled() {
                    const keep = browseList.currentIndex
                    hits = hits.map((h) => Object.assign({}, h, { installed: win.installedIds[h.id] !== undefined }))
                    browseList.currentIndex = keep
                }

                function openKeyboard() {
                    keyboard.open(query, (text) => {
                        query = text
                        sortIndex = text ? 1 : 0  // best match for a search, popular otherwise
                        search(true)
                        top.forceActiveFocus()
                    })
                }

                function activateTop() {
                    if (topIndex === 0) {
                        openKeyboard()
                    } else {
                        sortIndex = (sortIndex + 1) % sorts.length
                        search(true)
                    }
                }

                SubTabs {
                    id: browseKinds
                    labels: win.kindLabels
                    current: win.kind
                    onPicked: (index) => win.setKind(index)
                }

                Item {
                    id: top
                    anchors.top: browseKinds.bottom
                    anchors.topMargin: Theme.px(22)
                    width: parent.width
                    height: Theme.px(84)
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Left)
                            browse.topIndex = 0
                        else if (event.key === Qt.Key_Right)
                            browse.topIndex = 1
                        else if (event.key === Qt.Key_Down) {
                            if (browse.hits.length)
                                browseList.forceActiveFocus()
                        } else if (event.key === Qt.Key_Select || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            browse.activateTop()
                        else
                            return
                        event.accepted = true
                    }

                    Rectangle {
                        readonly property bool on: top.activeFocus && browse.topIndex === 0
                        width: parent.width - sortButton.width - Theme.px(20)
                        height: parent.height
                        radius: Theme.px(14)
                        color: Theme.panel
                        border.width: on ? Theme.px(4) : Theme.px(2)
                        border.color: on ? Theme.accent : Theme.line
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.px(28)
                            width: parent.width - Theme.px(56)
                            text: browse.query || "Search Modrinth " + win.kinds[win.kind].many + "…"
                            color: browse.query ? Theme.text : Theme.dim
                            font.pixelSize: Theme.px(30)
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                browse.topIndex = 0
                                top.forceActiveFocus()
                                browse.openKeyboard()
                            }
                        }
                    }
                    Rectangle {
                        id: sortButton
                        readonly property bool on: top.activeFocus && browse.topIndex === 1
                        anchors.right: parent.right
                        width: Theme.px(440)
                        height: parent.height
                        radius: Theme.px(14)
                        color: on ? Theme.panelHi : Theme.panel
                        border.width: on ? Theme.px(4) : Theme.px(2)
                        border.color: on ? Theme.accent : Theme.line
                        Text {
                            anchors.centerIn: parent
                            text: "Sort: " + browse.sorts[browse.sortIndex][1]
                            color: Theme.text
                            font.pixelSize: Theme.px(28)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                browse.topIndex = 1
                                top.forceActiveFocus()
                                browse.activateTop()
                            }
                        }
                    }
                }

                Text {
                    id: browseStatus
                    anchors.top: top.bottom
                    anchors.topMargin: Theme.px(20)
                    width: parent.width
                    elide: Text.ElideRight
                    text: browse.error ? browse.error
                        : browse.loading && !browse.hits.length ? "Searching Modrinth…"
                        : !browse.loaded ? ""
                        : Theme.count(browse.total) + " " + win.kinds[win.kind].many
                          + (!gameVersion ? ""
                             : win.kindKey === "mod" ? " for " + gameInfo
                             : win.kindKey === "shader" ? " for " + gameVersion + " with Iris"
                             : " for " + gameVersion)
                    color: browse.error ? Theme.danger : Theme.dim
                    font.pixelSize: Theme.px(26)
                }

                ModList {
                    id: browseList
                    anchors.top: browseStatus.bottom
                    anchors.topMargin: Theme.px(20)
                    anchors.bottom: parent.bottom
                    width: parent.width
                    model: browse.hits
                    emptyText: browse.loading || browse.error ? "" : (browse.loaded ? "No " + win.kinds[win.kind].many + " found" : "")
                    delegate: ModRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        selected: ListView.isCurrentItem && browseList.activeFocus
                        name: modelData.name
                        iconUrl: modelData.icon_url || ""
                        subtitle: "by " + modelData.author + "  ·  " + Theme.count(modelData.downloads) + " downloads"
                        detail: modelData.description
                        badges: modelData.installed ? [{ text: "Installed", color: Theme.accent }] : []
                        onClicked: {
                            browseList.currentIndex = index
                            browseList.forceActiveFocus()
                            win.openHit(modelData)
                        }
                    }
                    onActivated: (index) => win.openHit(browse.hits[index])
                    onLeftTop: top.forceActiveFocus()
                    onCurrentIndexChanged: {
                        if (currentIndex >= browse.hits.length - 4)
                            browse.search(false)  // next page
                    }
                }
            }

            // ---------------------------------------------- Updates
            FocusScope {
                id: updatesPage
                anchors.fill: parent
                visible: win.page === 2

                function takeFocus() {
                    if (win.updates.length)
                        updatesList.forceActiveFocus()
                    else
                        updateAll.forceActiveFocus()
                }

                Rectangle {
                    id: updateAll
                    readonly property bool on: activeFocus
                    width: allLabel.implicitWidth + Theme.px(70)
                    height: Theme.px(80)
                    radius: Theme.px(14)
                    color: win.updates.length ? (on ? Theme.accent : Theme.panelHi) : Theme.panel
                    border.width: on ? 0 : Theme.px(2)
                    border.color: Theme.line
                    Text {
                        id: allLabel
                        anchors.centerIn: parent
                        text: win.updates.length ? "Update all (" + win.updates.length + ")" : "Check again"
                        color: parent.on && win.updates.length ? Theme.accentText : Theme.text
                        font.pixelSize: Theme.px(28)
                        font.bold: true
                    }
                    function activate() {
                        if (win.updates.length)
                            win.change(["update"], "Updating " + win.updates.length + " of them…")
                        else {
                            win.updatesChecked = false
                            win.refreshUpdates()
                        }
                    }
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            activate()
                        else if (event.key === Qt.Key_Down && win.updates.length)
                            updatesList.forceActiveFocus()
                        else
                            return
                        event.accepted = true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            updateAll.forceActiveFocus()
                            updateAll.activate()
                        }
                    }
                }

                ModList {
                    id: updatesList
                    anchors.top: updateAll.bottom
                    anchors.topMargin: Theme.px(28)
                    anchors.bottom: parent.bottom
                    width: parent.width
                    model: win.updates
                    emptyText: !win.updatesChecked ? "Checking Modrinth for updates…"
                             : win.updatesError ? win.updatesError
                             : "Everything is up to date.\nMods that come with the system are updated with the system."
                    delegate: ModRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        selected: ListView.isCurrentItem && updatesList.activeFocus
                        name: modelData.name
                        subtitle: modelData.version + "  →  " + modelData.new_version
                        badges: [{ text: "Update", color: Theme.warn }]
                        onClicked: {
                            updatesList.currentIndex = index
                            updatesList.forceActiveFocus()
                            win.openInstalled(win.installedIds[modelData.id])
                        }
                    }
                    onActivated: (index) => win.openInstalled(win.installedIds[win.updates[index].id])
                    onLeftTop: updateAll.forceActiveFocus()
                }
            }
        }

        // Footer: what the buttons do
        Row {
            id: footer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(40)
            x: Theme.px(80)
            spacing: Theme.px(46)
            Repeater {
                model: gamepad.connected
                    ? [["A", "Select"], ["B", "Back / Exit"], ["LB  RB", "Switch tabs"], ["Y", "Search"]]
                    : [["Enter", "Select"], ["Esc", "Back / Exit"], ["Tab", "Switch tabs"], ["/", "Search"]]
                Row {
                    spacing: Theme.px(12)
                    Rectangle {
                        height: Theme.px(46)
                        width: Math.max(height, keyLabel.implicitWidth + Theme.px(26))
                        radius: height / 2
                        color: Theme.panelHi
                        Text {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: modelData[0]
                            color: Theme.text
                            font.pixelSize: Theme.px(22)
                            font.bold: true
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        color: Theme.dim
                        font.pixelSize: Theme.px(26)
                    }
                }
            }
        }

        Keyboard { id: keyboard }
        Dialog { id: dialog }

        // Busy: blocks input while a change runs
        FocusScope {
            id: busy
            property string text: ""
            property Item returnTo: null
            function show(what) {
                text = what
                returnTo = win.activeFocusItem
                visible = true
                forceActiveFocus()
            }
            function hide() {
                visible = false
                if (returnTo)
                    returnTo.forceActiveFocus()
            }
            anchors.fill: parent
            visible: false
            z: 200
            Keys.onPressed: (event) => { event.accepted = true }

            Rectangle {
                anchors.fill: parent
                color: "#c8000000"
                MouseArea { anchors.fill: parent }
            }
            Column {
                anchors.centerIn: parent
                spacing: Theme.px(40)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Theme.px(90)
                    height: width
                    color: Theme.accent
                    border.width: Theme.px(10)
                    border.color: "#7a5532"
                    RotationAnimation on rotation {
                        running: busy.visible
                        from: 0
                        to: 360
                        duration: 1400
                        loops: Animation.Infinite
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: busy.text
                    color: Theme.text
                    font.pixelSize: Theme.px(34)
                    font.bold: true
                }
            }
        }
    }
}
