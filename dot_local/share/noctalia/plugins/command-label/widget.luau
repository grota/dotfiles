--!nonstrict
-- Command Label bar widget for Noctalia.
--
-- Runs the configured shell command every `interval` seconds and shows the
-- first line of its stdout in the bar; the full output goes in the tooltip.
-- `noctalia msg plugin grota/command-label:label all refresh` re-runs it
-- immediately, so producers can push updates instead of waiting for a tick.

local TOOLTIP_MAX = 500

local running = false

local function intConfig(key, fallback)
  local value = tonumber(noctalia.getConfig(key))
  if value == nil then
    return fallback
  end
  return value
end

-- Truncate by codepoints, not bytes, so multi-byte text is never cut mid-char.
local function truncate(s, max)
  local len = utf8.len(s)
  if max <= 0 or len == nil or len <= max then
    return s
  end
  return s:sub(1, utf8.offset(s, max + 1) - 1) .. "…"
end

local function applyGlyph()
  local glyph = noctalia.getConfig("glyph")
  if type(glyph) == "string" and glyph ~= "" then
    barWidget.setGlyph(glyph)
  end
end

local function show(output)
  output = noctalia.string.trim(output or "")
  if output == "" and noctalia.getConfig("hide_when_empty") ~= false then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  applyGlyph()
  local firstLine = output:match("^[^\n]*") or ""
  barWidget.setText(truncate(firstLine, intConfig("max_chars", 40)))
  if output ~= "" then
    barWidget.setTooltip(truncate(output, TOOLTIP_MAX))
  else
    barWidget.clearTooltip()
  end
end

local function refresh()
  local cmd = noctalia.getConfig("command")
  if type(cmd) ~= "string" or cmd == "" then
    barWidget.setVisible(true)
    barWidget.setText("no command")
    barWidget.setTooltip("Set this widget's Command setting")
    return
  end
  -- Skip overlapping runs when a command is slower than the interval.
  if running then
    return
  end
  running = true
  noctalia.runAsync(cmd, function(result)
    running = false
    if type(result) ~= "table" then
      show("")
      return
    end
    if result.timedOut or result.exitCode ~= 0 then
      noctalia.log("command-label: '" .. cmd .. "' exited " .. tostring(result.exitCode) .. ": " .. (result.stderr or ""))
    end
    show(result.stdout)
  end, 5000)
end

function update()
  noctalia.setUpdateInterval(intConfig("interval", 10) * 1000)
  refresh()
end

function onIpc(event, _payload)
  if event == "refresh" then
    refresh()
  end
end
