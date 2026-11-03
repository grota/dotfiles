--!nonstrict
-- Niri Position service.
--
-- Mirrors Niri's workspaces and windows from `niri msg -j event-stream` and
-- publishes the focused workspace/column/window position to
-- `niri_position.info`. The overlay panel shows for `timeout_ms` after the
-- position changes or after a Super double-tap, and while Super is held, each
-- as enabled in the settings. Super is read from `libinput debug-events`, which
-- needs read access to /dev/input (membership in the `input` group).

local PANEL = "grota/niri-position:overlay"
-- Niri replays its full state when the stream starts; don't flash the overlay for it.
local STARTUP_GRACE_MS = 1500
local RUNTIME_DIR = noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp"

local workspaces = {} -- id -> workspace
local windows = {} -- id -> window
local focusedWindowId = nil

local superDown = {} -- libinput device -> true while its Super key is pressed
local superSince = nil -- when Super went down, nil while it is up
local tapReleasedAt = nil -- when the last tap ended, nil after a hold or double-tap
local panelOpen = false
local startedAt = noctalia.nowMs()
local lastKey = nil
local showUntil = 0 -- a position change or double-tap keeps the panel open until then

local function enabled(key)
  return noctalia.getConfig(key) ~= false
end

local function timeoutMs()
  return tonumber(noctalia.getConfig("timeout_ms")) or 900
end

-- Holding Super shorter than this (a quick Super+key shortcut) is a tap.
local function holdDelayMs()
  return tonumber(noctalia.getConfig("hold_delay_ms")) or 250
end

-- A press starting within this long after a tap was released is a double-tap.
local function doubleTapMs()
  return tonumber(noctalia.getConfig("double_tap_ms")) or 300
end

-- Every counted workspace on the focused workspace's output, top to bottom:
-- { current, columns = { { width, focused, windows = { { height, focused } } } } }
-- with columns left to right and windows top to bottom, sized from the tiles.
-- Floating windows are left out: they are not part of the scrolling layout.
local function buildMap(focusedWs, occupied, lastIdx, focused)
  local list = {}
  for _, ws in pairs(workspaces) do
    local trailingEmpty = ws.idx == lastIdx and not occupied[ws.id] and not ws.is_focused
    if ws.output == focusedWs.output and not trailingEmpty then
      table.insert(list, ws)
    end
  end
  table.sort(list, function(a, b)
    return a.idx < b.idx
  end)

  local map = {}
  for _, ws in ipairs(list) do
    local columns, maxCol = {}, 0
    for _, win in pairs(windows) do
      local layout = win.layout
      local pos = layout and layout.pos_in_scrolling_layout
      if win.workspace_id == ws.id and type(pos) == "table" then
        local col = columns[pos[1]] or { width = 0, focused = false, windows = {} }
        columns[pos[1]] = col
        local size = type(layout.tile_size) == "table" and layout.tile_size or { 1, 1 }
        col.width = math.max(col.width, size[1])
        local isFocused = focused ~= nil and win.id == focused.id
        col.focused = col.focused or isFocused
        col.windows[pos[2]] = { height = size[2], focused = isFocused }
        col.rows = math.max(col.rows or 0, pos[2])
        maxCol = math.max(maxCol, pos[1])
      end
    end
    -- Dense arrays: indices come from Niri and are contiguous, but be safe.
    local dense = {}
    for c = 1, maxCol do
      local col = columns[c]
      if col then
        local wins = {}
        for r = 1, col.rows do
          if col.windows[r] then
            table.insert(wins, col.windows[r])
          end
        end
        table.insert(dense, { width = col.width, focused = col.focused, windows = wins })
      end
    end
    table.insert(map, { current = ws.id == focusedWs.id, columns = dense })
  end
  return map
end

