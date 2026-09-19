local M = {}

local spotifyBundleId = "com.spotify.client"
local queryScript = [[
if application "Spotify" is not running then return ""
with timeout of 3 seconds
    tell application "Spotify"
        set separatorCharacter to ASCII character 30
        set currentItem to current track
        return (player state as text) & separatorCharacter & (name of currentItem) & separatorCharacter & (artist of currentItem) & separatorCharacter & (artwork url of currentItem) & separatorCharacter & (duration of currentItem as text) & separatorCharacter & (player position as text) & separatorCharacter & (shuffling as text) & separatorCharacter & (shuffling enabled as text)
    end tell
end timeout]]

local function nativeMiniPlayerWindow(app)
    for _, window in ipairs(app:allWindows()) do
        local title = window:title() or ""
        if title:match("^Spotify %- Web Player:") or title:match(" %- Your Chromium$") then
            return window
        end
    end
    return nil
end

local function parseTrack(output)
    local cleanOutput = (output or ""):gsub("\r", ""):gsub("\n$", "")
    local playerState, title, artist, artworkUrl, duration, position, shuffling, shuffleEnabled = cleanOutput:match(
        "^([^\30]*)\30([^\30]*)\30([^\30]*)\30([^\30]*)\30([^\30]*)\30([^\30]*)\30([^\30]*)\30([^\30]*)$"
    )
    if not playerState then return nil end
    return {
        playerState = playerState,
        title = title,
        artist = artist,
        artworkUrl = artworkUrl,
        duration = (tonumber(duration) or 0) / 1000,
        position = tonumber(position) or 0,
        shuffling = shuffling == "true",
        shuffleEnabled = shuffleEnabled == "true",
    }
end

local function measuredTextWidth(text, fontName, fontSize)
    local styledText = hs.styledtext.new(text, {
        font = {name = fontName, size = fontSize},
    })
    return hs.drawing.getTextDrawingSize(styledText).w
end

local colors = {
    background = {red = 10 / 255, green = 12 / 255, blue = 20 / 255, alpha = 1},
    accent = {red = 0.22, green = 0.89, blue = 0.56, alpha = 1},
    play = {white = 1, alpha = 1},
    like = {red = 0.97, green = 0.52, blue = 0.65, alpha = 1},
    text = {red = 0.95, green = 0.97, blue = 1, alpha = 1},
    secondary = {red = 0.70, green = 0.75, blue = 0.79, alpha = 1},
    ink = {white = 0.05, alpha = 1},
}


local function vectorPath(id, coordinates, color, action)
    return {
        id = id,
        type = "segments",
        coordinates = coordinates,
        action = action or "stroke",
        closed = action == "fill",
        fillColor = color,
        strokeColor = color,
        strokeWidth = 1.65,
        strokeCapStyle = "round",
        strokeJoinStyle = "round",
    }
end

local progressWaveAmplitude = 2
local progressWaveWavelength = 22
local progressWaveCyclesPerSecond = 0.75

local widthAnimationDuration = 0.25

local function easeInOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    end
    local u = -2 * t + 2
    return 1 - (u * u * u) / 2
end

local function progressWavePoints(length, centerY, phase, amplitude)
    local points = {}
    local segments = math.max(1, math.ceil(length / 2))
    for index = 0, segments do
        local x = length * index / segments
        local taper = math.min(1, x / 6, (length - x) / 6)
        points[#points + 1] = {
            x = 56 + x,
            y = centerY + math.sin(x * 2 * math.pi / progressWaveWavelength + phase) * amplitude * taper,
        }
    end
    return points
end

