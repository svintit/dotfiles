require("hs.ipc")
hs.allowAppleScript(true)

local activeBorderColor = {red=0.96, green=0.96, blue=0.96, alpha=1.0}
local inactiveBorderColor = {red=0.5, green=0.5, blue=0.5, alpha=1.0}
local borderWidth = 3
local borderRadius = 16
local messagesBorderRadius = 24
local inset = borderWidth / 2

local borders = {}
local selectedMonitorFile = hs.configdir .. "/workspace-selected-monitor"
local borderWorkspaceGeneration = 0
local borderWorkspaceRefreshAt = 0
local borderWorkspaceTask
local watchBorderWindow
local refreshBorderForWorkspace
local pendingBorderClick
local lastBorderClick

local function cancelWorkspaceBorderRefresh()
    borderWorkspaceGeneration = borderWorkspaceGeneration + 1
    if borderWorkspaceTask then
        borderWorkspaceTask:terminate()
        borderWorkspaceTask = nil
    end
end

local function borderWindowIsOnSelectedMonitor(win)
    local file = io.open(selectedMonitorFile, "r")
    if not file then return true end
    local selected = file:read("*l")
    file:close()
    selected = selected and selected:match("^([^|]+)")
    local screen = win and win:screen()
    return not selected or selected == "" or (screen and screen:name() == selected)
end

local function isSpotifyMiniPlayer(win)
    local app = win:application()
    if not app or app:name() ~= "Spotify" then return false end
    local title = win:title() or ""
    local frame = win:frame()
    return title:match("^Spotify %- Web Player:") ~= nil
        or title:match(" %- Your Chromium$") ~= nil
        or (frame.w <= 600 and frame.h <= 200)
end

local function borderWindowIsExcluded(win)
    local app = win and win:application()
    return isSpotifyMiniPlayer(win)
        or (app and (app:name() == "Raycast" or app:bundleID() == "com.raycast.macos"))
end

local function borderRadiusForWindow(win)
    local app = win and win:application()
    return app and app:name() == "Messages" and messagesBorderRadius or borderRadius
end

_G.spotifyMiniPlayerWindowIds = function()
    local app = hs.application.get("Spotify")
    if not app then return {} end
    local ids = {}
    for _, window in ipairs(app:allWindows()) do
        if isSpotifyMiniPlayer(window) then table.insert(ids, window:id()) end
    end
    return ids
end

local function deleteAllBorders()
    for winId, border in pairs(borders) do
        border:delete()
        borders[winId] = nil
    end
end

local function deleteBorder(win)
    local winId = win:id()
    if borders[winId] then
        borders[winId]:delete()
        borders[winId] = nil
    end
end

local function hideAllBorders()
    for _, border in pairs(borders) do
        if border:isShowing() then border:hide() end
    end
end

local function hideOtherBorders(visibleWindowId)
    for windowId, border in pairs(borders) do
        if windowId ~= visibleWindowId and border:isShowing() then border:hide() end
    end
end

local function windowIsOnActiveDesktop(win)
    local screen = win:screen()
    if not screen then return false end
    local activeSpace = hs.spaces.activeSpaceOnScreen(screen)
    if not activeSpace or hs.spaces.spaceType(activeSpace) ~= "user" then return false end
    return hs.fnutils.contains(hs.spaces.windowSpaces(win:id()) or {}, activeSpace)
end

local function updateBorderGeometry(win)
    local border = win and borders[win:id()]
    if not border or not border:isShowing() then return end
    local frame = win:frame()
    border:frame({
        x = frame.x - inset,
        y = frame.y - inset,
        w = frame.w + borderWidth,
        h = frame.h + borderWidth,
    })
    border[1].frame = {x = inset, y = inset, w = frame.w, h = frame.h}
end

local function drawBorder(win, forceFocused)
    if not win then return end

    if borderWindowIsExcluded(win) then
        deleteBorder(win)
        return
    end

    if not borderWindowIsOnSelectedMonitor(win) then
        hideAllBorders()
        return
    end

    if win:isFullScreen() or not windowIsOnActiveDesktop(win) then
        deleteBorder(win)
        return
    end

    local winId = win:id()
    local frame = win:frame()
    local focusedWin = hs.window.focusedWindow()
    local isFocused = forceFocused or (focusedWin and focusedWin:id() == winId)
    local borderColor = isFocused and activeBorderColor or inactiveBorderColor
    local radius = borderRadiusForWindow(win)

    if not borders[winId] then
        borders[winId] = hs.canvas.new({x = 0, y = 0, w = 0, h = 0})
        borders[winId]:level(hs.canvas.windowLevels.floating)
        borders[winId]:behavior(hs.canvas.windowBehaviors.default)
        borders[winId]:alpha(borderColor.alpha)
        borders[winId]:clickActivating(false)

        borders[winId][1] = {
            type = "rectangle",
            action = "stroke",
            strokeColor = borderColor,
            strokeWidth = borderWidth,
            roundedRectRadii = {xRadius = radius, yRadius = radius},
            frame = {x = inset, y = inset, w = frame.w, h = frame.h}
        }
    else
        borders[winId][1].strokeColor = borderColor
    end
    borders[winId][1].roundedRectRadii = {xRadius = radius, yRadius = radius}

    borders[winId]:frame({
        x = frame.x - inset,
        y = frame.y - inset,
        w = frame.w + borderWidth,
        h = frame.h + borderWidth,
    })
    borders[winId][1].frame = {x = inset, y = inset, w = frame.w, h = frame.h}

    if isFocused then
        hideOtherBorders(winId)
        borders[winId]:show()
    end
end

local function clearBorderTransition()
    hideAllBorders()
end

local function onlyVisibleBorderIs(windowId)
    local found = false
    for id, border in pairs(borders) do
        if border:isShowing() then
            if id ~= windowId then return false end
            found = true
        end
    end
    return found
end

local function showBorderAfterClear(win, forceFocused)
    if not win then
        clearBorderTransition()
        return
    end
    if not forceFocused then
        local focusedWindow = hs.window.focusedWindow()
        if not focusedWindow or focusedWindow:id() ~= win:id() then return end
    end
    if onlyVisibleBorderIs(win:id()) and not borderWindowIsExcluded(win) and borderWindowIsOnSelectedMonitor(win)
        and not win:isFullScreen() and windowIsOnActiveDesktop(win) then
        updateBorderGeometry(win)
        return
    end
    clearBorderTransition()
    drawBorder(win, forceFocused)
end

local function redrawFocusedBorder()
    local win = hs.window.focusedWindow()
    if pendingBorderClick and win and win:id() == pendingBorderClick.previousWindowId
        and win:id() ~= pendingBorderClick.windowId then return end
    pendingBorderClick = nil
    if borderWorkspaceTask then refreshBorderForWorkspace() end
    if watchBorderWindow then watchBorderWindow(win) end
    showBorderAfterClear(win, false)
end

