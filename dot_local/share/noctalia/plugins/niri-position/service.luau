--!nonstrict
-- Niri Position service.
--
-- Mirrors Niri's workspaces and windows from `niri msg -j event-stream` and,
-- whenever the focused workspace/column/window position changes, publishes it
-- to `niri_position.info` and shows the overlay panel (or a notification).
-- The overlay hides itself again after `timeout_ms`.

local PANEL = "grota/niri-position:overlay"
-- argv[0] of the stream loop; the PID file plus this tag let a reload kill
-- exactly the previous loop and nothing else.
local STREAM_TAG = "niri-position-stream"
local PID_FILE = `{noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp"}/niri-position-stream.pid`
-- Kills the loop named in PID_FILE (and its niri msg child), but only if that
-- PID still belongs to the loop: after a reboot the PID may be someone else's.
local KILL_STREAM = `if p=$(cat '{PID_FILE}' 2>/dev/null) && tr '\\0' ' ' </proc/"$p"/cmdline 2>/dev/null | grep -q '{STREAM_TAG}'; then pkill -P "$p"; kill "$p"; fi; rm -f '{PID_FILE}'`
-- Niri replays its full state when the stream starts; don't flash the overlay for it.
local STARTUP_GRACE_MS = 1500

local workspaces = {} -- id -> workspace
local windows = {} -- id -> window
local focusedWindowId = nil

local startedAt = noctalia.nowMs()
local lastKey = nil
local shownAt = 0
local panelOpen = false
local notifyId = nil

local function mode()
  return noctalia.getConfig("mode") or "overlay"
end

local function timeoutMs()
  return tonumber(noctalia.getConfig("timeout_ms")) or 900
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
      if focusedPos and type(focusedPos) == "table" and pos[1] == focusedPos[1] then
        info.rowTotal = math.max(info.rowTotal, pos[2])
      end
    end
  end
  if type(focusedPos) == "table" then
    info.col = focusedPos[1]
    info.row = focusedPos[2]
  end
  return info
end

local function notificationText(info)
  local parts = { `{noctalia.tr("ui.workspace")} {info.ws}/{info.wsTotal}` }
  if info.floating then
    table.insert(parts, noctalia.tr("ui.floating"))
  elseif info.col > 0 then
    table.insert(parts, `{noctalia.tr("ui.column")} {info.col}/{info.colTotal}`)
    if info.rowTotal > 1 then
      table.insert(parts, `{noctalia.tr("ui.window")} {info.row}/{info.rowTotal}`)
    end
  end
  return table.concat(parts, " · ")
end

local function showNotification(info)
  -- notify-send -r replaces the previous one instead of stacking.
  local argv = { "notify-send", "-p", "-a", "Niri", "-t", tostring(timeoutMs()) }
  if notifyId then
    table.insert(argv, "-r")
    table.insert(argv, notifyId)
  end
  table.insert(argv, notificationText(info))
  noctalia.runAsync(argv, function(result)
    if type(result) == "table" and result.exitCode == 0 then
      local id = noctalia.string.trim(result.stdout or "")
      if id ~= "" then
        notifyId = id
      end
    end
  end)
end

local function setPanel(open)
  if open ~= panelOpen then
    noctalia.togglePanel(PANEL)
    panelOpen = open
  end
end

local function maybeShow()
  local info = computeInfo()
  if info == nil then
    return
  end
  noctalia.state.set("niri_position.info", info)

  local key = `{info.wsId}:{info.col}:{info.row}:{info.floating}`
  if key == lastKey then
    return
  end
  lastKey = key
  if noctalia.nowMs() - startedAt < STARTUP_GRACE_MS then
    return
  end

  local m = mode()
  if m == "overlay" then
    shownAt = noctalia.nowMs()
    setPanel(true)
  elseif m == "notification" then
    showNotification(info)
  end
end

local function setWindow(win)
  if type(win) == "table" and win.id ~= nil then
    windows[win.id] = win
    if win.is_focused then
      focusedWindowId = win.id
    end
  end
end

local function handle(event)
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
  maybeShow()
end

local function startStream()
  -- Restart the stream if niri msg exits (for example across a Niri restart).
  local cmd = `exec sh -c 'echo $$ >"$1"; while :; do niri msg -j event-stream; sleep 1; done' {STREAM_TAG} '{PID_FILE}'`
  noctalia.runStream(cmd, function(line)
    local event = noctalia.json.decode(line)
    if type(event) == "table" then
      handle(event)
    end
  end)
end

-- The overlay reports its own open state, so a panel closed by other means
-- (for example `noctalia msg panel-close`) does not desync the toggle.
noctalia.state.watch("niri_position.open", function(value)
  panelOpen = value == true
end)

function update()
  if panelOpen and noctalia.nowMs() - shownAt >= timeoutMs() then
    setPanel(false)
  end
end

function onExit()
  noctalia.runAsync(KILL_STREAM)
end

noctalia.setUpdateInterval(100)
-- Kill a stream left over from a previous load before starting a new one.
noctalia.runAsync(KILL_STREAM, function()
  startStream()
end)
