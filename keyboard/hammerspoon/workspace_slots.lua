-- Pure slot reconciliation model for AeroSpace workspace indicator.
-- No hs APIs or I/O; all functions are data-only.
-- Row monitorIndex == screen.index (both are NSScreen.screens order).

local M = {}

local SCHEMA_VERSION = 1
local PLACEHOLDER_PREFIX = "ASW-"

local function deepCopy(v)
  if type(v) ~= "table" then return v end
  local copy = {}
  for k, val in pairs(v) do
    copy[deepCopy(k)] = deepCopy(val)
  end
  return copy
end

local function isPlaceholder(name)
  return type(name) == "string" and name:sub(1, #PLACEHOLDER_PREFIX) == PLACEHOLDER_PREFIX
end

local function isNumeric(s)
  return type(s) == "string" and s:match("^%d+$") ~= nil
end

-- Collision-free placeholder: ASW-<uuid-prefix>-<slot>[-<suffix>].
local function placeholderName(uuid, slot, usedNames)
  local prefix = (uuid or ""):gsub("[^%w]", ""):sub(1, 8)
  if #prefix == 0 then prefix = "xxxxxxxx" end
  local name = string.format("%s%s-%d", PLACEHOLDER_PREFIX, prefix, slot)
  if usedNames then
    local base = name
    local suffix = 0
    while usedNames[name] do
      suffix = suffix + 1
      name = string.format("%s-%d", base, suffix)
    end
    usedNames[name] = true
  end
  return name
end

-- Named workspaces first (alphabetical), then numeric (natural order).
local function sortWorkspaces(ws)
  local named, numeric = {}, {}
  for _, w in ipairs(ws) do
    if isNumeric(w) then table.insert(numeric, w)
    else table.insert(named, w) end
  end
  table.sort(named)
  table.sort(numeric, function(a, b) return tonumber(a) < tonumber(b) end)
  for _, w in ipairs(numeric) do table.insert(named, w) end
  return named
end

local function buildLookups(rows)
  local workspaceOwner = {}
  local workspacesByMonitor = {}
  for _, r in ipairs(rows) do
    if not workspaceOwner[r.workspace] then
      workspaceOwner[r.workspace] = {
        monitorIndex = r.monitorIndex,
        visible = r.visible,
        focused = r.focused,
      }
    end
    local byMon = workspacesByMonitor[r.monitorIndex]
    if not byMon then
      byMon = {}
      workspacesByMonitor[r.monitorIndex] = byMon
    end
    byMon[r.workspace] = { visible = r.visible, focused = r.focused }
  end
  return {
    workspaceOwner = workspaceOwner,
    workspacesByMonitor = workspacesByMonitor,
  }
end

-- Collect all names that must not collide with generated placeholders.
local function buildUsedNames(rows, state)
  local used = {}
  for _, r in ipairs(rows) do used[r.workspace] = true end
  if state and state.monitors then
    for _, mon in pairs(state.monitors) do
      if type(mon.slots) == "table" then
        for _, name in ipairs(mon.slots) do
          if type(name) == "string" then used[name] = true end
        end
      end
    end
  end
  return used
end

-- Seed: visible workspace, then named (alphabetical), then numeric (natural).
local function seedSlots(uuid, screenIndex, lookups, minSlots, usedNames)
  local myWs = lookups.workspacesByMonitor[screenIndex] or {}
  local visibleWs = nil
  local named, numeric = {}, {}
  for wsName, info in pairs(myWs) do
    if info.visible then
      visibleWs = wsName
    elseif isNumeric(wsName) then
      table.insert(numeric, wsName)
    else
      table.insert(named, wsName)
    end
  end
  table.sort(named)
  table.sort(numeric, function(a, b) return tonumber(a) < tonumber(b) end)
  local slots = {}
  if visibleWs then table.insert(slots, visibleWs) end
  for _, w in ipairs(named) do
    if w ~= visibleWs then table.insert(slots, w) end
  end
  for _, w in ipairs(numeric) do
    if w ~= visibleWs then table.insert(slots, w) end
  end
  for i = #slots + 1, minSlots do
    table.insert(slots, placeholderName(uuid, i, usedNames))
  end
  return slots
end

function M.newState()
  return { version = SCHEMA_VERSION, monitors = {} }
end

function M.validate(state)
  if type(state) ~= "table" then
    return false, "state is not a table"
  end
  local v = state.version
  if type(v) ~= "number" then
    return false, "state.version is not a number"
  end
  if v ~= SCHEMA_VERSION then
    return false, "state version " .. tostring(v) .. " is not supported"
  end
  local monitors = state.monitors
  if type(monitors) ~= "table" then
    return false, "state.monitors is absent or not a table"
  end
  for uuid, mon in pairs(monitors) do
    if type(uuid) ~= "string" or uuid == "" then
      return false, "monitor identity is not a non-empty string"
    end
    if type(mon) ~= "table" then
      return false, "monitor " .. tostring(uuid) .. " is not a table"
    end
    if type(mon.name) ~= "string" or #mon.name == 0 then
      return false, "monitor " .. tostring(uuid) .. " has no non-empty string name"
    end
    if type(mon.slots) ~= "table" then
      return false, "monitor " .. tostring(uuid) .. " has no table slots"
    end
    local seen = {}
    for i = 1, #mon.slots do
      local slot = mon.slots[i]
      if type(slot) ~= "string" or #slot == 0 then
        return false, "monitor " .. tostring(uuid) .. " slot " .. tostring(i) .. " is not a non-empty string"
      end
      if seen[slot] then
        return false, "monitor " .. tostring(uuid) .. " has duplicate slot name " .. slot
      end
      seen[slot] = true
    end
    -- Detect sparse arrays (non-numeric keys in slots).
    local count = 0
    for _ in pairs(mon.slots) do count = count + 1 end
    if count ~= #mon.slots then
      return false, "monitor " .. tostring(uuid) .. " slots is sparse or has non-array keys"
    end
  end
  return true, nil
end

function M.reconcile(state, screens, rows, minSlots)
  screens = screens or {}
  rows = rows or {}
  minSlots = minSlots or 10
  local lookups = buildLookups(rows)
  local usedNames = buildUsedNames(rows, state)

  local newState
  local changed = false
  if type(state) == "table" then
    newState = deepCopy(state)
  else
    newState = {}
    changed = true
  end
  if newState.version ~= SCHEMA_VERSION then
    newState.version = SCHEMA_VERSION
    changed = true
  end
  if type(newState.monitors) ~= "table" then
    newState.monitors = {}
  end

  for _, screen in ipairs(screens) do
    local mon = newState.monitors[screen.uuid]
    if not mon then
      newState.monitors[screen.uuid] = {
        name = screen.name,
        slots = seedSlots(screen.uuid, screen.index, lookups, minSlots, usedNames),
      }
      changed = true
    else
      if mon.name ~= screen.name then
        mon.name = screen.name
        changed = true
      end
      if type(mon.slots) ~= "table" then
        mon.slots = {}
        changed = true
      end

      -- Assign newly discovered real workspaces to unused placeholder slots.
      local myWs = lookups.workspacesByMonitor[screen.index] or {}
      local inSlots = {}
      for _, name in ipairs(mon.slots) do inSlots[name] = true end
      local newWs = {}
      for wsName in pairs(myWs) do
        if not inSlots[wsName] then table.insert(newWs, wsName) end
      end
      if #newWs > 0 then
        newWs = sortWorkspaces(newWs)
        local placeholderPos = {}
        for i, name in ipairs(mon.slots) do
          if isPlaceholder(name) and not myWs[name] then
            table.insert(placeholderPos, i)
          end
        end
        local pi = 1
        for _, wsName in ipairs(newWs) do
          if pi <= #placeholderPos then
            mon.slots[placeholderPos[pi]] = wsName
            pi = pi + 1
          else
            table.insert(mon.slots, wsName)
          end
        end
        changed = true
      end

      -- Fill to minSlots with collision-free placeholders.
      if #mon.slots < minSlots then
        for i = #mon.slots + 1, minSlots do
          table.insert(mon.slots, placeholderName(screen.uuid, i, usedNames))
        end
        changed = true
      end
    end
  end

  -- Disconnected monitors preserved unchanged for reconnects.

  -- Build views for connected screens.
  local views = {}
  local reservations = {}
  for _, screen in ipairs(screens) do
    for _, name in ipairs(newState.monitors[screen.uuid].slots) do
      reservations[name] = (reservations[name] or 0) + 1
    end
  end
  for _, screen in ipairs(screens) do
    local mon = newState.monitors[screen.uuid]
    if mon then
      local viewSlots = {}
      local activeSlot = nil
      local focused = false
      for i, slotName in ipairs(mon.slots) do
        local effectiveWs = slotName
        local exists, visible, wsFocused = false, false, false
        -- Check ownership for ALL names, including ASW-* placeholders.
        local owner = lookups.workspaceOwner[slotName]
        if owner then
          if owner.monitorIndex == screen.index then
            exists = true
            visible = owner.visible
            wsFocused = owner.focused
            if owner.focused then focused = true end
          else
            -- Owned by another connected monitor: blank it.
            effectiveWs = placeholderName(screen.uuid, i, usedNames)
          end
        elseif (reservations[slotName] or 0) > 1 then
          -- Reconnected monitors must not share an unmaterialized activation target.
          effectiveWs = placeholderName(screen.uuid, i, usedNames)
        end
        if visible then activeSlot = i end
        viewSlots[i] = {
          number = i,
          workspace = effectiveWs,
          exists = exists,
          visible = visible,
          focused = wsFocused,
        }
      end
      views[screen.uuid] = {
        uuid = screen.uuid,
        name = screen.name,
        index = screen.index,
        monitorId = screen.monitorId,
        slots = viewSlots,
        activeSlot = activeSlot,
        focused = focused,
      }
    end
  end

  return newState, views, changed
end

return M
