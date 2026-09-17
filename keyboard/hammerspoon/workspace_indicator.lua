local model = require("workspace_slots")
local M = {}

local AEROSPACE = "/opt/homebrew/bin/aerospace"
local STATE_FILE = hs.configdir .. "/workspace-slots.json"
local SELECTED_MONITOR_FILE = hs.configdir .. "/workspace-selected-monitor"
local CONNECTED_MONITORS_FILE = hs.configdir .. "/workspace-connected-monitors"
local URL_EVENT = "aerospace-workspace-slot"
local MIN_SLOTS = 3
local COMMAND_TIMEOUT = 5
local LIST_ARGS = {
    "list-workspaces", "--all", "--format",
    "%{workspace} %{monitor-id} %{monitor-name} %{monitor-appkit-nsscreen-screens-id} %{workspace-is-focused} %{workspace-is-visible}",
    "--json",
}

local running = false
local generation = 0
local state
local stateFileContent
local views = {}
local available = false
local queue = {}
local busy = false
local refreshPending = false
local tasks = {}
local canvases = {}
local windowCounts = {}
local shutdownHook
local previousShutdown
local queryCount = 0
local renderCount = 0
local actionCount = 0
local lastError
local pump
local selectionSyncTimer
local renderViews

local function reportError(message)
    message = tostring(message)
    if lastError ~= message then
        print("[workspace_indicator] " .. message)
    end
    lastError = message
end

local function decode(text)
    local ok, value = pcall(hs.json.decode, text)
    if not ok or type(value) ~= "table" then
        return nil, "Invalid JSON data"
    end
    return value
end
local function selectedMonitorName()
    local file = io.open(SELECTED_MONITOR_FILE, "r")
    if not file then return nil end
    local value = file:read("*l")
    file:close()
    return value and value:match("^([^|]+)") or nil
end
local function writeTextFile(path, text)
    local temporary = path .. ".tmp"
    local file, message = io.open(temporary, "w")
    if not file then return false, message end
    local written, writeError = file:write(text)
    local closed, closeError = file:close()
    if not written or not closed then
        os.remove(temporary)
        return false, writeError or closeError
    end
    local renamed, renameError = os.rename(temporary, path)
    if not renamed then
        os.remove(temporary)
        return false, renameError
    end
    return true
end

local function loadState()
    local file, message, code = io.open(STATE_FILE, "r")
    if not file then
        if code == 2 then stateFileContent = nil; return model.newState() end
        return nil, message
    end
    local content = file:read("*a")
    file:close()
    local loaded, err = decode(content or "")
    if not loaded then return nil, err end
    local valid, reason = model.validate(loaded)
    if not valid then return nil, reason end
    stateFileContent = content
    return loaded
end

local function saveState(value)
    local existing, readError, readCode = io.open(STATE_FILE, "r")
    local currentContent
    if existing then
        currentContent = existing:read("*a")
        existing:close()
    elseif readCode ~= 2 then
        return false, readError
    end
    if currentContent ~= stateFileContent then
        return false, "Workspace slot state changed externally; reload the indicator before saving"
    end
    local ok, encoded = pcall(hs.json.encode, value, true)
    if not ok or type(encoded) ~= "string" then
        return false, "Cannot encode workspace slots"
    end
    local temporary = STATE_FILE .. ".tmp"
    local file, message = io.open(temporary, "w")
    if not file then return false, message end
    local written, writeError = file:write(encoded .. "\n")
    local closed, closeError = file:close()
    if not written or not closed then
        os.remove(temporary)
        return false, writeError or closeError
    end
    local renamed, renameError = os.rename(temporary, STATE_FILE)
    if not renamed then
        os.remove(temporary)
        return false, renameError
    end
    stateFileContent = encoded .. "\n"
    return true
end