local connectedMonitorsFile = hs.configdir .. "/workspace-connected-monitors"
local function selectBorderMonitorAtMouse()
    local screen = hs.mouse.getCurrentScreen()
    if not screen then return end

    local connected = io.open(connectedMonitorsFile, "r")
    if not connected then return end
    local selected = nil
    for line in connected:lines() do
        if line:match("^([^|]+)") == screen:name() then
            selected = line
            break
        end
    end
    connected:close()
    if not selected then return end

    local currentFile = io.open(selectedMonitorFile, "r")
    local current = currentFile and currentFile:read("*l") or nil
    if currentFile then currentFile:close() end
    if current == selected then return end

    local temporary = selectedMonitorFile .. ".tmp"
    local output = io.open(temporary, "w")
    if not output then return end
    output:write(selected, "\n")
    output:close()
    os.rename(temporary, selectedMonitorFile)
    return screen
end

local function clickedBorderWindow(event)
    if next(event:getFlags()) then return nil end
    local element = hs.axuielement.systemElementAtPosition(event:location())
    if not element then return nil end
    element:setTimeout(0.025)
    local role = element:attributeValue('AXRole')
    if role == 'AXMenu' or role == 'AXMenuItem' or role == 'AXMenuBar' or role == 'AXMenuBarItem' then return nil end
    local subrole = element:attributeValue('AXSubrole')
    if subrole == 'AXCloseButton' or subrole == 'AXMinimizeButton'
        or subrole == 'AXZoomButton' or subrole == 'AXFullScreenButton' then return nil end
    local windowElement = element:attributeValue('AXWindow')
    if not windowElement and role == 'AXWindow' then
        windowElement = element
    end
    if not windowElement then return nil end
    windowElement:setTimeout(0.025)
    if windowElement:attributeValue('AXSubrole') ~= 'AXStandardWindow' then return nil end
    local win = windowElement:asHSWindow()
    if not win or not win:isStandard() or isSpotifyMiniPlayer(win) or win:isFullScreen() then return nil end
    return win
end

local borderMonitorClickWatcher = hs.eventtap.new({
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.leftMouseUp,
}, function(event)
    if event:getType() == hs.eventtap.event.types.leftMouseUp then
        if pendingBorderClick then refreshBorderForWorkspace() end
        return false
    end
    local started = hs.timer.absoluteTime()
    local ok, win = pcall(clickedBorderWindow, event)
    local changedScreen = selectBorderMonitorAtMouse()
    pendingBorderClick = nil
    if ok and win then
        local previousWindow = hs.window.focusedWindow()
        pendingBorderClick = {
            windowId = win:id(),
            previousWindowId = previousWindow and previousWindow:id(),
        }
        cancelWorkspaceBorderRefresh()
        showBorderAfterClear(win, true)
        watchBorderWindow(win)
        lastBorderClick = {
            windowId = win:id(),
            previousWindowId = pendingBorderClick.previousWindowId,
            drawMs = (hs.timer.absoluteTime() - started) / 1e6,
            visible = onlyVisibleBorderIs(win:id()),
        }
    elseif changedScreen then
        redrawFocusedBorder()
    end
    if changedScreen and _G.workspaceIndicator then
        _G.workspaceIndicator.selectMonitor(changedScreen:name())
    end
    return false
end)
borderMonitorClickWatcher:start()
_G.borderMonitorClickWatcher = borderMonitorClickWatcher

local function updateMovedBorder(win)
    if not win then return end
    local border = borders[win:id()]
    if not border or not border:isShowing() then return end
    local focusedWindow = hs.window.focusedWindow()
    if focusedWindow and focusedWindow:id() == win:id() then
        updateBorderGeometry(win)
    end
end
local borderWindowWatcher
local borderWatchedWindowId

watchBorderWindow = function(win)
    local id = win and win:id()
    if id == borderWatchedWindowId then return end
    if borderWindowWatcher then borderWindowWatcher:stop() end
    borderWindowWatcher = nil
    borderWatchedWindowId = id
    if not win then return end
    borderWindowWatcher = win:newWatcher(function(window, event)
        if event == hs.uielement.watcher.elementDestroyed then
            deleteBorder(win)
            borderWindowWatcher:stop()
            borderWindowWatcher = nil
            borderWatchedWindowId = nil
        else
            updateMovedBorder(window)
        end
    end)
    borderWindowWatcher:start({
        hs.uielement.watcher.windowMoved,
        hs.uielement.watcher.windowResized,
        hs.uielement.watcher.elementDestroyed,
    })
end

refreshBorderForWorkspace = function()
    cancelWorkspaceBorderRefresh()
    borderWorkspaceRefreshAt = hs.timer.secondsSinceEpoch()
    local generation = borderWorkspaceGeneration
    borderWorkspaceTask = hs.task.new('/opt/homebrew/bin/aerospace', function(code, output)
        if generation ~= borderWorkspaceGeneration then return end
        borderWorkspaceTask = nil
        pendingBorderClick = nil
        if code ~= 0 then clearBorderTransition(); return end
        local windowId = tonumber((output or ''):match('%d+'))
        local window = windowId and hs.window.get(windowId)
        watchBorderWindow(window)
        showBorderAfterClear(window, true)
    end, {'list-windows', '--focused', '--format', '%{window-id}'})
    if not borderWorkspaceTask or not borderWorkspaceTask:start() then
        borderWorkspaceTask = nil
        pendingBorderClick = nil
        clearBorderTransition()
    end
end

_G.refreshBorderForWorkspace = refreshBorderForWorkspace
_G.windowBorderDiagnostics = function()
    local visible = {}
    local alphas = {}
    local count = 0
    for windowId, border in pairs(borders) do
        count = count + 1
        alphas[windowId] = border:alpha()
        if border:isShowing() then table.insert(visible, windowId) end
    end
    table.sort(visible)
    return {
        count = count,
        visible = visible,
        alphas = alphas,
        workspaceRefreshAt = borderWorkspaceRefreshAt,
        generation = borderWorkspaceGeneration,
        lastClick = lastBorderClick,
        pendingClick = pendingBorderClick and pendingBorderClick.windowId,
    }
end

local borderFocusWatcher
local borderFocusAppPid

local function watchBorderFocus(app)
    local pid = app and app:pid()
    if pid ~= borderFocusAppPid then
        if borderFocusWatcher then borderFocusWatcher:stop() end
        borderFocusWatcher = nil
        borderFocusAppPid = pid
        if app then
            borderFocusWatcher = app:newWatcher(redrawFocusedBorder)
            borderFocusWatcher:start({hs.uielement.watcher.focusedWindowChanged})
        end
    end
    redrawFocusedBorder()
end

_G.borderApplicationWatcher = hs.application.watcher.new(function(_, event, app)
    if event == hs.application.watcher.activated then watchBorderFocus(app) end
end):start()

local function hideWindowBorder(win)
    local border = win and borders[win:id()]
    if border and border:isShowing() then border:hide() end
end