-- Position of the focused workspace among those on its output, and of the
-- focused window in the scrolling layout. nil when nothing is focused.
local function computeInfo()
  local focusedWs = nil
  for _, ws in pairs(workspaces) do
    if ws.is_focused then
      focusedWs = ws
    end
  end
  if focusedWs == nil then
    return nil
  end

  local occupied = {}
  for _, win in pairs(windows) do
    -- workspace_id is null for a window not on any workspace yet.
    if win.workspace_id ~= nil then
      occupied[win.workspace_id] = true
    end
  end

  -- Niri keeps one empty workspace at the end of each output; don't count it
  -- unless it is the focused one.
  local wsTotal, lastIdx = 0, 0
  for _, ws in pairs(workspaces) do
    if ws.output == focusedWs.output then
      wsTotal += 1
      lastIdx = math.max(lastIdx, ws.idx)
    end
  end
  for _, ws in pairs(workspaces) do
    if ws.output == focusedWs.output and ws.idx == lastIdx and not occupied[ws.id] and not ws.is_focused then
      wsTotal -= 1
    end
  end

  local info = {
    wsId = focusedWs.id,
    ws = focusedWs.idx,
    wsTotal = wsTotal,
    wsName = focusedWs.name,
    col = 0,
    colTotal = 0,
    row = 0,
    rowTotal = 0,
    floating = false,
  }

  local focused = focusedWindowId and windows[focusedWindowId]
  if focused and focused.workspace_id ~= focusedWs.id then
    focused = nil
  end
  local focusedPos = focused and focused.layout and focused.layout.pos_in_scrolling_layout
  if focused and focused.is_floating then
    info.floating = true
  end

  for _, win in pairs(windows) do
    local pos = win.layout and win.layout.pos_in_scrolling_layout
    if win.workspace_id == focusedWs.id and type(pos) == "table" then
      info.colTotal = math.max(info.colTotal, pos[1])
      if type(focusedPos) == "table" and pos[1] == focusedPos[1] then
        info.rowTotal = math.max(info.rowTotal, pos[2])
      end
    end
  end
  if type(focusedPos) == "table" then
    info.col = focusedPos[1]
    info.row = focusedPos[2]
  end
  info.map = buildMap(focusedWs, occupied, lastIdx, focused)
  return info
end

local function setWindow(win)
  if type(win) == "table" and win.id ~= nil then
    windows[win.id] = win
    if win.is_focused then
      focusedWindowId = win.id
    end
  end
end

local function handleNiri(event)
  if event.WorkspacesChanged then
    workspaces = {}
    for _, ws in ipairs(event.WorkspacesChanged.workspaces or {}) do
      workspaces[ws.id] = ws
    end
  elseif event.WorkspaceActivated then
    local e = event.WorkspaceActivated
    local target = workspaces[e.id]
    if target then
      for _, ws in pairs(workspaces) do
        if ws.output == target.output then
          ws.is_active = ws.id == e.id
        end
        if e.focused then
          ws.is_focused = ws.id == e.id
        end
      end
    end
  elseif event.WindowsChanged then
    windows = {}
    focusedWindowId = nil
    for _, win in ipairs(event.WindowsChanged.windows or {}) do
      setWindow(win)
    end
  elseif event.WindowOpenedOrChanged then
    setWindow(event.WindowOpenedOrChanged.window)
  elseif event.WindowClosed then
    windows[event.WindowClosed.id] = nil
  elseif event.WindowFocusChanged then
    -- id is null when a layer surface (a Noctalia panel, the launcher) takes
    -- keyboard focus. That is not a move: treating it as one would pop the
    -- overlay up and replace the panel that was just opened.
    if event.WindowFocusChanged.id == nil then
      return
    end
    focusedWindowId = event.WindowFocusChanged.id
  elseif event.WindowLayoutsChanged then
    for _, change in ipairs(event.WindowLayoutsChanged.changes or {}) do
      local win = windows[change[1]]
      if win then
        win.layout = change[2]
      end
    end
  else
    return
  end
  local info = computeInfo()
  if info == nil then
    return
  end
  noctalia.state.set("niri_position.info", info)

  local key = `{info.wsId}:{info.col}:{info.row}:{info.floating}`
  if key ~= lastKey then
    lastKey = key
    if enabled("on_change") and noctalia.nowMs() - startedAt >= STARTUP_GRACE_MS then
      showUntil = noctalia.nowMs() + timeoutMs()
    end
  end
