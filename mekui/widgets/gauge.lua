--[[
  mekui/widgets/gauge.lua
  FIXED:
    - draw() acumula cur_y corretamente: label -> value -> barra
    - _drawHorizontal nao sobrescreve mais self._height = 1
    - getRenderedHeight() retorna altura real para o layout
]]

local color_util = ( loadfile("mekui/util/color.lua") )()

local G = {}

local DEFAULT_COLORS = {
  background = colors.gray or 8,
  fill_low   = colors.red or 15,
  fill_mid   = colors.orange or 2,
  fill_high  = colors.green or 14,
  text       = colors.white or 1,
  border     = colors.lightGray or 9,
}

function G:new(config)
  config = config or {}
  local self = setmetatable({
    _x        = config.x or 1,
    _y        = config.y or 1,
    _width    = config.width or 20,
    _height   = config.height or 1,
    _min      = config.min or 0,
    _max      = config.max or 100,
    _value    = config.value or 0,
    _label    = config.label or "",
    _suffix   = config.suffix or "",
    _vertical   = config.vertical or false,
    _show_label = config.showLabel ~= false,
    _show_value = config.showValue ~= false,
    _border     = config.border ~= false,
    _use_gradient = config.useGradient or false,
    _colors = {
      background = config.bgColor     or DEFAULT_COLORS.background,
      fill_low   = config.fillLow     or DEFAULT_COLORS.fill_low,
      fill_mid   = config.fillMid     or DEFAULT_COLORS.fill_mid,
      fill_high  = config.fillHigh    or DEFAULT_COLORS.fill_high,
      text       = config.textColor   or DEFAULT_COLORS.text,
      border     = config.borderColor or DEFAULT_COLORS.border,
    },
    _low_threshold  = config.lowThreshold  or 0.33,
    _high_threshold = config.highThreshold or 0.66,
  }, { __index = G })
  return self
end

function G:setValue(val) self._value = val return self end
function G:setMin(val)   self._min = val   return self end
function G:setMax(val)   self._max = val   return self end
function G:setLabel(l)   self._label = l   return self end
function G:setPosition(x, y) self._x = x; self._y = y return self end
function G:setSize(w, h)     self._width = w; self._height = h return self end

function G:getPercent()
  local range = self._max - self._min
  if range <= 0 then return 0 end
  return math.max(0, math.min(1, (self._value - self._min) / range))
end

-- Altura real ocupada na tela (usado pelo layout em mekui.lua)
function G:getRenderedHeight()
  local h = 1
  if self._show_label and self._label and #self._label > 0 then h = h + 1 end
  if self._show_value then h = h + 1 end
  if self._vertical then
    h = self._height
    if self._show_label and self._label and #self._label > 0 then h = h + 1 end
    if self._show_value then h = h + 1 end
  end
  return h
end

function G:_pickColor(pct)
  if self._use_gradient then
    if pct <= self._low_threshold then
      local t = pct / self._low_threshold
      return color_util:lerp(self._colors.fill_low, self._colors.fill_mid, t)
    elseif pct <= self._high_threshold then
      local t = (pct - self._low_threshold) / (self._high_threshold - self._low_threshold)
      return color_util:lerp(self._colors.fill_mid, self._colors.fill_high, t)
    else
      return self._colors.fill_high
    end
  end
  if pct <= self._low_threshold then return self._colors.fill_low
  elseif pct <= self._high_threshold then return self._colors.fill_mid
  else return self._colors.fill_high
  end
end

-- FIXED: usa cur_y acumulado em vez de passar oy original para a barra
function G:draw(mon, ox, oy, max_h)
  ox = ox or self._x
  oy = oy or self._y

  local pct        = self:getPercent()
  local fill_color = self:_pickColor(pct)
  local cur_y      = oy

  if self._show_label and self._label and #self._label > 0 then
    mon.setBackgroundColor(colors.black or 16)
    mon.setTextColor(self._colors.text)
    mon.setCursorPos(ox, cur_y)
    mon.write(self._label)
    cur_y = cur_y + 1
  end

  if self._show_value then
    local val_str = tostring(self._value) .. self._suffix
    mon.setBackgroundColor(colors.black or 16)
    mon.setTextColor(self._colors.text)
    mon.setCursorPos(ox, cur_y)
    mon.write(val_str)
    cur_y = cur_y + 1
  end

  if self._vertical then
    self:_drawVertical(mon, ox, cur_y, pct, fill_color)
  else
    self:_drawHorizontal(mon, ox, cur_y, pct, fill_color)
  end
end

function G:_drawHorizontal(mon, ox, oy, pct, fill_color)
  local bar_w  = self._width
  local fill_w = math.floor(pct * bar_w)

  if self._border then
    mon.setBackgroundColor(colors.black or 16)
    mon.setTextColor(self._colors.border)
    mon.setCursorPos(ox, oy)
    mon.write("[")
    for col = 1, bar_w do
      mon.setCursorPos(ox + col, oy)
      mon.setBackgroundColor(col <= fill_w and fill_color or self._colors.background)
      mon.write(" ")
    end
    mon.setBackgroundColor(colors.black or 16)
    mon.setTextColor(self._colors.border)
    mon.setCursorPos(ox + bar_w + 1, oy)
    mon.write("]")
    -- percentual centrado
    local val_str = ("%3d%%"):format(math.floor(pct * 100 + 0.5))
    local text_x  = ox + 1 + math.floor((bar_w - #val_str) / 2)
    mon.setCursorPos(text_x, oy)
    mon.setTextColor(self._colors.text)
    mon.setBackgroundColor(fill_w >= math.floor(bar_w / 2) and fill_color or self._colors.background)
    mon.write(val_str)
  else
    for col = 1, bar_w do
      mon.setCursorPos(ox + col - 1, oy)
      mon.setBackgroundColor(col <= fill_w and fill_color or self._colors.background)
      mon.write(" ")
    end
    local val_str = ("%3d%%"):format(math.floor(pct * 100 + 0.5))
    local text_x  = ox + math.floor((bar_w - #val_str) / 2)
    mon.setCursorPos(text_x, oy)
    mon.setTextColor(self._colors.text)
    mon.setBackgroundColor(colors.black or 16)
    mon.write(val_str)
  end

  mon.setBackgroundColor(colors.black or 16)
  -- REMOVIDO: self._height = 1  <- era isso que quebrava o layout
  self._drawn_at = { x = ox, y = oy }
end

function G:_drawVertical(mon, ox, oy, pct, fill_color)
  local bar_w  = self._width
  local bar_h  = self._height
  local fill_h = math.floor(pct * bar_h)
  for row = 0, bar_h - 1 do
    for col = 0, bar_w - 1 do
      mon.setCursorPos(ox + col, oy + row)
      mon.setBackgroundColor((bar_h - row) <= fill_h and fill_color or self._colors.background)
      mon.write(" ")
    end
  end
  mon.setBackgroundColor(colors.black or 16)
  self._drawn_at = { x = ox, y = oy }
end

return G
