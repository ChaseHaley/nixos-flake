import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 40
    exclusiveZone: 40
    color: "#11111b"

    readonly property color foreground: "#cdd6f4"
    readonly property color muted: "#6c7086"
    readonly property color accent: "#89b4fa"
    readonly property color surface: "#1e1e2e"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 12

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            Repeater {
                model: 10

                Rectangle {
                    required property int index

                    readonly property int workspaceId: index + 1
                    readonly property bool isFocused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId

                    width: isFocused ? 28 : 22
                    height: 24
                    radius: 7
                    color: isFocused ? bar.accent : workspaceMouse.containsMouse ? bar.surface : "transparent"

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.workspaceId
                        color: parent.isFocused ? "#11111b" : bar.foreground
                        font.pixelSize: 12
                        font.weight: parent.isFocused ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.workspaceId + "})")
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 700
            Layout.alignment: Qt.AlignVCenter
            text: Hyprland.activeToplevel !== null && Hyprland.activeToplevel.title.length > 0 ? Hyprland.activeToplevel.title : "Desktop"
            color: bar.muted
            font.pixelSize: 13
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.preferredWidth: timeText.implicitWidth + 20
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
            radius: 8
            color: bar.surface

            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "ddd  MMM d   h:mm AP")
                color: bar.foreground
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
    }
}