local function runCommand(arguments, callback)
    local token = generation
    local completed = false
    local task
    local timer
    local function finish(err, output)
        if completed then return end
        completed = true
        if timer then timer:stop() end
        if task then tasks[task] = nil end
        if running and token == generation then callback(err, output or "") end
    end
    task = hs.task.new(AEROSPACE, function(code, output, stderr)
        if code ~= 0 then
            finish(arguments[1] .. ": " .. tostring(stderr ~= "" and stderr or code))
        else
            finish(nil, output)
        end
    end, arguments)
    if not task then finish("Cannot create AeroSpace task"); return end
    tasks[task] = true
    if not task:start() then finish("Cannot start AeroSpace task"); return end
    timer = hs.timer.doAfter(COMMAND_TIMEOUT, function()
        finish(arguments[1] .. " timed out")
        task:terminate()
    end)
    tasks[task] = timer
end

local function runSteps(steps, callback, index)
    index = index or 1
    if index > #steps then callback(); return end
    runCommand(steps[index], function(err)
        if err then callback(err); return end
        runSteps(steps, callback, index + 1)
    end)
end


local function readSnapshot(callback)
    queryCount = queryCount + 1
    runCommand(LIST_ARGS, function(err, output)
        if err then callback(err); return end
        local entries, decodeError = decode(output)
        if not entries then callback(decodeError); return end
        local snapshot = {screens = {}, rows = {}, owners = {}, visible = {}}
        local nativeScreens = hs.screen.allScreens()
        for index, screen in ipairs(nativeScreens) do
            snapshot.screens[index] = {
                uuid = screen:getUUID() or ("screen-" .. screen:id()),
                name = screen:name(), index = index,
            }
        end
        for _, entry in ipairs(entries) do
            local index = tonumber(entry["monitor-appkit-nsscreen-screens-id"])
            local monitorId = tonumber(entry["monitor-id"])
            local screen = index and snapshot.screens[index]
            local name = entry.workspace
            if not screen or not monitorId or type(name) ~= "string"
                or entry["monitor-name"] ~= screen.name then
                callback("Monitor mapping changed; waiting for a fresh workspace snapshot")
                return
            end
            screen.monitorId = monitorId
            local visible = entry["workspace-is-visible"] == true
                or entry["workspace-is-visible"] == "true"
            local focused = entry["workspace-is-focused"] == true
                or entry["workspace-is-focused"] == "true"
            table.insert(snapshot.rows, {
                workspace = name, monitorIndex = index,
                visible = visible, focused = focused,
            })
            snapshot.owners[name] = screen.uuid
            if visible then snapshot.visible[screen.uuid] = name end
            if focused then
                snapshot.focusedUUID = screen.uuid
                snapshot.focusedWorkspace = name
            end
        end
        for _, screen in ipairs(snapshot.screens) do
            if not screen.monitorId then
                callback("AeroSpace has not registered every display yet")
                return
            end
        end
        local selectedName = selectedMonitorName()
        local connected = {}
        for _, screen in ipairs(snapshot.screens) do
            table.insert(connected, screen.name .. "|" .. tostring(screen.monitorId))
            if screen.name == selectedName then snapshot.selectedUUID = screen.uuid end
        end
        local connectedSaved, connectedError = writeTextFile(
            CONNECTED_MONITORS_FILE, table.concat(connected, "\n") .. "\n")
        if not connectedSaved then callback(connectedError); return end
        if not snapshot.selectedUUID then
            snapshot.selectedUUID = snapshot.focusedUUID
            for _, screen in ipairs(snapshot.screens) do
                if screen.uuid == snapshot.selectedUUID then
                    local selectedSaved, selectedError = writeTextFile(
                        SELECTED_MONITOR_FILE,
                        screen.name .. "|" .. tostring(screen.monitorId) .. "\n")
                    if not selectedSaved then callback(selectedError); return end
                    break
                end
            end
        end
        runCommand({"list-windows", "--all", "--format", "%{window-id} %{workspace} %{app-name}", "--json"}, function(windowError, windowOutput)
            if windowError then callback(windowError); return end
            local windows, windowsError = decode(windowOutput)
            if not windows then callback(windowsError); return end
            snapshot.windows = windows
            callback(nil, snapshot)
        end)
    end)
