import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    // "ok" | "misplaced" | "missing"
    property string includeStatus: "ok"

    Component.onCompleted: includeCheckProc.running = true

    Process {
        id: includeCheckProc
        // ok = include line present and nothing but blanks/comments/includes after it
        command: ["sh", "-c", `cfg="$HOME/.config/mango/config.conf"
if [ ! -f "$cfg" ]; then echo missing; exit 0; fi
if ! grep -qs 'qssettings/shell.conf' "$cfg"; then echo missing
elif awk '/qssettings\\/shell.conf/ {found=1; next} found && NF && $0 !~ /qssettings/ && $0 !~ /^[ \\t]*#/ {bad=1} END {exit bad}' "$cfg"; then echo ok
else echo misplaced
fi`]
        stdout: StdioCollector {
            onStreamFinished: page.includeStatus = text.trim()
        }
    }

    Process {
        id: setupIncludeProc
        // Backs up config.conf, strips old include lines, appends ours at the end.
        // Writes through symlinks (stow-managed dotfiles).
        command: ["sh", "-c", `cfg="$HOME/.config/mango/config.conf"
cp -L "$cfg" "$cfg.backup.$(date +%s)" || exit 1
tmp=$(mktemp)
grep -v 'qssettings/shell.conf' "$cfg" > "$tmp"
printf '\\n%s\\n' '${MangoConfig.includeLine}' >> "$tmp"
cat "$tmp" > "$cfg"
rm -f "$tmp"`]
        onExited: includeCheckProc.running = true
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        NoticeBox {
            visible: page.includeStatus !== "ok"
            Layout.fillWidth: true
            text: page.includeStatus === "misplaced"
                ? Translation.tr("The qssettings include line is in your config.conf but not at the end. Mango applies later lines last, so your own settings currently override these. Fix moves it to the bottom (a backup of config.conf is made first).")
                : Translation.tr("These settings are saved to ~/.config/mango/qssettings/. Setup adds this line at the end of your config.conf (a backup is made first):") + "\n\n" + MangoConfig.includeLine

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                Layout.fillWidth: false
                buttonRadius: Appearance.rounding.small
                materialIcon: page.includeStatus === "misplaced" ? "build" : "auto_fix_high"
                mainText: page.includeStatus === "misplaced" ? Translation.tr("Fix") : Translation.tr("Setup")
                onClicked: setupIncludeProc.running = true
                colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
            }

            RippleButtonWithIcon {
                id: copyIncludeButton
                property bool justCopied: false
                Layout.fillWidth: false
                buttonRadius: Appearance.rounding.small
                materialIcon: justCopied ? "check" : "content_copy"
                mainText: justCopied ? Translation.tr("Copied!") : Translation.tr("Copy line")
                onClicked: {
                    copyIncludeButton.justCopied = true
                    Quickshell.clipboardText = MangoConfig.includeLine
                    revertCopyTimer.restart()
                }
                colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                Timer {
                    id: revertCopyTimer
                    interval: 1500
                    onTriggered: copyIncludeButton.justCopied = false
                }
            }
        }

        // Appearance
        ContentSection {
            icon: "rounded_corner"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Appearance")

            ContentSubsection {
                title: Translation.tr("Gaps")
                GroupedList {
                    ConfigSpinBox {
                        icon: "swap_horiz"
                        text: Translation.tr("Gap inside — horizontal")
                        value: MangoConfig.options.appearance.gapInnerHorizontal
                        from: 0; to: 60; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.appearance.gapInnerHorizontal) return
                            MangoConfig.options.appearance.gapInnerHorizontal = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "swap_vert"
                        text: Translation.tr("Gap inside — vertical")
                        value: MangoConfig.options.appearance.gapInnerVertical
                        from: 0; to: 60; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.appearance.gapInnerVertical) return
                            MangoConfig.options.appearance.gapInnerVertical = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "aspect_ratio"
                        text: Translation.tr("Gap outside — horizontal")
                        value: MangoConfig.options.appearance.gapOuterHorizontal
                        from: 0; to: 120; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.appearance.gapOuterHorizontal) return
                            MangoConfig.options.appearance.gapOuterHorizontal = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "height"
                        text: Translation.tr("Gap outside — vertical")
                        value: MangoConfig.options.appearance.gapOuterVertical
                        from: 0; to: 120; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.appearance.gapOuterVertical) return
                            MangoConfig.options.appearance.gapOuterVertical = value
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Borders & opacity")
                GroupedList {
                    ConfigSpinBox {
                        icon: "border_outer"
                        text: Translation.tr("Border width")
                        value: MangoConfig.options.appearance.borderPx
                        from: 0; to: 20; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.appearance.borderPx) return
                            MangoConfig.options.appearance.borderPx = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "rounded_corner"
                        text: Translation.tr("Corner radius")
                        value: MangoConfig.options.appearance.borderRadius
                        from: 0; to: 40; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.appearance.borderRadius) return
                            MangoConfig.options.appearance.borderRadius = value
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "crop_free"
                        text: Translation.tr("No border when only one window")
                        checked: MangoConfig.options.appearance.noBorderWhenSingle
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.appearance.noBorderWhenSingle) return
                            MangoConfig.options.appearance.noBorderWhenSingle = checked
                        }
                    }
                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Focused window opacity (%)")
                        value: Math.round(MangoConfig.options.appearance.focusedOpacity * 100)
                        from: 20; to: 100; stepSize: 5
                        onValueChanged: {
                            const next = value / 100
                            if (next === MangoConfig.options.appearance.focusedOpacity) return
                            MangoConfig.options.appearance.focusedOpacity = next
                        }
                    }
                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Unfocused window opacity (%)")
                        value: Math.round(MangoConfig.options.appearance.unfocusedOpacity * 100)
                        from: 20; to: 100; stepSize: 5
                        onValueChanged: {
                            const next = value / 100
                            if (next === MangoConfig.options.appearance.unfocusedOpacity) return
                            MangoConfig.options.appearance.unfocusedOpacity = next
                        }
                    }
                }
            }
        }

        // Layout
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Layout")

            ContentSubsection {
                title: Translation.tr("Tiling")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "star"
                        text: Translation.tr("New windows become master")
                        checked: MangoConfig.options.layout.newIsMaster
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.layout.newIsMaster) return
                            MangoConfig.options.layout.newIsMaster = checked
                        }
                    }
                    ConfigSpinBox {
                        icon: "aspect_ratio"
                        text: Translation.tr("Master size (%)")
                        value: Math.round(MangoConfig.options.layout.masterFactor * 100)
                        from: 20; to: 90; stepSize: 5
                        onValueChanged: {
                            const next = value / 100
                            if (next === MangoConfig.options.layout.masterFactor) return
                            MangoConfig.options.layout.masterFactor = next
                        }
                    }
                    ConfigSpinBox {
                        icon: "counter_1"
                        text: Translation.tr("Master window count")
                        value: MangoConfig.options.layout.masterCount
                        from: 1; to: 5; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.layout.masterCount) return
                            MangoConfig.options.layout.masterCount = value
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "space_dashboard"
                        text: Translation.tr("Smart gaps (no gaps with one window)")
                        checked: MangoConfig.options.layout.smartGaps
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.layout.smartGaps) return
                            MangoConfig.options.layout.smartGaps = checked
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Scroller")
                GroupedList {
                    ConfigSpinBox {
                        icon: "width"
                        text: Translation.tr("Default column width (%)")
                        value: Math.round(MangoConfig.options.layout.scrollerProportion * 100)
                        from: 20; to: 100; stepSize: 5
                        onValueChanged: {
                            const next = value / 100
                            if (next === MangoConfig.options.layout.scrollerProportion) return
                            MangoConfig.options.layout.scrollerProportion = next
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "align_horizontal_center"
                        text: Translation.tr("Center focused column")
                        checked: MangoConfig.options.layout.scrollerFocusCenter
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.layout.scrollerFocusCenter) return
                            MangoConfig.options.layout.scrollerFocusCenter = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "center_focus_strong"
                        text: Translation.tr("Prefer centered columns")
                        checked: MangoConfig.options.layout.scrollerPreferCenter
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.layout.scrollerPreferCenter) return
                            MangoConfig.options.layout.scrollerPreferCenter = checked
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Dwindle")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "smart_toy"
                        text: Translation.tr("Smart split (follow cursor)")
                        checked: MangoConfig.options.layout.dwindleSmartSplit
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.layout.dwindleSmartSplit) return
                            MangoConfig.options.layout.dwindleSmartSplit = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "call_split"
                        text: Translation.tr("Preserve split direction")
                        checked: MangoConfig.options.layout.dwindlePreserveSplit
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.layout.dwindlePreserveSplit) return
                            MangoConfig.options.layout.dwindlePreserveSplit = checked
                        }
                    }
                }
            }
        }

        // Effects
        ContentSection {
            icon: "deblur"
            shape: MaterialShape.Shape.Fan
            title: Translation.tr("Visual & Aesthetics")

            ContentSubsection {
                title: Translation.tr("Blur")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "blur_on"
                        text: Translation.tr("Blur windows")
                        checked: MangoConfig.options.effects.blur
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.effects.blur) return
                            MangoConfig.options.effects.blur = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "layers"
                        text: Translation.tr("Blur layer surfaces")
                        checked: MangoConfig.options.effects.blurLayer
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.effects.blurLayer) return
                            MangoConfig.options.effects.blurLayer = checked
                        }
                    }
                    ConfigSpinBox {
                        icon: "replay"
                        text: Translation.tr("Blur passes")
                        value: MangoConfig.options.effects.blurPasses
                        from: 1; to: 6; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.effects.blurPasses) return
                            MangoConfig.options.effects.blurPasses = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "blur_circular"
                        text: Translation.tr("Blur radius")
                        value: MangoConfig.options.effects.blurRadius
                        from: 1; to: 20; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.effects.blurRadius) return
                            MangoConfig.options.effects.blurRadius = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "grain"
                        text: Translation.tr("Blur noise (%)")
                        value: Math.round(MangoConfig.options.effects.blurNoise * 100)
                        from: 0; to: 20; stepSize: 1
                        onValueChanged: {
                            const next = value / 100
                            if (next === MangoConfig.options.effects.blurNoise) return
                            MangoConfig.options.effects.blurNoise = next
                        }
                    }
                    ConfigSpinBox {
                        icon: "palette"
                        text: Translation.tr("Blur saturation (%)")
                        value: Math.round(MangoConfig.options.effects.blurSaturation * 100)
                        from: 0; to: 300; stepSize: 10
                        onValueChanged: {
                            const next = value / 100
                            if (next === MangoConfig.options.effects.blurSaturation) return
                            MangoConfig.options.effects.blurSaturation = next
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Shadows")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "ev_shadow"
                        text: Translation.tr("Shadows")
                        checked: MangoConfig.options.effects.shadows
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.effects.shadows) return
                            MangoConfig.options.effects.shadows = checked
                        }
                    }
                    ConfigSpinBox {
                        icon: "expand_all"
                        text: Translation.tr("Shadow size")
                        value: MangoConfig.options.effects.shadowSize
                        from: 0; to: 50; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.effects.shadowSize) return
                            MangoConfig.options.effects.shadowSize = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "blur_linear"
                        text: Translation.tr("Shadow blur")
                        value: MangoConfig.options.effects.shadowBlur
                        from: 0; to: 50; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.effects.shadowBlur) return
                            MangoConfig.options.effects.shadowBlur = value
                        }
                    }
                }
            }
        }

        // Animations
        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Animations")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable animations")
                    checked: MangoConfig.options.animations.enable
                    onCheckedChanged: {
                        if (checked === MangoConfig.options.animations.enable) return
                        MangoConfig.options.animations.enable = checked
                    }
                }
                ConfigSwitch {
                    buttonIcon: "layers"
                    text: Translation.tr("Animate layers")
                    checked: MangoConfig.options.animations.layerAnimations
                    onCheckedChanged: {
                        if (checked === MangoConfig.options.animations.layerAnimations) return
                        MangoConfig.options.animations.layerAnimations = checked
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Open animation")
                    icon: "open_in_new"
                    currentValue: MangoConfig.options.animations.openType
                    onSelected: newValue => MangoConfig.options.animations.openType = newValue
                    options: [
                        { displayName: Translation.tr("Zoom"), icon: "zoom_in", value: "zoom" },
                        { displayName: Translation.tr("Slide"), icon: "slide_library", value: "slide" },
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Close animation")
                    icon: "close"
                    currentValue: MangoConfig.options.animations.closeType
                    onSelected: newValue => MangoConfig.options.animations.closeType = newValue
                    options: [
                        { displayName: Translation.tr("Zoom"), icon: "zoom_out", value: "zoom" },
                        { displayName: Translation.tr("Slide"), icon: "slide_library", value: "slide" },
                    ]
                }
                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Open duration (ms)")
                    value: MangoConfig.options.animations.durationOpen
                    from: 50; to: 2000; stepSize: 50
                    onValueChanged: {
                        if (value === MangoConfig.options.animations.durationOpen) return
                        MangoConfig.options.animations.durationOpen = value
                    }
                }
                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Close duration (ms)")
                    value: MangoConfig.options.animations.durationClose
                    from: 50; to: 2000; stepSize: 50
                    onValueChanged: {
                        if (value === MangoConfig.options.animations.durationClose) return
                        MangoConfig.options.animations.durationClose = value
                    }
                }
                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Tag switch duration (ms)")
                    value: MangoConfig.options.animations.durationTag
                    from: 50; to: 2000; stepSize: 50
                    onValueChanged: {
                        if (value === MangoConfig.options.animations.durationTag) return
                        MangoConfig.options.animations.durationTag = value
                    }
                }
            }
        }

        // Input
        ContentSection {
            icon: "trackpad_input"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Input")

            ContentSubsection {
                title: Translation.tr("Keyboard")
                GroupedList {
                    ConfigTextArea {
                        id: kbLayoutField
                        Layout.fillWidth: true
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keyboard layout")
                        placeholderText: Translation.tr("e.g., us, es, latam")
                        Component.onCompleted: value = MangoConfig.options.input.xkbLayout
                        onValueChanged: kbLayoutDebounceTimer.restart()

                        Timer {
                            id: kbLayoutDebounceTimer
                            interval: 1000
                            repeat: false
                            onTriggered: MangoConfig.options.input.xkbLayout = kbLayoutField.value
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "numbers"
                        text: Translation.tr("Numlock by default")
                        checked: MangoConfig.options.input.numlock
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.numlock) return
                            MangoConfig.options.input.numlock = checked
                        }
                    }
                    ConfigSpinBox {
                        icon: "keyboard_return"
                        text: Translation.tr("Repeat delay (ms)")
                        value: MangoConfig.options.input.repeatDelay
                        from: 100; to: 1000; stepSize: 10
                        onValueChanged: {
                            if (value === MangoConfig.options.input.repeatDelay) return
                            MangoConfig.options.input.repeatDelay = value
                        }
                    }
                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Repeat rate")
                        value: MangoConfig.options.input.repeatRate
                        from: 10; to: 100; stepSize: 1
                        onValueChanged: {
                            if (value === MangoConfig.options.input.repeatRate) return
                            MangoConfig.options.input.repeatRate = value
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "touch_app"
                        text: Translation.tr("Tap to click")
                        checked: MangoConfig.options.input.tapToClick
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.tapToClick) return
                            MangoConfig.options.input.tapToClick = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "pan_tool_alt"
                        text: Translation.tr("Tap and drag")
                        checked: MangoConfig.options.input.tapAndDrag
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.tapAndDrag) return
                            MangoConfig.options.input.tapAndDrag = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "lock"
                        text: Translation.tr("Drag lock")
                        checked: MangoConfig.options.input.dragLock
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.dragLock) return
                            MangoConfig.options.input.dragLock = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: MangoConfig.options.input.trackpadNatural
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.trackpadNatural) return
                            MangoConfig.options.input.trackpadNatural = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "keyboard_hide"
                        text: Translation.tr("Disable while typing")
                        checked: MangoConfig.options.input.trackpadDisableWhileTyping
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.trackpadDisableWhileTyping) return
                            MangoConfig.options.input.trackpadDisableWhileTyping = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "touchpad_off"
                        text: Translation.tr("Disable touchpad")
                        checked: MangoConfig.options.input.disableTrackpad
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.disableTrackpad) return
                            MangoConfig.options.input.disableTrackpad = checked
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Mouse")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: MangoConfig.options.input.mouseNatural
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.input.mouseNatural) return
                            MangoConfig.options.input.mouseNatural = checked
                        }
                    }
                }
            }
        }

        // Behavior
        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Behavior")

            ContentSubsection {
                title: Translation.tr("Focus")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "ads_click"
                        text: Translation.tr("Focus follows mouse")
                        checked: MangoConfig.options.misc.sloppyFocus
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.sloppyFocus) return
                            MangoConfig.options.misc.sloppyFocus = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "open_in_new"
                        text: Translation.tr("Focus window on activation")
                        checked: MangoConfig.options.misc.focusOnActivate
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.focusOnActivate) return
                            MangoConfig.options.misc.focusOnActivate = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "move_group"
                        text: Translation.tr("Focus across monitors")
                        checked: MangoConfig.options.misc.focusCrossMonitor
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.focusCrossMonitor) return
                            MangoConfig.options.misc.focusCrossMonitor = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "select_all"
                        text: Translation.tr("Focus across tags")
                        checked: MangoConfig.options.misc.focusCrossTag
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.focusCrossTag) return
                            MangoConfig.options.misc.focusCrossTag = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "mouse"
                        text: Translation.tr("Warp cursor to focused window")
                        checked: MangoConfig.options.misc.warpCursor
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.warpCursor) return
                            MangoConfig.options.misc.warpCursor = checked
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Windows")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "dashboard"
                        text: Translation.tr("Snap floating windows")
                        checked: MangoConfig.options.misc.floatingSnap
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.floatingSnap) return
                            MangoConfig.options.misc.floatingSnap = checked
                        }
                    }
                    ConfigSpinBox {
                        icon: "straighten"
                        text: Translation.tr("Snap distance")
                        value: MangoConfig.options.misc.snapDistance
                        from: 0; to: 100; stepSize: 5
                        onValueChanged: {
                            if (value === MangoConfig.options.misc.snapDistance) return
                            MangoConfig.options.misc.snapDistance = value
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "drag_pan"
                        text: Translation.tr("Drag tiled windows onto each other")
                        checked: MangoConfig.options.misc.dragTileToTile
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.dragTileToTile) return
                            MangoConfig.options.misc.dragTileToTile = checked
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "zoom_out_map"
                        text: Translation.tr("Drag small tiled windows")
                        checked: MangoConfig.options.misc.dragTileSmall
                        onCheckedChanged: {
                            if (checked === MangoConfig.options.misc.dragTileSmall) return
                            MangoConfig.options.misc.dragTileSmall = checked
                        }
                    }
                    ConfigSpinBox {
                        icon: "mouse"
                        text: Translation.tr("Cursor size")
                        value: MangoConfig.options.misc.cursorSize
                        from: 16; to: 64; stepSize: 2
                        onValueChanged: {
                            if (value === MangoConfig.options.misc.cursorSize) return
                            MangoConfig.options.misc.cursorSize = value
                        }
                    }
                }
            }
        }

        // Overview
        ContentSection {
            icon: "overview_key"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Overview")
            GroupedList {
                ConfigSpinBox {
                    icon: "margin"
                    text: Translation.tr("Inner gap")
                    value: MangoConfig.options.overview.gapInner
                    from: 0; to: 60; stepSize: 1
                    onValueChanged: {
                        if (value === MangoConfig.options.overview.gapInner) return
                        MangoConfig.options.overview.gapInner = value
                    }
                }
                ConfigSpinBox {
                    icon: "border_outer"
                    text: Translation.tr("Outer gap")
                    value: MangoConfig.options.overview.gapOuter
                    from: 0; to: 120; stepSize: 1
                    onValueChanged: {
                        if (value === MangoConfig.options.overview.gapOuter) return
                        MangoConfig.options.overview.gapOuter = value
                    }
                }
                ConfigSwitch {
                    buttonIcon: "select_all"
                    text: Translation.tr("Enable hot area")
                    checked: MangoConfig.options.overview.enableHotarea
                    onCheckedChanged: {
                        if (checked === MangoConfig.options.overview.enableHotarea) return
                        MangoConfig.options.overview.enableHotarea = checked
                    }
                }
                ConfigSpinBox {
                    icon: "pinch"
                    text: Translation.tr("Hot area size")
                    value: MangoConfig.options.overview.hotareaSize
                    from: 1; to: 50; stepSize: 1
                    onValueChanged: {
                        if (value === MangoConfig.options.overview.hotareaSize) return
                        MangoConfig.options.overview.hotareaSize = value
                    }
                }
            }
        }
    }
}
