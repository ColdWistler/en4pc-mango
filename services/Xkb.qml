pragma Singleton

import QtQuick
import Quickshell
import qs.services

/**
 * Compositor-agnostic XKB layout facade for indicators and the lock screen.
 */
Singleton {
    id: root

    readonly property string currentLayoutName: {
        if (WM.compositor === "hyprland") return HyprlandXkb.currentLayoutName;
        if (WM.compositor === "niri") return NiriXkb.currentLayoutName;
        if (WM.compositor === "mango") return MangoXkb.currentLayoutName;
        return "";
    }

    readonly property string currentLayoutCode: {
        if (WM.compositor === "hyprland") return HyprlandXkb.currentLayoutCode;
        if (WM.compositor === "niri") return NiriXkb.currentLayoutCode;
        if (WM.compositor === "mango") return MangoXkb.currentLayoutCode;
        return "";
    }
}