local windowFilter = hs.window.filter.new()
windowFilter:setDefaultFilter{}
windowFilter:subscribe(hs.window.filter.windowDestroyed, deleteBorder)
windowFilter:subscribe(hs.window.filter.windowMinimized, hideWindowBorder)
windowFilter:subscribe(hs.window.filter.windowHidden, hideWindowBorder)
windowFilter:subscribe(hs.window.filter.windowUnminimized, redrawFocusedBorder)
windowFilter:subscribe(hs.window.filter.windowUnhidden, redrawFocusedBorder)

_G.borderSpaceWatcher = hs.spaces.watcher.new(function()
    clearBorderTransition()
    deleteAllBorders()
    redrawFocusedBorder()
end):start()

watchBorderFocus(hs.application.frontmostApplication())

-- BEGIN tmux session menubar
-- Shows the focused Ghostty window title from tmux set-titles.
-- Revert: delete this block, then reload Hammerspoon.
local tmuxSessionMenubarEnabled = false
if tmuxSessionMenubarEnabled then
    local tmuxSessionMenubar = hs.menubar.new()
    _G.tmuxSessionMenubar = tmuxSessionMenubar
    local tmuxSessionLastTitle = nil
    local tmuxSessionMaxLen = 32

    local function trimMenubarTitle(text)
        if not text or text == "" then return "tmux: ?" end
        if #text > tmuxSessionMaxLen then
            return string.sub(text, 1, tmuxSessionMaxLen - 1) .. "…"
        end
        return text
    end

    local function currentTmuxSessionFromServer()
        local output, ok = hs.execute("/opt/homebrew/bin/tmux -L ghostty-main list-clients -F '#{client_activity}:#{client_session}' 2>/dev/null | /usr/bin/sort -nr | /usr/bin/head -n 1 | /usr/bin/cut -d: -f2-")
        if not ok or not output then return nil end

        local session = output:gsub("%s+$", "")
        if session == "" then return nil end
        return session
    end

    local function tmuxSessionMenubarImage(text)
        local font = { name = ".AppleSystemUIFont", size = 13 }
        local styled = hs.styledtext.new(text, {
            font = font,
            color = { red = 0.93, green = 0.93, blue = 0.96, alpha = 1.0 },
        })

        local measure = hs.canvas.new({ x = 0, y = 0, w = 10, h = 22 })
        local textSize = measure:minimumTextSize(styled)
        measure:delete()

        local padX = 12
        local width = math.ceil(textSize.w + (padX * 2))
        local height = 24
        local canvas = hs.canvas.new({ x = 0, y = 0, w = width, h = height })
        canvas[1] = {
            type = "rectangle",
            action = "fill",
            fillColor = { red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0 },
            roundedRectRadii = { xRadius = 12, yRadius = 12 },
            frame = { x = 0.5, y = 0.5, w = width - 1, h = height - 1 },
        }
        canvas[2] = {
            type = "rectangle",
            action = "stroke",
            strokeColor = { red = 0.0, green = 0.0, blue = 0.0, alpha = 0.95 },
            strokeWidth = 1,
            roundedRectRadii = { xRadius = 12, yRadius = 12 },
            frame = { x = 0.5, y = 0.5, w = width - 1, h = height - 1 },
        }
        canvas[3] = {
            type = "text",
            text = styled,
            frame = { x = padX, y = 4, w = width - (padX * 2), h = height - 4 },
        }

        local image = canvas:imageFromCanvas()
        canvas:delete()
        return image
    end

    local function updateTmuxSessionMenubar()
        local win = hs.window.focusedWindow()
        local app = win and win:application()

        if not app or string.lower(app:name() or "") ~= "ghostty" then
            app = hs.application.find("ghostty")
            if app then
                win = app:focusedWindow() or app:mainWindow() or app:allWindows()[1]
            end
        end

        local title = win and win:title() or ""
        if title == "" then
            title = "tmux: waiting for Ghostty title"
        end

        local session = currentTmuxSessionFromServer() or title:match("^(.-)%s·%s") or title
        if session == "" then session = title end
        if string.find(session, "popup_window", 1, true) or string.find(session, "sesh_picker", 1, true) then return end

        local display = "tmux // " .. trimMenubarTitle(session)
        tmuxSessionLastTitle = display
        tmuxSessionMenubar:imagePosition(hs.menubar.imagePositions.imageLeft)
        tmuxSessionMenubar:setIcon(tmuxSessionMenubarImage(display), false)
        -- A delayed spacer keeps macOS from collapsing image-only menu item to height 0.
        tmuxSessionMenubar:setTitle(" ")
        hs.timer.doAfter(0.05, function()
            if tmuxSessionMenubar then tmuxSessionMenubar:setTitle(" ") end
        end)
        tmuxSessionMenubar:setTooltip(title)
        tmuxSessionMenubar:setMenu({
            { title = title, disabled = true },
            { title = "Refresh", fn = updateTmuxSessionMenubar },
        })
    end

    _G.updateTmuxSessionMenubar = updateTmuxSessionMenubar
    local tmuxSessionWindowFilter = hs.window.filter.new({"ghostty"})
    tmuxSessionWindowFilter:subscribe(hs.window.filter.windowFocused, updateTmuxSessionMenubar)
    tmuxSessionWindowFilter:subscribe(hs.window.filter.windowTitleChanged, updateTmuxSessionMenubar)
    local tmuxSessionTimer = hs.timer.doEvery(1, updateTmuxSessionMenubar)
    local tmuxSessionInitTimer = hs.timer.doAfter(0.5, updateTmuxSessionMenubar)
    _G.tmuxSessionTimer = tmuxSessionTimer
    _G.tmuxSessionInitTimer = tmuxSessionInitTimer
end
-- END tmux session menubar


-- Focus Kitty on mouse hover
local kittyWatcher = nil
local lastApp = nil

function enableKittyFocusOnHover()
    if kittyWatcher then
        kittyWatcher:stop()
    end

    kittyWatcher = hs.timer.doEvery(0.3, function()
        local mousePoint = hs.mouse.absolutePosition()
        local hoveredWindow = nil

        -- Find window under mouse
        for _, win in ipairs(hs.window.orderedWindows()) do
            local frame = win:frame()
            if mousePoint.x >= frame.x and mousePoint.x <= frame.x + frame.w and
               mousePoint.y >= frame.y and mousePoint.y <= frame.y + frame.h then
                hoveredWindow = win
                break
            end
        end

        if hoveredWindow and hoveredWindow:application():name() == "kitty" then
            if lastApp ~= "kitty" then
                hoveredWindow:focus()
                lastApp = "kitty"
            end
        else
            if hoveredWindow then
                lastApp = hoveredWindow:application():name()
            end
        end
    end)
end

enableKittyFocusOnHover()

-- Convert Karabiner's F18 Caps tap candidate to Escape only when alone.
local inputTypes = hs.eventtap.event.types
local inputProperties = hs.eventtap.event.properties
local escapeKeyCode = hs.keycodes.map.escape
local capsTapMarkerKeyCode = hs.keycodes.map.f18
local heldKeys = {}
local heldMouseButtons = {}
local heldSystemKeys = {}
local heldModifiers = {}
local emitMarkerKeyUp = false
local capsEscapeStats = {
    allowedCandidates = 0,
    suppressedCandidates = 0,
}
local capsEscapeRecentEvents = {}

