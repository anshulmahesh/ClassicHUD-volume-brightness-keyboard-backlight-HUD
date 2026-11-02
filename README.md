RetroHUD for macOS
A small, configurable on-screen display inspired by the restrained visual language of classic macOS.

RetroHUD is a bottom-centre heads-up display (HUD) for screen brightness, volume, keyboard illumination and software contrast. It uses Hammerspoon for drawing and behaviour, Karabiner-Elements for shortcut mapping, and BetterDisplay for software contrast adjustment.

The interface deliberately stays minimal: flat monochrome icons, a quiet grey panel, thin segmented indicators, and no permanent numerical percentage labels. The source is plain Lua, so its appearance and behaviour can be customised without rebuilding an application.

Project status: Personal macOS automation project. Shortcut handling and keyboard-backlight support can vary across Mac models and existing configurations. Test on your own hardware before relying on it.

Features
A compact bottom-centre HUD with a near-square panel, subtly rounded corners and classic segmented bars.

Screen brightness: the sun changes size and ray count at different brightness levels, with a crossed-out symbol at minimum.

Volume: a centred, rounded speaker icon that progresses from no waves to three waves, plus a mute symbol.

Keyboard backlight: a horizontal baseline and straight rays in an upward fan, crossed out at zero.

Contrast: a signed, centre-zero scale; the segments grow in non-linear steps, giving more visual detail near neutral.

Hold to adjust: repeated adjustments after a configurable initial delay.

Optional sounds: a separate, user-replaceable MP3 for each adjustment direction and mute state.

No ambient-brightness popups: the brightness HUD is displayed when RetroHUD handles a keypress, rather than when macOS adjusts brightness automatically.

Requirements
macOS with Hammerspoon

Karabiner-Elements

BetterDisplay for contrast only; it must be running, with its command-line integration enabled

Appropriate macOS Accessibility/Input Monitoring permissions for keyboard automation

The Lua script calls the BetterDisplay app at /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay. If BetterDisplay is installed somewhere else, change RetroHUD.config.betterDisplayPath.

Installation
1. Install the Lua module
Put RetroHUD.lua in:

~/.hammerspoon/RetroHUD.lua
In your existing ~/.hammerspoon/init.lua, add one line:

dofile(os.getenv('HOME') .. '/.hammerspoon/RetroHUD.lua')
Do not replace your entire init.lua. Remove or disable older bindings for F18/F19 and other overlapping RetroHUD shortcuts; duplicate listeners can cause conflicting results.

2. Add the Karabiner rule
Open Karabiner-Elements → Complex Modifications → Add Your Own Rule. Paste the content of RetroHUD-karabiner.json, save and enable it.

The supplied file is a single rule object containing description and manipulators. If you install it manually in ~/.config/karabiner/assets/complex_modifications/, Karabiner expects a different, wrapped file format, such as:

{
  "title": "RetroHUD",
  "rules": [
    { "description": "RetroHUD controls", "manipulators": [] }
  ]
}
The object in that example is only a format illustration; do not install it with an empty manipulators array. For the easiest setup, use Add Your Own Rule with the supplied JSON unchanged.

Disable any older Karabiner rule that remaps the same F1/F2 combinations.

3. Enable BetterDisplay contrast
Open BetterDisplay, verify that its software contrast slider works on your display, and enable its CLI integration. RetroHUD currently uses:

"/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay" set -displayWithMainStatus -contrast=5% -offset
This adjusts the main display by a relative amount. It is not macOS Accessibility's Display Contrast setting. You can disable BetterDisplay's own OSD if you want RetroHUD to be the only indicator.

4. Reload and preview
Select Hammerspoon → Reload Config and open the Hammerspoon Console. You should see:

RetroHUD ready: four HUDs + per-action sounds
Preview the indicators without changing system settings:

RetroHUD.preview('display')
RetroHUD.preview('volume')
RetroHUD.preview('keyboard')
RetroHUD.preview('contrast')
Default shortcuts

Shortcut

Function

Controller

F1 / F2

Screen brightness down/up

Hammerspoon

Option + F1/F2

Software contrast down/up

BetterDisplay via Hammerspoon

Command + F1/F2

Keyboard illumination down/up

macOS illumination events

F10 / F11 / F12

Native mute and volume

macOS, observed by Hammerspoon

The supplied Karabiner rule does not alter Spotlight, media play/pause or unrelated shortcuts. If another rule already uses these combinations, resolve the conflict first. Some keyboards require enabling the normal function-key mode or using Fn, depending on macOS and Karabiner settings.

Customisation guide
All changes below are made in RetroHUD.lua. Save and reload Hammerspoon afterward. The examples correspond to the current module.

A. Global behaviour
Near the top of the script:

