--!nonstrict
-- Niri Position overlay: renders the info published by the service, laid out
-- like Niri itself: workspaces as a vertical strip of dots on the left,
-- columns as a horizontal strip next to their "n / total" row.

-- Dots per strip. Beyond this the strip shows a window around the current
-- item, with a small marker at each end that has more items past it.
local MAX_SLOTS = 7
local DOT = 8
local CURRENT = 18
local MORE = 4
local GAP = 4

-- Slot kinds for `total` items: "current", "item", or "more".
local function slots(current, total)
  local list = {}
  if total <= MAX_SLOTS then
    for i = 1, total do
      table.insert(list, i == current and "current" or "item")
    end
    return list
  end
  local size = MAX_SLOTS - 2
  local first = math.max(1, math.min(current - math.floor(size / 2), total - size + 1))
  local last = first + size - 1
  -- An end with nothing clipped needs no marker; give its slot to an item.
  if first == 1 then
    last += 1
  elseif last == total then
    first -= 1
  end
  if first > 1 then
    table.insert(list, "more")
  end
  for i = first, last do
    table.insert(list, i == current and "current" or "item")
  end
  if last < total then
    table.insert(list, "more")
  end
  return list
end

-- Colors from the settings: a palette role ("primary") or a hex value.
local function color(key, default)
  local value = noctalia.getConfig(key)
  return if type(value) == "string" and value ~= "" then value else default
end

local function currentColor()
  return color("current_color", "primary")
end

local function itemColor()
  return color("item_color", "outline_variant")
end

local function slotLength(kind)
  if kind == "current" then
    return CURRENT
  elseif kind == "more" then
    return MORE
  end
  return DOT
end

