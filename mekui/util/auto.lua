--[[
  mekui/util/auto.lua
  Auto-detection utilities for peripherals and monitors.
]]

local auto = {}

-- ═══════════════════════════════════════════════════════════════════════
-- Monitor Detection
-- ═══════════════════════════════════════════════════════════════════════

function auto.findMonitor()
  -- Fallback manual - procurar em todos os lados
  local sides = {"top", "bottom", "left", "right", "back"}
  
  for _, side in ipairs(sides) do
    if peripheral.isPresent(side) then
      local ok, mon = pcall(peripheral.wrap, side)
      if ok and mon and mon.isColor and mon.setCursorPos then
        return side, mon
      end
    end
  end
  
  return nil, nil
end

function auto.findAllMonitors()
  local monitors = {}
  local sides = {"top", "bottom", "left", "right", "back"}
  
  for _, side in ipairs(sides) do
    if peripheral.isPresent(side) then
      local ok, mon = pcall(peripheral.wrap, side)
      if ok and mon and mon.isColor and mon.setCursorPos then
        table.insert(monitors, { side = side, mon = mon })
      end
    end
  end
  
  return monitors
end

-- ═══════════════════════════════════════════════════════════════════════
-- Mekanism Detection
-- ═══════════════════════════════════════════════════════════════════════

function auto.findMekanismPeripheral()
  -- Tenta encontrar por nome (peripheral.find)
  local names = {
    "mekanismReactor", "fissionReactor", "reactor", "mekareactor",
    "mekanism_fission", "mekanism_turbine", "mekanism_boiler",
    "modularController", "mekanismMachine", "fissionController"
  }
  
  for _, name in ipairs(names) do
    local periph = peripheral.find(name)
    if periph then
      print("[mekui] Encontrado por nome: " .. name)
      return name, periph
    end
  end
  
  -- Fallback: procurar em "back" primeiro (posição padrão)
  local sides = {"back", "top", "bottom", "left", "right"}
  
  for _, side in ipairs(sides) do
    if peripheral.isPresent(side) then
      local ok, periph = pcall(peripheral.wrap, side)
      if ok and periph then
        -- Verifica se tem métodos de reator
        local hasReactor = type(periph.getReactorStatus) == "function" or
                          type(periph.getTurbineStatus) == "function" or
                          type(periph.getBoilerStatus) == "function" or
                          type(periph.getStatus) == "function" or
                          type(periph.getInputInfo) == "function"
        
        -- Se tem qualquer método ou está no lado "back", aceita
        if hasReactor or side == "back" then
          print("[mekui] Encontrado em " .. side .. ", aceito como reator")
          return side, periph
        end
      end
    end
  end
  
  return nil, nil
end

-- ═══════════════════════════════════════════════════════════════════════
-- Applied Energistics Detection
-- ═══════════════════════════════════════════════════════════════════════

function auto.findAEPeripheral()
  local sides = {"top", "bottom", "left", "right", "back"}
  
  for _, side in ipairs(sides) do
    if peripheral.isPresent(side) then
      local ok, periph = pcall(peripheral.wrap, side)
      if ok and periph then
        -- Check for AE2 methods
        if type(periph.getStorageInformation) == "function" or
           type(periph.getCraftingJobList) == "function" then
          return side, periph
        end
      end
    end
  end
  
  return nil, nil
end

-- ═══════════════════════════════════════════════════════════════════════
-- Monitor Scale Detection
-- ═══════════════════════════════════════════════════════════════════════

function auto.getMonitorScale(monitor)
  if not monitor then return 1 end
  
  local ok, scale = pcall(monitor.getTextScale)
  if ok then
    return scale
  end
  
  return 1
end

function auto.getEffectiveSize(monitor)
  if not monitor then return 0, 0 end
  
  local w, h = monitor.getSize()
  local scale = auto.getMonitorScale(monitor)
  
  -- Effective size = raw size / scale
  local effective_w = math.floor(w / scale)
  local effective_h = math.floor(h / scale)
  
  return effective_w, effective_h
end

-- ═══════════════════════════════════════════════════════════════════════
-- Layout Calculator
-- ═══════════════════════════════════════════════════════════════════════

function auto.calculateLayout(width, height)
  local layout = {
    scale = 1,
    gaugeWidth = 20,
    statWidth = 12,
    graphWidth = 30,
    graphHeight = 8,
    cols = 1,
  }
  
  if width >= 40 and height >= 20 then
    -- Large monitor (3x3 or bigger)
    layout.scale = 1
    layout.gaugeWidth = 25
    layout.statWidth = 15
    layout.graphWidth = 35
    layout.graphHeight = 10
    layout.cols = 2
  elseif width >= 25 and height >= 15 then
    -- Medium monitor (2x2)
    layout.scale = 0.5
    layout.gaugeWidth = 20
    layout.statWidth = 12
    layout.graphWidth = 30
    layout.graphHeight = 8
    layout.cols = 1
  else
    -- Small monitor (1x1 or smaller)
    layout.scale = 0.5
    layout.gaugeWidth = 15
    layout.statWidth = 10
    layout.graphWidth = 20
    layout.graphHeight = 6
    layout.cols = 1
  end
  
  return layout
end

return auto