end

local function applySnapshot(snapshot)
    local updated, nextViews, changed = model.reconcile(
        state, snapshot.screens, snapshot.rows, MIN_SLOTS)
    if changed then
        local saved, err = saveState(updated)
        if not saved then return false, err end
    end
    state = updated
    views = nextViews
    local selectedUUID = snapshot.selectedUUID or snapshot.focusedUUID
    for uuid, view in pairs(views) do
        view.actualFocused = view.focused
        view.focused = uuid == selectedUUID
    end
    for _, window in ipairs(snapshot.windows) do
        windowCounts[window.workspace] = (windowCounts[window.workspace] or 0) + 1
    end
    available = true
    return true
end

local function screenForFrame(frame, screens)
    local x, y = frame.x + frame.w / 2, frame.y + frame.h / 2
    for _, screen in ipairs(screens) do
        local bounds = screen:fullFrame()
        if x >= bounds.x and x < bounds.x + bounds.w
            and y >= bounds.y and y < bounds.y + bounds.h then
            return screen
        end
    end
end


local tiledAssignments = {}

local function isTileableWindow(window, appName)
    if not window or not window:isStandard() then return false end
    if appName == "Spotify" then
        local title, frame = window:title() or "", window:frame()
        if title:match("^Spotify %- Web Player:")
            or title:match(" %- Your Chromium$")
            or (frame.w <= 700 and frame.h <= 200) then return false end
    end
    return true
end

local function tileNonMainWindows(snapshot, callback)
    local tiledWorkspaces = {}
    for _, view in pairs(views) do
        for index = 2, #view.slots do
            tiledWorkspaces[view.slots[index].workspace] = true
        end
    end
    local steps, assignments = {}, {}
    for _, entry in ipairs(snapshot.windows) do
        local id = tonumber(entry["window-id"])
        if id and tiledWorkspaces[entry.workspace] then
            local assignment = entry.workspace .. ":" .. generation
            if isTileableWindow(hs.window.get(id), entry["app-name"]) then
                assignments[id] = assignment
                if tiledAssignments[id] ~= assignment then
                    table.insert(steps, {"layout", "tiling", "--window-id", tostring(id)})
                end
            end
        end
    end
    runSteps(steps, function(err)
        if not err then tiledAssignments = assignments end
        callback(err)
    end)
end

local function displayedSlots(view)
    local slots = {}
    for _, slot in ipairs(view.slots) do
        if slot.number <= MIN_SLOTS or slot.visible or (windowCounts[slot.workspace] or 0) > 0 then
            table.insert(slots, slot)
        end
    end
    return slots
end

local function indicatorLayout(view, clock)
    local slots = displayedSlots(view)
    local font = {name = "HelveticaNeue-Thin", size = clock:frame().h * 42 / 54}
    local text = clock[1].text
    if type(text) == "userdata" then
        local style = text:sub(-1):asTable()[2]
        if style and style.attributes.font then font = style.attributes.font end
    end
    local fontMetrics = hs.styledtext.fontInfo(font)
    local capHeight = fontMetrics.capHeight
    local dividerDiameterRatio = 1 - 2 * 0.75 / 24
    local diameter = math.floor(capHeight * 1.15 / dividerDiameterRatio + 0.5)
    local textHeight = clock:minimumTextSize(hs.styledtext.new("00:00", {font = font})).h
    local clockCenter = clock:frame().y + textHeight + fontMetrics.descender - capHeight / 2
    return slots, #slots > 0 and diameter or 0, clockCenter
end

local function indicatorFrame(screen, width, clockCenter)
    local full = screen:fullFrame()
    local y = math.max(full.y, math.floor(clockCenter - width / 2 + 0.5))
    local margin = y - full.y
    return {x = full.x + full.w - margin - width, y = y, w = width, h = width}