local function hasHeldInput()
    if next(heldKeys) or next(heldMouseButtons) or next(heldSystemKeys) then
        return true
    end

    return heldModifiers.cmd
        or heldModifiers.alt
        or heldModifiers.shift
        or heldModifiers.ctrl
        or heldModifiers.fn
end

local function recordCapsEscapeEvent(kind, details)
    details.kind = kind
    details.time = hs.timer.secondsSinceEpoch()
    capsEscapeRecentEvents[#capsEscapeRecentEvents + 1] = details
    if #capsEscapeRecentEvents > 100 then
        table.remove(capsEscapeRecentEvents, 1)
    end
end

local function capsEscapeHandler(event)
    local eventType = event:getType()

    if eventType == inputTypes.flagsChanged then
        heldModifiers = event:getFlags()
        return false
    end

    if eventType == inputTypes.keyDown then
        local keyCode = event:getKeyCode()
        if keyCode == capsTapMarkerKeyCode then
            local overlap = hasHeldInput() and true or false
            recordCapsEscapeEvent("tapCandidateDown", {
                overlap = overlap,
            })

            emitMarkerKeyUp = not overlap
            if overlap then
                capsEscapeStats.suppressedCandidates =
                    capsEscapeStats.suppressedCandidates + 1
                return true
            end

            capsEscapeStats.allowedCandidates =
                capsEscapeStats.allowedCandidates + 1
            return true, {
                hs.eventtap.event.newKeyEvent({}, escapeKeyCode, true),
            }
        end

        if keyCode ~= escapeKeyCode then
            heldKeys[keyCode] = true
        end
        return false
    end

    if eventType == inputTypes.keyUp then
        local keyCode = event:getKeyCode()
        if keyCode == capsTapMarkerKeyCode then
            local emitEscapeUp = emitMarkerKeyUp
            emitMarkerKeyUp = false
            recordCapsEscapeEvent("tapCandidateUp", {
                emittedEscape = emitEscapeUp,
            })

            if emitEscapeUp then
                return true, {
                    hs.eventtap.event.newKeyEvent({}, escapeKeyCode, false),
                }
            end
            return true
        end

        heldKeys[keyCode] = nil
        return false
    end

    if eventType == inputTypes.systemDefined then
        local systemKey = event:systemKey()
        if systemKey.keyCode then
            if systemKey.down then
                heldSystemKeys[systemKey.keyCode] = true
            else
                heldSystemKeys[systemKey.keyCode] = nil
            end
        end
        return false
    end

    local button = event:getProperty(inputProperties.mouseEventButtonNumber)
    if eventType == inputTypes.leftMouseDown
        or eventType == inputTypes.rightMouseDown
        or eventType == inputTypes.otherMouseDown then
        heldMouseButtons[button] = true
    else
        heldMouseButtons[button] = nil
    end

    return false
end

_G.capsEscapeHandler = capsEscapeHandler
_G.capsEscapeState = {
    heldKeys = heldKeys,
    heldMouseButtons = heldMouseButtons,
    heldSystemKeys = heldSystemKeys,
    stats = capsEscapeStats,
    recentEvents = capsEscapeRecentEvents,
}

local capsEscapeFilter = hs.eventtap.new({
    inputTypes.keyDown,
    inputTypes.keyUp,
    inputTypes.flagsChanged,
    inputTypes.leftMouseDown,
    inputTypes.leftMouseUp,
    inputTypes.rightMouseDown,
    inputTypes.rightMouseUp,
    inputTypes.otherMouseDown,
    inputTypes.otherMouseUp,
    inputTypes.systemDefined,
}, capsEscapeHandler)

capsEscapeFilter:start()
_G.capsEscapeFilter = capsEscapeFilter

-- Put new windows on the cursor monitor unless AeroSpace assigns their app.
local aerospaceManagedAppPatterns = {
    "iterm",
    "ghostty",
    "kitty",
    "obsidian",
    "spotify",
    "messages",
    "chrome",
    "slack",
    "cursor",
    "code",
    "zed",
}

local function aerospaceManagesApp(appName)
    local lower = appName:lower()
    for _, pattern in ipairs(aerospaceManagedAppPatterns) do
        if string.find(lower, pattern, 1, true) then return true end
    end
    return false
end

local function aerospaceMonitorPattern(screenName)
    if not screenName then return nil end
    local lower = screenName:lower()
    if string.match(lower, "dell") then return "dell"
    elseif string.match(lower, "benq") then return "benq"
    elseif string.match(lower, "built") then return "built-in"
    end
    return nil
end

local function focusAerospaceCursorMonitor()
    local cursorScreen = hs.mouse.getCurrentScreen()
    local monitorPattern = cursorScreen and aerospaceMonitorPattern(cursorScreen:name()) or nil
    if monitorPattern then
        hs.execute("/opt/homebrew/bin/aerospace focus-monitor " .. monitorPattern)
    end
end

local raycastHotkeyWatcher = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
}, function(event)
    local flags = event:getFlags()
    local isRaycastHotkey = event:getKeyCode() == 49
        and flags.cmd
        and not flags.alt
        and not flags.ctrl
        and not flags.shift
        and not flags.fn
    if isRaycastHotkey then focusAerospaceCursorMonitor() end
    return false
end)

raycastHotkeyWatcher:start()
_G.raycastHotkeyWatcher = raycastHotkeyWatcher

local shottrCapture = nil
local shottrCaptureGeneration = 0
local shottrPlacedGeneration = {}
local shottrPlacementTasks = {}

local function windowUnderMouse()
    local point = hs.mouse.absolutePosition()
    for _, win in ipairs(hs.window.orderedWindows()) do
        local app = win:application()
        local frame = win:frame()
        if app and app:name() ~= "Shottr"
            and point.x >= frame.x and point.x < frame.x + frame.w
            and point.y >= frame.y and point.y < frame.y + frame.h then
            return win:id()
        end
    end
    return nil
end

local function rememberShottrCapture()
    local screen = hs.mouse.getCurrentScreen()
    local space = screen and hs.spaces.activeSpaceOnScreen(screen) or nil
    if not screen or not space then return end
    shottrCaptureGeneration = shottrCaptureGeneration + 1
    shottrCapture = {
        generation = shottrCaptureGeneration,
        sourceWindowId = windowUnderMouse(),
        space = space,
    }
end

local shottrCapturePendingUntil = 0
local shottrCaptureWatcher = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseUp,
}, function(event)
    local now = hs.timer.secondsSinceEpoch()
    if event:getType() == hs.eventtap.event.types.leftMouseUp then
        if now <= shottrCapturePendingUntil then
            rememberShottrCapture()
            shottrCapturePendingUntil = 0
        end
    else
        local flags = event:getFlags()
        if event:getKeyCode() == 35 and flags.cmd and flags.shift then
            shottrCapturePendingUntil = now + 15
            rememberShottrCapture()
        end
    end
    return false
end)

shottrCaptureWatcher:start()
_G.shottrCaptureWatcher = shottrCaptureWatcher