RetroHUD.config = {
    betterDisplayPath = '/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay',
    soundsPath = os.getenv('HOME') .. '/Music/config/RetroHUD',
    soundsEnabled = true,
    soundVolume = 0.35,
    displayStep = 6.25,
    keyboardStep = 6.25,
    contrastStep = 5,
    holdDelay = 0.38,
    holdInterval = 0.16,
    hudSeconds = 1.5,
}

Variable

Effect

displayStep

Screen brightness change per adjustment, in percentage points

keyboardStep

Change to the estimated keyboard backlight level per adjustment

contrastStep

BetterDisplay contrast offset per adjustment, in percentage points

holdDelay

Seconds before a held key begins repeating

holdInterval

Seconds between repeated adjustments

hudSeconds

Time the HUD remains visible after the last update

soundsEnabled

Master switch for custom sound effects

soundVolume

Playback volume, from 0.0 (silent) to 1.0

For a slower hold-to-adjust experience, try holdDelay = 0.45 and holdInterval = 0.22.

B. Panel size, position and corner radius
Just below the configuration block:

local PANEL = 202
local CORNER = 18
local BOTTOM_GAP = 105
local CENTRE = PANEL / 2
PANEL: panel width and height in points. For example, 220 makes the HUD larger.

CORNER: radius of the panel corners. 12 is sharper; 26 is rounder.

BOTTOM_GAP: distance above the bottom of the active screen. Increase it to move the HUD up.

CENTRE: leave this as PANEL / 2 to keep elements horizontally aligned.

Note: The icons and bar placements use additional pixel coordinates inside functions such as drawSun and drawBars. Changing PANEL alone enlarges the canvas, not every icon and segment proportionally. Adjust those coordinates if you want a fully scaled design.

C. Colour and transparency
The current palette is:

local INK = {white=0.86, alpha=1.0}           -- icons and filled segments
local DIM = {white=0.39, alpha=0.68}          -- unfilled segments
local PANEL_GREY = {white=0.18, alpha=0.97}   -- panel background
white is a greyscale value from 0 (black) to 1 (white). alpha controls opacity from 0 (transparent) to 1 (opaque).

For a slightly lighter charcoal background and brighter indicators:

local INK = {white=0.96, alpha=1.0}
local DIM = {white=0.45, alpha=0.60}
local PANEL_GREY = {white=0.23, alpha=0.96}
For a custom colour instead of greyscale, use RGB values:

local INK = {red=0.90, green=0.95, blue=1.00, alpha=1.0}
Keep contrast strong enough that unfilled bars remain discernible.

D. Brightness sun: icon thresholds and sizes
Find drawSun(c, level) under -- ===== ICONS =====.

local radius = (level <= 0 and 11)
    or (level < 30 and 12)
    or (level < 60 and 17)
    or (level < 90 and 22)
    or 25

local rayCount = level < 30 and 4 or 8
This gives a crossed-out minimum at 0, then different sun sizes below 30%, below 60%, below 90%, and at 90–100%. Change the values on the left to adjust when stages switch, and the values on the right to change the icon's size. rayCount controls the number of sun rays.

Example: earlier transitions at 20%, 50%, and 80%:

local radius = (level <= 0 and 11)
    or (level < 20 and 12)
    or (level < 50 and 17)
    or (level < 80 and 22)
    or 25
E. Volume speaker: thresholds and wave count
Find drawSpeaker(c, level, muted):

if level >= 80 then waves=3
elseif level >= 60 then waves=2
elseif level >= 30 then waves=1 end
Current stages:


Volume

Icon

0% or muted

Speaker with cross

1–29%

Speaker only

30–59%

One sound wave

60–79%

Two waves

80–100%

Three waves

For earlier wave transitions, change those thresholds to 20, 45, and 70. The shift values in the same function determine the horizontal centring of each wave state; change them carefully if you customise the icon silhouette or wave spacing.

F. Keyboard backlight: ray thresholds
Find drawKeyboard(c, level):

local count = (level > 65 and 7) or (level > 30 and 5) or 3
This uses 3, 5, or 7 straight rays arranged in an upward fan, with an X instead when the estimated keyboard level reaches zero. To switch earlier, try:

local count = (level > 55 and 7) or (level > 20 and 5) or 3
The keyboard-backlight HUD uses an estimate, because Hammerspoon's illumination events do not provide a reliable hardware-level readback on every Mac. To manually realign that estimate, run:

RetroHUD.setKeyboardLevel(50)
G. Slim segmented indicators
Find drawBars(c, kind, level). For ordinary brightness, keyboard and volume bars:

local y, height = 172, 8
local count, bw, gap = 16, 7, 3
count: total segments (currently 16)

bw: width of each segment (currently 7 points)

gap: spacing between segments (currently 3 points)

height: vertical thickness (currently 8 points)

y: vertical position inside the panel

For slimmer indicators with tighter spacing, try height = 6, bw = 6, and gap = 3. The bar-centering formula automatically accommodates different counts and widths.

H. Contrast sensitivity: exponential-style thresholds
In drawBars(c, kind, level), find:

