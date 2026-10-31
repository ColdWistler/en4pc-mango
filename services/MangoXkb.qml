pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * Exposes the active Mango keyboard layout name and code for indicators.
 * Mirrors HyprlandXkb.qml / NiriXkb.qml's shape so widgets can bind to any
 * compositor transparently through the Xkb facade.
 */
Singleton {
    id: root
    property var cachedLayoutCodes: ({})
    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    property var baseLayoutFilePath: "/usr/share/X11/xkb/rules/base.lst"

    onCurrentLayoutNameChanged: root.updateLayoutCode()

    function updateLayoutCode() {
        if (WM.compositor !== "mango") return;
        if (!root.currentLayoutName) return;
        if (cachedLayoutCodes.hasOwnProperty(currentLayoutName)) {
            root.currentLayoutCode = cachedLayoutCodes[currentLayoutName];
        } else {
            getLayoutProc.running = true;
        }
    }

    function setLayoutName(name) {
        const cleaned = String(name ?? "").trim();
        if (cleaned.length === 0 || cleaned === root.currentLayoutName) return;
        root.currentLayoutName = cleaned;
        Config.options.osk.layout = cleaned.split(" (")[0];
    }

    Process {
        id: getLayoutProc
        command: ["cat", root.baseLayoutFilePath]

        stdout: StdioCollector {
            id: layoutCollector

            onStreamFinished: {
                const lines = layoutCollector.text.split("\n");
                const targetDescription = root.currentLayoutName;
                lines.find(line => {
                    if (!line.trim() || line.trim().startsWith('!'))
                        return false;

                    const matchLayout = line.match(/^\s*(\S+)\s+(.+)$/);
                    if (matchLayout && matchLayout[2] === targetDescription) {
                        root.cachedLayoutCodes[matchLayout[2]] = matchLayout[1];
                        root.currentLayoutCode = matchLayout[1];
                        return true;
                    }

                    const matchVariant = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/);
                    if (matchVariant && matchVariant[3] === targetDescription) {
                        const complexLayout = matchVariant[2] + matchVariant[1];
                        root.cachedLayoutCodes[matchVariant[3]] = complexLayout;
                        root.currentLayoutCode = complexLayout;
                        return true;
                    }

                    return false;
                });
            }
        }
    }

    Component.onCompleted: {
        if (WM.compositor === "mango")
            fetchProc.running = true;
    }

    Process {
        id: fetchProc
        command: ["mmsg", "get", "keyboardlayout"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.setLayoutName(parsed.layout);
                } catch (e) {
                    console.log("[MangoXkb] keyboardlayout parse error: " + e);
                }
            }
        }
    }

    Process {
        id: watchProc
        running: WM.compositor === "mango"
        command: ["mmsg", "watch", "keyboardlayout"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const trimmed = String(line ?? "").trim();
                if (!trimmed) return;
                try {
                    const parsed = JSON.parse(trimmed);
                    root.setLayoutName(parsed.layout);
                } catch (e) {}
            }
        }
        onExited: restartTimer.restart()
    }

    Timer { id: restartTimer; interval: 1000; onTriggered: { if (WM.compositor === "mango") watchProc.running = true } }
}
