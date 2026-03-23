import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1a1a2e"

    property var board: null

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#16213e"

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "YOLO-NG"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#e94560"
                }

                Text {
                    text: "Text Board"
                    font.pixelSize: 16
                    color: "#a0a0a0"
                    anchors.verticalCenter: parent.verticalCenter
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
                    text: "No posts yet.\nBe the first to write!"
                    color: "#666666"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Input area
        Rectangle {
            Layout.fillWidth: true
            height: 100
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
                            var result = board.submitPost(postInput.text)
                            if (result) {
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
        visible: board && board.lastCid !== ""
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        color: "#0a0a0a"

        Text {
            anchors.centerIn: parent
            text: "CID: " + (board ? board.lastCid : "")
            color: "#00ff00"
            font.pixelSize: 10
            font.family: "monospace"
        }
    }
}
