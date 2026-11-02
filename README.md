# RetroHUD for macOS

A customizable, retro-inspired macOS on-screen display built with Hammerspoon and Karabiner-Elements.

RetroHUD brings classic macOS-style indicators to modern Macs, with flat icons, a segmented progress bar, and a compact bottom-centre layout.

## Features

- Display brightness control with dynamic sun icons
- Volume indicator with progressive sound waves
- Keyboard backlight controls and visual feedback
- Signed contrast adjustment through BetterDisplay
- Custom MP3 sound effects for individual actions
- Press-and-hold adjustments
- Customizable appearance and thresholds

## Requirements

- macOS
- Hammerspoon
- Karabiner-Elements
- BetterDisplay for contrast adjustment

## Installation

1. Download `RetroHUD.lua`.
2. Place it inside `~/.hammerspoon/`.
3. Add the following line to your existing `init.lua`:

```lua
dofile(os.getenv("HOME") .. "/.hammerspoon/RetroHUD.lua")
```

4. Install the supplied Karabiner rule under Complex Modifications.
5. Disable overlapping keyboard rules and old RetroHUD bindings.
6. Reload Hammerspoon.

## Default Shortcuts

| Shortcut | Action |
|---|---|
| F1/F2 | Display brightness |
| Option + F1/F2 | Contrast |
| Command + F1/F2 | Keyboard backlight |
| F10/F11/F12 | Native volume controls |

## Custom Sounds

Place your own MP3 files in `~/Music/config/RetroHUD/` using the filenames expected by the script. Sound playback can be disabled in the configuration.

## Notes

Contrast and keyboard-backlight level indicators may use estimated values. Hardware behaviour depends on the Mac model and software configuration.
