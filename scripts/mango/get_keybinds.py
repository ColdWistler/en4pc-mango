#!/usr/bin/env python3
"""Parse MangoWM `bind=` lines into the same JSON tree shape the launcher
expects from the Hyprland parser.

Mango bind syntax:

    bind=MODS,key,dispatcher[,params...]

`params` may itself contain commas (e.g. `spawn,foo --flag,bar`), so only the
first three separators are significant. Descriptions come from the comment
block directly above a bind.
"""
import argparse
import json
import os
import re
import sys

HIDE_MARKERS = ("[hidden]",)
MOD_NAMES = {"SUPER", "SHIFT", "CTRL", "ALT", "META", "NONE", "MOD4"}


def read_lines(path):
    expanded = os.path.expanduser(os.path.expandvars(path))
    try:
        with open(expanded, "r", encoding="utf-8", errors="replace") as handle:
            return handle.readlines()
    except OSError:
        return []


def is_hidden(text):
    return any(marker in text for marker in HIDE_MARKERS)


def parse_mods(mods_str):
    mods = []
    for raw in mods_str.split("+"):
        part = raw.strip().upper()
        if not part or part == "NONE":
            continue
        if part == "MOD4":
            part = "SUPER"
        mods.append(part)
    return mods


def prettify(dispatcher, params):
    """Human readable fallback when the user did not write a comment."""
    d = dispatcher.strip().lower()
    p = params.strip()
    if d.startswith("spawn"):
        return "Execute: " + (p[:60] + "..." if len(p) > 60 else p)
    if d == "view":
        return "Switch to tag " + p.split(",")[0]
    if d in ("tag", "tagsilent"):
        return "Move window to tag " + p.split(",")[0]
    if d in ("viewtoleft", "viewtoleft_have_client"):
        return "Previous tag"
    if d in ("viewtoright", "viewtoright_have_client"):
        return "Next tag"
    labels = {
        "reload_config": "Reload configuration",
        "quit": "Quit Mango",
        "killclient": "Close window",
        "togglefloating": "Toggle floating",
        "togglefullscreen": "Toggle fullscreen",
        "togglefakefullscreen": "Toggle fake fullscreen",
        "togglemaximizescreen": "Toggle maximized",
        "toggle_scratchpad": "Toggle scratchpad",
        "switch_layout": "Switch layout",
        "focusstack": "Focus next window",
        "focusdir": "Focus window " + p,
        "focusmon": "Focus monitor " + p,
        "move_client": "Move window " + p,
        "tagmon": "Move tag to monitor " + p,
        "exchange_client": "Swap window " + p,
        "enteroverview": "Open overview",
        "leaveoverview": "Close overview",
        "toggleoverview": "Toggle overview",
        "incgaps": "Adjust gaps",
        "togglegaps": "Toggle gaps",
        "minimized": "Minimize window",
        "restore_minimized": "Restore minimized window",
    }
    return labels.get(d, d.replace("_", " ").capitalize())


def parse_bind(value, comment):
    parts = value.split(",", 3)
    if len(parts) < 3:
        return None
    mods_str, key, dispatcher = parts[0], parts[1], parts[2]
    params = parts[3] if len(parts) > 3 else ""
    if not key.strip():
        return None
    description = comment.strip() or prettify(dispatcher, params)
    if not description:
        return None
    return {
        "mods": parse_mods(mods_str),
        "key": key.strip(),
        "dispatcher": dispatcher.strip(),
        "params": params.strip(),
        "comment": description,
    }


def collect_comment(lines, index):
    """Return the contiguous comment block ending right before `index`."""
    collected = []
    i = index - 1
    while i >= 0:
        line = lines[i].strip()
        if not line:
            break
        if not line.startswith("#"):
            break
        text = line.lstrip("#").strip()
        # Ignore examples of commented-out binds: they describe syntax, not
        # the bind that follows them.
        if text and not re.match(r"(bind|mousebind|axisbind|gesturebind)=", text):
            collected.insert(0, text)
        i -= 1
    return " · ".join(collected)


def main():
    parser = argparse.ArgumentParser(description="MangoWM keybind reader")
    parser.add_argument(
        "--path",
        type=str,
        default=os.path.expanduser("~/.config/mango/config.conf"),
    )
    args = parser.parse_args()

    lines = read_lines(args.path)
    binds = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("bind="):
            continue
        if is_hidden(stripped):
            continue
        bind = parse_bind(stripped[len("bind="):], collect_comment(lines, index))
        if bind:
            binds.append(bind)

    payload = {
        "children": [
            {
                "name": "MangoWM",
                "children": [],
                "keybinds": binds,
            }
        ]
    }
    json.dump(payload, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
