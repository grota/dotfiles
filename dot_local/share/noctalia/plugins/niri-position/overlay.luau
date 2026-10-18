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

local function strip(key, current, total, vertical)
  local children = {}
  for i, kind in ipairs(slots(current, total)) do
    local long, short, fill, opacity = DOT, DOT, "outline", 1
    if kind == "current" then
      long, fill = CURRENT, "primary"
    elseif kind == "more" then
      long, short, opacity = MORE, MORE, 0.6
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
  local props = { key = key, gap = 4, align = "center" }
  return vertical and ui.column(props, children) or ui.row(props, children)
end

local function line(key, title, current, total, dots)
  local children = {
    ui.label({ text = title, fontSize = 13, opacity = 0.7, width = 84 }),
    ui.label({ text = `{current} / {total}`, fontSize = 16, fontWeight = "bold", width = 52 }),
  }
  if dots and total >= 2 then
    table.insert(children, strip(`{key}-dots`, current, total, false))
  end
  return ui.row({ key = key, gap = 10, align = "center" }, children)
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
  local rows = { line("ws", wsTitle, info.ws, info.wsTotal, false) }
  if info.floating then
    table.insert(rows, ui.label({ key = "float", text = noctalia.tr("ui.floating"), fontSize = 13, opacity = 0.7 }))
  elseif info.col > 0 then
    table.insert(rows, line("col", noctalia.tr("ui.column"), info.col, info.colTotal, true))
    if info.rowTotal > 1 then
      table.insert(rows, line("row", noctalia.tr("ui.window"), info.row, info.rowTotal, false))
    end
  end

  panel.render(ui.row({ gap = 16, padding = 16, align = "center", flexGrow = 1 }, {
    strip("ws-dots", info.ws, info.wsTotal, true),
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
