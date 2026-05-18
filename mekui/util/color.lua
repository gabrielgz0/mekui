--[[
  mekui/util/color.lua
  Color utilities: palettes, interpolation (lerp) by value,
  and mapping from values to colors.
]]

local color = {}
local C = {}

-- ─── Built-in Color Palettes ─────────────────────────────────────────

-- Map from numeric color to name (CC:Tweaked colors API)
local COLOR_NAMES = {
  [1]  = "white",
  [2]  = "orange",
  [3]  = "magenta",
  [4]  = "lightBlue",
  [5]  = "yellow",
  [6]  = "lime",
  [7]  = "pink",
  [8]  = "gray",
  [9]  = "lightGray",
  [10] = "cyan",
  [11] = "purple",
  [12] = "blue",
  [13] = "brown",
  [14] = "green",
  [15] = "red",
  [16] = "black",
}

-- Predefined palettes
local PALETTES = {
  -- Temperature: cold → hot
  temperature = { 12, 4, 5, 2, 15 },
  -- Danger: safe → critical
  danger = { 14, 6, 5, 2, 15 },
  -- Energy: empty → full
  energy = { 8, 9, 4, 12, 14 },
  -- Rainbow
  rainbow = { 15, 2, 5, 4, 12, 6, 14 },
  -- Monochrome
  mono = { 16, 8, 9, 7, 1 },
}

function C:new()
  return setmetatable({}, { __index = C })
end

-- ── Palette Access ───────────────────────────────────────────────────

--- Get a palette by name. Returns a table of color numbers.
function C:palette(name)
  return PALETTES[name] or PALETTES.danger
end

--- List available palette names.
function C:listPalettes()
  local names = {}
  for k, _ in pairs(PALETTES) do
    table.insert(names, k)
  end
  table.sort(names)
  return names
end

--- Register a custom palette.
function C:registerPalette(name, colors)
  PALETTES[name] = colors
  return self
end

--- Get color name for a color value.
function C:name(color_val)
  return COLOR_NAMES[color_val] or "unknown"
end

-- ── Color Interpolation (Lerp) ───────────────────────────────────────

--- Extract RGB components from a CC:Tweaked color value.
--- CC:Tweaked colors are bit flags; we approximate with known values.
--- @param color_val number (1-16)
--- @return table {r, g, b} each 0-1
local function colorToRGB(color_val)
  -- CC:Tweaked color -> approximate sRGB (normalized 0-1)
  local map = {
    [1]  = { 1.0, 1.0, 1.0 },  -- white
    [2]  = { 1.0, 0.5, 0.0 },  -- orange
    [3]  = { 1.0, 0.0, 1.0 },  -- magenta
    [4]  = { 0.5, 0.5, 1.0 },  -- lightBlue
    [5]  = { 1.0, 1.0, 0.0 },  -- yellow
    [6]  = { 0.0, 1.0, 0.0 },  -- lime
    [7]  = { 1.0, 0.7, 0.7 },  -- pink
    [8]  = { 0.5, 0.5, 0.5 },  -- gray
    [9]  = { 0.75, 0.75, 0.75 }, -- lightGray
    [10] = { 0.0, 1.0, 1.0 },  -- cyan
    [11] = { 0.5, 0.0, 0.5 },  -- purple
    [12] = { 0.0, 0.0, 1.0 },  -- blue
    [13] = { 0.6, 0.3, 0.1 },  -- brown
    [14] = { 0.0, 0.5, 0.0 },  -- green
    [15] = { 1.0, 0.0, 0.0 },  -- red
    [16] = { 0.0, 0.0, 0.0 },  -- black
  }
  return map[color_val] or { 0.5, 0.5, 0.5 }
end

--- Convert RGB (0-1) back to the nearest CC:Tweaked color.
local function rgbToColor(r, g, b)
  local best, best_dist = 1, math.huge
  for i = 1, 16 do
    local cr, cg, cb = table.unpack(colorToRGB(i))
    local dist = (r - cr)^2 + (g - cg)^2 + (b - cb)^2
    if dist < best_dist then
      best_dist = dist
      best = i
    end
  end
  return best
end

--- Linearly interpolate between two CC:Tweaked color values.
--- @param c1 number start color (1-16)
--- @param c2 number end color (1-16)
--- @param t number interpolation factor (0-1)
--- @return number interpolated color (1-16)
function C:lerp(c1, c2, t)
  t = math.max(0, math.min(1, t))
  local r1, g1, b1 = table.unpack(colorToRGB(c1))
  local r2, g2, b2 = table.unpack(colorToRGB(c2))
  return rgbToColor(
    r1 + (r2 - r1) * t,
    g1 + (g2 - g1) * t,
    b1 + (b2 - b1) * t
  )
end

--- Map a value to a color using a palette gradient.
--- @param value number current value
--- @param min number range minimum
--- @param max number range maximum
--- @param palette_name string palette name (default: danger)
--- @return number color value
function C:map(value, min, max, palette_name)
  local pal = PALETTES[palette_name] or PALETTES.danger
  if min >= max then return pal[1] end

  local t = (value - min) / (max - min)
  t = math.max(0, math.min(1, t))

  -- Map t to palette index
  local segments = #pal - 1
  local seg = math.floor(t * segments)
  local local_t = (t * segments) - seg

  if seg >= #pal then
    return pal[#pal]
  end

  return self:lerp(pal[seg + 1], pal[seg + 2], local_t)
end

--- Get a contrasting text color for a given background color.
--- @param bg_color number background color (1-16)
--- @return number text color
function C:contrast(bg_color)
  local r, g, b = table.unpack(colorToRGB(bg_color))
  local luminance = 0.299 * r + 0.587 * g + 0.114 * b
  if luminance > 0.5 then
    return colors.black or 16
  else
    return colors.white or 1
  end
end

-- ── Terminal colors guard ────────────────────────────────────────────

-- Provide fallback colors if colors API is not available
if not colors then
  colors = {
    white      = 1,
    orange     = 2,
    magenta    = 3,
    lightBlue  = 4,
    yellow     = 5,
    lime       = 6,
    pink       = 7,
    gray       = 8,
    lightGray  = 9,
    cyan       = 10,
    purple     = 11,
    blue       = 12,
    brown      = 13,
    green      = 14,
    red        = 15,
    black      = 16,
  }
end

return C
