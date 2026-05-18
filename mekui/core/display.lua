--[[
  mekui/core/display.lua
  Multi-monitor abstraction layer.
  Wraps peripheral.wrap for monitors and provides:
    - Multiple monitor support with active switching
    - Text scaling helpers
    - Color/grayscale detection
    - Write-thru: all calls go to the active monitor
]]

local display = {}
local D = {}

-- colour codes for fallback if colors API unavailable
local C = {
  WHITE   = 1,
  ORANGE  = 2,
  MAGENTA = 3,
  LIGHT_BLUE = 4,
  YELLOW  = 5,
  LIME    = 6,
  PINK    = 7,
  GRAY    = 8,
  LIGHT_GRAY = 9,
  CYAN    = 10,
  PURPLE  = 11,
  BLUE    = 12,
  BROWN   = 13,
  GREEN   = 14,
  RED     = 15,
  BLACK   = 16,
}

function D:new()
  return setmetatable({
    _monitors = {},
    _active   = nil,    -- index into _monitors
    _palette  = nil,    -- cached palette for active monitor
    _width    = 0,
    _height   = 0,
    _is_color = nil,    -- boolean; nil = unknown
  }, { __index = D })
end

-- ── Monitor Registration ─────────────────────────────────────────────

function D:addMonitor(side, label, monitorObj)
  local mon = monitorObj
  
  -- Se não passou monitorObj, tenta wrap pelo side
  if not mon then
    if not side then
      error("Monitor side or monitor object required")
    end
    local ok, wrapped = pcall(peripheral.wrap, side)
    if not ok or not wrapped then
      error("Cannot wrap monitor on side: " .. tostring(side))
    end
    mon = wrapped
  end
  
  if not mon.isColor or not mon.setCursorPos then
    error("Peripheral is not a monitor")
  end

  local entry = {
    side   = side or "auto",
    label  = label or side or "auto",
    mon    = mon,
  }
  table.insert(self._monitors, entry)

  -- Auto-select the first added monitor
  if #self._monitors == 1 then
    self:setActive(1)
  end

  return self
end

function D:removeMonitor(side)
  for i = #self._monitors, 1, -1 do
    if self._monitors[i].side == side then
      table.remove(self._monitors, i)
      break
    end
  end
  -- Reset active if the removed monitor was active
  if self._active and not self._monitors[self._active] then
    self._active = nil
    if #self._monitors > 0 then
      self:setActive(1)
    end
  end
  return self
end

function D:clear()
  self._monitors = {}
  self._active = nil
  return self
end

function D:list()
  local list = {}
  for _, entry in ipairs(self._monitors) do
    table.insert(list, { side = entry.side, label = entry.label })
  end
  return list
end

function D:count()
  return #self._monitors
end

-- ── Active Monitor Selection ─────────────────────────────────────────

function D:setActive(index)
  if index < 1 or index > #self._monitors then
    error("Monitor index out of range: " .. tostring(index))
  end
  self._active = index
  self:_cacheMonitorProps()
  return self
end

function D:getCurrent()
  if not self._active then return nil end
  local entry = self._monitors[self._active]
  return entry and entry.mon or nil
end

function D:getCurrentSide()
  if not self._active then return nil end
  local entry = self._monitors[self._active]
  return entry and entry.side or nil
end

-- ── Internal cache refresh ───────────────────────────────────────────

function D:_cacheMonitorProps()
  local mon = self:getCurrent()
  if not mon then
    self._width = 0
    self._height = 0
    self._is_color = false
    return
  end

  local w, h = mon.getSize()
  self._width  = w
  self._height = h

  -- Detect color capability
  local ok, is_col = pcall(mon.isColor)
  self._is_color = ok and is_col
end

-- ── Dimension Queries ────────────────────────────────────────────────

function D:getWidth()
  return self._width
end

function D:getHeight()
  return self._height
end

function D:isColor()
  return self._is_color or false
end

-- ── Drawing Helpers ──────────────────────────────────────────────────

function D:write(str)
  local mon = self:getCurrent()
  if mon then mon.write(tostring(str)) end
  return self
end

function D:writeAt(x, y, str)
  local mon = self:getCurrent()
  if mon then
    mon.setCursorPos(x, y)
    mon.write(tostring(str))
  end
  return self
end

function D:clearLine(y)
  local mon = self:getCurrent()
  if not mon then return self end
  mon.setCursorPos(1, y)
  mon.write(string.rep(" ", self._width))
  return self
end

function D:fill(x, y, w, h, char)
  local mon = self:getCurrent()
  if not mon then return self end
  char = char or " "
  for row = y, math.min(y + h - 1, self._height) do
    mon.setCursorPos(x, row)
    mon.write(string.rep(char, math.min(w, self._width - x + 1)))
  end
  return self
end

-- ── Color / Text Color ───────────────────────────────────────────────

function D:setTextColor(color)
  local mon = self:getCurrent()
  if mon then
    pcall(mon.setTextColor, color)
  end
  return self
end

function D:setBackgroundColor(color)
  local mon = self:getCurrent()
  if mon then
    pcall(mon.setBackgroundColor, color)
  end
  return self
end

-- ── Blit (per-character color) ───────────────────────────────────────

function D:blit(text, textColor, bgColor)
  local mon = self:getCurrent()
  if mon then
    pcall(mon.blit, text, textColor, bgColor)
  end
  return self
end

-- ── Text Scale ────────────────────────────────────────────────────────

function D:setTextScale(scale)
  local mon = self:getCurrent()
  if mon then
    pcall(mon.setTextScale, scale)
    -- Re-cache dimensions after scaling change
    self:_cacheMonitorProps()
  end
  return self
end

function D:getTextScale()
  local mon = self:getCurrent()
  if not mon then return 0.5 end
  local ok, scale = pcall(mon.getTextScale)
  return ok and scale or 0.5
end

-- ── Config Persistence ───────────────────────────────────────────────

function D:getConfig()
  return {
    active_index = self._active,
    monitors = {},
  }
end

function D:applyConfig(cfg)
  if not cfg then return self end
  if cfg.active_index then
    self:setActive(cfg.active_index)
  end
  return self
end

return D
