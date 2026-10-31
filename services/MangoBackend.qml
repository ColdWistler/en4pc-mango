pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * MangoWM (mmsg) backend.
 *
 * Exposes the same data shapes as the Hyprland backend so the rest of the
 * shell can go through `WM` instead of touching compositor specifics.
 *
 * Mango is tag based: every monitor owns `tag_num` tags (usually 9). Tags are
 * exposed as "workspaces" with a globally unique id:
 *
 *     id = (monitorIndex + 1) * 100 + tagIndex
 *
 * and the tag index itself as `idx`. This keeps the generic WorkspaceModel
 * path working for multi-monitor setups.
 */
Scope {
    id: root

    // === Data (HyprlandData-compatible shapes) ===
    property var windowList: []
    property var windowByAddress: ({})
    property var addresses: []
    property var workspaces: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var focusedMonitor: null
    property var layers: ({}) // mmsg does not expose layer geometry; kept empty on purpose
    property string currentLayoutName: ""
    property string keymode: "default"

    // === Raw mmsg state ===
    property var _monitorData: []
    property var _tagData: ({})
    property var _clientData: []
    property string _focusedMonitorName: ""
    property bool _hasFocusedClient: false

    readonly property int tagScale: 100

    // === Dispatch helpers ===
    function dispatch(token) {
        Quickshell.execDetached(["mmsg", "dispatch", String(token)]);
    }

    function dispatchClient(token, clientId) {
        Quickshell.execDetached(["mmsg", "dispatch", String(token), "client," + String(clientId)]);
    }

    // === Workspace id helpers ===
    function monitorIndexFor(monitorName) {
        for (let i = 0; i < root._monitorData.length; i++)
            if (root._monitorData[i].name === monitorName)
                return i;
        return 0;
    }

    function workspaceIdFor(monitorName, tagIndex) {
        return (root.monitorIndexFor(monitorName) + 1) * root.tagScale + Number(tagIndex);
    }

    function decodeWorkspaceId(id) {
        const n = Number(id);
        if (n >= root.tagScale)
            return { monitorIndex: Math.floor(n / root.tagScale) - 1, tag: n % root.tagScale };
        return { monitorIndex: -1, tag: n };
    }

    // Overview workspaces are numbered 1..N (one per tag) on every compositor.
    function workspaceDisplayIndex(id) {
        const d = root.decodeWorkspaceId(id);
        return d.monitorIndex >= 0 ? d.tag : Number(id);
    }

    function workspaceIdFromDisplayIndex(displayIndex, monitorName) {
        const name = monitorName || root._focusedMonitorName || (root.monitors[0]?.name ?? "");
        return root.workspaceIdFor(name, Number(displayIndex));
    }

    // === Action API ===
    function switchWorkspaceRelative(direction) {
        const prev = ["prev", "previous", "up", "left", "-1"].includes(String(direction));
        root.dispatch((prev ? "viewtoleft" : "viewtoright") + ",0");
    }

    function switchWorkspace(id) {
        let d = root.decodeWorkspaceId(id);
        if (d.monitorIndex < 0) {
            // Bare display number (e.g. from the bar): resolve it on the
            // focused monitor, falling back to the first one.
            const name = root._focusedMonitorName || (root.monitors[0]?.name ?? "");
            d = root.decodeWorkspaceId(root.workspaceIdFor(name, d.tag));
        }
        // Mango only has `tag_num` tags, so clamp: clicking a slot past the
        // last tag (the 10th bar cell with 9 tags) would be an invalid index.
        const mon = root._monitorData[d.monitorIndex];
        const tags = root._tagData[mon?.name] || mon?.tags || [];
        if (tags.length > 0)
            d.tag = Math.min(Math.max(d.tag, 1), tags.length);
        root.dispatch(`view,${d.tag},${d.monitorIndex}`);
    }

    function focusWindow(id) {
        root.dispatch("focusid," + String(id));
    }

    function closeWindow(id) {
        root.dispatchClient("kill", id);
    }

    function moveWindowToWorkspace(id, wsId) {
        const d = root.decodeWorkspaceId(wsId);
        const win = root.windowByAddress[String(id)];
        const monitorName = root._monitorData[d.monitorIndex]?.name;
        if (monitorName && win && win.monitorName && monitorName !== win.monitorName) {
            root.dispatchClient(`tagcrossmon,${d.tag},${monitorName}`, id);
        } else {
            // tagsilent = move without following, matching Hyprland's follow = false
            root.dispatchClient(`tagsilent,${d.tag}`, id);
        }
    }

    function moveWindowAbsolute(id, x, y) {
        const win = root.windowByAddress[String(id)];
        if (!win) return;
        const dx = Math.round(Number(x) - (win.x ?? 0));
        const dy = Math.round(Number(y) - (win.y ?? 0));
        if (dx === 0 && dy === 0) return;
        root.dispatchClient(`movewin,${dx},${dy}`, id);
    }

    function toggleFloating(id) { root.dispatchClient("togglefloating", id); }
    function toggleFullscreen(id) { root.dispatchClient("togglefullscreen", id); }
    function focusMonitor(direction) { root.dispatch("focusmon," + String(direction)); }

    function setCursorWarp(enabled) {
        // mango's `warpcursor` option: 1 = warp, 0 = do not warp.
        root.dispatch("setoption,warpcursor," + (enabled ? "1" : "0"));
    }

    // Swaps two windows. Mango exchanges with the neighbour in a direction, so
    // derive the direction from the windows' positions.
    function swapWindows(a, b) {
        const from = root.windowByAddress[String(a)];
        const to = root.windowByAddress[String(b)];
        if (!from || !to) return;
        const dx = (to.x ?? 0) - (from.x ?? 0);
        const dy = (to.y ?? 0) - (from.y ?? 0);
        const dir = Math.abs(dx) >= Math.abs(dy)
            ? (dx >= 0 ? "right" : "left")
            : (dy >= 0 ? "down" : "up");
        root.dispatchClient("exchange_client," + dir, a);
    }

    // === Query API used by WM ===
    function monitorFor(screen) {
        if (!screen) return null;
        return root.monitors.find(m => m.name === screen.name) ?? null;
    }

    function activeWorkspaceForMonitor(monitorName) {
        if (!monitorName) return null;
        return root.monitors.find(m => m.name === monitorName)?.activeWorkspace ?? null;
    }

    function biggestWindowForWorkspace(wsId) {
        const wins = root.windowList.filter(w => w.workspaceId === Number(wsId));
        if (wins.length === 0) return null;
        return wins.reduce((a, b) => ((a.width * a.height) >= (b.width * b.height) ? a : b));
    }

    function fullscreenOnMonitor(monitorName) {
        const ws = root.activeWorkspaceForMonitor(monitorName);
        if (!ws) return false;
        return root.monitors.some(m => m.name === monitorName)
            && root.windowList.some(w => w.workspaceId === ws.id && w.fullscreen);
    }

    function monitorGeometry(screen) {
        const m = root.monitorFor(screen);
        if (!m) return { x: 0, y: 0, scale: 1 };
        return { x: m.x, y: m.y, scale: m.scale };
    }

    // === Normalisation ===
    function normalizeMonitor(name, index, tags) {
        return {
            id: index,
            name: name,
            x: 0,
            y: 0,
            width: 0,
            height: 0,
            scale: 1,
            reserved: [0, 0, 0, 0],
            transform: 0,
            focused: false,
            activeWorkspace: null,
            specialWorkspace: { name: "" },
            tags: tags,
            active_tags: []
        };
    }

    function rebuild() {
        const clientData = root._clientData || [];
        const monitorData = root._monitorData || [];

        // Keep the focused monitor valid before building monitor objects.
        if (root._focusedMonitorName === "" && monitorData.length > 0)
            root._focusedMonitorName = monitorData[0].name;
        if (monitorData.length > 0 && !monitorData.some(m => m.name === root._focusedMonitorName))
            root._focusedMonitorName = monitorData[0].name;

        // Build workspaces (tags) first so monitors can reference them.
        const workspaces = [];
        const workspaceById = {};
        for (let mi = 0; mi < monitorData.length; mi++) {
            const mon = monitorData[mi];
            const tags = root._tagData[mon.name] || mon.tags || [];
            const activeTags = mon.active_tags || [];
            for (const tag of tags) {
                const id = (mi + 1) * root.tagScale + Number(tag.index);
                const isActive = (tag.is_active === true) || activeTags.includes(tag.index);
                const hasFullscreen = clientData.some(c =>
                    c.monitor === mon.name
                    && (c.tags || []).includes(tag.index)
                    && (c.is_fullscreen || c.is_fakefullscreen));
                const ws = {
                    id: id,
                    idx: Number(tag.index),
                    name: String(tag.index),
                    output: mon.name,
                    monitor: mon.name,
                    monitorID: mi,
                    windows: tag.client_count ?? 0,
                    hasfullscreen: hasFullscreen,
                    active: isActive,
                    is_active: isActive,
                    urgent: tag.is_urgent === true,
                    layout: tag.layout || mon.layout_symbol || "T"
                };
                workspaces.push(ws);
                workspaceById[id] = ws;
            }
        }
        root.workspaces = workspaces;
        root.workspaceById = workspaceById;

        // Build windows.
        const windows = [];
        const windowByAddress = {};
        for (const client of clientData) {
            const mi = root.monitorIndexFor(client.monitor);
            const tag = (client.tags && client.tags.length > 0) ? client.tags[0] : 0;
            const workspaceId = (mi + 1) * root.tagScale + Number(tag);
            const win = {
                id: String(client.id),
                address: String(client.id),
                numericId: client.id,
                pid: client.pid,
                title: client.title || "",
                class: client.appid || "",
                appId: client.appid || "",
                workspace: { id: workspaceId },
                workspaceId: workspaceId,
                monitor: mi,
                monitorName: client.monitor,
                at: [client.x ?? 0, client.y ?? 0],
                size: [client.width ?? 0, client.height ?? 0],
                x: client.x ?? 0,
                y: client.y ?? 0,
                width: client.width ?? 0,
                height: client.height ?? 0,
                floating: client.is_floating === true,
                fullscreen: client.is_fullscreen === true || client.is_fakefullscreen === true,
                focused: client.is_focused === true,
                mapped: client.is_visible === true,
                xwayland: client.is_xwayland === true,
                tags: client.tags || []
            };
            windows.push(win);
            windowByAddress[win.address] = win;
            // Older overview code prefixes addresses with 0x (Hyprland style).
            windowByAddress["0x" + win.address] = win;
        }
        root.windowList = windows;
        root.windowByAddress = windowByAddress;
        root.addresses = windows.map(w => w.address);

        // Build monitors.
        const monitors = [];
        for (let mi = 0; mi < monitorData.length; mi++) {
            const mon = monitorData[mi];
            const activeTags = mon.active_tags || [];
            const activeTag = activeTags.length > 0 ? activeTags[0] : 0;
            const activeWorkspace = workspaceById[(mi + 1) * root.tagScale + Number(activeTag)] ?? null;
            monitors.push({
                id: mi,
                name: mon.name,
                x: mon.x ?? 0,
                y: mon.y ?? 0,
                width: mon.width ?? 1920,
                height: mon.height ?? 1080,
                scale: mon.scale ?? 1,
                reserved: [0, 0, 0, 0],
                transform: 0,
                focused: mon.name === root._focusedMonitorName,
                activeWorkspace: activeWorkspace
                    ? { id: activeWorkspace.id, name: activeWorkspace.name, idx: activeWorkspace.idx }
                    : null,
                specialWorkspace: { name: "" },
                tags: root._tagData[mon.name] || mon.tags || [],
                active_tags: activeTags,
                activeClient: mon.active_client ?? null,
                keyboardLayout: mon.keyboardlayout || "",
                layoutSymbol: mon.layout_symbol || "",
                layoutIndex: mon.layout_index ?? 0,
                tagNum: mon.tag_num ?? 9
            });
        }
        root.monitors = monitors;
        root.focusedMonitor = monitors.find(m => m.name === root._focusedMonitorName) ?? monitors[0] ?? null;
        root.activeWorkspace = root.focusedMonitor?.activeWorkspace
            ? (workspaceById[root.focusedMonitor.activeWorkspace.id] ?? null)
            : null;
    }

    // === Stream handlers ===
    function handleMonitors(payload) {
        if (!payload || !payload.monitors) return;
        root._monitorData = payload.monitors;
        const focused = payload.monitors.find(m => m.name === root._focusedMonitorName) ?? payload.monitors[0];
        if (focused?.keyboardlayout)
            root.currentLayoutName = focused.keyboardlayout;
        if (focused?.keymode)
            root.keymode = focused.keymode;
        root.rebuild();
    }

    function handleClients(payload) {
        if (!payload || !payload.clients) return;
        root._clientData = payload.clients;
        const focusedClient = payload.clients.find(c => c.is_focused);
        root._hasFocusedClient = focusedClient !== undefined;
        if (focusedClient?.monitor)
            root._focusedMonitorName = focusedClient.monitor;
        root.rebuild();
    }

    function handleTags(payload) {
        if (!payload || !payload.all_tags) return;
        const byMonitor = {};
        for (const entry of payload.all_tags)
            byMonitor[entry.monitor] = entry.tags || [];
        root._tagData = byMonitor;
        root.rebuild();
    }

    function parseLine(line, handler) {
        const trimmed = String(line ?? "").trim();
        if (trimmed.length === 0) return;
        try {
            handler(JSON.parse(trimmed));
        } catch (e) {
            console.log("[MangoBackend] JSON parse error: " + e);
        }
    }

    Component.onCompleted: root.rebuild();

    // === Watchers ===
    Process {
        id: monitorWatcher
        command: ["mmsg", "watch", "all-monitors"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.parseLine(line, root.handleMonitors)
        }
        onExited: monitorRestart.restart()
    }
    Timer { id: monitorRestart; interval: 1000; onTriggered: monitorWatcher.running = true }

    Process {
        id: clientWatcher
        command: ["mmsg", "watch", "all-clients"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.parseLine(line, root.handleClients)
        }
        onExited: clientRestart.restart()
    }
    Timer { id: clientRestart; interval: 1000; onTriggered: clientWatcher.running = true }

    Process {
        id: tagWatcher
        command: ["mmsg", "watch", "all-tags"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.parseLine(line, root.handleTags)
        }
        onExited: tagRestart.restart()
    }
    Timer { id: tagRestart; interval: 1000; onTriggered: tagWatcher.running = true }

    // Falls back to the pointer's monitor when no client holds focus.
    Process {
        id: cursorProc
        command: ["mmsg", "get", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._hasFocusedClient) return;
                try {
                    const payload = JSON.parse(text);
                    if (payload.monitor && payload.monitor !== root._focusedMonitorName) {
                        root._focusedMonitorName = payload.monitor;
                        root.rebuild();
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            cursorProc.running = false;
            cursorProc.running = true;
        }
    }
}
