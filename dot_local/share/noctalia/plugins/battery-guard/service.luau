--!nonstrict
-- Battery Guard service.
--
-- Polls the laptop battery's sysfs uevent and, while it is discharging at or
-- below the start threshold, warns right away and then every interval minutes.
-- At or below the critical threshold the interval is the critical one and the
-- panel is used even in notification mode when Do Not Disturb would hide the
-- notification. Plugging in stops the warnings and closes the panel.
--
-- The warning shown is published to `battery_guard.info` for the panel.

local PANEL = "grota/battery-guard:alert"
local POLL_MS = 5000
local CANDIDATES = { "BAT0", "BAT1", "BAT2", "BATT", "BAT" }
local SOUND = "warning"

local batteryPath = nil -- uevent path of the battery, once found
local nextPollAt = 0
local polling = false

local lastWarnAt = nil -- nil while no warning cycle is running
local lastTier = nil -- "low" or "critical" for the running cycle

local panelOpen = false
local panelOpenedAt = 0

local loadedSound = nil -- path loaded into the sound bank under SOUND

local function cfgInt(key, default)
  return tonumber(noctalia.getConfig(key)) or default
end

local function cfgString(key, default)
  local value = noctalia.getConfig(key)
  return if type(value) == "string" and value ~= "" then value else default
end

local function setPanel(open)
  if open ~= panelOpen then
    noctalia.togglePanel(PANEL)
    panelOpen = open
  end
  if open then
    panelOpenedAt = noctalia.nowMs()
  end
end

-- "1h 05m" / "25m" from hours, nil when unknown.
local function formatHours(hours)
  if hours == nil or hours <= 0 or hours > 48 then
    return nil
  end
  local minutes = math.floor(hours * 60 + 0.5)
  if minutes >= 60 then
    return string.format("%dh %02dm", minutes // 60, minutes % 60)
  end
  return `{minutes}m`
end

local function parseUevent(raw)
  local fields = {}
  for key, value in string.gmatch(raw, "POWER_SUPPLY_([%w_]+)=([^\n]*)") do
    fields[key] = value
  end
  local level = tonumber(fields.CAPACITY)
  if level == nil then
    return nil
  end
  local hours = nil
  local energy, power = tonumber(fields.ENERGY_NOW), tonumber(fields.POWER_NOW)
  if energy and power and power > 0 then
    hours = energy / power
  else
    local charge, current = tonumber(fields.CHARGE_NOW), tonumber(fields.CURRENT_NOW)
    if charge and current and current > 0 then
      hours = charge / current
    end
  end
  return {
    level = level,
    -- "Not charging" means plugged in but held (charge limit): not a drain.
    discharging = fields.STATUS == "Discharging",
    timeLeft = formatHours(hours),
  }
end

local function playSound()
  if noctalia.getConfig("sound") ~= true then
    return
  end
  local path = cfgString("sound_file", nil)
  if path == nil then
    return
  end
  if path == loadedSound then
    noctalia.sound.play(SOUND)
    return
  end
  noctalia.sound.load(SOUND, path, function(ok, err)
    if ok then
      loadedSound = path
      noctalia.sound.play(SOUND)
    else
      noctalia.notifyError("Battery Guard: could not load sound", err)
    end
  end)
end

local function showPanel(info)
  noctalia.state.set("battery_guard.info", info)
  setPanel(true)
end

local function sendNotification(info)
  local title = noctalia.tr(if info.tier == "critical" then "ui.critical_title" else "ui.low_title")
  local body = if info.timeLeft
    then noctalia.tr("ui.remaining_time", { percent = info.level, time = info.timeLeft })
    else noctalia.tr("ui.remaining", { percent = info.level })
  local payload = noctalia.json.encode({
    app_name = "Battery Guard",
    summary = title,
    body = body,
    urgency = if info.tier == "critical" then "critical" else "normal",
    timeout_ms = cfgInt("auto_dismiss_s", 2) * 1000,
    icon = "battery-exclamation",
  })
  noctalia.runAsync({ "noctalia", "msg", "notification-show", payload })
end

local function warn(info)
  lastWarnAt = noctalia.nowMs()
  lastTier = info.tier
  playSound()
  if noctalia.getConfig("delivery") ~= "notify" then
    showPanel(info)
    return
  end
  noctalia.runAsync({ "noctalia", "msg", "notification-dnd-status" }, function(result)
    local dnd = string.match(result.stdout or "", "^%s*on") ~= nil
    if dnd and (info.tier == "critical" or noctalia.getConfig("dnd_fallback") ~= false) then
      showPanel(info)
    else
      sendNotification(info)
    end
  end)
end

local function reset()
  lastWarnAt = nil
  lastTier = nil
  setPanel(false)
end

local function evaluate(battery)
  local start = cfgInt("start_threshold", 20)
  local critical = math.min(cfgInt("critical_threshold", 8), start)
  if battery == nil or not battery.discharging or battery.level > start then
    reset()
    return
  end

  local tier = if battery.level <= critical then "critical" else "low"
  local intervalMin = if tier == "critical" then cfgInt("critical_interval_min", 1) else cfgInt("interval_min", 5)
  local due = lastWarnAt == nil
    or (tier == "critical" and lastTier ~= "critical")
    or noctalia.nowMs() - lastWarnAt >= intervalMin * 60000

  local info = { level = battery.level, tier = tier, timeLeft = battery.timeLeft }
  if due then
    warn(info)
  elseif panelOpen then
    -- Keep an open panel's numbers current without restarting its timer.
    noctalia.state.set("battery_guard.info", info)
  end
end

local function findBattery(index, done)
  local name = CANDIDATES[index]
  if name == nil then
    done(nil)
    return
  end
  local path = `/sys/class/power_supply/{name}/uevent`
  local queued = noctalia.readFileAsync(path, function(contents, _err)
    if contents and parseUevent(contents) then
      done(path)
    else
      findBattery(index + 1, done)
    end
  end)
  if not queued then
    done(nil)
  end
end

local function poll()
  local simulated = cfgInt("simulate_percent", 0)
  if simulated > 0 then
    evaluate({ level = simulated, discharging = true, timeLeft = nil })
    return
  end
  if polling then
    return
  end
  polling = true
  local function read(path)
    if path == nil then
      polling = false
      return
    end
    batteryPath = path
    local queued = noctalia.readFileAsync(path, function(contents, _err)
      polling = false
      if contents then
        evaluate(parseUevent(contents))
      else
        batteryPath = nil -- look it up again next time
      end
    end)
    if not queued then
      polling = false
    end
  end
  if batteryPath then
    read(batteryPath)
  else
    findBattery(1, read)
  end
end

-- The panel reports its own open state, so a click on it (or
-- `noctalia msg panel-close`) does not desync the toggle.
noctalia.state.watch("battery_guard.open", function(value)
  panelOpen = value == true
end)

function update()
  local now = noctalia.nowMs()
  if now >= nextPollAt then
    nextPollAt = now + POLL_MS
    poll()
  end
  local dismissMs = cfgInt("auto_dismiss_s", 2) * 1000
  if panelOpen and dismissMs > 0 and now - panelOpenedAt >= dismissMs then
    setPanel(false)
  end
end

function onResume()
  -- The battery may have drained or been plugged in while asleep.
  nextPollAt = 0
end

function onExit()
  if panelOpen then
    noctalia.togglePanel(PANEL)
  end
end

noctalia.setUpdateInterval(250)
