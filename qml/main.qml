import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1a1a2e"

    // State: "selector" = board list, "setup" = create/follow board, "board" = viewing a board
    property string viewState: board && board.boardName !== "" ? "board" : "selector"

    // ── Board Selector Screen ─────────────────────────────────────────────────
    Rectangle {
        visible: viewState === "selector"
        anchors.fill: parent
        color: "#1a1a2e"
        z: 1

        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: selectorColumn.height
            clip: true

            ColumnLayout {
                id: selectorColumn
                width: parent.width
                spacing: 16

                // Title
                Text {
                    text: "YOLO-NG"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e94560"
                    Layout.alignment: Qt.AlignHCenter
                }

                // ── My Boards section ──
                Text {
                    text: "My Boards"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#ffffff"
                    Layout.topMargin: 8
                }

                Repeater {
                    model: board ? board.myBoards() : []

                    Rectangle {
                        Layout.fillWidth: true
                        height: 56
                        color: "#0f3460"
                        radius: 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    text: modelData.channelId || ""
                                    color: "#888888"
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                            }

                            Button {
                                text: "Open"
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ffffff"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 13
                                }
                                background: Rectangle {
                                    color: "#e94560"
                                    radius: 4
                                    implicitWidth: 60
                                    implicitHeight: 32
                                }
                                onClicked: {
                                    board.switchToBoard(modelData.name)
                                    viewState = "board"
                                }
                            }

                            Button {
                                text: "\u2715"
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ff6666"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 16
                                }
                                background: Rectangle { color: "transparent"; implicitWidth: 32; implicitHeight: 32 }
                                onClicked: board.removeBoard(modelData.name)
                            }
                        }
                    }
                }

                // Empty state for my boards
                Text {
                    visible: !board || board.myBoards().length === 0
                    text: "No boards yet. Create one below."
                    color: "#666666"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }

                Button {
                    Layout.fillWidth: true
                    text: "+ Create New Board"
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 15
                    }
                    background: Rectangle {
                        color: "#e94560"
                        radius: 6
                        implicitHeight: 44
                    }
                    onClicked: {
                        setupMode = "create"
                        viewState = "setup"
                    }
                }

                // ── Following section ──
                Text {
                    text: "Following"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#ffffff"
                    Layout.topMargin: 16
                }

                Repeater {
                    model: board ? board.followingChannels() : []

                    Rectangle {
                        Layout.fillWidth: true
                        height: 56
                        color: "#16213e"
                        radius: 8
                        border.color: "#0f3460"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name || "Unknown"
                                    color: "#ffffff"
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    text: modelData.channelId || ""
                                    color: "#888888"
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                            }

                            Button {
                                text: "Open"
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ffffff"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 13
                                }
                                background: Rectangle {
                                    color: "#0f3460"
                                    radius: 4
                                    implicitWidth: 60
                                    implicitHeight: 32
                                }
                                onClicked: {
                                    board.followBoard(modelData.channelId)
                                    viewState = "board"
                                }
                            }

                            Button {
                                text: "\u2715"
                                contentItem: Text {
                                    text: parent.text
                                    color: "#ff6666"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 16
                                }
                                background: Rectangle { color: "transparent"; implicitWidth: 32; implicitHeight: 32 }
                                onClicked: board.unfollowBoard(modelData.channelId)
                            }
                        }
                    }
                }

                // Empty state for following
                Text {
                    visible: !board || board.followingChannels().length === 0
                    text: "Not following any boards yet."
                    color: "#666666"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }

                // Follow by channel ID inline
                Rectangle {
                    Layout.fillWidth: true
                    height: followCol.height + 24
                    color: "#16213e"
                    radius: 8
                    Layout.topMargin: 8

                    Column {
                        id: followCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "Follow a board by channel ID"
                            color: "#a0a0a0"
                            font.pixelSize: 13
                        }

                        TextField {
                            id: selectorChannelField
                            width: parent.width
                            placeholderText: "Channel ID (64-char hex)"
                            color: "#ffffff"
                            font.pixelSize: 14
                            background: Rectangle { color: "#0f3460"; radius: 6 }
                            leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
                            Keys.onReturnPressed: {
                                if (selectorChannelField.text.trim().length === 64) {
                                    board.followBoard(selectorChannelField.text.trim())
                                    selectorChannelField.clear()
                                    viewState = "board"
                                }
                            }
                        }

                        Button {
                            width: parent.width
                            text: "Follow"
                            enabled: selectorChannelField.text.trim().length === 64
                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                            }
                            background: Rectangle {
                                color: parent.enabled ? "#0f3460" : "#444444"
                                radius: 6
                                implicitHeight: 40
                            }
                            onClicked: {
                                board.followBoard(selectorChannelField.text.trim())
                                selectorChannelField.clear()
                                viewState = "board"
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Board Setup Screen (Create new board) ─────────────────────────────────
    property string setupMode: "create"

    Rectangle {
        visible: viewState === "setup"
        anchors.fill: parent
        color: "#1a1a2e"
        z: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20
            width: 300

            Text {
                text: "YOLO-NG"
                font.pixelSize: 32
                font.bold: true
                color: "#e94560"
                Layout.alignment: Qt.AlignHCenter
            }

            // Back button
            Button {
                text: "\u2190 Back to boards"
                contentItem: Text {
                    text: parent.text
                    color: "#a0a0a0"
                    font.pixelSize: 14
                }
                background: Rectangle { color: "transparent" }
                onClicked: viewState = "selector"
            }

            Text {
                text: "Create a new board"
                font.pixelSize: 16
                color: "#ffffff"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Enter board name and secret to connect"
                font.pixelSize: 14
                color: "#a0a0a0"
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: boardNameInput
                Layout.fillWidth: true
                placeholderText: "Board name"
                color: "#ffffff"
                font.pixelSize: 14
                background: Rectangle { color: "#0f3460"; radius: 6 }
                leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
            }

            TextField {
                id: boardSecretInput
                Layout.fillWidth: true
                placeholderText: "Secret"
                echoMode: TextInput.Password
                color: "#ffffff"
                font.pixelSize: 14
                background: Rectangle { color: "#0f3460"; radius: 6 }
                leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
                Keys.onReturnPressed: {
                    if (boardNameInput.text.trim().length > 0 && boardSecretInput.text.length > 0) {
                        board.setBoard(boardNameInput.text.trim(), boardSecretInput.text)
                        viewState = "board"
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: "Connect"
                enabled: boardNameInput.text.trim().length > 0 && boardSecretInput.text.length > 0
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "#ffffff" : "#666666"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 16
                }
                background: Rectangle {
                    color: parent.enabled ? "#e94560" : "#444444"
                    radius: 6
                }
                onClicked: {
                    board.setBoard(boardNameInput.text.trim(), boardSecretInput.text)
                    viewState = "board"
                }
            }
        }
    }

    // ── Main Board View ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: viewState === "board"

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#16213e"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Button {
                    text: "\u2190"
                    font.pixelSize: 20
                    contentItem: Text {
                        text: parent.text
                        color: "#a0a0a0"
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: "transparent" }
                    onClicked: {
                        board.disconnectBoard()
                        viewState = "selector"
                    }
                }

                Text {
                    text: board ? board.boardName : "YOLO-NG"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#e94560"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                Text {
                    visible: board && board.readOnly
                    text: "(read-only)"
                    font.pixelSize: 13
                    color: "#ff9944"
                    Layout.alignment: Qt.AlignVCenter
                }

                Button {
                    text: "\u21bb"
                    font.pixelSize: 20
                    contentItem: Text {
                        text: parent.text
                        color: "#a0a0a0"
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: "transparent" }
                    onClicked: board.refreshPosts()
                }
            }
        }

        // Error display
        Rectangle {
            Layout.fillWidth: true
            height: errorText.visible ? 40 : 0
            visible: errorText.visible
            color: "#ff4444"

            Text {
                id: errorText
                anchors.centerIn: parent
                text: board ? board.errorMessage : ""
                color: "white"
                font.pixelSize: 14
            }

            Behavior on height { NumberAnimation { duration: 200 } }
        }

        // Posts list
        ListView {
            id: postsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            model: board ? board.posts : []
            clip: true

            spacing: 8

            ScrollBar.vertical: ScrollBar {
                width: 8
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: postsList.width
                height: postColumn.height + 16
                color: "#0f3460"
                radius: 8

                Column {
                    id: postColumn
                    anchors.centerIn: parent
                    width: parent.width - 20
                    spacing: 4

                    Text {
                        width: parent.width
                        text: modelData.content
                        color: "#eaeaea"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: new Date(modelData.timestamp).toLocaleString()
                        color: "#888888"
                        font.pixelSize: 11
                    }
                }
            }

            // Empty state
            Rectangle {
                anchors.centerIn: parent
                visible: parent.count === 0
                width: 200
                height: 100
                color: "#16213e"
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: board && board.readOnly
                        ? "No posts fetched yet.\nTap \u21bb to refresh."
                        : "No posts yet.\nBe the first to write!"
                    color: "#666666"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Input area (hidden for read-only boards)
        Rectangle {
            Layout.fillWidth: true
            height: board && board.readOnly ? 0 : 100
            visible: !board || !board.readOnly
            color: "#16213e"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                TextArea {
                    id: postInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "Write something..."
                    color: "#ffffff"
                    background: Rectangle { color: "transparent" }
                    font.pixelSize: 14
                    wrapMode: TextEdit.Wrap
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return && (event.modifiers & Qt.ControlModifier)) {
                            submitButton.clicked()
                        }
                    }
                }

                Button {
                    id: submitButton
                    Layout.fillHeight: true
                    width: 100
                    text: "Post"
                    enabled: postInput.text.trim().length > 0

                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "#ffffff" : "#666666"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: parent.enabled ? "#e94560" : "#444444"
                        radius: 6
                    }

                    onClicked: {
                        if (board && postInput.text.trim().length > 0) {
                            var result = board.createPost("anonymous", postInput.text)
                            if (result !== "") {
                                postInput.clear()
                            }
                        }
                    }
                }
            }
        }
    }

    // CID display (debug)
    Rectangle {
        visible: viewState === "board" && board && board.lastCid !== undefined && board.lastCid !== ""
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        color: "#0a0a0a"
        z: 2

        Text {
            anchors.centerIn: parent
            text: "CID: " + (board ? board.lastCid : "")
            color: "#00ff00"
            font.pixelSize: 10
            font.family: "monospace"
        }
    }
}
