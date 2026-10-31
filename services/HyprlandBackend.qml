pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Scope {
    id: root
    property var windowList: []
    property var windowByAddress: ({})
    property var addresses: []
    property var workspaces: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var focusedMonitor: Hyprland.focusedMonitor
    property var layers: ({})

    function switchWorkspaceRelative(direction) {
        Hyprland.dispatch(`hl.dsp.focus({workspace = "r${direction === "next" ? "+1" : "-1"}"})`);
    }
    function focusWindow(id) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${id}" })`);
    }
    function closeWindow(id) {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${id}" })`);
    }
    function switchWorkspace(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }
    function moveWindowToWorkspace(id, wsId) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${wsId}, follow = false, window = "address:${id}" })`);
    }
    function moveWindowAbsolute(id, x, y) {
        Hyprland.dispatch(`hl.dsp.window.move({ x = "${x}", y = "${y}", window = "address:${id}" })`);
    }
    function toggleFloating(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "togglefloating", `address:${id}`]);
    }
    function toggleFullscreen(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "fullscreen", `address:${id}`]);
    }
    function focusMonitor(direction) {
        Quickshell.execDetached(["hyprctl", "dispatch", "focusmonitor", String(direction)]);
    }
    function swapWindows(a, b) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${b}" })`);
        Hyprland.dispatch(`hl.dsp.window.swap({ window = "address:${a}" })`);
    }
    function setCursorWarp(enabled) {
        Hyprland.dispatch(`hl.config({cursor = {no_warps = ${enabled ? "false" : "true"}}})`);
    }

    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }

    function workspaceDisplayIndex(id) {
        const n = Number(id);
        return Number.isFinite(n) ? n : 1;
    }

    function workspaceIdFromDisplayIndex(displayIndex) {
        return Number(displayIndex);
    }

    function activeWorkspaceForMonitor(monitorName) {
        const m = Hyprland.monitors.values.find(mm => mm.name === monitorName);
        return m?.activeWorkspace ? { id: m.activeWorkspace.id } : null;
    }

    function biggestWindowForWorkspace(wsId) {
        return HyprlandData.biggestWindowForWorkspace(wsId);
    }

    function fullscreenOnMonitor(monitorName) {
        const wsList = Hyprland.workspaces.values.filter(ws => ws.monitor && ws.monitor.name === monitorName);
        return wsList.some(ws => ws.active && ws.toplevels.values.some(w => w.wayland?.fullscreen));
    }

    function monitorGeometry(screen) {
        const m = Hyprland.monitorFor(screen);
        if (!m) return { x: 0, y: 0, scale: 1 };
        return { x: m.x, y: m.y, scale: m.scale };
    }

    Component.onCompleted: refresh()

    function refresh() {
        windowList = HyprlandData.windowList;
        windowByAddress = HyprlandData.windowByAddress;
        addresses = HyprlandData.addresses;
        workspaces = HyprlandData.workspaces;
        workspaceById = HyprlandData.workspaceById;
        activeWorkspace = HyprlandData.activeWorkspace;
        monitors = HyprlandData.monitors;
        layers = HyprlandData.layers;
        focusedMonitor = Hyprland.focusedMonitor;
    }

    Connections {
        target: HyprlandData
        function onWindowListChanged() { root.refresh() }
        function onWorkspacesChanged() { root.refresh() }
        function onMonitorsChanged() { root.refresh() }
        function onLayersChanged() { root.refresh() }
        function onActiveWorkspaceChanged() { root.refresh() }
    }
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { root.refresh() }
    }
}
