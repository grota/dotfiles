--!nonstrict
-- Battery Guard alert panel: renders the warning published by the service.
-- A click anywhere on it dismisses it.

local function color(key, default)
  local value = noctalia.getConfig(key)
  return if type(value) == "string" and value ~= "" then value else default
end

local function render()
  local info = noctalia.state.get("battery_guard.info")
  if type(info) ~= "table" then
    panel.render(ui.column({}, {}))
    return
  end

  local critical = info.tier == "critical"
  local accent = if critical then color("critical_color", "error") else color("warning_color", "tertiary")
  local title = noctalia.tr(if critical then "ui.critical_title" else "ui.low_title")
  local body = if info.timeLeft
    then noctalia.tr("ui.remaining_time", { percent = info.level, time = info.timeLeft })
    else noctalia.tr("ui.remaining", { percent = info.level })

  panel.render(ui.row({
    gap = 14,
    padding = 14,
    align = "center",
    flexGrow = 1,
    radius = 12,
    fill = `{accent}/0.12`,
    border = accent,
    borderWidth = 2,
    tooltip = noctalia.tr("ui.dismiss_hint"),
    onClick = function()
      panel.close()
    end,
  }, {
    ui.glyph({ name = if critical then "battery-exclamation" else "battery-1", size = 34, color = accent }),
    ui.column({ gap = 6, flexGrow = 1, justify = "center" }, {
      ui.label({ text = title, fontSize = 16, fontWeight = "bold", color = accent }),
      ui.label({ text = body, fontSize = 13, opacity = 0.85 }),
      ui.progress({ progress = math.clamp(info.level / 100, 0, 1), fill = accent, height = 4, radius = 2 }),
    }),
  }))
end

noctalia.state.watch("battery_guard.info", function()
  render()
end)

function onOpen(_context)
  noctalia.state.set("battery_guard.open", true)
  render()
end

function onClose()
  noctalia.state.set("battery_guard.open", false)
end
