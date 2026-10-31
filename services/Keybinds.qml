pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

/**
 * Compositor-agnostic keybind source for the launcher's keybind search.
 * Exposes the same `{children: [{keybinds: [...]}]}` tree for every backend.
 */
Singleton {
    id: root

    readonly property var keybinds: {
        if (WM.compositor === "hyprland") return HyprlandKeybinds.keybinds;
        if (WM.compositor === "mango") return MangoKeybinds.keybinds;
        return { children: [] };
    }
}