function M.start(options)
    options = options or {}
    local preferredScreens = options.preferredScreens or {}
    local fallbackScreen = options.fallbackScreen
    local minWidth = options.minWidth or 320
    local maxWidth = options.maxWidth or 650
    local height = options.height or 52
    local padding = options.padding or 9
    local builtInInset = options.builtInInset or 50
    local state = {
        artwork = hs.image.imageFromAppBundle(spotifyBundleId),
        artworkAlpha = 1,
        artworkGeneration = 0,
        commandTasks = {},
        controls = {},
        wavePhase = 0,
    }
    local controller = {}
    local refresh
    local renderPlayer

    local function spotifyApp()
        return hs.application.get(spotifyBundleId) or hs.application.find("Spotify")
    end

    local function targetScreen()
        local screensByName = {}
        for _, screen in ipairs(hs.screen.allScreens()) do
            screensByName[screen:name()] = screen
        end
        for _, name in ipairs(preferredScreens) do
            if screensByName[name] then return screensByName[name], false end
        end
        if screensByName[fallbackScreen] then return screensByName[fallbackScreen], true end
        return hs.screen.primaryScreen(), false
    end

    local function playerWidth(info)
        local titleWidth = measuredTextWidth(info.title or "Spotify", "HelveticaNeue-Medium", 13)
        local artistWidth = measuredTextWidth(info.artist or "", "HelveticaNeue", 11)
        return math.max(minWidth, math.min(maxWidth, math.ceil(math.max(titleWidth, artistWidth) + 262)))
    end

    local function playerFrame(width)
        local screen, useBuiltInLayout = targetScreen()
        if not screen then return nil end
        local screenFrame = useBuiltInLayout and screen:fullFrame() or screen:frame()
        local x = useBuiltInLayout
            and screenFrame.x + builtInInset
            or screenFrame.x + (screenFrame.w - width) / 2
        return {
            x = math.floor(x + 0.5),
            y = screenFrame.y + padding,
            w = width,
            h = height,
        }, useBuiltInLayout
    end

    local function stopProgressAnimation()
        if state.progressAnimationTimer then state.progressAnimationTimer:stop() end
        state.waveUpdatedAt = nil
    end

    local function stopWidthAnimation()
        if state.widthAnimationTimer then
            state.widthAnimationTimer:stop()
            state.widthAnimationTimer = nil
        end
        state.widthAnimation = nil
    end

    local function animateProgress()
        if state.stopped or not state.canvas or not state.canvas:isShowing()
            or not state.info or state.info.playerState ~= "playing" then
            stopProgressAnimation()
            return
        end
        -- Keep Spotify polling out of the animation timer.
        local now = hs.timer.absoluteTime() / 1e9
        local elapsed = math.min(now - (state.waveUpdatedAt or now), 0.25)
        state.waveUpdatedAt = now
        state.wavePhase = (state.wavePhase + elapsed * 2 * math.pi * progressWaveCyclesPerSecond) % (2 * math.pi)
        state.canvas.progress.coordinates = progressWavePoints(
            state.progressLength or 0, height - 6, state.wavePhase, progressWaveAmplitude
        )
    end

    local function syncProgressAnimation(info)
        if info.playerState ~= "playing" or (state.progressLength or 0) <= 0 then
            stopProgressAnimation()
            return
        end
        if not state.progressAnimationTimer:running() then
            state.waveUpdatedAt = hs.timer.absoluteTime() / 1e9
            state.progressAnimationTimer:start()
        end
    end

    local function hidePlayer()
        stopProgressAnimation()
        stopWidthAnimation()
        if state.canvas and state.canvas:isShowing() then state.canvas:hide() end
        if state.tooltip then state.tooltip:hide() end
        state.hoveredControl = nil
        state.tooltipText = nil
    end

    local function controlLabel(elementId)
        if elementId == "playpause" then
            return state.info and state.info.playerState == "playing" and "Pause" or "Play"
        elseif elementId == "shuffle" then
            if not state.info or not state.info.shuffleEnabled then return "Shuffle unavailable" end
            return state.info.shuffling and "Turn shuffle off" or "Turn shuffle on"
        end
        return ({
            previous = "Previous track",
            next = "Next track",
            like = "Like / unlike (opens Spotify)",
            showSpotify = "Open Spotify",
        })[elementId]
    end

    local function showTooltip(text, elementId)
        if state.stopped or not state.canvas or not text then return end
        local frame = state.canvas:frame()
        local control = state.controls[elementId]
        local width = math.ceil(measuredTextWidth(text, "HelveticaNeue", 11)) + 20
        local centerX = frame.x + (control and control.x or frame.w / 2)
        local screen = targetScreen()
        local screenFrame = screen and screen:fullFrame() or frame
        local x = math.max(screenFrame.x + 4, math.min(centerX - width / 2, screenFrame.x + screenFrame.w - width - 4))
        local tooltipFrame = {x = math.floor(x), y = frame.y + frame.h + 6, w = width, h = 26}
        if not state.tooltip then
            state.tooltip = hs.canvas.new(tooltipFrame)
            state.tooltip:level(hs.canvas.windowLevels.floating)
            state.tooltip:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
            state.tooltip:clickActivating(false)
            state.tooltip:canvasMouseEvents(false, false, false, false)
        end
        state.tooltip:frame(tooltipFrame)
        state.tooltip:replaceElements({
            type = "rectangle", action = "fill",
            fillColor = {red = 0.09, green = 0.11, blue = 0.14, alpha = 0.98},
            roundedRectRadii = {xRadius = 7, yRadius = 7},
        }, {
            type = "text", text = text, textFont = "HelveticaNeue", textSize = 11,
            textColor = colors.text, textAlignment = "center",
            frame = {x = 6, y = 5, w = width - 12, h = 16},
        })
        state.tooltipText = text
        state.tooltip:show()
    end

    local function likeCurrentTrack()
        if state.likeTimer then return end
        local app = spotifyApp()
        if not app then return end
        local deadline = hs.timer.absoluteTime() + 2e9
        local window = app:mainWindow()
        if window then window:focus() else app:activate(true) end
        state.likeTimer = hs.timer.doEvery(0.05, function()
            if state.stopped or hs.timer.absoluteTime() >= deadline then
                state.likeTimer:stop()
                state.likeTimer = nil
                if not state.stopped and state.hoveredControl == "like" then
                    showTooltip("Open Spotify, then press Option-Shift-B", "like")
                end
                return
            end
            if not app:isFrontmost() then return end
            state.likeTimer:stop()
            state.likeTimer = nil
            -- Spotify exposes a library shortcut, but no reliable saved-state property.
            hs.eventtap.keyStroke({"alt", "shift"}, "b", 0, app)
            if state.hoveredControl == "like" then showTooltip("Like / unlike shortcut sent", "like") end
        end)
    end

    local function runSpotifyCommand(command)
        if next(state.commandTasks) then return end
        local app = spotifyApp()
        if not app then return end
        local script = 'if application "Spotify" is running then\n'
            .. 'with timeout of 3 seconds\n'
            .. 'tell application "Spotify" to ' .. command
            .. '\nend timeout\nend if'
        local task
        task = hs.task.new("/usr/bin/osascript", function(exitCode)
            state.commandTasks[task] = nil
            if state.stopped then return end
            if exitCode ~= 0 then showTooltip("Spotify did not respond", state.hoveredControl) end
            refresh()
        end, {"-e", script})
        if task and task:start() then state.commandTasks[task] = true end
    end

    local function handleMouse(_, message, elementId)
        if state.stopped then return end
        if message == "mouseEnter" then
            state.hoveredControl = elementId
            showTooltip(controlLabel(elementId), elementId)
        elseif message == "mouseExit" then
            if state.hoveredControl ~= elementId then return end
            state.hoveredControl = nil
            state.tooltipText = nil
            if state.tooltip then state.tooltip:hide() end
        elseif message == "mouseUp" then
            if elementId == "previous" then
                runSpotifyCommand("previous track")
            elseif elementId == "playpause" then
                runSpotifyCommand("playpause")
            elseif elementId == "next" then
                runSpotifyCommand("next track")
            elseif elementId == "shuffle" then
                if state.info and state.info.shuffleEnabled then
                    runSpotifyCommand("set shuffling to not shuffling")
                end
            elseif elementId == "like" then
                likeCurrentTrack()
            elseif elementId == "showSpotify" then
                local app = spotifyApp()
                if app then app:activate(true) end
            end
        else
            return
        end
        if state.info then renderPlayer(state.info) end
    end

    local function ensureCanvas(frame, useBuiltIn)
        local level = useBuiltIn
            and hs.canvas.windowLevels.mainMenu
            or hs.canvas.windowLevels.floating
        if state.canvas then
            if state.canvasLevel ~= level then
                state.canvas:level(level)
                state.canvasLevel = level
            end
            state.canvas:frame(frame)
            return
        end
        state.canvas = hs.canvas.new(frame)
        state.canvas:level(level)
        state.canvasLevel = level
        state.canvas:behavior(
            hs.canvas.windowBehaviors.canJoinAllSpaces
                + hs.canvas.windowBehaviors.stationary
        )
        state.canvas:clickActivating(false)
        state.canvas:wantsLayer(true)
        state.canvas:mouseCallback(handleMouse)
    end

    local function elementsFor(info, width)
        local centerY = height / 2
        local controlsStart = width - 200
        local textWidth = math.max(40, controlsStart - 62)
        local ratio = info.duration > 0 and math.max(0, math.min(1, info.position / info.duration)) or 0
        local filledWidth = textWidth * ratio
        state.progressLength = filledWidth
        local elements = {
            {
                id = "background", type = "rectangle", action = "fill",
                fillColor = colors.background,
                roundedRectRadii = {xRadius = 14, yRadius = 14},
                frame = {x = 0, y = 0, w = width, h = height},
            },
            {
                id = "outline", type = "rectangle", action = "stroke",
                strokeColor = {white = 1, alpha = 0.10}, strokeWidth = 1,
                roundedRectRadii = {xRadius = 13.5, yRadius = 13.5},
                frame = {x = 0.5, y = 0.5, w = width - 1, h = height - 1},
            },
            {
                id = "showSpotify", type = "rectangle", action = "fill",
                fillColor = {white = 1, alpha = 0.001},
                frame = {x = 0, y = 0, w = controlsStart - 4, h = height},
                trackMouseUp = true,
            },
        }
        if state.artwork then
            local artworkFrame = {x = 6, y = centerY - 20, w = 40, h = 40}
            table.insert(elements, {
                type = "rectangle", action = "clip", frame = artworkFrame,
                roundedRectRadii = {xRadius = 7, yRadius = 7},
            })
            table.insert(elements, {
                id = "artwork", type = "image", image = state.artwork,
                imageAlpha = state.artworkAlpha,
                imageScaling = "scaleProportionally", frame = artworkFrame,
            })
            table.insert(elements, {type = "resetClip"})
        end
        table.insert(elements, {
            id = "title", type = "text", text = info.title,
            textColor = colors.text, textFont = "HelveticaNeue-Medium", textSize = 13,
            textLineBreak = "truncateTail",
            frame = {x = 56, y = centerY - 21, w = textWidth, h = 19},
        })
        table.insert(elements, {
            id = "artist", type = "text", text = info.artist,
            textColor = colors.secondary, textFont = "HelveticaNeue", textSize = 11,
            textLineBreak = "truncateTail",
            frame = {x = 56, y = centerY - 1, w = textWidth, h = 16},
        })
        local remainingStart = math.min(textWidth, filledWidth + 5)
        table.insert(elements, {
            id = "progressTrack", type = "rectangle", action = "fill",
            fillColor = {white = 1, alpha = 0.12},
            roundedRectRadii = {xRadius = 1, yRadius = 1},
            frame = {x = 56 + remainingStart, y = height - 7, w = textWidth - remainingStart, h = 2},
        })
        local wave = vectorPath("progress", progressWavePoints(
            filledWidth, height - 6, state.wavePhase,
            info.playerState == "playing" and progressWaveAmplitude or 0
        ), colors.accent)
        wave.strokeWidth = 2
        wave.action = filledWidth > 0 and "stroke" or "skip"
        table.insert(elements, wave)
        table.insert(elements, {
            id = "progressThumb", type = "circle", action = "fill", fillColor = colors.accent,
            center = {x = 56 + filledWidth, y = height - 6}, radius = 2.5,
        })

        state.controls = {
            like = {x = width - 180, y = centerY, size = 30},
            shuffle = {x = width - 146, y = centerY, size = 30},
            previous = {x = width - 112, y = centerY, size = 30},
            playpause = {x = width - 72, y = centerY, size = 36},
            next = {x = width - 32, y = centerY, size = 30},
        }
        for _, id in ipairs({"like", "shuffle", "previous", "playpause", "next"}) do
            local control = state.controls[id]
            local hovered = state.hoveredControl == id
            local fill = {white = 1, alpha = hovered and 0.10 or 0.001}
            if id == "playpause" then fill = colors.play end
            table.insert(elements, {
                id = id, type = "oval", action = "fill", fillColor = fill,
                frame = {x = control.x - control.size / 2, y = control.y - control.size / 2, w = control.size, h = control.size},
                trackMouseUp = true, trackMouseEnterExit = true, trackMouseByBounds = true,
            })
        end

        local likeX = state.controls.like.x
        local likePoints = {
            {x = likeX, y = centerY + 7},
            {x = likeX - 8, y = centerY - 2, c1x = likeX - 3, c1y = centerY + 4, c2x = likeX - 8, c2y = centerY + 1},
            {x = likeX, y = centerY - 4, c1x = likeX - 8, c1y = centerY - 9, c2x = likeX - 2, c2y = centerY - 9},
            {x = likeX + 8, y = centerY - 2, c1x = likeX + 2, c1y = centerY - 9, c2x = likeX + 8, c2y = centerY - 9},
            {x = likeX, y = centerY + 7, c1x = likeX + 8, c1y = centerY + 1, c2x = likeX + 3, c2y = centerY + 4},
        }
        table.insert(elements, vectorPath("likeIcon", likePoints, colors.like))

        local shuffleX = state.controls.shuffle.x
        local shuffleColor = info.shuffling and colors.accent or colors.secondary
        if not info.shuffleEnabled then shuffleColor = {white = 0.42} end
        for _, direction in ipairs({-1, 1}) do
            table.insert(elements, vectorPath("shuffleLine" .. direction, {
                {x = shuffleX - 7, y = centerY - direction * 5},
                {x = shuffleX - 4, y = centerY - direction * 5},
                {x = shuffleX + 4, y = centerY + direction * 5, c1x = shuffleX, c1y = centerY - direction * 5, c2x = shuffleX, c2y = centerY + direction * 5},
                {x = shuffleX + 8, y = centerY + direction * 5},
            }, shuffleColor))
            table.insert(elements, vectorPath("shuffleArrow" .. direction, {
                {x = shuffleX + 5, y = centerY + direction * 5 - 3},
                {x = shuffleX + 8, y = centerY + direction * 5},
                {x = shuffleX + 5, y = centerY + direction * 5 + 3},
            }, shuffleColor))
        end
        if info.shuffling and info.shuffleEnabled then
            table.insert(elements, {
                id = "shuffleActive", type = "circle", action = "fill", fillColor = colors.accent,
                center = {x = shuffleX, y = centerY + 12}, radius = 1.5,
            })
        end

        for _, control in ipairs({{id = "previous", direction = -1}, {id = "next", direction = 1}}) do
            local x = state.controls[control.id].x
            local direction = control.direction
            local color = state.hoveredControl == control.id and colors.text or colors.secondary
            table.insert(elements, vectorPath(control.id .. "Icon", {
                {x = x - direction * 6, y = centerY - 6},
                {x = x + direction * 4, y = centerY},
                {x = x - direction * 6, y = centerY + 6},
            }, color, "fill"))
            table.insert(elements, {
                id = control.id .. "Bar", type = "rectangle", action = "fill", fillColor = color,
                roundedRectRadii = {xRadius = 0.7, yRadius = 0.7},
                frame = {x = x + direction * 6 - 1, y = centerY - 6, w = 2, h = 12},
            })
        end

        local playX = state.controls.playpause.x
        if info.playerState == "playing" then
            for index, offset in ipairs({-5.5, 2}) do
                table.insert(elements, {
                    id = "pauseBar" .. index, type = "rectangle", action = "fill", fillColor = colors.ink,
                    roundedRectRadii = {xRadius = 1, yRadius = 1},
                    frame = {x = playX + offset, y = centerY - 6.5, w = 3.5, h = 13},
                })
            end
        else
            table.insert(elements, vectorPath("playIcon", {
                {x = playX - 4, y = centerY - 7},
                {x = playX + 8, y = centerY},
                {x = playX - 4, y = centerY + 7},
            }, colors.ink, "fill"))
        end
        return elements
    end

    local function canvasWidth()
        if not state.canvas then return nil end
        local frame = state.canvas:frame()
        return frame and frame.w or nil
    end

    local function drawAtWidth(width)
        if state.stopped then return false end
        local frame, useBuiltIn = playerFrame(width)
        if not frame then return false end
        ensureCanvas(frame, useBuiltIn)
        state.canvas:replaceElements(elementsFor(state.info, width))
        if not state.canvas:isShowing() then state.canvas:show() end
        return true
    end

    local function startWidthAnimation(targetWidth)
        local current = canvasWidth()
        stopWidthAnimation()
        if current == nil then
            return drawAtWidth(targetWidth)
        end
        local animation = {
            from = current,
            to = targetWidth,
            startedAt = hs.timer.absoluteTime() / 1e9,
        }
        state.widthAnimation = animation
        state.widthAnimationTimer = hs.timer.doEvery(1 / 60, function()
            if state.stopped or not state.canvas or not state.canvas:isShowing() or not state.info then
                stopWidthAnimation()
                return
            end
            local elapsed = hs.timer.absoluteTime() / 1e9 - animation.startedAt
            local progress = math.min(1, elapsed / widthAnimationDuration)
            local eased = easeInOutCubic(progress)
            local width = animation.from + (animation.to - animation.from) * eased
            if not drawAtWidth(width) then
                stopWidthAnimation()
                hidePlayer()
                return
            end
            if progress >= 1 then
                stopWidthAnimation()
                drawAtWidth(targetWidth)
            end
        end)
    end

    renderPlayer = function(info)
        if state.stopped then return end
        local app = spotifyApp()
        if not app or nativeMiniPlayerWindow(app) then
            stopWidthAnimation()
            hidePlayer()
            return
        end
        state.info = info
        local target = playerWidth(info)
        local animation = state.widthAnimation
        if animation and math.abs(animation.to - target) < 0.5 then
            -- An in-flight resize already targets this width; its timer redraws
            -- from cached data and reflects hover changes live.
            syncProgressAnimation(info)
            return
        end
        local current = canvasWidth()
        if not state.canvas or not state.canvas:isShowing() or current == nil
            or math.abs(current - target) < 0.5 then
            stopWidthAnimation()
            if drawAtWidth(target) then syncProgressAnimation(info) else hidePlayer() end
        else
            syncProgressAnimation(info)
            startWidthAnimation(target)
        end
    end

    local function fadeArtwork(image)
        if state.artworkFadeTimer then state.artworkFadeTimer:stop() end
        local startedAt = hs.timer.absoluteTime() / 1e9
        local initialAlpha = state.artworkAlpha
        local swapped = false
        state.artworkFadeTimer = hs.timer.doEvery(1 / 30, function()
            local elapsed = hs.timer.absoluteTime() / 1e9 - startedAt
            local visible = state.canvas and state.canvas:isShowing()
            if state.stopped or not visible or elapsed >= 0.36 then
                state.artworkFadeTimer:stop()
                state.artworkFadeTimer = nil
                if state.stopped then return end
                state.artwork = image
                state.artworkAlpha = 1
            elseif elapsed < 0.18 then
                local progress = elapsed / 0.18
                local eased = progress * progress * (3 - 2 * progress)
                state.artworkAlpha = initialAlpha * (1 - eased)
            else
                if not swapped then state.artwork = image; swapped = true end
                local progress = (elapsed - 0.18) / 0.18
                state.artworkAlpha = progress * progress * (3 - 2 * progress)
            end
            if state.canvas then
                state.canvas.artwork.image = state.artwork
                state.canvas.artwork.imageAlpha = state.artworkAlpha
            end
        end)
    end

    local function updateArtwork(info)
        if info.artworkUrl == state.artworkUrl then return end
        state.artworkUrl = info.artworkUrl
        state.artworkGeneration = state.artworkGeneration + 1
        local generation = state.artworkGeneration
        if not info.artworkUrl or info.artworkUrl == "" or not info.artworkUrl:match("^https://") then
            local placeholder = hs.image.imageFromAppBundle(spotifyBundleId)
            if placeholder then fadeArtwork(placeholder) end
            return
        end
        hs.image.imageFromURL(info.artworkUrl, function(image)
            if state.stopped or generation ~= state.artworkGeneration or not image then return end
            fadeArtwork(image)
        end)
    end

    refresh = function()
        if state.stopped then return end
        local app = spotifyApp()
        if not app then
            hidePlayer()
            state.info = nil
            return
        end
        if nativeMiniPlayerWindow(app) then
            hidePlayer()
            return
        end
        if state.refreshTask then return end
        if state.info then renderPlayer(state.info) end

        local task
        task = hs.task.new("/usr/bin/osascript", function(exitCode, output)
            state.refreshTask = nil
            if state.stopped then return end
            if exitCode ~= 0 then return end
            local info = parseTrack(output)
            if not info then return end
            state.info = info
            updateArtwork(info)
            renderPlayer(info)
        end, {"-e", queryScript})
        if task and task:start() then state.refreshTask = task end
    end

    local function scheduleRefresh()
        if state.stopped then return end
        if state.refreshTimer then state.refreshTimer:stop() end
        state.refreshTimer = hs.timer.doAfter(0.1, function()
            state.refreshTimer = nil
            refresh()
        end)
    end

    state.progressAnimationTimer = hs.timer.new(1 / 30, animateProgress)
    state.pollTimer = hs.timer.doEvery(1, refresh)
    state.screenWatcher = hs.screen.watcher.new(scheduleRefresh):start()
    state.appWatcher = hs.application.watcher.new(function(name)
        if name == "Spotify" then scheduleRefresh() end
    end):start()
    state.windowFilter = hs.window.filter.new({"Spotify"})
    state.windowFilter:subscribe(hs.window.filter.windowCreated, scheduleRefresh)
    state.windowFilter:subscribe(hs.window.filter.windowDestroyed, scheduleRefresh)

    function controller:refresh()
        refresh()
    end

    function controller:status()
        local app = spotifyApp()
        return {
            spotifyRunning = app ~= nil,
            nativeMiniPlayer = app and nativeMiniPlayerWindow(app) ~= nil or false,
            fallbackVisible = state.canvas and state.canvas:isShowing() or false,
            frame = state.canvas and state.canvas:frame() or nil,
            playerState = state.info and state.info.playerState or nil,
            title = state.info and state.info.title or nil,
            shuffling = state.info and state.info.shuffling or false,
            shuffleEnabled = state.info and state.info.shuffleEnabled or false,
            controls = state.controls,
            tooltip = state.tooltipText,
        }
    end

    function controller:snapshot(path)
        if not state.canvas then return false end
        local image = state.canvas:imageFromCanvas()
        if not image then return false end
        image:saveToFile(path)
        return true
    end


    function controller:stop()
        state.stopped = true
        stopProgressAnimation()
        stopWidthAnimation()
        if state.likeTimer then state.likeTimer:stop(); state.likeTimer = nil end
        if state.artworkFadeTimer then state.artworkFadeTimer:stop(); state.artworkFadeTimer = nil end
        if state.pollTimer then state.pollTimer:stop() end
        if state.screenWatcher then state.screenWatcher:stop() end
        if state.appWatcher then state.appWatcher:stop() end
        if state.refreshTimer then state.refreshTimer:stop() end
        if state.windowFilter then state.windowFilter:unsubscribeAll() end
        if state.refreshTask then state.refreshTask:terminate() end
        for task in pairs(state.commandTasks) do task:terminate() end
        if state.canvas then state.canvas:delete() end
        if state.tooltip then state.tooltip:delete(); state.tooltip = nil end
        state.canvas = nil
    end

    refresh()
    return controller
end

return M