end

-- Lines look like "-event19  KEYBOARD_KEY  +1.234s  KEY_LEFTMETA (125) pressed".
-- Each keyboard (including virtual ones such as input-remapper's) reports its
-- own Super, so Super counts as held while any device has it down.
local function handleKey(line)
  local device = string.match(line, "^[%- ]?(event%d+)")
  if device == nil then
    return
  end
  if string.find(line, "DEVICE_REMOVED", 1, true) then
    superDown[device] = nil
  elseif string.find(line, "META (", 1, true) then
    superDown[device] = string.find(line, "pressed", 1, true) ~= nil or nil
  else
    return
  end
  local now = noctalia.nowMs()
  if next(superDown) == nil then
    if superSince then
      local tapped = now - superSince < holdDelayMs()
      tapReleasedAt = if tapped then now else nil
      superSince = nil
    end
  elseif superSince == nil then
    superSince = now
    if tapReleasedAt and now - tapReleasedAt <= doubleTapMs() then
      tapReleasedAt = nil
      if enabled("on_double_tap") then
        showUntil = now + timeoutMs()
      end
    end
  end
end

local function setPanel(open)
  if open ~= panelOpen then
    noctalia.togglePanel(PANEL)
    panelOpen = open
  end
end

-- Noctalia delivers lines from only one runStream per script, so both readers
-- run under one shell: each restarts its command when it exits (for example
-- across a Niri restart), and lines are told apart by their first character.
-- setsid -w gives the tree its own process group (and waits, so the stream
-- stays open even when setsid has to fork); its PID (the group id) goes to
-- a file so the next load kills exactly that tree. The tag guards against
-- a reused PID.
local STREAM_TAG = "niri-position-stream"
local PID_FILE = `{RUNTIME_DIR}/{STREAM_TAG}.pid`
local NIRI = "while :; do niri msg -j event-stream; sleep 1; done"
local KEYS = "while :; do libinput debug-events | grep --line-buffered -E \"KEY_(LEFT|RIGHT)META|DEVICE_REMOVED\"; sleep 1; done"
-- The new tree kills the previous one itself, so overlapping reloads (a file
-- hot reload racing a disable/enable) can't leave two trees running.
local START_STREAM = `exec setsid -w sh -c 'if p=$(cat "$1" 2>/dev/null) && [ "$p" != $$ ] && tr "\\0" " " </proc/"$p"/cmdline 2>/dev/null | grep -q "$0"; then kill -- -"$p"; fi; echo $$ >"$1"; echo "pid $$"; ({NIRI}) & ({KEYS}) & wait' {STREAM_TAG} '{PID_FILE}'`

local streamPid = nil -- this instance's tree, reported on the stream's first line

noctalia.runStream(START_STREAM, function(line)
  local pid = string.match(line, "^pid (%d+)$")
  if pid then
    streamPid = pid
  elseif string.sub(line, 1, 1) == "{" then
    local event = noctalia.json.decode(line)
    if type(event) == "table" then
      handleNiri(event)
    end
  else
    handleKey(line)
  end
end)

-- The overlay reports its own open state, so a panel closed by other means
-- (for example `noctalia msg panel-close`) does not desync the toggle.
noctalia.state.watch("niri_position.open", function(value)
  panelOpen = value == true
end)

function update()
  local now = noctalia.nowMs()
  local held = superSince ~= nil and now - superSince >= holdDelayMs()
  setPanel((held and enabled("on_hold")) or now < showUntil)
end

function onExit()
  -- Only this instance's own tree: a reload may already have started the next.
  if streamPid then
    noctalia.runAsync(`if tr '\\0' ' ' </proc/{streamPid}/cmdline 2>/dev/null | grep -q '{STREAM_TAG}'; then kill -- -{streamPid}; fi`)
  end
  if panelOpen then
    noctalia.togglePanel(PANEL)
  end
end

noctalia.setUpdateInterval(50)
