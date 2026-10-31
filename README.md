
<div align="center">

# 🥭 end4-pC

**My personal Quickshell desktop configuration for [MangoWM](https://github.com/mangowm/mango)**

A fork of the [illogical-impulse](https://github.com/end-4/dots-hyprland) shell,
customised and adapted from Hyprland to MangoWM.

</div>

---

> [!IMPORTANT]
> **This is a personal dotfiles repository**, not a distribution or a supported
> project. It exists so my own machines have a working shell on MangoWM.
> Everything here is provided **as-is and without warranty** — no install
> support, no bug-fix SLA, no guarantee it will work on your machine. Expect it
> to change without notice. Have a look around, copy what you like, and fork it
> for your own use.

---

## 📸 Screenshots

<div align="center">

| 🌿 Desktop & widgets | 🎧 Wallpaper |
|:---:|:---:|
| ![Desktop](screenshots/mango/mango-desktop-1.png) | ![Wallpaper](screenshots/mango/mango-desktop-2.png) |

</div>

Bar with workspace indicators, clock, weather, media controls, greeting
widget and dock — running on MangoWM.

---

## 📦 What this is

| | |
|:---|:---|
| **Shell** | [Quickshell](https://quickshell.outfoxxed.me/) (Material 3 Expressive) |
| **Compositor** | MangoWM (`mmsg` IPC), with Hyprland/Niri code paths kept |
| **Base** | [illogical-impulse](https://github.com/end-4/dots-hyprland) by [@end-4](https://github.com/end-4) |
| **Fork point** | [pctrade/end4-pC](https://github.com/pctrade/end4-pC) — my Custom end4 fork |
| **This repo** | [ColdWistler/en4pc-mango](https://github.com/ColdWistler/en4pc-mango), branch `mangowm` |

MangoWM is **tag based**, so the shell exposes Mango's tags as workspaces and
normalises them into the same shapes the Hyprland path produced. Everything goes
through a single compositor facade, `services/WM.qml`, instead of talking to a
compositor-specific API.

---

## 🚀 Installation

### Requirements

- [Quickshell](https://quickshell.outfoxxed.me/) with Qt 6
- MangoWM (tested on 0.18.x, `mmsg` in `PATH`)
- A MangoWM config in `~/.config/mango/config.conf`
- Shared stock pieces: `python3`, `jq`, `grim`, `slurp`, `wl-clipboard`,
  `brightnessctl`, `wpctl`, `magick`, `tesseract`, `mmsg`, `wlsunset`

### Clone & run

```bash
cd ~/.config/quickshell/
git clone https://github.com/ColdWistler/en4pc-mango.git en4-pC
cd en4-pC && git checkout mangowm
qs -c end4-pC > /dev/null 2>&1 & disown
```

### MangoWM config

Add the shell to `~/.config/mango/config.conf`:

```bash
exec_once=qs -c end4-pC
```

And, **at the very end of the file**, include the file the shell manages so its
own Mango settings win over manual edits (the Settings → Mango page can add this
for you and backs `config.conf` up first):

```bash
source_optional=/home/<user>/.config/mango/qssettings/shell.conf
```

Reload afterwards:

```bash
mmsg dispatch reload_config
```

### Switching back to Hyprland

The Hyprland code path is untouched and still works. Set the shell as your
default in your Hyprland config the usual way (`qsConfig = "end4-pC"`), or run
`qs -c end4-pC` directly. The shell detects the compositor at startup and picks
the matching backend automatically.

---

## ⌨️ Keybinds

MangoWM has no global-shortcut protocol, so the shell's features are triggered
through IPC instead of compositor bindings:

```bash
qs -c end4-pC ipc call <target> <function>
```

Bind them in `~/.config/mango/config.conf` — full list in
[`mango-keybinds.conf`](mango-keybinds.conf):

```bash
# launcher, wallpaper selector, workspace overview
bind=SUPER,d,spawn,qs -c end4-pC ipc call search toggle
bind=SUPER,w,spawn,qs -c end4-pC ipc call wallpaperSelector toggle
bind=SUPER,t,spawn,qs -c end4-pC ipc call search workspacesToggle

# brightness — Fn keys emit XF86 keysyms on this laptop
bind=NONE,XF86MonBrightnessUp,spawn,qs -c end4-pC ipc call brightness increment
bind=NONE,XF86MonBrightnessDown,spawn,qs -c end4-pC ipc call brightness decrement
bind=SUPER+ALT,Up,spawn,qs -c end4-pC ipc call brightness increment
bind=SUPER+ALT,Down,spawn,qs -c end4-pC ipc call brightness decrement

# volume — the volume OSD listens on pipewire, so these show it automatically
bind=NONE,XF86AudioRaiseVolume,spawn_shell,wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bind=NONE,XF86AudioLowerVolume,spawn_shell,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind=NONE,XF86AudioMute,spawn_shell,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
```

Run `qs -c end4-pC ipc show` for every target the shell exposes.

---

## 🥭 MangoWM-specific bits

| Piece | What it does |
|:---|:---|
| `services/WM.qml` | The compositor facade: `isHyprland` / `isNiri` / `isMango`, plus window, workspace, monitor and action proxies. Consumers never call a compositor API directly. |
| `services/MangoBackend.qml` | `mmsg` watch streams normalised into Hyprland-shaped data. Tags become workspaces with ids `(monitorIndex + 1) * 100 + tagIndex`. |
| `services/MangoConfig.qml` + `modules/ii/settings/pages/MangoConfig.qml` | The Settings → Mango page. Options live in `~/.config/mango/qssettings/settings.json` and are written to `qssettings/shell.conf`, which your config includes. |
| `services/MangoXkb.qml`, `services/Xkb.qml` | Keyboard layout, replacing the Hyprland-only indicator. |
| `services/Keybinds.qml`, `services/MangoKeybinds.qml`, `scripts/mango/` | Keybind parsing so launcher search can find your binds. |
| `mango-keybinds.conf` | The Mango keybind reference for the IPC calls above. |

---

## 📁 Where things are saved

| Tool | Path |
|:---|:---|
| Shell screen snip — Settings → Services → *Screenshot path* | unset means clipboard only; set it to a folder such as `~/Pictures/Screenshots` |
| `flameshot` (`SUPER + O`) | `~/Pictures/Screenshots` |
| Screen recordings | `~/Videos` |
| Shell state, themes, chat history | `~/.local/state/…` and `~/.config/illogical-impulse/config.json` |

---

## 🤖 AI use disclosure

Parts of this repository were written with AI assistance and then reviewed by
hand. Specifically:

- The **MangoWM backend and supporting services** (`services/WM.qml`,
  `services/MangoBackend.qml`, `services/MangoConfig.qml`,
  `services/MangoKeybinds.qml`, `services/MangoXkb.qml`,
  `services/Xkb.qml`, `services/Keybinds.qml`) were written by an AI coding
  agent in [OpenCode](https://opencode.ai) and adjusted afterwards.
- The **MangoCOM port fixes** in `modules/` (workspace/overview/OSD/lock/theme
  handling) and the **script changes** (`scripts/colors/switchwall.sh`,
  `scripts/videos/record.sh`, `scripts/system-appearance.sh`) are AI-written
  edits to the original code.
- The **`mango-shell` replacement in `~/.config/mango/config.conf`** (the
  `exec_once` line and the dead signal binds) and this **README** were also
  drafted with AI assistance.

Everything else is the original end-4 / illogical-impulse shell or pctrade's
`end4-pC` fork. I have reviewed each AI-written change, but treat the port as
"works on my machine" — worth a read before you trust it.

---

## 🙏 Credits

- **[@end-4](https://github.com/end-4)** — for creating
  [dots-hyprland](https://github.com/end-4/dots-hyprland), the illogical-impulse
  shell this whole thing is built on. An absolute masterpiece of a dotfiles
  project — nothing here would exist without it. 🫡
- **[@gh0stzk](https://github.com/gh0stzk)** — for the weather API integration
  that powers the weather widget. 🙌
- **[@StarS2112](https://github.com/StarS2112)** — for showcasing the base fork. 🙌
- **[@simeulinuxkaliwr](https://github.com/simeulinuxkaliwr)** — for shader
  transitions. 🎨
- **[pctrade](https://github.com/pctrade)** — for `end4-pC`, the Custom end4 fork
  this repo is based on.
- **The MangoWM team** — [mangowm/mango](https://github.com/mangowm/mango) for
  the compositor this port targets, `mmsg`/tag/kb shortcuts included.
- **[Quickshell](https://quickshell.outfoxxed.me/)** and the Qt/QML ecosystem
  it sits on.

---

<div align="center">

Personal config — **use at your own risk** 😉

</div>
