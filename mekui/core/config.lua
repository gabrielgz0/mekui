--[[
  mekui/core/config.lua
  Reads and writes settings from a JSON file on disk.
  Uses textutils.serialize / textutils.unserialize for CC:Tweaked compatibility.
]]

local config = {}
local C = {}

function C:new(path)
  return setmetatable({
    _path     = path or "mekui_config",
    _data     = {},
    _dirty    = false,
    _auto_save = true,
  }, { __index = C })
end

-- ── Load ─────────────────────────────────────────────────────────────

function C:load(filepath)
  local path = filepath or self._path

  if not fs.exists(path) then
    return nil
  end

  local ok, data = pcall(function()
    local handle = fs.open(path, "r")
    local content = handle.readAll()
    handle.close()
    return content
  end)

  if not ok or not data or data == "" then
    return nil
  end

  -- Attempt to unserialize (CC:Tweaked uses Lua table serialization)
  local ok2, result = pcall(textutils.unserialize, data)
  if ok2 and type(result) == "table" then
    self._data = result
    self._dirty = false
    return result
  end

  -- Fallback: try JSON (some CC distributions have textutils.unserializeJSON)
  local ok3, result_json = pcall(textutils.unserializeJSON, data, { nbt = false })
  if ok3 and type(result_json) == "table" then
    self._data = result_json
    self._dirty = false
    return result_json
  end

  return nil
end

-- ── Save ─────────────────────────────────────────────────────────────

function C:save(data, filepath)
  local path = filepath or self._path

  if data then
    self._data = data
  end

  local ok, serialized = pcall(textutils.serialize, self._data)
  if not ok then
    print("[mekui/config] Failed to serialize config")
    return false
  end

  local ok2, err = pcall(function()
    local handle = fs.open(path, "w")
    handle.write(serialized)
    handle.close()
  end)

  if not ok2 then
    print("[mekui/config] Failed to write config: " .. tostring(err))
    return false
  end

  self._dirty = false
  return true
end

-- ── Getters / Setters ────────────────────────────────────────────────

function C:get(key, default)
  if key == nil then
    return self._data
  end
  local val = self._data
  for part in key:gmatch("[^.]+") do
    if type(val) ~= "table" then
      return default
    end
    val = val[part]
    if val == nil then
      return default
    end
  end
  return val
end

function C:set(key, value)
  -- Support nested keys like "display.monitors"
  local parts = {}
  for part in key:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local target = self._data
  for i = 1, #parts - 1 do
    if type(target[parts[i]]) ~= "table" then
      target[parts[i]] = {}
    end
    target = target[parts[i]]
  end
  target[parts[#parts]] = value
  self._dirty = true

  if self._auto_save then
    self:save()
  end

  return self
end

-- ── Auto-save Toggle ─────────────────────────────────────────────────

function C:setAutoSave(enabled)
  self._auto_save = enabled
  if enabled and self._dirty then
    self:save()
  end
  return self
end

-- ── Exists ───────────────────────────────────────────────────────────

function C:exists(path)
  return fs.exists(path or self._path)
end

-- ── Delete ───────────────────────────────────────────────────────────

function C:delete()
  if fs.exists(self._path) then
    fs.delete(self._path)
  end
  self._data = {}
  self._dirty = false
  return self
end

return C
