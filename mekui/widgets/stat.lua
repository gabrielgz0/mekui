--[[
  mekui/widgets/stat.lua
  FIXED: getRenderedHeight() adicionado para o layout
]]

local S = {}

function S:new(config)
  config = config or {}
  local self = setmetatable({
    _x           = config.x or 1,
    _y           = config.y or 1,
    _width       = config.width or 12,
    _height      = config.height or 2,
    _label       = config.label or "",
    _value       = config.value or "",
    _suffix      = config.suffix or "",
    _color       = config.color or colors.white or 1,
    _label_color = config.labelColor or colors.lightGray or 9,
    _align       = config.align or "center",
  }, { __index = S })
  return self
end

function S:setValue(val)   self._value = val   return self end
function S:setLabel(l)     self._label = l     return self end
function S:setColor(c)     self._color = c     return self end
function S:setPosition(x, y) self._x = x; self._y = y return self end
function S:setSize(w, h)     self._width = w; self._height = h return self end

-- Altura real na tela: 1 linha de valor + 1 linha de label
function S:getRenderedHeight()
  local h = 1  -- valor
  if self._label and #self._label > 0 then h = h + 1 end
  return h
end

local function align_text(str, width, align)
  if #str >= width then return str:sub(1, width) end
  local pad = string.rep(" ", width - #str)
  if align == "right"  then return pad .. str end
  if align == "center" then
    local l = math.floor(#pad / 2)
    return pad:sub(1, l) .. str .. pad:sub(l + 1)
  end
  return str .. pad
end

function S:draw(mon, ox, oy, max_h)
  ox = ox or self._x
  oy = oy or self._y

  local val_str = tostring(self._value) .. self._suffix

  -- Valor
  mon.setBackgroundColor(colors.black or 16)
  mon.setTextColor(self._color)
  mon.setCursorPos(ox, oy)
  mon.write(align_text(val_str, self._width, self._align))

  -- Label
  if self._label and #self._label > 0 then
    mon.setTextColor(self._label_color)
    mon.setCursorPos(ox, oy + 1)
    mon.write(align_text(self._label, self._width, self._align))
  end

  self._drawn_at = { x = ox, y = oy }
end

return S