-- Length of a strip along its axis.
local function stripLength(current, total)
  local list = slots(current, total)
  local length = GAP * math.max(#list - 1, 0)
  for _, kind in ipairs(list) do
    length += slotLength(kind)
  end
  return length
end

local function strip(key, current, total, vertical)
  local children = {}
  for i, kind in ipairs(slots(current, total)) do
    local long, short, fill, opacity = slotLength(kind), DOT, itemColor(), 1
    if kind == "current" then
      fill = currentColor()
    elseif kind == "more" then
      short, opacity = MORE, 0.6
    end
    table.insert(children, ui.box({
      key = `{key}{i}`,
      width = vertical and short or long,
      height = vertical and long or short,
      radius = short / 2,
      fill = fill,
      opacity = opacity,
    }))
  end
  local props = { key = key, gap = GAP, align = "center" }
  return vertical and ui.column(props, children) or ui.row(props, children)
end

local function dotsLeft()
  return noctalia.getConfig("dots_position") == "left"
end

-- With the dots on the left, a row gets a slot there `slotWidth` wide (the
-- column strip's width; 0 for none), empty on rows without dots, so the rows
-- that share it line up.
local function line(key, title, current, total, dots, slotWidth)
  local children = {
    ui.label({ text = title, fontSize = 13, opacity = 0.7, width = 84 }),
    ui.label({ text = `{current} / {total}`, fontSize = 16, fontWeight = "bold", width = 52 }),
  }
  local dotStrip = if dots and total >= 2 then strip(`{key}-dots`, current, total, false) else nil
  if dotsLeft() and slotWidth > 0 then
    table.insert(children, 1, ui.row({ key = `{key}-slot`, width = slotWidth, justify = "end", align = "center" }, { dotStrip }))
  elseif dotStrip then
    table.insert(children, dotStrip)
  end
  return ui.row({ key = key, gap = 10, align = "center" }, children)
end

-- Mini-map style: workspaces top to bottom, their columns left to right with
-- widths proportional to the real ones, windows stacked inside each column.
local MAP_WIDTH = 120
local MAP_HEIGHT = 96
local MAP_ROWS = 6 -- workspaces drawn; beyond this a window around the current one
local MAP_GAP = 3
local MAP_ROW_MAX = 16

local function miniMap(map)
  local first, last = 1, #map
  if #map > MAP_ROWS then
    local current = 1
    for i, ws in ipairs(map) do
      if ws.current then
        current = i
      end
    end
    first = math.max(1, math.min(current - math.floor(MAP_ROWS / 2), #map - MAP_ROWS + 1))
    last = first + MAP_ROWS - 1
  end
  local n = last - first + 1
  local rowHeight = math.min(MAP_ROW_MAX, math.floor((MAP_HEIGHT - MAP_GAP * (n - 1)) / n))

  -- One scale for every row, so equal columns look equal across workspaces.
  local scale = nil
  for i = first, last do
    local cols = map[i].columns
    local total = 0
    for _, col in ipairs(cols) do
      total += col.width
    end
    if total > 0 then
      local s = (MAP_WIDTH - MAP_GAP * (#cols - 1)) / total
      scale = if scale then math.min(scale, s) else s
    end
  end
  scale = scale or 1

  local rows = {}
  for i = first, last do
    local ws = map[i]
    local children = {
      -- Marks the current workspace.
      ui.box({ key = `mark{i}`, width = 3, height = rowHeight, radius = 1.5, fill = color("marker_color", "primary"), opacity = if ws.current then 1 else 0 }),
    }
    if #ws.columns == 0 then
      table.insert(children, ui.box({ key = `empty{i}`, width = rowHeight * 2, height = rowHeight, radius = 3, border = itemColor(), borderWidth = 1 }))
    end
    for c, col in ipairs(ws.columns) do
      local width = math.max(4, math.floor(col.width * scale))
      local stack = {}
      local total = 0
      for _, win in ipairs(col.windows) do
        total += win.height
      end
      local available = rowHeight - (#col.windows - 1)
      for w, win in ipairs(col.windows) do
        table.insert(stack, ui.box({
          key = `win{i}-{c}-{w}`,
          width = width,
          height = math.max(2, if total > 0 then available * win.height / total else available),
          radius = 2,
          fill = if win.focused then currentColor() else itemColor(),
        }))
      end
      table.insert(children, ui.column({ key = `col{i}-{c}`, gap = 1 }, stack))
    end
    table.insert(rows, ui.row({ key = `ws{i}`, gap = MAP_GAP, align = "center", opacity = if ws.current then 1 else 0.45 }, children))
  end
  return ui.column({ key = "map", gap = MAP_GAP, justify = "center" }, rows)
end

local function render()
  local info = noctalia.state.get("niri_position.info")
  if type(info) ~= "table" then
    panel.render(ui.column({}, {}))
    return
  end

  local wsTitle = noctalia.tr("ui.workspace")
  if type(info.wsName) == "string" and info.wsName ~= "" then
    wsTitle = info.wsName
  end
  local isMap = noctalia.getConfig("style") == "map"
  local showCols = not info.floating and info.col > 0
  local slotWidth = if showCols and not isMap and info.colTotal >= 2 then stripLength(info.col, info.colTotal) else 0
  -- The workspace row starts right after the workspace strip; only the column
  -- and window rows share the dot slot.
  local rows = { line("ws", wsTitle, info.ws, info.wsTotal, false, 0) }
  if info.floating then
    table.insert(rows, ui.label({ key = "float", text = noctalia.tr("ui.floating"), fontSize = 13, opacity = 0.7 }))
  elseif showCols then
    table.insert(rows, line("col", noctalia.tr("ui.column"), info.col, info.colTotal, not isMap, slotWidth))
    if info.rowTotal > 1 then
      table.insert(rows, line("row", noctalia.tr("ui.window"), info.row, info.rowTotal, false, slotWidth))
    end
  end

  local graphic = strip("ws-dots", info.ws, info.wsTotal, true)
  if noctalia.getConfig("style") == "map" and type(info.map) == "table" then
    graphic = miniMap(info.map)
  end
  panel.render(ui.row({ gap = 16, padding = 16, align = "center", justify = "center", flexGrow = 1 }, {
    graphic,
    ui.column({ key = "text", gap = 8, justify = "center" }, rows),
  }))
end

noctalia.state.watch("niri_position.info", function()
  render()
end)

function onOpen(_context)
  noctalia.state.set("niri_position.open", true)
  render()
end

function onClose()
  noctalia.state.set("niri_position.open", false)
end
