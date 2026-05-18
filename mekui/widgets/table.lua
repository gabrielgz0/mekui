--[[
  mekui/widgets/table.lua
  Scrollable item list with quantities.
  Displays a paginated list of rows (name + count).
  Supports header, footer, scroll indicators.
]]

local table_widget = {}
local T = {}

local DEFAULT_COLORS = {
  header      = colors.white or 1,
  header_bg   = colors.gray or 8,
  row         = colors.white or 1,
  row_alt     = colors.lightGray or 9,
  number      = colors.yellow or 5,
  scroll      = colors.gray or 8,
  border      = colors.gray or 8,
}

function T:new(config)
  config = config or {}

  local self = setmetatable({
    _x          = config.x or 1,
    _y          = config.y or 1,
    _width      = config.width or 25,
    _height     = config.height or 15,
    _items      = config.items or {},
    _header     = config.header or "Items",
    _row_height = config.rowHeight or 1,
    _scroll_pos = 0,
    _show_header = config.showHeader ~= false,
    _show_number = config.showNumbers ~= false,
    _alt_rows    = config.altRows ~= false,
    _name_width  = config.nameWidth or 0, -- 0 = auto

    _colors = {
      header      = config.headerColor or DEFAULT_COLORS.header,
      header_bg   = config.headerBg or DEFAULT_COLORS.header_bg,
      row         = config.rowColor or DEFAULT_COLORS.row,
      row_alt     = config.altRowColor or DEFAULT_COLORS.row_alt,
      number      = config.numberColor or DEFAULT_COLORS.number,
      scroll      = config.scrollColor or DEFAULT_COLORS.scroll,
      border      = config.borderColor or DEFAULT_COLORS.border,
    },
  }, { __index = T })

  return self
end

-- ── Data Management ──────────────────────────────────────────────────

function T:setItems(items)
  self._items = items or {}
  self._scroll_pos = 0
  return self
end

function T:addItem(name, count)
  table.insert(self._items, { name = name, count = count })
  return self
end

function T:setHeader(header)
  self._header = header
  return self
end

-- ── Scrolling ────────────────────────────────────────────────────────

function T:scrollUp()
  if self._scroll_pos > 0 then
    self._scroll_pos = self._scroll_pos - 1
  end
  return self
end

function T:scrollDown()
  local vis_rows = self:_visibleRows()
  if self._scroll_pos + vis_rows < #self._items then
    self._scroll_pos = self._scroll_pos + 1
  end
  return self
end

function T:scrollTo(index)
  self._scroll_pos = math.max(0, math.min(index, #self._items - 1))
  return self
end

function T:resetScroll()
  self._scroll_pos = 0
  return self
end

-- ── Internal ─────────────────────────────────────────────────────────

function T:_visibleRows()
  local header_lines = self._show_header and 1 or 0
  return math.max(1, self._height - header_lines - 1) -- -1 for border/padding
end

function T:_calcNameWidth()
  if self._name_width > 0 then return self._name_width end
  local max_w = self._width - 10 -- reserve for count
  -- Calculate auto width
  local w = 10
  for _, item in ipairs(self._items) do
    if #item.name > w then
      w = #item.name
    end
  end
  return math.min(w, max_w)
end

-- ── Draw ─────────────────────────────────────────────────────────────

function T:draw(mon, ox, oy, max_h)
  ox = ox or self._x
  oy = oy or self._y

  local vis_rows = self._height
  local line = oy

  -- Draw top border
  mon.setCursorPos(ox, line)
  mon.setTextColor(self._colors.border)
  mon.write("+" .. string.rep("-", self._width - 2) .. "+")
  line = line + 1

  -- Draw header
  if self._show_header then
    mon.setCursorPos(ox, line)
    mon.setTextColor(self._colors.header)
    mon.setBackgroundColor(self._colors.header_bg)
    mon.write(" ")
    local hdr = self._header
    if #hdr > self._width - 4 then
      hdr = hdr:sub(1, self._width - 7) .. "..."
    end
    mon.write(hdr)
    mon.write(string.rep(" ", self._width - #hdr - 3))
    mon.setBackgroundColor(colors.black or 16)
    line = line + 1
  end

  -- Draw separator
  mon.setCursorPos(ox, line)
  mon.setTextColor(self._colors.border)
  mon.write("+" .. string.rep("-", self._width - 2) .. "+")
  line = line + 1

  -- Draw rows
  local name_w = self:_calcNameWidth()
  local count_w = self._width - name_w - 5 -- account for " | " and borders
  if count_w < 5 then count_w = 5 end

  local end_row = math.min(self._scroll_pos + (self._height - line + oy - 1), #self._items)

  for i = self._scroll_pos + 1, end_row do
    if line > oy + self._height - 1 then break end

    local item = self._items[i]
    local row_color = self._colors.row
    if self._alt_rows and i % 2 == 0 then
      row_color = self._colors.row_alt
    end

    mon.setCursorPos(ox, line)
    mon.setTextColor(self._colors.border)
    mon.write("|")

    if self._show_number then
      mon.setTextColor(self._colors.number)
      local num_str = tostring(i) .. "."
      mon.write(num_str)
      -- Adjust name width
      local remaining = name_w - #num_str - 1
      mon.setTextColor(row_color)
      local name = item.name
      if #name > remaining then
        name = name:sub(1, remaining - 2) .. ".."
      end
      mon.write(" " .. name .. string.rep(" ", remaining - #name - 1))
    else
      mon.setTextColor(row_color)
      local name = item.name
      if #name > name_w then
        name = name:sub(1, name_w - 2) .. ".."
      end
      mon.write(" " .. name .. string.rep(" ", name_w - #name - 1))
    end

    mon.setTextColor(self._colors.border)
    mon.write(" |")

    -- Count (right-aligned)
    mon.setTextColor(self._colors.number)
    local count_str = tostring(item.count)
    if #count_str > count_w - 1 then
      count_str = ">999"
    end
    mon.write(string.rep(" ", count_w - #count_str - 1) .. count_str)

    mon.setTextColor(self._colors.border)
    mon.write("|")

    line = line + 1
  end

  -- Fill remaining rows
  while line <= oy + self._height - 1 do
    mon.setCursorPos(ox, line)
    mon.setTextColor(self._colors.border)
    mon.write("|" .. string.rep(" ", self._width - 2) .. "|")
    line = line + 1
  end

  -- Bottom border
  mon.setCursorPos(ox, line)
  mon.setTextColor(self._colors.border)
  mon.write("+" .. string.rep("-", self._width - 2) .. "+")

  -- Scroll indicator
  if #self._items > self:_visibleRows() then
    local pct = self._scroll_pos / math.max(1, #self._items - self:_visibleRows())
    local ind_y = oy + 1 + math.floor(pct * (self._height - 2))
    mon.setCursorPos(ox + self._width - 1, ind_y)
    mon.setTextColor(self._colors.scroll)
    mon.write("#")
  end

  self._drawn_at = { x = ox, y = oy }
end

return T
