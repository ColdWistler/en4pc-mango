import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Mango layout indicator: a single icon for the focused tag's layout, click to
// pick one, scroll to cycle. Icon-only keeps it the same size as the other bar
// items (the vertical bar is only 46px wide). Inactive (zero size) on other
// compositors, so adding it to the bar is harmless anywhere.
Loader {
    id: root
    active: WM.isMango
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    property bool vertical: Config.options.bar.vertical
    property color color: Appearance.colors.colOnSurfaceVariant
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4

    readonly property var layout: WM.currentLayout

    function iconFor(symbol) {
        switch (symbol) {
        case "T":  return "grid_view";
        case "S":  return "view_carousel";
        case "G":  return "grid_on";
        case "M":  return "crop_square";
        case "K":  return "layers";
        case "CT": return "center_focus_strong";
        case "RT": return "align_horizontal_right";
        case "VS":
        case "VT": return "swap_vert";
        case "VG": return "grid_4x4";
        case "VK": return "layers";
        case "DW": return "call_split";
        case "F":
        case "VF": return "balance";
        default:   return "dashboard_customize";
        }
    }

    function pretty(name) {
        const words = String(name).replace(/[_-]+/g, " ").trim();
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    sourceComponent: Item {
        implicitWidth: root.isMaterial ? 32 : 26
        implicitHeight: implicitWidth

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.iconFor(root.layout.symbol)
            iconSize: 18
            color: root.contentColorOverridden ? root.color : root.contentColor
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            // Mango only has a "cycle" dispatch, so either scroll direction
            // steps to the next layout.
            onWheel: WM.cycleLayout()
            onClicked: {
                if (popup.active && popup.item) popup.item.close();
                else popup.active = true;
            }
        }

        // No tooltip: Qt positions tooltips against the screen edge and in a
        // vertical/left bar that clips them. Click the icon for the list.

        Loader {
            id: popup
            active: false
            sourceComponent: LayoutIndicatorPopup {
                anchor {
                    window: root.QsWindow.window
                    item: root
                    gravity: Config.options.bar.vertical
                        ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                        : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                    edges: Config.options.bar.vertical
                        ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                        : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                }
                onPopupClosed: popup.active = false
            }
        }
    }
}
