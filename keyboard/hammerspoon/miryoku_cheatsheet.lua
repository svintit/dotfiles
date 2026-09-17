-- Miryoku cheat sheet overlay.
-- Shows the current layer's split keymap. Appears while a modifier or a thumb layer is held,
-- highlights the held modifier keys and the key being pressed, and shows the resulting chord.
-- Data: ~/.hammerspoon/miryoku_layers.json (generated from the Piantor .vil).
-- Karabiner thumb rules call `hs -c "miryokuLayer('nav')"` on hold and `miryokuLayer('base')` on release.

local M = {}

local dataPath = os.getenv("HOME") .. "/.hammerspoon/miryoku_layers.json"

local layers, order, physical
local canvas
local pinned = false
local current = "base"
local hideTimer
local heldMods = {}           -- { cmd=true, alt=true, ... }
local pressedKey = nil        -- hs.keycodes name of the key currently down
local lastChord = ""
local externalPressed = {}
local externalPressedName = nil
local externalLayerActive = false
local vialTask
local vialBuffer = ""
local vialStatus = "STARTING"
local pinComboHeld = false
local vialPaused = false
local vialRestartTimer
local manualMonitorPaused = false
local vialWindowActive = false
local vialWindowTimer
local vialTabCheckTask

local KEY, GAP, PAD = 40, 5, 14
local HALF_W = 6 * KEY + 5 * GAP
local SPLIT = 30
local TITLE_H = 24
local CHORD_H = 30
local STAGGER_H = 12
local THUMB_DROP = 11
local leftStagger = { 12, 12, 6, 0, 6, 12 }
local rightStagger = { 12, 6, 0, 6, 12, 12 }
local leftThumbX = { 2, 5, 8 }
local rightThumbX = { -8, -5, -2 }
local leftThumbY = { 0, 5, 11 }
local rightThumbY = { 11, 5, 0 }
local W = PAD * 2 + HALF_W * 2 + SPLIT
local H = PAD * 2 + TITLE_H + 3 * (KEY + GAP) + KEY + 20 + CHORD_H
    + STAGGER_H + THUMB_DROP

local colors = {
    bg        = { red = 0.07, green = 0.08, blue = 0.10, alpha = 0.90 },
    border    = { red = 1, green = 1, blue = 1, alpha = 0.08 },
    key       = { red = 0.17, green = 0.18, blue = 0.22, alpha = 0.96 },
    keyEdge   = { red = 1, green = 1, blue = 1, alpha = 0.07 },
    keyDead   = { red = 1, green = 1, blue = 1, alpha = 0.04 },
    keyMod    = { red = 0.24, green = 0.20, blue = 0.34, alpha = 0.96 },
    thumb     = { red = 0.12, green = 0.24, blue = 0.30, alpha = 0.96 },
    held      = { red = 0.55, green = 0.35, blue = 0.85, alpha = 1 },
    pressed   = { red = 0.95, green = 0.60, blue = 0.20, alpha = 1 },
    text      = { red = 0.94, green = 0.94, blue = 0.96, alpha = 1 },
    dim       = { red = 0.50, green = 0.52, blue = 0.58, alpha = 1 },
    modText   = { red = 0.78, green = 0.66, blue = 0.98, alpha = 1 },
    layerText = { red = 0.38, green = 0.82, blue = 0.86, alpha = 1 },
    title     = { red = 0.97, green = 0.80, blue = 0.35, alpha = 1 },
    tabActive = { red = 0.97, green = 0.80, blue = 0.35, alpha = 0.16 },
    home      = { red = 1, green = 1, blue = 1, alpha = 0.35 },
}

local modNames = { Cmd = true, Opt = true, Ctrl = true, Shift = true }
local layerDisplay = { media = "Media", nav = "Nav", mouse = "Mouse", sym = "Sym", num = "Num", fun = "Fun" }

local FONT = "JetBrainsMonoNF-Regular"
local modSymbol = { cmd = "Cmd", alt = "Opt", ctrl = "Ctrl", shift = "Shift" }
local modWord = { cmd = "cmd", alt = "alt", ctrl = "ctrl", shift = "shift" }
local symbolWord = { Cmd = "cmd", Opt = "alt", Ctrl = "ctrl", Shift = "shift" }
local modOrder = { "ctrl", "alt", "shift", "cmd" }

local function load()
    local f = io.open(dataPath, "r")
    if not f then hs.alert.show("miryoku_layers.json missing"); return false end
    local raw = f:read("*a"); f:close()
    local d = hs.json.decode(raw)
    layers, order, physical = d.layers, d.order, d.physical
    return true