end

function M.statusWidth(clock)
    local frame = clock:frame()
    local screen = screenForFrame(frame, hs.screen.allScreens())
    local view = screen and views[screen:getUUID()]
    if not available or not view then return frame.w end
    local _, width, clockCenter = indicatorLayout(view, clock)
    if width == 0 then return frame.w end
    local target = indicatorFrame(screen, width, clockCenter)
    local margin = target.y - screen:fullFrame().y
    return math.min(frame.w, target.x - frame.x - margin)
end


local function compactEventText(clock, text, timing, font, overflow)
    if type(text) ~= "string" or text == "" or overflow <= 0 then return text end
    local prefix, title = text:match("^(%d+ min left for )(.+)$")
    local suffix = ""
    if not title then
        prefix = ""
        if timing and text:sub(-#timing) == timing then
            title, suffix = text:sub(1, #text - #timing - 1), " " .. timing
        else
            title, suffix = text:match("^(.*)( starts now)$")
            if not title then
                title, suffix = text:match("^(.*)( at %d%d:%d%d)$")
                if title and title:sub(1, 14) == "Next event is " then
                    prefix, title = "Next event is ", title:sub(15)
                end
            end
        end
    end
    if not title or title == "" then return text end
    local function textWidth(value)
        return clock:minimumTextSize(hs.styledtext.new(value, {font = font})).w
    end
    local limit = math.max(textWidth("…"), textWidth(title) - overflow)
    if textWidth(title) <= limit then return text end
    local titleStart, titleEnd = #prefix + 1, #prefix + #title
    title = title:gsub("…$", "")
    while title ~= "" and textWidth(title .. "…") > limit do
        title = title:sub(1, utf8.offset(title, -1) - 1):gsub("%s+$", "")
    end
    return prefix .. title .. "…" .. suffix, titleStart, titleEnd, title .. "…"
end

function M.fitStatusText(clock, styledText, eventText, timing, font, metricsWidth)
    local frame = clock:frame()
    local screen = screenForFrame(frame, hs.screen.allScreens())
    local view = screen and views[screen:getUUID()]
    if not view or #view.slots == 0 then return styledText end
    local full, usable = screen:fullFrame(), screen:frame()
    local left = frame.x
    if screen:name():lower():find("built", 1, true) and frame.y < usable.y then
        left = math.max(left, full.x + full.w / 2 + 120)
    end
    local maximumWidth = frame.x + M.statusWidth(clock) - left - metricsWidth - 1
    local overflow = clock:minimumTextSize(styledText).w - maximumWidth
    if overflow <= 0 then return styledText end
    local fitted, first, last, title = compactEventText(clock, eventText, timing, font, overflow)
    if fitted == eventText then return styledText end
    local eventStart = styledText:getString():find(eventText, 1, true)
    if not eventStart then return styledText end
    return styledText:setString(title, eventStart + first - 1, eventStart + last - 1)
end

local function renderStrip(uuid, view, clock, screen)
    local slots, width, clockCenter = indicatorLayout(view, clock)
    if width == 0 then return false end
    local target = indicatorFrame(screen, width, clockCenter)
    local focused = view.focused == true
    local signature = {target.x, target.y, target.w, target.h, tostring(focused)}
    for _, slot in ipairs(slots) do
        table.insert(signature, slot.workspace .. ":" .. tostring(slot.visible) .. ":" .. tostring(slot.focused))
    end
    signature = table.concat(signature, "|")
    local entry = canvases[uuid]
    if entry and entry.signature == signature then return true end
    if not entry then
        entry = {canvas = hs.canvas.new(target)}
        entry.canvas:level(hs.canvas.windowLevels.desktopIcon)
        entry.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
        entry.canvas:clickActivating(false)
        canvases[uuid] = entry
    end
    entry.canvas:frame(target)
    local center = width / 2
    local scale = width / 24
    local elements = {{
        type = "circle", action = "fill",
        center = {x = center, y = center}, radius = center - 3 * scale,
        fillColor = {white = 1, alpha = focused and 0.10 or 0.035},
    }}
    if focused then
        table.insert(elements, {
            id = "focus-ring", type = "circle", action = "stroke",
            center = {x = center, y = center}, radius = center - 0.8 * scale,
            strokeWidth = 0.8 * scale, strokeColor = {white = 1, alpha = 0.9},
        })
    end
    local sector = 360 / #slots
    local gap = math.min(12, sector * 0.25)
    for index, slot in ipairs(slots) do
        table.insert(elements, {
            id = "slot-" .. slot.number,
            type = "arc", action = "stroke", arcRadii = false,
            center = {x = center, y = center}, radius = center - 2 * scale,
            startAngle = (index - 1) * sector + gap / 2,
            endAngle = index * sector - gap / 2,
            arcClockwise = true,
            strokeWidth = 1.75 * scale, strokeCapStyle = "butt",
            strokeColor = {white = 1, alpha = slot.visible and (focused and 1 or 0.7) or (focused and 0.25 or 0.18)},
        })
        local angle = math.rad((index - 1) * sector)
        local inner, outer = center - 3.5 * scale, center - 0.75 * scale
        table.insert(elements, {
            id = "divider-" .. index, type = "segments", action = "stroke",
            coordinates = {
                {x = center + math.sin(angle) * inner, y = center - math.cos(angle) * inner},
                {x = center + math.sin(angle) * outer, y = center - math.cos(angle) * outer},
            },
            strokeWidth = 0.6 * scale, strokeColor = {white = 1, alpha = focused and 0.5 or 0.36},
        })
    end
    table.insert(elements, {
        id = "active-slot", type = "text", text = tostring(view.activeSlot or 1),
        frame = {x = 3 * scale, y = center - 8 * scale, w = width - 6 * scale, h = 16 * scale},
        textFont = "HelveticaNeue-Medium", textSize = 11 * scale,
        textAlignment = "center", textColor = {white = 1, alpha = focused and 0.98 or 0.62},
    })
    entry.canvas:replaceElements(table.unpack(elements))
    entry.canvas:show()
    entry.frame, entry.signature = target, signature
    renderCount = renderCount + 1
    return true
end

renderViews = function()
    if not running then return end
    local seen = {}
    if available then
        local screens = hs.screen.allScreens()
        for _, clock in ipairs(_G.desktopClocks or {}) do
            local ok, frame = pcall(function() return clock:frame() end)
            local screen = ok and screenForFrame(frame, screens)
            local uuid = screen and (screen:getUUID() or ("screen-" .. screen:id()))
            if uuid and views[uuid] then
                local rendered, visible = pcall(renderStrip, uuid, views[uuid], clock, screen)
                if rendered and visible then seen[uuid] = true end
                if not rendered then reportError(visible) end
            end
        end
    end
    for uuid, entry in pairs(canvases) do
        if not seen[uuid] then entry.canvas:delete(); canvases[uuid] = nil end
    end
end

local function restorationSteps(snapshot)
    local steps = {}
    for _, screen in ipairs(snapshot.screens) do
        local workspace = snapshot.visible[screen.uuid]
        if workspace then
            table.insert(steps, {
                "move-workspace-to-monitor", "--workspace", workspace,
                "--", tostring(screen.monitorId),
            })
        end
    end
    if snapshot.focusedWorkspace then
        table.insert(steps, {"workspace", snapshot.focusedWorkspace})
    end
    return steps
end

local function performNavigation(request, snapshot, callback)
    local uuid = request.uuid or snapshot.selectedUUID or snapshot.focusedUUID
    local view = uuid and views[uuid]
    if not view then callback("No focused monitor is available"); return end
    local number = request.slot
    if request.action == "cycle" then
        local slots, selected = displayedSlots(view), 1
        for index, slot in ipairs(slots) do
            if slot.number == view.activeSlot then selected = index end
        end
        number = slots[(selected - 1 + request.delta) % #slots + 1].number
    end
    local slot = view.slots[number]
    if not slot then callback("Workspace slot is not available"); return end
    local name = slot.workspace
    if snapshot.owners[name] and snapshot.owners[name] ~= uuid then
        callback("Workspace slot belongs to another monitor")
        return
    end
    local stored = state.monitors[uuid].slots
    if stored[number] ~= name then
        local previous = stored[number]
        stored[number] = name
        local saved, err = saveState(state)
        if not saved then stored[number] = previous; callback(err); return end
    end
    local create = not slot.exists
    local place = {"move-workspace-to-monitor", "--workspace", name, "--", tostring(view.monitorId)}
    if request.action ~= "move" then
        local steps = create and {place} or {}
        table.insert(steps, {"workspace", name})
        table.insert(steps, {"focus-monitor", tostring(view.monitorId)})
        runSteps(steps, callback)
        return
    end
    local function moveWindow(windowId)
        local steps = create and {place} or {}
        table.insert(steps, {"move-node-to-workspace", "--window-id", tostring(windowId), name})
        if request.follow then table.insert(steps, {"focus", "--window-id", tostring(windowId)}) end
        runSteps(steps, function(err)
            -- Creating a workspace makes it visible. Silent moves must undo that view change.
            if create and (not request.follow or err) then
                runSteps(restorationSteps(snapshot), function(restoreError)
                    callback(err or restoreError)
                end)
            else
                callback(err)
            end
        end)
    end
    if request.windowId then moveWindow(request.windowId); return end
    runCommand({"list-windows", "--focused", "--format", "%{window-id}"}, function(err, output)
        local windowId = tonumber(output)
        if err or not windowId then callback(err or "No focused window to move"); return end
        moveWindow(windowId)
    end)
end

local function finishRequest(err)
    if not running then return end
    readSnapshot(function(snapshotError, snapshot)
        if snapshot then
            local applied, applyError = applySnapshot(snapshot)
            if not applied then snapshotError = applyError end
        end
        local function finish(layoutError)
            if snapshotError then available = false end
            local failure = err or snapshotError or layoutError
            if failure then reportError(failure) else lastError = nil end
            renderViews()
            busy = false
            pump()
        end
        if snapshot and not snapshotError then tileNonMainWindows(snapshot, finish) else finish() end
    end)
end

pump = function()
    if not running or busy then return end
    local request = table.remove(queue, 1)
    if not request and not refreshPending then return end
    if not request then refreshPending = false end
    busy = true
    readSnapshot(function(err, snapshot)
        if not err then
            local applied, applyError = applySnapshot(snapshot)
            if not applied then err = applyError end
        end
        if err then
            available = false
            reportError(err)
            renderViews()
            busy = false
            pump()
            return
        end
        tileNonMainWindows(snapshot, function(layoutError)
            if layoutError then reportError(layoutError) end
            renderViews()
            if not request then
                busy = false
                if not layoutError then lastError = nil end
                pump()
                return
            end
            actionCount = actionCount + 1
            performNavigation(request, snapshot, finishRequest)
        end)
    end)
end

local function enqueue(request)
    if not running then return false end
    if #queue >= 64 then reportError("Workspace navigation queue is full"); return false end
    table.insert(queue, request)
    pump()
    return true
end

local function validSlot(slot)
    return type(slot) == "number" and slot >= 1 and slot <= 99 and slot % 1 == 0
end

function M.focusSlot(slot, uuid)
    if not validSlot(slot) then return false end
    return enqueue({action = "focus", slot = slot, uuid = uuid})
end

function M.moveSlot(slot, follow, uuid, windowId)
    if not validSlot(slot) then return false end
    if windowId and (type(windowId) ~= "number" or windowId < 1 or windowId % 1 ~= 0) then return false end
    return enqueue({action = "move", slot = slot, follow = follow == true, uuid = uuid, windowId = windowId})
end

function M.cycle(delta, uuid)
    if delta ~= 1 and delta ~= -1 then return false end
    return enqueue({action = "cycle", delta = delta, uuid = uuid})
end

function M.refresh()
    if not running then return false end
    refreshPending = true
    pump()
    return true
end
function M.syncSelectionToPointerFocus()
    if not running then return false end
    local window = hs.window.focusedWindow()
    local windowScreen = window and window:screen()
    local mouseScreen = hs.mouse.getCurrentScreen()
    if not windowScreen or not mouseScreen
        or windowScreen:getUUID() ~= mouseScreen:getUUID() then return false end

    local uuid = windowScreen:getUUID()
    local view = uuid and views[uuid]
    if not view then return false end
    local saved, err = writeTextFile(
        SELECTED_MONITOR_FILE, view.name .. "|" .. tostring(view.monitorId) .. "\n")
    if not saved then reportError(err); return false end
    for viewUUID, candidate in pairs(views) do
        candidate.focused = viewUUID == uuid
    end
    renderViews()
    return true
end

function M.scheduleSelectionSync()
    if selectionSyncTimer then selectionSyncTimer:stop() end
    selectionSyncTimer = hs.timer.doAfter(0.05, function()
        selectionSyncTimer = nil
        M.syncSelectionToPointerFocus()
        M.refresh()
    end)
    return true
end


function M.render()
    renderViews()
end



function M.start()
    if running then return true end
    local loaded, err = loadState()
    if not loaded then reportError("Workspace slot state: " .. tostring(err)); return false end
    state = loaded
    generation = generation + 1
    running = true
    available = false
    lastError = nil
    hs.urlevent.bind(URL_EVENT, function(_, parameters)
        local action = parameters.action
        if action == "next" then M.cycle(1, parameters.uuid)
        elseif action == "prev" then M.cycle(-1, parameters.uuid)
        elseif action == "focus" then M.focusSlot(tonumber(parameters.slot), parameters.uuid)
        elseif action == "move" or action == "move-follow" then
            M.moveSlot(tonumber(parameters.slot), action == "move-follow", parameters.uuid)
        end
    end)
    previousShutdown = hs.shutdownCallback
    local previous = previousShutdown
    shutdownHook = function()
        M.stop()
        if previous then previous() end
    end
    hs.shutdownCallback = shutdownHook
    M.refresh()
    return true
end

function M.stop()
    if not running then return end
    running = false
    generation = generation + 1
    if selectionSyncTimer then selectionSyncTimer:stop(); selectionSyncTimer = nil end
    for task, timer in pairs(tasks) do
        if timer ~= true then timer:stop() end
        task:terminate()
    end
    tasks = {}
    for _, entry in pairs(canvases) do entry.canvas:delete() end
    canvases = {}
    queue = {}
    busy = false
    refreshPending = false
    available = false
    hs.urlevent.bind(URL_EVENT, nil)
    if hs.shutdownCallback == shutdownHook then hs.shutdownCallback = previousShutdown end
    shutdownHook, previousShutdown = nil, nil
end

function M.diagnostics()
    local result = {
        running = running, available = available, busy = busy, queueLength = #queue,
        queryCount = queryCount, renderCount = renderCount, actionCount = actionCount,
        refreshPending = refreshPending,
        updateSource = "aerospace-hooks",
        lastError = lastError, stateFile = STATE_FILE, monitors = {},
    }
    for uuid, view in pairs(views) do
        local entry = canvases[uuid]
        table.insert(result.monitors, {
            uuid = uuid, name = view.name, monitorId = view.monitorId, index = view.index,
            activeSlot = view.activeSlot, focused = view.focused,
            actualFocused = view.actualFocused, slots = view.slots,
            slotCount = #view.slots, canvas = entry and entry.frame or nil,
        })
    end
    table.sort(result.monitors, function(a, b) return a.index < b.index end)
    return result
end

return M
