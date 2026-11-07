pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PopupWindow {
    id: root

    signal popupClosed()

    readonly property real cardWidth: 236
    readonly property real rowHeight: 38
    readonly property real maxListHeight: 380
    readonly property string currentSymbol: WM.currentLayout.symbol

    property bool closing: false

    color: "transparent"
    implicitWidth: cardWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: card.implicitHeight + Appearance.sizes.elevationMargin * 2

    function open() {
        root.visible = true;
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        if (root.closing) return;
        root.closing = true;
        openAnim.stop();
        closeAnim.restart();
    }

    function pretty(name) {
        const words = String(name).replace(/[_-]+/g, " ").trim();
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    function pick(layout) {
        if (!layout) return;
        WM.setLayout(layout.name);
        root.close();
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
        root.open();
    }
    Component.onDestruction: GlobalFocusGrab.removeDismissable(root)

    Connections {
        target: GlobalFocusGrab
        function onDismissed() { root.close() }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: cardScale
            property: Config.options.bar.vertical ? "xScale" : "yScale"
            to: 1
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 1
            duration: Appearance.animationCurves.expressiveEffectsDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveEffects
        }
    }

    ParallelAnimation {
        id: closeAnim
        onFinished: {
            root.visible = false;
            root.popupClosed();
        }
        NumberAnimation {
            target: cardScale
            property: Config.options.bar.vertical ? "xScale" : "yScale"
            to: 0.4
            duration: 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()

        StyledRectangularShadow {
            target: card
            opacity: card.opacity
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            implicitWidth: cardWidth
            implicitHeight: contentColumn.implicitHeight + 24
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.large
            opacity: 0

            transform: Scale {
                id: cardScale
                origin.x: card.width / 2
                origin.y: card.height / 2
            }

            ColumnLayout {
                id: contentColumn
                anchors.centerIn: parent
                width: cardWidth - 24
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Layout")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    // Sizes to content up to maxListHeight, so the card does not
                    // depend on the list's layout height (no binding loop).
                    implicitHeight: Math.min(contentHeight, root.maxListHeight)
                    clip: true
                    spacing: 4
                    model: WM.layouts

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool isCurrent: modelData.symbol === root.currentSymbol
                        readonly property bool hovered: rowMouse.containsMouse

                        width: list.width
                        height: root.rowHeight
                        radius: Appearance.rounding.small
                        color: row.isCurrent
                            ? Appearance.colors.colSecondaryContainer
                            : (row.hovered ? Appearance.colors.colLayer1Hover : "transparent")

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // Short layout symbol badge ("T", "DW", "VS");
                            // replaced by a check when it is the current one.
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                visible: row.isCurrent
                                text: "check_circle"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                visible: !row.isCurrent
                                Layout.preferredWidth: 26
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.symbol
                                font.family: "monospace"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: root.pretty(modelData.name)
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: row.isCurrent ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(modelData)
                        }
                    }
                }
            }
        }
    }
}