end

local function labelText(cell)
    if type(cell) == "table" then return cell.tap, cell.hold end
    return cell, nil
end

local function anyModHeld()
    for _, v in pairs(heldMods) do if v then return true end end
    return false
end

local function chordText()
    local parts = {}
    for _, m in ipairs(modOrder) do
        if heldMods[m] then parts[#parts + 1] = modWord[m] end
    end
    local key = externalLayerActive and externalPressedName or pressedKey
    if key then
        if key == "space" then key = "Space" elseif #key == 1 then key = key:upper() end
        parts[#parts + 1] = key
    end
    return table.concat(parts, " ")
end

local function highlightFor(cell, physKey, matrixKey)
    if externalPressed[matrixKey] then return colors.pressed end
    if not externalLayerActive and physKey ~= "" and pressedKey == physKey then return colors.pressed end
    local _, hold = labelText(cell)
    if hold then
        for m, sym in pairs(modSymbol) do
            if heldMods[m] and hold == sym then return colors.held end
        end
    end
    return nil
end

local function addKey(c, x, y, cell, physKey, matrixKey, opts)
    opts = opts or {}
    local tap, hold = labelText(cell)
    local tapIsMod = modNames[tap] ~= nil
    local dead = (tap == nil or tap == "") and not hold
    local fill = colors.key
    if opts.thumb then fill = colors.thumb
    elseif hold or tapIsMod then fill = colors.keyMod end
    local highlight = highlightFor(cell, physKey, matrixKey)
    fill = highlight or fill

    if dead and not highlight then
        c:appendElements({
            type = "rectangle", action = "stroke", strokeColor = colors.keyDead, strokeWidth = 1,
            roundedRectRadii = { xRadius = 8, yRadius = 8 },
            frame = { x = x + 0.5, y = y + 0.5, w = KEY - 1, h = KEY - 1 },
        })
        return
    end

    c:appendElements({
        type = "rectangle", action = "fill", fillColor = fill,
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
        frame = { x = x, y = y, w = KEY, h = KEY },
    })
    c:appendElements({
        type = "rectangle", action = "stroke", strokeColor = colors.keyEdge, strokeWidth = 1,
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
        frame = { x = x + 0.5, y = y + 0.5, w = KEY - 1, h = KEY - 1 },
    })
    if opts.activeLayer and (tap == opts.activeLayer or hold == opts.activeLayer) then
        c:appendElements({
            type = "rectangle", action = "stroke", strokeColor = colors.title, strokeWidth = 2,
            roundedRectRadii = { xRadius = 8, yRadius = 8 },
            frame = { x = x + 1, y = y + 1, w = KEY - 2, h = KEY - 2 },
        })
    end
    if opts.home then
        c:appendElements({
            type = "circle", action = "fill", fillColor = colors.home,
            center = { x = x + KEY / 2, y = y + 5 }, radius = 1.5,
        })
    end

    if tap and tap ~= "" then
        local size = (#tap > 4) and 10 or ((#tap > 3) and 11 or ((#tap > 1) and 13 or 18))
        local color = colors.text
        if tapIsMod then color = colors.modText
        elseif layerDisplay[tap:lower()] == tap and not hold then color = colors.layerText end
        c:appendElements({
            type = "text", text = tap,
            textFont = FONT, textSize = size, textColor = color, textAlignment = "center",
            frame = { x = x, y = y + (hold and 2 or (KEY - size) / 2 - 3), w = KEY, h = size + 6 },
        })
    end
    if hold then
        local holdWord = symbolWord[hold] or hold
        local color = symbolWord[hold] and colors.modText or colors.layerText
        c:appendElements({
            type = "text", text = holdWord,
            textFont = FONT, textSize = symbolWord[hold] and 10 or 11, textColor = color, textAlignment = "center",
            frame = { x = x, y = y + KEY - 17, w = KEY, h = 15 },
        })
    end
end

local function textWidth(text, size)
    return #text * size * 0.62
end

local function addLegend(c, x, y)
    local items = {
        { colors.keyMod, "mod" }, { colors.thumb, "layer" },
        { colors.held, "held" }, { colors.pressed, "pressed" },
    }
    for _, item in ipairs(items) do
        c:appendElements({
            type = "rectangle", action = "fill", fillColor = item[1],
            roundedRectRadii = { xRadius = 2, yRadius = 2 },
            frame = { x = x, y = y + 3, w = 8, h = 8 },
        })
        local w = textWidth(item[2], 10)
        c:appendElements({
            type = "text", text = item[2],
            textFont = FONT, textSize = 10, textColor = colors.dim,
            frame = { x = x + 12, y = y - 1, w = w + 4, h = 14 },
        })
        x = x + 12 + w + 14
    end
end

local function build(layerName)
    local layer = layers[layerName] or layers.base
    local screen = hs.screen.mainScreen():frame()
    local ox = screen.x + (screen.w - W) / 2
    local oy = screen.y + screen.h - H - 16

    if canvas then canvas:delete() end
    canvas = hs.canvas.new({ x = ox, y = oy, w = W, h = H })
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    canvas:appendElements({
        type = "rectangle", action = "fill", fillColor = colors.bg,
        roundedRectRadii = { xRadius = 14, yRadius = 14 },
        frame = { x = 0, y = 0, w = W, h = H },
    })
    canvas:appendElements({
        type = "rectangle", action = "stroke", strokeColor = colors.border, strokeWidth = 1,
        roundedRectRadii = { xRadius = 14, yRadius = 14 },
        frame = { x = 0.5, y = 0.5, w = W - 1, h = H - 1 },
    })

    local tx = PAD
    for _, name in ipairs(order) do
        local label = name:upper()
        local w = textWidth(label, 11) + 14
        if name == layerName then
            canvas:appendElements({
                type = "rectangle", action = "fill", fillColor = colors.tabActive,
                roundedRectRadii = { xRadius = 8, yRadius = 8 },
                frame = { x = tx, y = PAD - 4, w = w, h = 18 },
            })
        end
        canvas:appendElements({
            type = "text", text = label,
            textFont = FONT, textSize = 11, textAlignment = "center",
            textColor = (name == layerName) and colors.title or colors.dim,
            frame = { x = tx, y = PAD - 3, w = w, h = 16 },
        })
        tx = tx + w + 4
    end
    canvas:appendElements({
        type = "text", text = "fun + Q  pin",
        textFont = FONT, textSize = 10, textColor = colors.dim, textAlignment = "right",
        frame = { x = W - PAD - 165, y = PAD - 2, w = 165, h = 16 },
    })

    local activeLayer = layerName ~= "base" and layerDisplay[layerName] or nil
    local top = PAD + TITLE_H
    local rx0 = PAD + HALF_W + SPLIT
    for r = 1, 3 do
        local rowY = top + (r - 1) * (KEY + GAP)
        for c = 1, 6 do
            local home = (r == 2 and c == 5)
            addKey(canvas, PAD + (c - 1) * (KEY + GAP), rowY + leftStagger[c],
                layer.left[r][c], physical.left[r][c],
                string.format("%d,%d", r - 1, c - 1), { home = home, activeLayer = activeLayer })
            addKey(canvas, rx0 + (c - 1) * (KEY + GAP), rowY + rightStagger[c],
                layer.right[r][c], physical.right[r][c],
                string.format("%d,%d", r + 3, 6 - c), { home = (r == 2 and c == 2), activeLayer = activeLayer })
        end
    end
    local ty = top + 3 * (KEY + GAP) + STAGGER_H + 2
    for i = 1, 3 do
        local leftX = PAD + (2 + i) * (KEY + GAP) + leftThumbX[i]
        local rightX = rx0 + (i - 1) * (KEY + GAP) + rightThumbX[i]
        local leftY = ty + leftThumbY[i]
        local rightY = ty + rightThumbY[i]
        addKey(canvas, leftX, leftY, layer.lthumb[i], physical.lthumb[i],
            string.format("3,%d", i + 2), { thumb = true, activeLayer = activeLayer })
        addKey(canvas, rightX, rightY, layer.rthumb[i], physical.rthumb[i],
            string.format("7,%d", 6 - i), { thumb = true, activeLayer = activeLayer })
    end

    local footY = H - PAD - CHORD_H + 3
    addLegend(canvas, PAD, footY + 8)
    local chord = chordText()
    if chord ~= "" then lastChord = chord end
    canvas:appendElements({
        type = "text", text = lastChord,
        textFont = FONT, textSize = 18, textColor = colors.pressed, textAlignment = "center",
        frame = { x = 0, y = footY, w = W, h = CHORD_H },
    })
    canvas:show()
end

local function hide()
    if canvas then canvas:hide() end
    lastChord = ""
end

local shortcutFired = false

local function shouldShow()
    if pinned then return true end
    if shortcutFired then return false end
    local splitModifierHeld = next(externalPressed) ~= nil and anyModHeld()
    return externalLayerActive or splitModifierHeld
end

local SHOW_DELAY = 0.55
local showTimer
local redrawPending = false
local function scheduleRedraw()
    if redrawPending then return end
    redrawPending = true
    hs.timer.doAfter(0, function()
        redrawPending = false
        if shouldShow() then build(current) end
    end)
end

local function isVisible()
    return canvas ~= nil and canvas:isShowing()
end

local function refresh()
    if hideTimer then hideTimer:stop(); hideTimer = nil end
    if shouldShow() then
        if isVisible() then
            scheduleRedraw()
        elseif not showTimer then
            showTimer = hs.timer.doAfter(SHOW_DELAY, function()
                showTimer = nil
                if shouldShow() then build(current) end
            end)
        end
    else
        if showTimer then showTimer:stop(); showTimer = nil end
        hideTimer = hs.timer.doAfter(0.25, hide)
    end
end

M.layerLog = {}
-- Global on purpose: Karabiner calls it via `hs -c "miryokuLayer('nav')"`.
function miryokuLayer(name)
    current = name or "base"
    table.insert(M.layerLog, string.format("%.2f %s", hs.timer.secondsSinceEpoch() % 1000, current))
    if #M.layerLog > 20 then table.remove(M.layerLog, 1) end
    refresh()
end

local thumbLayers = {
    ["3,3"] = { name = "media", layer = 3 },
    ["3,4"] = { name = "nav", layer = 1 },
    ["3,5"] = { name = "mouse", layer = 2 },
    ["7,3"] = { name = "fun", layer = 6 },
    ["7,4"] = { name = "num", layer = 4 },
    ["2,1"] = { name = "num", layer = 4 },
    ["7,5"] = { name = "sym", layer = 5 },
}

local function matrixPhysicalName(matrixKey)
    local row, col = matrixKey:match("^(%d+),(%d+)$")
    row, col = tonumber(row), tonumber(col)
    if row <= 2 then return physical.left[row + 1][col + 1] end
    if row >= 4 and row <= 6 then return physical.right[row - 3][6 - col] end
    return nil
end

local function layerCell(layerName, matrixKey)
    local layer = layers[layerName]
    if not layer then return nil end
    local row, col = matrixKey:match("^(%d+),(%d+)$")
    row, col = tonumber(row), tonumber(col)
    if row <= 2 then return layer.left[row + 1][col + 1] end
    if row == 3 then return layer.lthumb[col - 2] end
    if row <= 6 then return layer.right[row - 3][6 - col] end
    return layer.rthumb[6 - col]
end

local function cellMapped(cell)
    local tap, hold = labelText(cell)
    return (tap ~= nil and tap ~= "") or (hold ~= nil and hold ~= "")
end

local function handleVialState(line)
    local status = line:match("^STATUS%s+(.+)$")
    if status then
        vialStatus = status
        return
    end
    local state = line:match("^STATE%s+(.+)$")
    if not state then return end
    externalPressed = {}
    externalPressedName = nil
    local selectedLayer
    local otherKeys = {}
    if state ~= "-" then
        for matrixKey in state:gmatch("[^;]+") do
            externalPressed[matrixKey] = true
            local layer = thumbLayers[matrixKey]
            if layer and (not selectedLayer or layer.layer > selectedLayer.layer) then
                selectedLayer = layer
            elseif not layer then
                otherKeys[#otherKeys + 1] = matrixKey
                externalPressedName = matrixPhysicalName(matrixKey) or externalPressedName
            end
        end
    end

    local pinComboDown = externalPressed["7,3"] and externalPressed["0,1"]
    if pinComboDown and not pinComboHeld then M.toggle() end
    pinComboHeld = pinComboDown

    externalLayerActive = selectedLayer ~= nil
    current = selectedLayer and selectedLayer.name or "base"

    if not selectedLayer and not anyModHeld() then
        shortcutFired = false
    elseif selectedLayer then
        for _, matrixKey in ipairs(otherKeys) do
            if cellMapped(layerCell(current, matrixKey)) then shortcutFired = true end
        end
    end
    refresh()
end

local function startVialMonitor()
    if vialPaused then return end
    local python = hs.configdir .. "/vial-hid-venv/bin/python"
    local script = hs.configdir .. "/vial_matrix_monitor.py"
    vialTask = hs.task.new(python, function()
        vialTask = nil
        externalPressed = {}
        externalPressedName = nil
        externalLayerActive = false
        current = "base"
        refresh()
        if not vialPaused then
            vialRestartTimer = hs.timer.doAfter(1, startVialMonitor)
        end
    end, function(_, stdout)
        vialBuffer = vialBuffer .. (stdout or "")
        while true do
            local newline = vialBuffer:find("\n", 1, true)
            if not newline then break end
            handleVialState(vialBuffer:sub(1, newline - 1))
            vialBuffer = vialBuffer:sub(newline + 1)
        end
        return true
    end, { script })
    vialTask:start()
end

function M.capture(path)
    if canvas then canvas:imageFromCanvas():saveToFile(path) end
    return path
end

local function applyMonitorState()
    local shouldPause = manualMonitorPaused or vialWindowActive
    if shouldPause then
        vialPaused = true
        vialStatus = vialWindowActive and "PAUSED FOR VIAL" or "PAUSED"
        if vialRestartTimer then vialRestartTimer:stop(); vialRestartTimer = nil end
        if vialTask and vialTask:isRunning() then vialTask:terminate() end
        return
    end

    vialPaused = false
    vialStatus = "STARTING"
    if not vialTask or not vialTask:isRunning() then
        vialTask = nil
        startVialMonitor()
    end
end

local function updateVialWindowState()
    if vialTabCheckTask and vialTabCheckTask:isRunning() then return end
    local script = 'tell application "Google Chrome" to get title of every tab of every window'
    vialTabCheckTask = hs.task.new("/usr/bin/osascript", function(exitCode, stdout)
        vialTabCheckTask = nil
        local active = exitCode == 0
            and (stdout or ""):lower():find("vial web", 1, true) ~= nil
        if active ~= vialWindowActive then
            vialWindowActive = active
            applyMonitorState()
        elseif not active and not vialTask then
            applyMonitorState()
        end
    end, { "-e", script })
    vialTabCheckTask:start()
end

M.updateVialWindowState = updateVialWindowState
function M.pauseMonitor()
    manualMonitorPaused = true
    applyMonitorState()
end

function M.resumeMonitor()
    manualMonitorPaused = false
    applyMonitorState()
end

function M.toggleMonitor()
    manualMonitorPaused = not manualMonitorPaused
    applyMonitorState()
    hs.alert.show(manualMonitorPaused and "Piantor monitor paused" or "Piantor monitor automatic")
end
_G.miryokuVialState = handleVialState

function M.toggle()
    pinned = not pinned
    refresh()
end

function M.snapshot(path, layerName)
    build(layerName or current)
    local img = canvas:imageFromCanvas()
    img:saveToFile(path)
    if not shouldShow() then hide() end
    return path
end

local flagsTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
    local f = e:getFlags()
    heldMods = { cmd = f.cmd, alt = f.alt, ctrl = f.ctrl, shift = f.shift }
    if not anyModHeld() then
        pressedKey = nil
        if not externalLayerActive then shortcutFired = false end
    end
    refresh()
    return false
end)

local keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp }, function(e)
    local name = hs.keycodes.map[e:getKeyCode()]
    if e:getType() == hs.eventtap.event.types.keyDown then
        if pinned and name == "escape" then M.toggle(); return true end
        pressedKey = name
        if anyModHeld() then shortcutFired = true end
    elseif pressedKey == name then
        pressedKey = nil
    end
    if shouldShow() or isVisible() then refresh() end
    return false
end)

flagsTap:start()
keyTap:start()

if load() then
    hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "p", M.toggle)
    hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "v", M.toggleMonitor)
    hs.urlevent.bind("miryoku", function(_, params) miryokuLayer(params.layer) end)
    updateVialWindowState()
    vialWindowTimer = hs.timer.doEvery(1, updateVialWindowState)
end

function miryokuDebug()
    return hs.inspect({ current = current, pinned = pinned, held = heldMods, pressed = pressedKey,
        externalPressed = externalPressed, externalPressedName = externalPressedName,
        externalLayerActive = externalLayerActive, vialStatus = vialStatus, vialPaused = vialPaused,
        manualMonitorPaused = manualMonitorPaused, vialWindowActive = vialWindowActive,
        vialWindowTimerRunning = vialWindowTimer and vialWindowTimer:running() or false,
        vialTaskRunning = vialTask and vialTask:isRunning() or false,
        canvasShowing = canvas and canvas:isShowing() or false, frame = canvas and canvas:frame(),
        flagsTap = flagsTap:isEnabled(), keyTap = keyTap:isEnabled() })
end

return M
