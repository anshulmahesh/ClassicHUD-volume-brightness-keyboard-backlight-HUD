-- RetroHUD.lua — classic Mac-style bottom-centre HUD
-- Load exactly once from ~/.hammerspoon/init.lua:
-- dofile(os.getenv('HOME') .. '/.hammerspoon/RetroHUD.lua')
-- Requires the companion Karabiner complex modification for F1/F2.

RetroHUD = RetroHUD or {}

-- Stop older copies of THIS module if it is reloaded separately.
if RetroHUD._hotkeys then
    for _, hk in ipairs(RetroHUD._hotkeys) do pcall(function() hk:delete() end) end
end
if RetroHUD._volumeMonitor then RetroHUD._volumeMonitor:stop() end
if RetroHUD._hideTimer then RetroHUD._hideTimer:stop() end
if RetroHUD._canvas then RetroHUD._canvas:delete() end
if RetroHUD._holds then
    for _, h in pairs(RetroHUD._holds) do
        if h.delay then h.delay:stop() end
        if h.repeatTimer then h.repeatTimer:stop() end
    end
end

-- ===== SETTINGS =====
RetroHUD.config = {
    betterDisplayPath = '/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay',
    soundsPath = os.getenv('HOME') .. '/Music/config/RetroHUD',
    soundsEnabled = true,
    soundVolume = 0.35,  -- 0.0 to 1.0, relative to macOS system volume
    displayStep = 6.25,
    keyboardStep = 6.25,
    contrastStep = 5,   -- BetterDisplay percentage-point offset
    holdDelay = 0.38,
    holdInterval = 0.16,
    hudSeconds = 1.5,
}

local PANEL = 202
local CORNER = 18            -- slightly sharper than the previous 23
local BOTTOM_GAP = 105       -- higher than the previous layout
local CENTRE = PANEL / 2
local INK = {white=0.86, alpha=1.0}
local DIM = {white=0.39, alpha=0.68}
local PANEL_GREY = {white=0.18, alpha=0.97}

local function clamp(value, lo, hi)
    return math.max(lo, math.min(hi, value))
end

-- Positive or negative number of 5%-point steps from calibrated neutral.
-- This is a PERSISTED ESTIMATE; BetterDisplay manual slider changes
-- cannot currently be read reliably through its CLI on this machine.
local contrastSteps = tonumber(hs.settings.get('retroHUD_signedContrastSteps')) or 0
local keyboardLevel = tonumber(hs.settings.get('retroHUD_keyboardLevel')) or 50

-- ===== SOUND ENGINE =====
local soundNames = {
    ['brightness-up'] = 'brightness-up.mp3',
    ['brightness-down'] = 'brightness-down.mp3',
    ['contrast-up'] = 'contrast-up.mp3',
    ['contrast-down'] = 'contrast-down.mp3',
    ['keyboard-up'] = 'keyboard-up.mp3',
    ['keyboard-down'] = 'keyboard-down.mp3',
    ['volume-up'] = 'volume-up.mp3',
    ['volume-down'] = 'volume-down.mp3',
    ['volume-mute'] = 'volume-mute.mp3',
    ['volume-unmute'] = 'volume-unmute.mp3',
}
local soundCache = {}

function RetroHUD.reloadSounds()
    for _, sound in pairs(soundCache) do
        if sound then pcall(function() sound:stop() end) end
    end
    soundCache = {}
end

local function playSound(name)
    if not RetroHUD.config.soundsEnabled then return end
    local filename = soundNames[name]
    if not filename then return end
    local sound = soundCache[name]
    if sound == nil then
        local path = RetroHUD.config.soundsPath .. '/' .. filename
        local ok, loaded = pcall(hs.sound.getByFile, path)
        if not ok or not loaded then
            -- Missing or invalid MP3? Silently skip, without breaking the HUD.
            return
        end
        sound = loaded
        soundCache[name] = sound
    end
    pcall(function()
        sound:stop()
        sound:volume(clamp(RetroHUD.config.soundVolume, 0, 1))
        sound:play()
    end)
end

function RetroHUD.testSound(action)
    playSound(action or 'brightness-up')
end

-- ===== CANVAS HELPERS =====
local function rect(c, x, y, w, h, colour, radius)
    c:appendElements({
        type='rectangle', action='fill',
        frame={x=x, y=y, w=w, h=h},
        roundedRectRadii={xRadius=radius or 0, yRadius=radius or 0},
        fillColor=colour,
    })
end