local function focusShottrWindow(winId)
    hs.timer.doAfter(0.05, function()
        local currentWindow = hs.window.get(winId)
        if currentWindow then currentWindow:focus() end
    end)
end

local function moveShottrToWorkspace(winId, workspace, capture)
    local task
    task = hs.task.new("/opt/homebrew/bin/aerospace", function(code, _, stderr)
        shottrPlacementTasks[task] = nil
        if shottrCapture ~= capture then return end
        if code ~= 0 then
            print("Shottr workspace placement failed: " .. tostring(stderr))
            return
        end
        focusShottrWindow(winId)
    end, {
        "move-node-to-workspace", workspace,
        "--window-id", tostring(winId),
    })
    if task and task:start() then
        shottrPlacementTasks[task] = true
    end
end

local function placeShottrOnCaptureWorkspace(win)
    local winId = win and win:id()
    local capture = shottrCapture
    if not winId or not capture or hs.spaces.spaceType(capture.space) ~= "user" then return end
    if shottrPlacedGeneration[winId] == capture.generation then return end
    shottrPlacedGeneration[winId] = capture.generation

    local onTargetSpace = false
    for _, currentSpace in ipairs(hs.spaces.windowSpaces(winId) or {}) do
        if currentSpace == capture.space then onTargetSpace = true; break end
    end
    if not onTargetSpace then
        local moved, err = hs.spaces.moveWindowToSpace(winId, capture.space, true)
        if not moved then
            print("Shottr space placement failed: " .. tostring(err))
            return
        end
    end

    if not capture.sourceWindowId then
        focusShottrWindow(winId)
        return
    end

    local task
    task = hs.task.new("/opt/homebrew/bin/aerospace", function(code, stdout, stderr)
        shottrPlacementTasks[task] = nil
        if shottrCapture ~= capture then return end
        if code ~= 0 then
            print("Shottr workspace lookup failed: " .. tostring(stderr))
            focusShottrWindow(winId)
            return
        end
        local sourceId = tostring(capture.sourceWindowId)
        for line in (stdout or ""):gmatch("[^\r\n]+") do
            local id, workspace = line:match("^(%d+)\t(.+)$")
            if id == sourceId then
                moveShottrToWorkspace(winId, workspace, capture)
                return
            end
        end
        focusShottrWindow(winId)
    end, {
        "list-windows", "--all",
        "--format", "%{window-id}\t%{workspace}",
    })
    if task and task:start() then
        shottrPlacementTasks[task] = true
    else
        focusShottrWindow(winId)
    end
end

local shottrPlacementFilter = hs.window.filter.new({"Shottr"})
shottrPlacementFilter:subscribe(hs.window.filter.windowFocused, placeShottrOnCaptureWorkspace)
_G.shottrPlacementFilter = shottrPlacementFilter
_G.rememberShottrCapture = rememberShottrCapture
_G.placeShottrOnCaptureWorkspace = placeShottrOnCaptureWorkspace



windowFilter:subscribe(hs.window.filter.windowCreated, function(win)
    local app = win:application()
    if not app or aerospaceManagesApp(app:name()) then return end

    if app:name():lower() == "shottr" then return end
    local targetScreen = hs.mouse.getCurrentScreen()
    if not targetScreen then return end

    local monitorPattern = aerospaceMonitorPattern(targetScreen:name())
    local winId = win:id()
    if not monitorPattern or not winId then return end

    local windowScreen = win:screen()
    if windowScreen and windowScreen:name() == targetScreen:name() then return end

    local attempts = 0
    local function syncAerospaceWindow(onComplete)
        attempts = attempts + 1
        local _, moved = hs.execute(
            "/opt/homebrew/bin/aerospace move-node-to-monitor --window-id " .. winId .. " " .. monitorPattern
        )
        if not moved and attempts < 4 then
            hs.timer.doAfter(0.03, function()
                syncAerospaceWindow(onComplete)
            end)
            return
        end
        if onComplete then onComplete() end
    end


    win:moveToScreen(targetScreen, false, true, 0)
    syncAerospaceWindow()
end)

local builtInDisplayName = "Built-in Retina Display"
local benqDisplayName = "BenQ PD3220U"
local homeDellDisplayName = "DELL U2725QE"
local officeDellDisplayName = "DELL P2723QE"

local screenEdgeInset = 50

_G.spotifyMiniPlayer = require("spotify_miniplayer").start({
    preferredScreens = {benqDisplayName, officeDellDisplayName},
    fallbackScreen = builtInDisplayName,
    minWidth = 320,
    maxWidth = 650,
    height = 52,
    padding = 9,
    builtInInset = screenEdgeInset,
})

-- Show a clock behind application windows on every display.
local desktopClocks = {}
local desktopClockStyles = {}
local nextCalendarEventText = ""
local calendarEventTask = nil
local currentCalendarEventTitle = nil
local currentCalendarEventEndMinutes = nil
local nextCalendarEventStartMinutes = nil
local nextCalendarEventTitle = nil
local nextCalendarEventTime = nil

local function truncateEventTitle(title, limit)
    limit = math.max(1, limit)
    if utf8.len(title) <= limit then return title end
    return title:sub(1, utf8.offset(title, limit) - 1):gsub("%s+$", "") .. "…"
end

local function calendarEventText(
    minutesUntilNextEvent,
    showFullTitle,
    titleReduction
)
    titleReduction = titleReduction or 0
    if currentCalendarEventTitle then
        local now = os.date("*t")
        local nowMinutes = now.hour * 60 + now.min
        local minutesLeft = currentCalendarEventEndMinutes
            and currentCalendarEventEndMinutes - nowMinutes
        if minutesLeft and minutesLeft < 0 and now.hour >= 20
            and currentCalendarEventEndMinutes < 240
        then
            minutesLeft = minutesLeft + 24 * 60
        end
        minutesLeft = math.max(0, minutesLeft or 0)
        local title = showFullTitle
            and currentCalendarEventTitle
            or truncateEventTitle(currentCalendarEventTitle, 28 - titleReduction)
        return string.format("%d min left for %s", minutesLeft, title)
    end
    if nextCalendarEventTitle
        and minutesUntilNextEvent
        and minutesUntilNextEvent >= 0
        and minutesUntilNextEvent <= 60
    then
        if minutesUntilNextEvent == 0 then
            local title = showFullTitle
                and nextCalendarEventTitle
                or truncateEventTitle(nextCalendarEventTitle, 33 - titleReduction)
            return title .. " starts now"
        end
        local minuteLabel = minutesUntilNextEvent == 1 and "minute" or "minutes"
        local timingText = minutesUntilNextEvent <= 10 and "starts soon in" or "starts in"
        local countdownSuffix = string.format(
            "%s %d %s",
            timingText,
            minutesUntilNextEvent,
            minuteLabel
        )
        local countdownTitle = nextCalendarEventTitle
        if not showFullTitle then
            local countdownTitleLimit = math.max(
                1,
                44 - titleReduction - #countdownSuffix
            )
            countdownTitle = truncateEventTitle(countdownTitle, countdownTitleLimit)
        end
        return countdownTitle .. " " .. countdownSuffix, countdownSuffix
    end
    if nextCalendarEventTitle and nextCalendarEventTime then
        local title = showFullTitle
            and nextCalendarEventTitle
            or truncateEventTitle(nextCalendarEventTitle, 33 - titleReduction)
        if #title > 20 then
            return title .. " at " .. nextCalendarEventTime
        end
        return "Next event is " .. title .. " at " .. nextCalendarEventTime
    end
    return nextCalendarEventText
