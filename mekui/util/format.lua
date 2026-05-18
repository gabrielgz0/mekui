--[[
  mekui/util/format.lua
  Formatting utilities for displaying values on screen.
  Converts raw numbers into human-readable strings:
    "1.2 MRF", "45.3%", "5.4k items", etc.
]]

local format = {}
local F = {}

function F:new()
  return setmetatable({}, { __index = F })
end

-- ── Number Suffixes ──────────────────────────────────────────────────

local SUFFIXES = {
  { threshold = 1e15, suffix = "Q"  },
  { threshold = 1e12, suffix = "T"  },
  { threshold = 1e9,  suffix = "G"  },
  { threshold = 1e6,  suffix = "M"  },
  { threshold = 1e3,  suffix = "k"  },
}

--- Format a number with SI suffixes.
--- @param n number
--- @param decimals number decimal places (default 1)
--- @return string
function F:si(n, decimals)
  decimals = decimals or 1
  local abs_n = math.abs(n)

  for _, entry in ipairs(SUFFIXES) do
    if abs_n >= entry.threshold then
      local val = n / entry.threshold
      local fmt = "%." .. tostring(decimals) .. "f"
      return string.format(fmt, val) .. " " .. entry.suffix
    end
  end

  -- Below 1000: just format with decimals
  local fmt = "%." .. tostring(decimals) .. "f"
  return string.format(fmt, n)
end

-- ── Energy ───────────────────────────────────────────────────────────

--- Format energy in FE/RF.
--- @param n number energy amount
--- @return string e.g. "1.2 MRF", "500 FE"
function F:energy(n)
  if n >= 1e15 then
    return self:si(n, 2) .. "RF"
  elseif n >= 1e12 then
    return self:si(n, 2) .. "RF"
  elseif n >= 1e9 then
    return self:si(n, 2) .. "RF"
  elseif n >= 1e6 then
    return self:si(n, 2) .. "RF"
  elseif n >= 1e3 then
    return self:si(n, 1) .. "RF"
  else
    return string.format("%.0f RF", n)
  end
end

-- ── Percentage ───────────────────────────────────────────────────────

--- Format a percentage.
--- @param pct number 0-100
--- @param decimals number (default 1)
--- @return string e.g. "45.3%"
function F:percent(pct, decimals)
  decimals = decimals or 1
  local fmt = "%." .. tostring(decimals) .. "f%%"
  return string.format(fmt, pct)
end

-- ── Temperature ──────────────────────────────────────────────────────

--- Format temperature.
--- @param temp number in Kelvin (Mekanism default)
--- @return string e.g. "1200K" or "927°C"
function F:temp(temp, unit)
  unit = unit or "K"
  if unit == "C" then
    -- Convert K to C
    local c = temp - 273.15
    return string.format("%.0f°C", c)
  elseif unit == "F" then
    local f = (temp - 273.15) * 9/5 + 32
    return string.format("%.0f°F", f)
  else
    -- Kelvin
    if temp >= 1000 then
      return self:si(temp, 1) .. "K"
    end
    return string.format("%.0fK", temp)
  end
end

-- ── Generic Amount ───────────────────────────────────────────────────

--- Format a generic item/fluid amount.
--- @param n number
--- @param label string optional suffix like "B", "items"
--- @return string
function F:amount(n, label)
  label = label or ""
  if n >= 1e6 then
    return self:si(n, 1) .. label
  elseif n >= 1e3 then
    return self:si(n, 1) .. label
  else
    return string.format("%.0f%s", n, label)
  end
end

-- ── Rate ─────────────────────────────────────────────────────────────

--- Format a rate (per tick / per second).
--- @param n number
--- @param per string "t" for tick, "s" for second
--- @return string
function F:rate(n, per)
  per = per or "t"
  return self:si(n, 1) .. "/" .. per
end

-- ── Time ─────────────────────────────────────────────────────────────

--- Format seconds into human-readable duration.
--- @param seconds number
--- @return string e.g. "2h 15m", "45s"
function F:time(seconds)
  if seconds < 0 then return "0s" end

  local s = math.floor(seconds)
  local m = math.floor(s / 60)
  local h = math.floor(m / 60)
  local d = math.floor(h / 24)

  s = s % 60
  m = m % 60
  h = h % 24

  local parts = {}
  if d > 0 then table.insert(parts, d .. "d") end
  if h > 0 then table.insert(parts, h .. "h") end
  if m > 0 then table.insert(parts, m .. "m") end
  if s > 0 or #parts == 0 then table.insert(parts, s .. "s") end

  return table.concat(parts, " ")
end

-- ── Fixed Width ──────────────────────────────────────────────────────

--- Pad a string to a fixed width.
--- @param str string
--- @param width number
--- @param align string "left", "right", "center"
--- @return string
function F:fixed(str, width, align)
  str = tostring(str)
  align = align or "left"

  if #str >= width then
    return str:sub(1, width)
  end

  local padding = string.rep(" ", width - #str)
  if align == "right" then
    return padding .. str
  elseif align == "center" then
    local left = math.floor(#padding / 2)
    return padding:sub(1, left) .. str .. padding:sub(left + 1)
  else
    return str .. padding
  end
end

-- ── Comma Sep ────────────────────────────────────────────────────────

--- Format integer with commas.
--- @param n number
--- @return string e.g. "1,234,567"
function F:comma(n)
  local str = tostring(math.floor(math.abs(n)))
  local parts = {}
  local len = #str
  for i = len, 1, -3 do
    local start = math.max(1, i - 2)
    table.insert(parts, 1, str:sub(start, i))
  end
  local result = table.concat(parts, ",")
  if n < 0 then result = "-" .. result end
  return result
end

return F
