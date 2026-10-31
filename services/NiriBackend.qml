pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var windowList: []
    property var windowByAddress: ({})
    property var addresses: []
    property var workspaces: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var focusedMonitor: null
    property var layers: ({})

    function switchWorkspaceRelative(direction) {
        actionProc.command = ["niri", "msg", "action", direction === "next" ? "focus-workspace-down" : "focus-workspace-up"];
        actionProc.running = true;
    }

    function normalizeWindow(w) {
        const pos = w.layout?.tile_pos_in_workspace_view ?? [0, 0];
        const size = w.layout?.window_size ?? w.layout?.tile_size ?? [0, 0];
        return {
            id: String(w.id),
            address: String(w.id),
            pid: w.pid,
            title: w.title ?? "",
            appId: w.app_id ?? "",
            class: w.app_id ?? "",
            workspace: { id: w.workspace_id },
            workspaceId: w.workspace_id,
            monitor: root.monitorIndexForWindow(w),
            at: pos,
            size: size,
            x: pos[0],
            y: pos[1],
            width: size[0],
            height: size[1],
            floating: w.is_floating === true,
            fullscreen: false,
            focused: w.is_focused ?? false,
            mapped: true,
            xwayland: false
        };
    }

    function monitorIndexForWindow(w) {
        const ws = root.workspaces.find(ws => ws.id === w.workspace_id);
        if (!ws) return 0;
        return Math.max(0, root.monitors.findIndex(m => m.name === ws.output));
    }

    function focusWindow(id) {
        actionProc.command = ["niri", "msg", "action", "focus-window", "--id", id];
        actionProc.running = true;
    }
    function closeWindow(id) {
        actionProc.command = ["niri", "msg", "action", "close-window", "--id", id];
        actionProc.running = true;
    }
    function switchWorkspace(id) {
        actionProc.command = ["niri", "msg", "action", "focus-workspace", String(id)];
        actionProc.running = true;
    }
    function moveWindowToWorkspace(id, wsId) {
        actionProc.command = ["niri", "msg", "action", "move-window-to-workspace", "--window-id", id, String(wsId)];
        actionProc.running = true;
    }
    function moveWindowAbsolute(id, x, y) {
        actionProc.command = ["niri", "msg", "action", "move-floating-window", "--id", id, "--x", String(Math.round(x)), "--y", String(Math.round(y))];
        actionProc.running = true;
    }
    function toggleFloating(id) {
        actionProc.command = ["niri", "msg", "action", "toggle-window-floating", "--id", id];
        actionProc.running = true;
    }
    function toggleFullscreen(id) {
        focusWindow(id);
        actionProc.command = ["niri", "msg", "action", "fullscreen-window"];
        actionProc.running = true;
    }
    function focusMonitor(direction) {
        actionProc.command = ["niri", "msg", "action", direction === "left" ? "focus-monitor-left" : "focus-monitor-right"];
        actionProc.running = true;
    }
    function swapWindows(a, b) {
        actionProc.command = ["niri", "msg", "action", "swap-window", "--id", a];
        actionProc.running = true;
    }
    function setCursorWarp(enabled) {}

    function monitorFor(screen) {
        if (!screen) return null;
        return root.monitors.find(m => m.name === screen.name) ?? null;
    }

    function workspaceDisplayIndex(id) {
        const n = Number(id);
        return Number.isFinite(n) ? n : 1;
    }

    function workspaceIdFromDisplayIndex(displayIndex) {
        return Number(displayIndex);
    }

    function activeWorkspaceForMonitor(monitorName) {
        if (!monitorName) return null;
        return root.workspaces.find(ws => ws.output === monitorName && ws.is_active) ?? null;
    }

    function biggestWindowForWorkspace(wsId) {
        const wins = root.windowList.filter(w => w.workspaceId === wsId);
        if (wins.length === 0) return null;
        return wins.reduce((a, b) => (a.width * a.height >= b.width * b.height ? a : b));
    }

    function fullscreenOnMonitor(monitorName) {
        const mon = root.monitors.find(m => m.name === monitorName);
        if (!mon || !mon.logical) return false;
        const ws = root.workspaces.find(w => w.output === monitorName && w.is_active);
        if (!ws) return false;
        return root.windowList.some(w => w.workspaceId === ws.id
            && w.width === mon.logical.width
            && w.height === mon.logical.height);
    }

    function monitorGeometry(screen) {
        const m = root.monitors.find(mm => mm.name === screen?.name);
        if (!m || !m.logical) return { x: 0, y: 0, scale: 1 };
        return { x: m.logical.x, y: m.logical.y, scale: m.logical.scale };
    }

    Process { id: actionProc }

    function updateAll() {
        getWindows.running = true;
        getWorkspaces.running = true;
        getOutputs.running = true;
    }

    Component.onCompleted: {
        updateAll();
        eventStream.running = true;
    }

    Process {
        id: getWindows
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(text).map(root.normalizeWindow);
                    const byAddress = {};
                    for (const win of root.windowList) byAddress[win.address] = win;
                    root.windowByAddress = byAddress;
                    root.addresses = root.windowList.map(w => w.address);
                } catch (e) { console.log("[NiriBackend] windows parse error: " + e) }
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    const windows = root.windowList || [];
                    root.workspaces = raw.map(ws => Object.assign({}, ws, {
                        active: ws.is_active === true,
                        windows: windows.filter(w => w.workspaceId === ws.id).length,
                        hasfullscreen: false
                    }));
                    let byId = {};
                    for (const ws of root.workspaces) byId[ws.id] = ws;
                    root.workspaceById = byId;
                    root.activeWorkspace = root.workspaces.find(ws => ws.is_focused) ?? null;
                } catch (e) { console.log("[NiriBackend] workspaces parse error: " + e) }
            }
        }
    }

    Process {
        id: getOutputs
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    root.monitors = Object.keys(raw).map((name, index) => {
                        const o = raw[name];
                        const logical = o.logical ?? {};
                        return {
                            id: index,
                            name: name,
                            make: o.make ?? "",
                            model: o.model ?? "",
                            current_mode: o.current_mode,
                            modes: o.modes,
                            logical: o.logical,
                            x: logical.x ?? 0,
                            y: logical.y ?? 0,
                            width: logical.width ?? 1920,
                            height: logical.height ?? 1080,
                            scale: logical.scale ?? 1,
                            reserved: [0, 0, 0, 0],
                            transform: logical.transform ?? 0,
                            specialWorkspace: { name: "" },
                            activeWorkspace: root.workspaces.find(ws => ws.output === name && ws.is_active) ?? null
                        };
                    });
                    root.focusedMonitor = root.monitors.find(m => root.workspaces.find(ws => ws.output === m.name && ws.is_focused)) ?? root.monitors[0] ?? null;
                } catch (e) { console.log("[NiriBackend] outputs parse error: " + e) }
            }
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => { if (line.trim().length > 0) refreshDebounce.restart() }
        }
        onExited: restartTimer.restart()
    }
    Timer { id: restartTimer; interval: 1000; onTriggered: eventStream.running = true }
    Timer { id: refreshDebounce; interval: 80; onTriggered: root.updateAll() }
}