end

local metricElements = setmetatable({}, {__mode = "k"})

local function setMetricElement(clock, index, element)
    local elements = metricElements[clock]
    if not elements then
        elements = {}
        metricElements[clock] = elements
    end
    local previous = elements[index]
    if previous then
        local sameText
        if type(element.text) == "userdata" then
            sameText = type(previous.text) == "userdata" and previous.text:isIdentical(element.text)
        else
            sameText = previous.text == element.text
        end
        local oldFrame, newFrame = previous.frame, element.frame
        if sameText and oldFrame.x == newFrame.x and oldFrame.y == newFrame.y
            and oldFrame.w == newFrame.w and oldFrame.h == newFrame.h then return end
    end
    clock[index] = element
    elements[index] = element
end

local function updateDesktopClocks()
    local dateText = string.format(
        "%s %s %d",
        os.date("%a"),
        os.date("%b"),
        tonumber(os.date("%d"))
    )
    local batteryPercentage = math.floor(hs.battery.percentage() + 0.5)
    local onBatteryPower = hs.battery.powerSource() == "Battery Power"
    local nowMinutes = tonumber(os.date("%H")) * 60 + tonumber(os.date("%M"))
    local minutesUntilNextEvent = nextCalendarEventStartMinutes
        and nextCalendarEventStartMinutes - nowMinutes
    local nextEventIsStartingSoon = minutesUntilNextEvent
        and minutesUntilNextEvent >= 0
        and minutesUntilNextEvent <= 10
    local alignment = {alignment = "right"}
    for _, clock in ipairs(desktopClocks) do
        local style = desktopClockStyles[clock]
        local dateFont = {name = "HelveticaNeue-Thin", size = style.dateSize}
        local timeFont = {name = "HelveticaNeue-Thin", size = style.timeSize}
        local smallAttributes = {
            color = {white = 1, alpha = 0.80},
            baselineOffset = style.statusBaselineOffset,
            font = dateFont,
            paragraphStyle = alignment,
        }
        local statusText = nil

        local function appendStyledStatus(styledText)
            if statusText then
                statusText = statusText .. hs.styledtext.new("  •  ", smallAttributes)
            end
            statusText = (statusText or hs.styledtext.new("", smallAttributes))
                .. styledText
        end

        local function appendStatus(text, attributes)
            appendStyledStatus(hs.styledtext.new(text, attributes or smallAttributes))
        end
        local function addUnderline(attributes)
            return {
                color = attributes.color,
                baselineOffset = attributes.baselineOffset,
                font = attributes.font,
                paragraphStyle = attributes.paragraphStyle,
                underlineStyle = 1,
            }
        end


        local eventText, eventTimingText = calendarEventText(
            minutesUntilNextEvent,
            style.showFullEventTitle,
            style.eventTitleReduction
        )
        if eventText ~= "" then
            local eventAttributes
            if currentCalendarEventTitle then
                eventAttributes = {
                    color = {red = 0.15, green = 0.80, blue = 1, alpha = 1.0},
                    baselineOffset = style.statusBaselineOffset,
                    font = dateFont,
                    paragraphStyle = alignment,
                }
            elseif nextEventIsStartingSoon then
                local eventAlpha = 1.0
                if minutesUntilNextEvent <= 2 then
                    local pulse = 0.50 + 0.50
                        * math.sin(hs.timer.secondsSinceEpoch() * math.pi * 2 / 3)
                    eventAlpha = 0.30 + 0.70 * pulse
                end
                eventAttributes = {
                    color = {red = 1, green = 0.65, blue = 0.15, alpha = eventAlpha},
                    baselineOffset = style.statusBaselineOffset,
                    font = dateFont,
                    paragraphStyle = alignment,
                }
            end
            if currentCalendarEventTitle then
                local prefix, remainder = eventText:match("^(%d+ min left)(.*)$")
                local prefixAttributes = addUnderline(eventAttributes)
                appendStyledStatus(
                    hs.styledtext.new(prefix, prefixAttributes)
                        .. hs.styledtext.new(remainder, eventAttributes)
                )
            elseif eventTimingText
                and (
                    minutesUntilNextEvent == 60
                    or minutesUntilNextEvent == 10
                    or minutesUntilNextEvent == 2
                )
            then
                local titleText = eventText:sub(1, #eventText - #eventTimingText)
                local baseAttributes = eventAttributes or smallAttributes
                appendStyledStatus(
                    hs.styledtext.new(titleText, baseAttributes)
                        .. hs.styledtext.new(
                            eventTimingText,
                            addUnderline(baseAttributes)
                        )
                )
            else
                appendStatus(eventText, eventAttributes)
            end
        end
        if onBatteryPower then
            local batteryAttributes = smallAttributes
            if batteryPercentage < 20 then
                local batteryAlpha = 1.0
                if batteryPercentage < 10 then
                    local pulse = 0.50 + 0.50
                        * math.sin(hs.timer.secondsSinceEpoch() * math.pi * 2 / 3)
                    batteryAlpha = 0.30 + 0.70 * pulse
                end
                batteryAttributes = addUnderline({
                    color = {
                        red = 1,
                        green = 0.15,
                        blue = 0.15,
                        alpha = batteryAlpha,
                    },
                    baselineOffset = style.statusBaselineOffset,
                    font = dateFont,
                    paragraphStyle = alignment,
                })
            end
            appendStatus(string.format("%d%%", batteryPercentage), batteryAttributes)
        end
        appendStatus(dateText)

        local fullText = statusText .. hs.styledtext.new(" " .. os.date("%H:%M"), {
            color = {white = 1, alpha = 1.0},
            font = timeFont,
            paragraphStyle = alignment,
        })
        if _G.resourceStats then
            fullText = hs.styledtext.new("•  ", smallAttributes) .. fullText
        end

        -- Stacked cpu/mem blocks: value over label, left of the status text.
        local stats = _G.resourceStats
        -- Two rows must fit inside the time's visible band (~78% of height).
        local metricFontSize = style.height * 0.30
        local rowHeight = style.height * 0.39
        local blockTop = style.height * 0.12
        local blockWidth = metricFontSize * 2.6
        -- Centering slack plus this nudge matches the bullet's trailing space.
        local gap = 3.5
        if _G.workspaceIndicator then
            fullText = _G.workspaceIndicator.fitStatusText(
                clock, fullText, eventText, eventTimingText, dateFont, 2 * blockWidth + gap
            )
        end
        local previousText = clock[1].text
        if type(previousText) ~= "userdata" or not previousText:isIdentical(fullText) then
            clock[1].text = fullText
        end
        local statusWidth = _G.workspaceIndicator and _G.workspaceIndicator.statusWidth(clock) or style.width
        local textFrame = clock[1].frame
        if textFrame.w ~= statusWidth then
            clock[1].frame = {x = textFrame.x, y = textFrame.y, w = statusWidth, h = textFrame.h}
        end
        local textWidth = clock:minimumTextSize(fullText).w
        local metrics = stats and {
            {value = string.format("%d%%", stats.cpu), label = "cpu"},
            {value = string.format("%d%%", stats.mem), label = "ram"},
        } or {}
        local blocksRight = statusWidth - textWidth - gap
        local shadow = {
            blurRadius = 6,
            color = {white = 0, alpha = 0.75},
            offset = {h = -1, w = 0},
        }
        for index = 1, 2 do
            local metric = metrics[index]
            local x = blocksRight - (3 - index) * blockWidth
            setMetricElement(clock, index * 2, {
                type = "text",
                text = metric and hs.styledtext.new(metric.value, {
                    color = {white = 1, alpha = 0.80},
                    font = {name = "HelveticaNeue-Thin", size = metricFontSize},
                    paragraphStyle = {alignment = "center"},
                }) or "",
                frame = {x = x, y = blockTop, w = blockWidth, h = rowHeight},
                withShadow = true,
                shadow = shadow,
            })
            setMetricElement(clock, index * 2 + 1, {
                type = "text",
                text = metric and hs.styledtext.new(metric.label, {
                    color = {white = 1, alpha = 0.80},
                    font = {name = "HelveticaNeue-Thin", size = metricFontSize},
                    paragraphStyle = {alignment = "center"},
                }) or "",
                frame = {
                    x = x,
                    y = blockTop + rowHeight,
                    w = blockWidth,
                    h = rowHeight,
                },
                withShadow = true,
                shadow = shadow,
            })
        end
    end
    if _G.workspaceIndicator then
        _G.workspaceIndicator.render()
    end
end
local function applyCalendarEventOutput(output)
    local currentTime, currentTitle = output:match("^CURRENT|([^|]+)|(.+)$")
    local eventTime, eventTitle = output:match("^NEXT|([^|]+)|(.+)$")
    if currentTime and currentTitle then
        currentTitle = currentTitle:gsub("%s+", " ")
        local endHour, endMinute = currentTime:match(".*(%d%d):(%d%d)")
        currentCalendarEventEndMinutes = endHour
            and tonumber(endHour) * 60 + tonumber(endMinute)
        currentCalendarEventTitle = currentTitle
        nextCalendarEventTitle = nil
        nextCalendarEventStartMinutes = nil
        nextCalendarEventText = ""
        nextCalendarEventTime = nil
    elseif eventTime and eventTitle then
        currentCalendarEventTitle = nil
        currentCalendarEventEndMinutes = nil
        eventTime = eventTime:gsub(" at ", " ")
        eventTime = eventTime:gsub("^" .. os.date("%a") .. " ", "")
        local eventHour, eventMinute = eventTime:match("(%d%d):(%d%d)")
        nextCalendarEventStartMinutes = eventHour
            and tonumber(eventHour) * 60 + tonumber(eventMinute)
        eventTitle = eventTitle:gsub("%s+", " ")
        nextCalendarEventTitle = eventTitle
        nextCalendarEventTime = eventTime
        nextCalendarEventText = ""
    else
        currentCalendarEventTitle = nil
        currentCalendarEventEndMinutes = nil
        nextCalendarEventTitle = nil
        nextCalendarEventStartMinutes = nil
        nextCalendarEventTime = nil
        nextCalendarEventText = "No more events today"
    end
end

_G.setDesktopCalendarEventOutput = function(output)
    applyCalendarEventOutput(output)
    updateDesktopClocks()
end

-- A local launch agent refreshes this cache.
local function refreshNextCalendarEvent()
    local eventFile = io.open(hs.configdir .. "/calendar-helper/next-event.txt", "r")
    if not eventFile then return end
    local output = eventFile:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
    eventFile:close()

    applyCalendarEventOutput(output)
    updateDesktopClocks()
end

local function rebuildDesktopClocks()
    for _, clock in ipairs(desktopClocks) do
        clock:delete()
    end
    desktopClocks = {}
    desktopClockStyles = {}
    _G.desktopClocks = desktopClocks

    for _, screen in ipairs(hs.screen.allScreens()) do
        local frame = screen:frame()
        local screenName = screen:name()
        local isBuiltIn = screenName == builtInDisplayName
        local isHomeDell = screenName == homeDellDisplayName
        local isBenQ = screenName == benqDisplayName
        local usesBenQLayout = isHomeDell or isBenQ or screenName == officeDellDisplayName
        local width = frame.w - screenEdgeInset * 2
        local height = usesBenQLayout and 54 or 50
        local topPadding = isBuiltIn and -28
            or (usesBenQLayout and 8 or 20)
        local rightPadding = screenEdgeInset
        local clock = hs.canvas.new({
            x = frame.x + frame.w - width - rightPadding,
            y = frame.y + topPadding,
            w = width,
            h = height,
        })
        clock:level(hs.canvas.windowLevels.desktopIcon)
        clock:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
        clock:clickActivating(false)
        clock[1] = {
            type = "text",
            text = "",
            textAlignment = "right",
            textColor = {white = 1, alpha = 0.9},
            textFont = "SF Pro Display",
            textSize = 38,
            frame = {x = 0, y = 0, w = width, h = height},
            withShadow = true,
            shadow = {
                blurRadius = 6,
                color = {white = 0, alpha = 0.75},
                offset = {h = -1, w = 0},
            },
        }
        clock:show()
        desktopClockStyles[clock] = {
            dateSize = usesBenQLayout and 21 or 19,
            timeSize = usesBenQLayout and 42 or 38,
            statusBaselineOffset = usesBenQLayout and 7.0 or 6.4,
            width = width,
            height = height,
            showFullEventTitle = isHomeDell,
            eventTitleReduction = isBuiltIn and 5 or 0,
        }
        table.insert(desktopClocks, clock)
    end

    updateDesktopClocks()
    if _G.workspaceIndicator then
        _G.workspaceIndicator.refresh()
    end
end

local desktopClockTimer = hs.timer.doEvery(1, updateDesktopClocks)
local desktopClockPulseTimer = hs.timer.doEvery(0.05, function()
    local nowMinutes = tonumber(os.date("%H")) * 60 + tonumber(os.date("%M"))
    local minutesUntilNextEvent = nextCalendarEventStartMinutes
        and nextCalendarEventStartMinutes - nowMinutes
    local meetingIsPulsing = minutesUntilNextEvent
        and minutesUntilNextEvent >= 0
        and minutesUntilNextEvent <= 2
    local batteryIsPulsing = hs.battery.powerSource() == "Battery Power"
        and hs.battery.percentage() < 10
    if meetingIsPulsing or batteryIsPulsing then
        updateDesktopClocks()
    end
end)
local calendarEventTimer = hs.timer.doEvery(60, refreshNextCalendarEvent)
local desktopClockScreenWatcher = hs.screen.watcher.new(rebuildDesktopClocks)
_G.desktopClockTimer = desktopClockTimer
_G.desktopClockPulseTimer = desktopClockPulseTimer
_G.calendarEventTimer = calendarEventTimer
_G.desktopClockScreenWatcher = desktopClockScreenWatcher
desktopClockScreenWatcher:start()
rebuildDesktopClocks()
refreshNextCalendarEvent()

-- Route media keys directly to Spotify and consume both event edges.
-- This prevents rcd from marking media commands as user activity.
local spotifyLaunching = false

local function spotifyIsRunning()
    return hs.application.get("com.spotify.client") ~= nil
end

local function sendSpotifyCommand(cmd)
    hs.osascript.applescript(string.format('tell application "Spotify" to %s', cmd))
end

local function launchAndSendSpotify(cmd)
    spotifyLaunching = true
    hs.application.open("com.spotify.client")
    local attempts = 0
    local poll = hs.timer.doEvery(0.3, function()
        attempts = attempts + 1
        if spotifyIsRunning() or attempts > 20 then
            poll:stop()
            sendSpotifyCommand(cmd)
            spotifyLaunching = false
        end
    end)
end

local function mediaKeyHandler(event)
    local sk = event:systemKey()
    if not sk then return false end

    local cmd
    if sk.key == "PLAY" then
        cmd = "playpause"
    elseif sk.key == "NEXT" then
        cmd = "next track"
    elseif sk.key == "PREVIOUS" then
        cmd = "previous track"
    else
        return false
    end

    if not sk.down or sk["repeat"] then return true end

    if spotifyIsRunning() then
        sendSpotifyCommand(cmd)
    elseif not spotifyLaunching then
        launchAndSendSpotify(cmd)
    end

    return true
end

local mediaKeyTap = hs.eventtap.new({hs.eventtap.event.types.systemDefined}, mediaKeyHandler)
mediaKeyTap:start()
_G.spotifyMediaKeyTap = mediaKeyTap

-- CPU and memory feed for the desktop clock status line.
local previousCpuTicks = nil

local function cpuPercent()
    local ticks = hs.host.cpuUsageTicks().overall
    local previous = previousCpuTicks
    previousCpuTicks = ticks
    if not previous then return nil end
    local active = (ticks.user - previous.user) + (ticks.system - previous.system)
    local total = active + (ticks.idle - previous.idle)
    if total <= 0 then return nil end
    return math.floor(active / total * 100 + 0.5)
end

local function memoryPercent()
    local vm = hs.host.vmStat()
    local usedBytes = (vm.pagesActive + vm.pagesWiredDown + vm.pagesUsedByVMCompressor) * vm.pageSize
    return math.floor(usedBytes / vm.memSize * 100 + 0.5)
end

local function updateResourceStatus()
    local cpu = cpuPercent()
    if not cpu then return end
    _G.resourceStats = {cpu = cpu, mem = memoryPercent()}
    updateDesktopClocks()
end

local resourceStatusTimer = hs.timer.doEvery(5, updateResourceStatus)
_G.resourceStatusTimer = resourceStatusTimer
updateResourceStatus()

-- Black rounded-corner masks on every display, all four corners.
local cornerMaskRadius = 24
local cornerMasks = {}

local function rebuildCornerMasks()
    for _, mask in ipairs(cornerMasks) do
        mask:delete()
    end
    cornerMasks = {}
    for _, screen in ipairs(hs.screen.allScreens()) do
        local frame = screen:fullFrame()
        local r = cornerMaskRadius
        local corners = {
            {x = frame.x, y = frame.y, cx = r, cy = r},
            {x = frame.x + frame.w - r, y = frame.y, cx = 0, cy = r},
            {x = frame.x, y = frame.y + frame.h - r, cx = r, cy = 0},
            {x = frame.x + frame.w - r, y = frame.y + frame.h - r, cx = 0, cy = 0},
        }
        for _, corner in ipairs(corners) do
            local mask = hs.canvas.new({x = corner.x, y = corner.y, w = r, h = r})
            mask[1] = {
                type = "rectangle",
                action = "fill",
                fillColor = {black = 1, alpha = 1},
            }
            mask[2] = {
                type = "circle",
                action = "fill",
                center = {x = corner.cx, y = corner.cy},
                radius = r,
                fillColor = {black = 1, alpha = 1},
                compositeRule = "destinationOut",
            }
            mask:level(hs.canvas.windowLevels.screenSaver)
            mask:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces
                + hs.canvas.windowBehaviors.stationary)
            mask:clickActivating(false)
            mask:show()
            table.insert(cornerMasks, mask)
        end
    end
