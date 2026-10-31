pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A service that provides access to MangoWM keybinds.
 * Uses scripts/mango/get_keybinds.py to parse `bind=` lines from the Mango
 * config into the same JSON tree shape HyprlandKeybinds exposes.
 */
Singleton {
    id: root
    property string keybindParserPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/mango/get_keybinds.py`)
    property string configPath: FileUtils.trimFileProtocol(`${Directories.config}/mango/config.conf`)
    property var keybinds: ({ "children": [] })

    function refresh() {
        parseProc.running = false
        parseProc.running = true
    }

    Process {
        id: parseProc
        running: WM.compositor === "mango"
        command: ["python3", root.keybindParserPath, "--path", root.configPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.keybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[MangoKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }

    FileView {
        path: root.configPath
        watchChanges: true
        onFileChanged: root.refresh()
        onLoaded: root.refresh()
    }
}
