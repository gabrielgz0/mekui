--[[
  mekui/widgets/graph.lua
  FIXED:
    - autoScale nao gera _min negativo (math.max(0, ...))
    - _min_floor preserva o minimo configurado pelo usuario
    - label e valor recente nao colidem no rodape
    - getRenderedHeight() retorna altura real para o layout
]]

local color_util = ( loadfile("mekui/util/color.lua") )()

local G = {}

local DEFAULT_COLORS = {
  axis       = colors.gray or 8,
  line       = colors.lime or 6,
  fill       = colors.green or 14,
  grid       = colors.gray or 8,
  background = colors.black or 16,
  label      = colors.white or 1,
}

function G:new(config)
  config = config or {}
  local self = setmetatable({
    _x          = config.x or 1,
    _y          = config.y or 1,
    _width      = config.width or 30,
    _height     = config.height or 10,
    _max_points = config.maxPoints or 60,
    _data       = {},
    _min        = config.min or 0,
    _max        = config.max or 100,
    _min_floor  = config.min or 0,  -- FIXED: preserva minimo do usuario
    _auto_scale = config.autoScale or false,
    _label      = config.label or "",
    _suffix     = config.suffix or "",
    _show_grid  = config.showGrid ~= false,
    _show_axis  = config.showAxis ~= false,
    _fill_area  = config.fillArea or false,
    _colors = {
      axis       = config.axisColor or DEFAULT_COLORS.axis,
      line       = config.lineColor or DEFAULT_COLORS.line,
      fill       = config.fillColor or DEFAULT_COLORS.fill,
      grid       = config.gridColor or DEFAULT_COLORS.grid,
      background = config.bgColor   or DEFAULT_COLORS.background,
      label      = config.labelColor or DEFAULT_COLORS.label,
    },
  }, { __index = G })
  return self
end

function G:push(value)
  table.insert(self._data, value)
  while #self._data > self._max_points do
    table.remove(self._data, 1)
  end

  if self._auto_scale and #self._data > 1 then
    local mn, mx = self:_bounds()
    local range = mx - mn
    if range < 1 then range = 1 end
    -- FIXED: nunca desce abaixo do minimo configurado pelo usuario
    self._min = math.max(self._min_floor, mn - range * 0.1)
    self._max = mx + range * 0.1
  end

  return self
end

function G:clear()
  self._data = {}
  return self
end

function G:setBounds(min, max)
  self._min = min
  self._max = max
  self._min_floor = min
  self._auto_scale = false
  return self
end

function G:setAutoScale(enabled)
  self._auto_scale = enabled
  return self
end

-- Altura real na tela: area do grafico + 1 linha de label/rodape
function G:getRenderedHeight()
  local h = self._height
  if self._label and #self._label > 0 then h = h + 1 end
  return h
end

function G:_bounds()
  local mn, mx = math.huge, -math.huge
  for _, v in ipairs(self._data) do
    if v < mn then mn = v end
    if v > mx then mx = v end
  end
  if mn == math.huge then mn, mx = 0, 1 end
  return mn, mx
end

function G:_valueToRow(val)
  local range = self._max - self._min
  if range <= 0 then return self._y + self._height - 1 end
  local pct = (val - self._min) / range
  pct = math.max(0, math.min(1, pct))
  return self._y + self._height - 1 - math.floor(pct * (self._height - 1))
end

function G:draw(mon, ox, oy, max_h)
  ox = ox or self._x
  oy = oy or self._y

  local graph_w = self._width
  local graph_h = self._height

  -- Limpa area
  mon.setBackgroundColor(self._colors.background)
  for row = 0, graph_h - 1 do
    mon.setCursorPos(ox, oy + row)
    mon.write(string.rep(" ", graph_w))
  end
  mon.setBackgroundColor(colors.black or 16)

  if #self._data < 2 then
    mon.setCursorPos(ox + 1, oy + math.floor(graph_h / 2))
    mon.setTextColor(self._colors.label)
    mon.write("no data")
    -- ainda escreve o rodape
    if self._label and #self._label > 0 then
      mon.setCursorPos(ox, oy + graph_h)
      mon.setBackgroundColor(colors.black or 16)
      mon.setTextColor(self._colors.label)
      mon.write(self._label)
    end
    return
  end

  -- Pontos a exibir
  local display_count = math.min(#self._data, graph_w)
  local start_idx     = #self._data - display_count + 1

  -- Calcula posicoes dos pontos usando oy local
  local points = {}
  for i = 0, display_count - 1 do
    local idx = start_idx + i
    local val = self._data[idx]
    local col = ox + math.floor(i * (graph_w - 1) / math.max(display_count - 1, 1))
    -- _valueToRow usa self._y; ajustamos para oy dinamico
    local range = self._max - self._min
    local pct = range > 0 and math.max(0, math.min(1, (val - self._min) / range)) or 0
    local row = oy + graph_h - 1 - math.floor(pct * (graph_h - 1))
    table.insert(points, { x = col, y = row })
  end

  -- Grid
  if self._show_grid then
    mon.setTextColor(self._colors.grid)
    for grid_row = oy, oy + graph_h - 1, 2 do
      mon.setCursorPos(ox, grid_row)
      mon.write(string.rep("-", graph_w))
    end
  end

  -- Area de fill
  if self._fill_area and #points >= 2 then
    local bottom_row = oy + graph_h - 1
    for _, p in ipairs(points) do
      for row = p.y + 1, bottom_row do
        mon.setCursorPos(p.x, row)
        mon.setBackgroundColor(self._colors.fill)
        mon.write(" ")
      end
    end
    mon.setBackgroundColor(colors.black or 16)
  end

  -- Linha
  if #points >= 2 then
    mon.setTextColor(self._colors.line)
    for _, p in ipairs(points) do
      mon.setCursorPos(p.x, p.y)
      mon.write("x")
    end
    for i = 2, #points do
      local a, b  = points[i - 1], points[i]
      local min_y = math.min(a.y, b.y)
      local max_y = math.max(a.y, b.y)
      for row = min_y, max_y do
        mon.setCursorPos(a.x, row)
        mon.setTextColor(self._colors.line)
        if a.y == b.y then mon.write("-")
        elseif row == a.y then mon.write("+")
        elseif row == b.y then mon.write("+")
        else mon.write("|")
        end
      end
    end
  end

  -- Labels de eixo (FIXED: usa floor(max) e floor(min), nunca negativo)
  if self._show_axis then
    mon.setBackgroundColor(colors.black or 16)
    mon.setTextColor(self._colors.axis)
    mon.setCursorPos(ox + 1, oy)
    mon.write(tostring(math.floor(self._max)))
    mon.setCursorPos(ox + 1, oy + graph_h - 1)
    mon.write(tostring(math.max(0, math.floor(self._min))))
  end

  -- Rodape: label a esquerda, valor recente a direita (FIXED: sem colisao)
  if self._label and #self._label > 0 then
    local latest  = self._data[#self._data]
    local val_str = tostring(math.floor(latest + 0.5)) .. self._suffix

    mon.setBackgroundColor(colors.black or 16)
    mon.setTextColor(self._colors.label)
    -- label a esquerda
    mon.setCursorPos(ox, oy + graph_h)
    mon.write(self._label)
    -- valor alinhado a direita, nunca sobrepoe o label
    local val_x = math.max(ox + #self._label + 1, ox + graph_w - #val_str)
    mon.setCursorPos(val_x, oy + graph_h)
    mon.write(val_str)
  end

  self._drawn_at = { x = ox, y = oy }
end

return G