end

local cornerMaskScreenWatcher = hs.screen.watcher.new(rebuildCornerMasks)
cornerMaskScreenWatcher:start()
_G.cornerMaskScreenWatcher = cornerMaskScreenWatcher
rebuildCornerMasks()

-- BEGIN multi-output device volume restore
-- Re-applies target volume to devices inside the Multi-Output Device
-- when they reset on sleep/wake or device reconnection.
-- Disabled 2026-09-02 while debugging AirPods auto-switch. Set to true to re-enable.
local AUDIO_VOLUME_RESTORE_ENABLED = false

if AUDIO_VOLUME_RESTORE_ENABLED then
local audioVolumeTargets = {
  ["BuiltInSpeakerDevice"] = 95,
}

local audioVolTimer = nil

local function applyAudioVolumes()
  for uid, targetVol in pairs(audioVolumeTargets) do
    local dev = hs.audiodevice.findDeviceByUID(uid)
    if dev and dev:isOutputDevice() then
      local current = dev:volume()
      if current == nil or math.abs(current - targetVol) > 0.5 then
        dev:setVolume(targetVol)
      end
    end
  end
end

local function debouncedApplyAudioVolumes()
  if audioVolTimer then audioVolTimer:stop() end
  audioVolTimer = hs.timer.doAfter(1.0, applyAudioVolumes)
end

hs.audiodevice.watcher.setCallback(function(_uid)
  debouncedApplyAudioVolumes()
end)
hs.audiodevice.watcher.start()

local audioCaffeinateWatcher = hs.caffeinate.watcher.new(function(eventType)
  if eventType == hs.caffeinate.watcher.systemDidWake
      or eventType == hs.caffeinate.watcher.screensDidWake then
    debouncedApplyAudioVolumes()
  end
end)
audioCaffeinateWatcher:start()

hs.timer.doAfter(2.0, applyAudioVolumes)
_G.applyAudioVolumes = applyAudioVolumes
_G.audioCaffeinateWatcher = audioCaffeinateWatcher
end
-- END multi-output device volume restore

-- Miryoku layer cheat sheet overlay (⌃⌥⌘K to pin, auto-shows on thumb layer hold)
miryoku = require("miryoku_cheatsheet")

_G.workspaceIndicator = require("workspace_indicator")
_G.workspaceIndicator.start()
