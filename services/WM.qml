pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string compositor: detectCompositor()
    readonly property bool isHyprland: compositor === "hyprland"
    readonly property bool isMango: compositor === "mango"
    readonly property bool isNiri: compositor === "niri"
    property QtObject backend: null

    function switchWorkspaceRelative(direction) { backend?.switchWorkspaceRelative(direction) }

    function detectCompositor() {
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase();
        const session = (Quickshell.env("XDG_SESSION_DESKTOP") ?? "").toLowerCase();
        const combined = desktop + " " + session;

        if (combined.includes("hyprland")) return "hyprland";
        if (combined.includes("niri")) return "niri";
        if (combined.includes("sway")) return "sway";
        if (combined.includes("mango")) return "mango";
        return "unknown";
    }

    Component { id: hyprlandComp; HyprlandBackend {} }
    Component { id: niriComp; NiriBackend {} }
    // Component { id: swayComp; SwayBackend {} }
    Component { id: mangoComp; MangoBackend {} }

    Component.onCompleted: {
        switch (root.compositor) {
        case "hyprland": backend = hyprlandComp.createObject(root); break;
        case "niri":     backend = niriComp.createObject(root); break;
        // case "sway":  backend = swayComp.createObject(root); break;
        case "mango": backend = mangoComp.createObject(root); break;
        default:
            console.log("[WM] Unknown compositor: " + root.compositor + ", falling back to Hyprland backend");
            backend = hyprlandComp.createObject(root);
        }
    }

    // Proxies
    readonly property var windowList: backend?.windowList ?? []
    readonly property var windowByAddress: backend?.windowByAddress ?? ({})
    readonly property var addresses: backend?.addresses ?? []
    readonly property var workspaces: backend?.workspaces ?? []
    readonly property var workspaceById: backend?.workspaceById ?? ({})
    readonly property var activeWorkspace: backend?.activeWorkspace ?? null
    readonly property var monitors: backend?.monitors ?? []
    readonly property var focusedMonitor: backend?.focusedMonitor ?? null
    readonly property var layers: backend?.layers ?? ({})

    function focusWindow(id) { backend?.focusWindow(id) }
    function closeWindow(id) { backend?.closeWindow(id) }
    function switchWorkspace(id) { backend?.switchWorkspace(id) }
    function moveWindowToWorkspace(id, wsId) { backend?.moveWindowToWorkspace(id, wsId) }
    function moveWindowAbsolute(id, x, y) { backend?.moveWindowAbsolute(id, x, y) }
    function toggleFloating(id) { backend?.toggleFloating(id) }
    function toggleFullscreen(id) { backend?.toggleFullscreen(id) }
    function focusMonitor(direction) { backend?.focusMonitor(direction) }
    function swapWindows(a, b) { backend?.swapWindows(a, b) }
    function setCursorWarp(enabled) { backend?.setCursorWarp(enabled) }
    function monitorFor(screen) { return backend?.monitorFor(screen) ?? null }

    // Compositor layouts (Mango only). Each entry is { name, symbol }; the
    // current layout reflects the focused tag, since Mango lays out per tag.
    // A property (not a function) so bindings re-evaluate when it changes.
    readonly property var layouts: backend?.layouts ?? []
    readonly property var currentLayout: backend?.currentLayout()
        ?? { name: "", symbol: "", known: false }
    function setLayout(name) { backend?.setLayout(name) }
    function cycleLayout() { backend?.cycleLayout() }
    function workspaceDisplayIndex(id) { return backend?.workspaceDisplayIndex(id) ?? Number(id) }
    function workspaceIdFromDisplayIndex(displayIndex, monitorName) { return backend?.workspaceIdFromDisplayIndex(displayIndex, monitorName) ?? Number(displayIndex) }
    function activeWorkspaceForMonitor(monitorName) { return backend?.activeWorkspaceForMonitor(monitorName) ?? null }
    function biggestWindowForWorkspace(wsId) { return backend?.biggestWindowForWorkspace(wsId) ?? null }
    function fullscreenOnMonitor(monitorName) { return backend?.fullscreenOnMonitor(monitorName) ?? false }
    function monitorGeometry(screen) { return backend?.monitorGeometry(screen) ?? { x: 0, y: 0, scale: 1 } }
}