local thresholds = {1,2,3,5,8,13,21,34}
These thresholds refer to the number of contrast key adjustments away from the calibrated neutral point, not percentages. One step represents the contrastStep defined in RetroHUD.config (currently a 5-percentage-point offset request to BetterDisplay).

Small initial numbers = fine visual feedback close to neutral.

Larger outer numbers = wider adjustment range without adding more bars.

Negative adjustments light bars to the left of centre; positive adjustments light bars to the right.

For a more responsive centre and a longer tail:

local thresholds = {1,2,3,4,7,12,22,40}
For fewer overall segments, shorten this array to (for example) {1,2,4,7,12,20}. Keep it in ascending order. The bar positions use fixed offsets, so very long arrays may extend beyond the panel.

Calibration: this indicator is relative and estimated. It does not currently read changes made manually in BetterDisplay. Set BetterDisplay to neutral, then run:

RetroHUD.calibrateContrast()
Its tracked position persists across Hammerspoon reloads using hs.settings.

I. Icon shapes and layout
The four visual functions are all under -- ===== ICONS =====:

drawSun — circular sun, ray size/count, crossed-out minimum

drawSpeaker — rounded speaker, wave arcs and centring shifts

drawKeyboard — flat baseline, straight upward fan rays and zero marker

drawContrast — half-filled contrast disc

All icons are drawn with Hammerspoon canvas primitives (rect, disc, stroke, arc). No image assets or icon font installations are needed. Change their cx, cy, radii, stroke widths and point arrays to customise proportions.

Sound effects
Sound files are loaded from:

~/Music/config/RetroHUD/
Use these exact names:

brightness-up.mp3
brightness-down.mp3
contrast-up.mp3
contrast-down.mp3
keyboard-up.mp3
keyboard-down.mp3
volume-up.mp3
volume-down.mp3
volume-mute.mp3
volume-unmute.mp3
You can use the silent placeholders included with the package and replace them with your own MP3s. Missing or invalid files are ignored; they do not interrupt the HUD. Sounds play once for the start of a held brightness/contrast/keyboard keypress, rather than on every repeated adjustment. Volume changes are observed, so the sound logic groups rapid changes approximately.

After changing files, open the Hammerspoon Console and run:

RetroHUD.reloadSounds()
RetroHUD.testSound('brightness-up')
Sound playback is affected by the Mac's output device, output volume and mute state. Only distribute audio you have the rights to share.

Troubleshooting

Problem

Check

unexpected symbol near '{'

JSON was pasted into the Lua file. RetroHUD.lua must contain Lua only.

manipulators is missing or empty

In Karabiner's Add Your Own Rule, paste the single-rule object; do not paste a title/rules wrapper.

hs.brightness.watcher is nil

An obsolete script is still loaded. Current RetroHUD does not use hs.brightness.watcher.

F1/F2 or Option+F1/F2 do nothing

Check enabled Karabiner rules, function-key mode, Hammerspoon permissions and duplicate F18/F19 bindings.

Contrast changes but its bar is wrong

Set BetterDisplay to neutral and run RetroHUD.calibrateContrast(). Manual BetterDisplay changes do not resynchronise automatically.

Keyboard HUD moves but backlight does not

macOS may not accept the simulated ILLUMINATION_UP/DOWN events on that Mac/model. The displayed level is estimated.

BetterDisplay HUD appears as well

Disable BetterDisplay's own on-screen-display overlay, keeping CLI integration enabled.

Sounds are missing

Check filenames, folder, soundsEnabled, output mute and run RetroHUD.reloadSounds().

HUD appears on unexpected volume changes

Volume is monitored at the system audio-device level, so app-driven volume changes may also trigger it.

Project structure
RetroHUD-macOS/
├── RetroHUD.lua
├── RetroHUD-karabiner.json
├── README.md
└── sounds/
    ├── brightness-up.mp3
    ├── brightness-down.mp3
    ├── contrast-up.mp3
    ├── contrast-down.mp3
    ├── keyboard-up.mp3
    ├── keyboard-down.mp3
    ├── volume-up.mp3
    ├── volume-down.mp3
    ├── volume-mute.mp3
    └── volume-unmute.mp3
The sounds/ directory is optional. Runtime sound files belong in ~/Music/config/RetroHUD/, not in the repository folder unless you copy them there separately.

Design approach
RetroHUD is an experiment in quiet, legible feedback: enough visual information to confirm an action, and little else. The familiar grammar of a single icon and a segmented bar makes an everyday interaction readable at a glance. The code is intentionally editable so the user—not a fixed theme—controls its size, colours, pacing and visual thresholds.

Credits and license
Built with Hammerspoon, Karabiner-Elements and BetterDisplay. These are separate projects with their own licenses and terms.

If you want the repository to be open-source, add a LICENSE file (for example, MIT) before encouraging redistribution. The README alone does not grant reuse rights.


Search