local function disc(c, cx, cy, radius, colour)
    c:appendElements({
        type='oval', action='fill',
        frame={x=cx-radius, y=cy-radius, w=radius*2, h=radius*2},
        fillColor=colour,
    })
end

local function stroke(c, points, colour, width, filled, roundedFill)
    c:appendElements({
        type='segments',
        action=filled and (roundedFill and 'strokeAndFill' or 'fill') or 'stroke',
        coordinates=points,
        closed=filled or false,
        fillColor=colour, strokeColor=colour,
        strokeWidth=width or 4,
        strokeCapStyle='round', strokeJoinStyle='round',
    })
end

local function arc(c, cx, cy, r, startAngle, endAngle, colour, width)
    local points = {}
    for i=0,30 do
        local a = startAngle + (endAngle-startAngle)*i/30
        points[#points+1] = {x=cx+r*math.cos(a), y=cy+r*math.sin(a)}
    end
    stroke(c, points, colour, width or 5)
end

-- ===== ICONS =====
local function drawSun(c, level)
    local cx, cy = CENTRE, 82
    local radius = (level <= 0 and 11)
        or (level < 30 and 12)
        or (level < 60 and 17)
        or (level < 90 and 22)
        or 25

    disc(c, cx, cy, radius, INK)
    local rayCount = level < 30 and 4 or 8
    for i=0,rayCount-1 do
        local a = 2*math.pi*i/rayCount - math.pi/2
        stroke(c, {
            {x=cx+(radius+8)*math.cos(a), y=cy+(radius+8)*math.sin(a)},
            {x=cx+(radius+18)*math.cos(a),y=cy+(radius+18)*math.sin(a)},
        }, INK, 4.5)
    end
    if level <= 0 then
        stroke(c, {{x=cx-29,y=cy-29},{x=cx+29,y=cy+29}}, PANEL_GREY, 9)
        stroke(c, {{x=cx-29,y=cy-29},{x=cx+29,y=cy+29}}, INK, 4)
    end
end

local function drawSpeaker(c, level, muted)
    local waves = 0
    if not muted and level > 0 then
        if level >= 70 then waves=3
        elseif level >= 40 then waves=2
        elseif level >= 10 then waves=1 end
    end

    -- Centre the whole silhouette + wave group, not just the speaker body.
    -- In the no-wave state, the speaker alone is centred.
    local shift = (muted or level <= 0) and 8
        or ({[0]=30, [1]=19, [2]=12, [3]=4})[waves]
    local x, y = CENTRE + shift, 81

    -- Thick rounded polygon imitates the soft original macOS speaker icon.
    stroke(c, {
        {x=x-49,y=y-12}, {x=x-32,y=y-12},
        {x=x-12,y=y-30}, {x=x-12,y=y+30},
        {x=x-32,y=y+12}, {x=x-49,y=y+12},
    }, INK, 5.5, true, true)

    if muted or level <= 0 then
        stroke(c, {{x=x+3,y=y-18},{x=x+33,y=y+18}}, INK, 5)
        stroke(c, {{x=x+33,y=y-18},{x=x+3,y=y+18}}, INK, 5)
        return
    end
    for i=1,waves do
        arc(c, x-12, y, 23+(i-1)*15,
            -math.pi/3, math.pi/3, INK, 6)
    end
end

local function drawKeyboard(c, level)
    local cx, baseline = CENTRE, 122
    -- One straight baseline: no rings or semicircular strokes.
    stroke(c, {{x=cx-44,y=baseline},{x=cx+44,y=baseline}}, INK, 5)

    if level <= 0 then
        -- Crossout at zero keyboard brightness.
        stroke(c, {{x=cx-15,y=baseline-53},{x=cx+15,y=baseline-23}}, INK, 4.5)
        stroke(c, {{x=cx+15,y=baseline-53},{x=cx-15,y=baseline-23}}, INK, 4.5)
        return
    end

    -- Straight radial RAYS arranged in an upwards semicircular fan.
    local count = (level > 65 and 7) or (level > 30 and 5) or 3
    local indexes = (count==7 and {1,2,3,4,5,6,7})
        or (count==5 and {2,3,4,5,6}) or {3,4,5}
    local rayCentreY = baseline-10
    for _,i in ipairs(indexes) do
        local a = math.pi+0.15 + (math.pi-0.30)*(i-1)/6
        stroke(c, {
            {x=cx+24*math.cos(a), y=rayCentreY+24*math.sin(a)},
            {x=cx+40*math.cos(a), y=rayCentreY+40*math.sin(a)},
        }, INK, 4.5)
    end
end

local function drawContrast(c)
    local cx, cy, r = CENTRE, 82, 33
    disc(c, cx, cy, r, INK)
    local points = {{x=cx,y=cy-r}}
    for i=0,40 do
        local a = -math.pi/2 + math.pi*i/40
        points[#points+1] = {x=cx+r*math.cos(a),y=cy+r*math.sin(a)}
    end
    points[#points+1] = {x=cx,y=cy+r}
    stroke(c, points, PANEL_GREY, 0, true)
end

-- ===== SEGMENTED BARS =====
local function drawBars(c, kind, level)
    local y, height = 172, 8
    if kind == 'contrast' then
        -- Eight segments per side, densely spaced near neutral.
        -- Larger adjustments fill the far segments progressively more slowly.
        local thresholds = {1,2,3,5,8,13,21,34}
        local active = 0
        for _,threshold in ipairs(thresholds) do
            if math.abs(level) >= threshold then active=active+1 end
        end
        rect(c, CENTRE-1, y-5, 2, height+10, INK)
        for i=1,#thresholds do
            rect(c, CENTRE-16-(i-1)*11, y, 7, height,
                (level < 0 and i<=active) and INK or DIM)
            rect(c, CENTRE+9+(i-1)*11, y, 7, height,
                (level > 0 and i<=active) and INK or DIM)
        end
    else
        -- 16 thin bars instead of 18: one removed at each end.
        local count, bw, gap = 16, 7, 3
        local start = (PANEL-(count*bw+(count-1)*gap))/2
        local filled = math.floor(clamp(level or 0,0,100)*count/100+0.5)
        for i=1,count do
            rect(c, start+(i-1)*(bw+gap), y, bw, height,
                i<=filled and INK or DIM)
        end
    end
end

local function show(kind, level, muted)
    if RetroHUD._hideTimer then RetroHUD._hideTimer:stop() end
    if RetroHUD._canvas then RetroHUD._canvas:delete() end
    local screen = hs.screen.mainScreen():frame()
    local c = hs.canvas.new({
        x=screen.x+(screen.w-PANEL)/2,
        y=screen.y+screen.h-PANEL-BOTTOM_GAP,
        w=PANEL, h=PANEL,
    })
    rect(c,0,0,PANEL,PANEL,PANEL_GREY,CORNER)
    if kind=='contrast' then drawContrast(c)
    elseif kind=='display' then drawSun(c,level)
    elseif kind=='keyboard' then drawKeyboard(c,level)
    elseif kind=='volume' then drawSpeaker(c,level,muted) end
    drawBars(c,kind,level)
    c:behavior({'canJoinAllSpaces','fullScreenAuxiliary'})
    c:show()
    c:bringToFront(true)
    RetroHUD._canvas = c
    RetroHUD._hideTimer = hs.timer.doAfter(RetroHUD.config.hudSeconds,function()
        if RetroHUD._canvas==c then c:delete(); RetroHUD._canvas=nil end
        RetroHUD._hideTimer=nil
    end)
end

-- ===== CONTROLLERS =====
local function adjustContrast(up, firstPress)
    local delta = up and RetroHUD.config.contrastStep or -RetroHUD.config.contrastStep
    local command = string.format('%q set -displayWithMainStatus -contrast=%d%% -offset',
        RetroHUD.config.betterDisplayPath, delta)
    local output, ok = hs.execute(command)
    if not ok then
        print('RetroHUD: BetterDisplay contrast failed: '..tostring(output))
        return
    end
    contrastSteps = contrastSteps + (up and 1 or -1)
    hs.settings.set('retroHUD_signedContrastSteps',contrastSteps)
    show('contrast',contrastSteps)
    if firstPress then playSound(up and 'contrast-up' or 'contrast-down') end
end

local function adjustDisplay(up, firstPress)
    local old = hs.brightness.get()
    if type(old) ~= 'number' then return end
    local new = clamp(old+(up and RetroHUD.config.displayStep or -RetroHUD.config.displayStep),0,100)
    if math.abs(new-old) < 0.1 then show('display',old); return end
    if hs.brightness.set(math.floor(new+0.5)) then
        show('display',hs.brightness.get() or new)
        if firstPress then playSound(up and 'brightness-up' or 'brightness-down') end
    end
end

local function adjustKeyboard(up, firstPress)
    local key = up and 'ILLUMINATION_UP' or 'ILLUMINATION_DOWN'
    hs.eventtap.event.newSystemKeyEvent(key,true):post()
    hs.eventtap.event.newSystemKeyEvent(key,false):post()
    keyboardLevel = clamp(keyboardLevel+(up and RetroHUD.config.keyboardStep
        or -RetroHUD.config.keyboardStep),0,100)
    hs.settings.set('retroHUD_keyboardLevel', keyboardLevel)
    show('keyboard',keyboardLevel)
    if firstPress then playSound(up and 'keyboard-up' or 'keyboard-down') end
end

-- ===== PRESS-AND-HOLD WITH ONE SOUND PER PRESS =====
RetroHUD._hotkeys = {}
RetroHUD._holds = {}
local function bindHold(modifiers, key, id, action)
    local function release()
        local h = RetroHUD._holds[id]
        if not h then return end
        if h.delay then h.delay:stop() end
        if h.repeatTimer then h.repeatTimer:stop() end
        RetroHUD._holds[id] = nil
    end
    local function press()
        if RetroHUD._holds[id] then return end
        local h = {}
        RetroHUD._holds[id] = h
        action(true)
        h.delay = hs.timer.doAfter(RetroHUD.config.holdDelay,function()
            if RetroHUD._holds[id] ~= h then return end
            h.repeatTimer = hs.timer.doEvery(RetroHUD.config.holdInterval,function()
                action(false)
            end)
        end)
    end
    -- Karabiner must preserve key-up (do not set to.repeat=false).
    RetroHUD._hotkeys[#RetroHUD._hotkeys+1] =
        hs.hotkey.bind(modifiers,key,press,release,function() end)
end

bindHold({},'F18','contrastDown',function(first) adjustContrast(false,first) end)
bindHold({},'F19','contrastUp',function(first) adjustContrast(true,first) end)
bindHold({'shift'},'F18','displayDown',function(first) adjustDisplay(false,first) end)
bindHold({'shift'},'F19','displayUp',function(first) adjustDisplay(true,first) end)
bindHold({'ctrl'},'F18','keyboardDown',function(first) adjustKeyboard(false,first) end)
bindHold({'ctrl'},'F19','keyboardUp',function(first) adjustKeyboard(true,first) end)

-- ===== VOLUME: OBSERVE NATIVE MEDIA KEYS, DO NOT REMAP =====
-- Do NOT monitor ambient screen brightness: no HUD for automatic changes.
local lastVolume, lastMuted, lastUID = nil,nil,nil
local lastVolumeChange = -999
RetroHUD._volumeMonitor = hs.timer.doEvery(0.15,function()
    local device = hs.audiodevice.defaultOutputDevice()
    if not device then return end
    local volume = device:outputVolume()
    local muted = device:outputMuted()
    local uid = device:uid()
    if uid ~= lastUID then
        lastUID, lastVolume, lastMuted = uid, volume, muted
        return
    end
    local volumeChanged = type(volume)=='number' and type(lastVolume)=='number'
        and math.abs(volume-lastVolume)>=0.5
    local muteChanged = type(muted)=='boolean' and muted ~= lastMuted
    if volumeChanged or muteChanged then
        show('volume',type(volume)=='number' and volume or 0, muted==true)
        -- Sound once at the start of a rapid volume-change sequence (hold).
        local now = hs.timer.secondsSinceEpoch()
        if muteChanged then
            playSound(muted and 'volume-mute' or 'volume-unmute')
        elseif now - lastVolumeChange > 0.45 then
            playSound(volume > lastVolume and 'volume-up' or 'volume-down')
        end
        lastVolumeChange=now
    end
    lastVolume,lastMuted = volume,muted
end)

-- ===== CONSOLE UTILITIES =====
function RetroHUD.preview(kind)
    local example={contrast=-4,display=60,keyboard=45,volume=75}
    kind = example[kind] and kind or 'contrast'
    show(kind,example[kind],false)
end
function RetroHUD.calibrateContrast(steps)
    -- Manually put BetterDisplay contrast at neutral BEFORE calling.
    contrastSteps = tonumber(steps) or 0
    hs.settings.set('retroHUD_signedContrastSteps',contrastSteps)
    show('contrast',contrastSteps)
end
function RetroHUD.setKeyboardLevel(level)
    keyboardLevel=clamp(tonumber(level) or 0,0,100)
    hs.settings.set('retroHUD_keyboardLevel',keyboardLevel)
    show('keyboard',keyboardLevel)
end
print('RetroHUD ready: four HUDs + per-action sounds')
