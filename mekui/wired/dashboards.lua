--[[
  mekui/wired/dashboards.lua
  Define como coletar dados e montar widgets para cada tipo de estrutura.
  Adicione novos tipos aqui sem alterar o startup.lua.
]]

local Gauge = (loadfile("mekui/widgets/gauge.lua"))()
local Stat  = (loadfile("mekui/widgets/stat.lua"))()
local Graph = (loadfile("mekui/widgets/graph.lua"))()

local M = {}

-- ════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════

local function safe(fn, ...)
  local ok, v = pcall(fn, ...)
  return ok and v or nil
end

local function pct(raw)
  return math.floor((raw or 0) * 100)
end

local function num(raw)
  return math.floor(raw or 0)
end

-- ════════════════════════════════════════════════════════════════
-- DEFINIÇÕES DE DASHBOARDS
-- Cada entrada da tabela M.types deve ter:
--   collect(device) -> table    lê dados do periférico
--   widgets(cfg)    -> {order, map}  cria os widgets
--   update(map, data)            atualiza valores nos widgets
-- ════════════════════════════════════════════════════════════════

M.types = {}

-- ────────────────────────────────────────────────────────────────
-- FISSION REACTOR
-- ────────────────────────────────────────────────────────────────
M.types.fission = {

  collect = function(dev)
    return {
      active       = safe(dev.getStatus),
      fuelPercent  = safe(dev.getFuelFilledPercentage),
      wastePercent = safe(dev.getWasteFilledPercentage),
      burnRate     = safe(dev.getActualBurnRate),
      heatingRate  = safe(dev.getHeatingRate),
      temperature  = safe(dev.getTemperature),
    }
  end,

  widgets = function(cfg)
    local gw, sw = 24, 14
    local enabled = cfg.widgets  -- nil = todos
    local function want(name)
      if not enabled then return true end
      for _, v in ipairs(enabled) do if v == name then return true end end
      return false
    end

    local order, map = {}, {}
    local function add(name, w)
      map[name] = w
      table.insert(order, {name = name, widget = w})
    end

    if want("status") then add("status", Stat:new{label="Status",    width=sw}) end
    if want("fuel")   then add("fuel",   Gauge:new{label="Fuel",     width=gw, max=100, showValue=true,
                                fillLow=colors.red, fillMid=colors.orange, fillHigh=colors.green}) end
    if want("waste")  then add("waste",  Gauge:new{label="Waste",    width=gw, max=100, showValue=true,
                                fillLow=colors.green, fillMid=colors.orange, fillHigh=colors.red}) end
    if want("burn")   then add("burn",   Stat:new{label="Burn Rate", width=sw, suffix=" mB/t"}) end
    if want("heat")   then add("heat",   Stat:new{label="Heat Rate", width=sw, suffix=" K/t"}) end
    if want("graph")  then add("graph",  Graph:new{width=28, height=6, label="Temperature", autoScale=true, min=0}) end

    return order, map
  end,

  update = function(map, d)
    if map.status then
      map.status:setValue(d.active and "ACTIVE" or "STOPPED")
      map.status:setColor(d.active and colors.green or colors.red)
    end
    if map.fuel   then map.fuel:setValue(pct(d.fuelPercent))   end
    if map.waste  then map.waste:setValue(pct(d.wastePercent)) end
    if map.burn   then map.burn:setValue(num(d.burnRate))      end
    if map.heat   then map.heat:setValue(num(d.heatingRate))   end
    if map.graph  then map.graph:push(d.temperature or 0)      end
  end,

  commands = {
    activate   = function(dev) return pcall(dev.activate)   end,
    deactivate = function(dev) return pcall(dev.scram)       end,
    set_burn_rate = function(dev, v) return pcall(dev.setBurnRate, v) end,
  },
}

-- ────────────────────────────────────────────────────────────────
-- FUSION REACTOR
-- ────────────────────────────────────────────────────────────────
M.types.fusion = {

  collect = function(dev)
    return {
      active         = safe(dev.getStatus),
      temperature    = safe(dev.getTemperature),
      plasmaTemp     = safe(dev.getPlasmaTemperature),
      caseTemp       = safe(dev.getCaseTemperature),
      productionRate = safe(dev.getProductionRate),
      injectionRate  = safe(dev.getInjectionRate),
    }
  end,

  widgets = function(cfg)
    local gw, sw = 24, 14
    local enabled = cfg.widgets
    local function want(name)
      if not enabled then return true end
      for _, v in ipairs(enabled) do if v == name then return true end end
      return false
    end

    local order, map = {}, {}
    local function add(name, w)
      map[name] = w
      table.insert(order, {name = name, widget = w})
    end

    if want("status")     then add("status",     Stat:new{label="Status",        width=sw}) end
    if want("temperature") then add("temperature", Stat:new{label="Temperature", width=sw, suffix=" K"}) end
    if want("plasmaTemp") then add("plasmaTemp",  Stat:new{label="Plasma Temp",  width=sw, suffix=" K"}) end
    if want("caseTemp")   then add("caseTemp",    Stat:new{label="Case Temp",    width=sw, suffix=" K"}) end
    if want("production") then add("production",  Stat:new{label="Production",   width=sw, suffix=" MJ/t"}) end
    if want("injection")  then add("injection",   Stat:new{label="Injection",    width=sw, suffix=" mB/t"}) end
    if want("graph")      then add("graph",       Graph:new{width=28, height=6, label="Temperature", autoScale=true, min=0}) end

    return order, map
  end,

  update = function(map, d)
    if map.status then
      map.status:setValue(d.active and "ACTIVE" or "STOPPED")
      map.status:setColor(d.active and colors.green or colors.red)
    end
    if map.temperature then map.temperature:setValue(num(d.temperature))    end
    if map.plasmaTemp  then map.plasmaTemp:setValue(num(d.plasmaTemp))       end
    if map.caseTemp    then map.caseTemp:setValue(num(d.caseTemp))           end
    if map.production  then map.production:setValue(num(d.productionRate))   end
    if map.injection   then map.injection:setValue(num(d.injectionRate))     end
    if map.graph       then map.graph:push(d.temperature or 0)               end
  end,

  commands = {
    activate   = function(dev) return pcall(dev.activate)   end,
    deactivate = function(dev) return pcall(dev.deactivate) end,
    set_injection_rate = function(dev, v) return pcall(dev.setInjectionRate, v) end,
  },
}

-- ────────────────────────────────────────────────────────────────
-- INDUSTRIAL TURBINE
-- ────────────────────────────────────────────────────────────────
M.types.turbine = {

  collect = function(dev)
    return {
      active         = safe(dev.getStatus),
      steamPercent   = safe(dev.getSteamFilledPercentage),
      energyPercent  = safe(dev.getEnergyFilledPercentage),
      flowRate       = safe(dev.getFlowRate),
      productionRate = safe(dev.getProductionRate),
      rotorSpeed     = safe(dev.getRotorSpeed),
    }
  end,

  widgets = function(cfg)
    local gw, sw = 24, 14
    local enabled = cfg.widgets
    local function want(name)
      if not enabled then return true end
      for _, v in ipairs(enabled) do if v == name then return true end end
      return false
    end

    local order, map = {}, {}
    local function add(name, w)
      map[name] = w
      table.insert(order, {name = name, widget = w})
    end

    if want("status")     then add("status",     Stat:new{label="Status",     width=sw}) end
    if want("steam")      then add("steam",      Gauge:new{label="Steam",     width=gw, max=100, showValue=true,
                                    fillLow=colors.red, fillMid=colors.orange, fillHigh=colors.blue}) end
    if want("energy")     then add("energy",     Gauge:new{label="Energy",    width=gw, max=100, showValue=true,
                                    fillLow=colors.red, fillMid=colors.orange, fillHigh=colors.green}) end
    if want("flow")       then add("flow",       Stat:new{label="Flow Rate",  width=sw, suffix=" mB/t"}) end
    if want("production") then add("production", Stat:new{label="Production", width=sw, suffix=" RF/t"}) end
    if want("rotor")      then add("rotor",      Stat:new{label="Rotor RPM",  width=sw, suffix=" RPM"}) end
    if want("graph")      then add("graph",      Graph:new{width=28, height=6, label="Production", autoScale=true, min=0}) end

    return order, map
  end,

  update = function(map, d)
    if map.status then
      map.status:setValue(d.active and "ACTIVE" or "STOPPED")
      map.status:setColor(d.active and colors.green or colors.red)
    end
    if map.steam      then map.steam:setValue(pct(d.steamPercent))    end
    if map.energy     then map.energy:setValue(pct(d.energyPercent))  end
    if map.flow       then map.flow:setValue(num(d.flowRate))          end
    if map.production then map.production:setValue(num(d.productionRate)) end
    if map.rotor      then map.rotor:setValue(num(d.rotorSpeed))      end
    if map.graph      then map.graph:push(d.productionRate or 0)       end
  end,

  commands = {
    activate   = function(dev) return pcall(dev.activate)   end,
    deactivate = function(dev) return pcall(dev.deactivate) end,
    set_flow_rate = function(dev, v) return pcall(dev.setFlowRate, v) end,
  },
}

-- ────────────────────────────────────────────────────────────────
-- INDUCTION MATRIX (bateria)
-- ────────────────────────────────────────────────────────────────
M.types.battery = {

  collect = function(dev)
    return {
      energyPercent   = safe(dev.getEnergyFilledPercentage),
      energy          = safe(dev.getEnergy),
      maxEnergy       = safe(dev.getMaxEnergy),
      lastInput       = safe(dev.getLastInput),
      lastOutput      = safe(dev.getLastOutput),
    }
  end,

  widgets = function(cfg)
    local gw, sw = 24, 14
    local enabled = cfg.widgets
    local function want(name)
      if not enabled then return true end
      for _, v in ipairs(enabled) do if v == name then return true end end
      return false
    end

    local order, map = {}, {}
    local function add(name, w)
      map[name] = w
      table.insert(order, {name = name, widget = w})
    end

    if want("charge")  then add("charge",  Gauge:new{label="Charge",    width=gw, max=100, showValue=true,
                                  fillLow=colors.red, fillMid=colors.orange, fillHigh=colors.green}) end
    if want("input")   then add("input",   Stat:new{label="Input",      width=sw, suffix=" RF/t"}) end
    if want("output")  then add("output",  Stat:new{label="Output",     width=sw, suffix=" RF/t"}) end
    if want("graph")   then add("graph",   Graph:new{width=28, height=6, label="Charge %", autoScale=false, min=0, max=100}) end

    return order, map
  end,

  update = function(map, d)
    if map.charge  then map.charge:setValue(pct(d.energyPercent)) end
    if map.input   then map.input:setValue(num(d.lastInput))       end
    if map.output  then map.output:setValue(num(d.lastOutput))     end
    if map.graph   then map.graph:push(pct(d.energyPercent))       end
  end,

  commands = {},
}

-- ────────────────────────────────────────────────────────────────
-- SPS (Supercritical Phase Shifter)
-- ────────────────────────────────────────────────────────────────
M.types.sps = {

  collect = function(dev)
    return {
      coils         = safe(dev.getCoils),
      inputPercent  = safe(dev.getInputFilledPercentage),
      outputPercent = safe(dev.getOutputFilledPercentage),
      processRate   = safe(dev.getProcessRate),
    }
  end,

  widgets = function(cfg)
    local gw, sw = 24, 14
    local enabled = cfg.widgets
    local function want(name)
      if not enabled then return true end
      for _, v in ipairs(enabled) do if v == name then return true end end
      return false
    end

    local order, map = {}, {}
    local function add(name, w)
      map[name] = w
      table.insert(order, {name = name, widget = w})
    end

    if want("coils")   then add("coils",   Stat:new{label="Coils",   width=sw}) end
    if want("input")   then add("input",   Gauge:new{label="Input",  width=gw, max=100, showValue=true,
                                  fillLow=colors.red, fillMid=colors.orange, fillHigh=colors.green}) end
    if want("output")  then add("output",  Gauge:new{label="Output", width=gw, max=100, showValue=true,
                                  fillLow=colors.red, fillMid=colors.orange, fillHigh=colors.green}) end
    if want("process") then add("process", Stat:new{label="Process", width=sw, suffix=" mB/t"}) end
    if want("graph")   then add("graph",   Graph:new{width=28, height=6, label="Process Rate", autoScale=true, min=0}) end

    return order, map
  end,

  update = function(map, d)
    if map.coils   then map.coils:setValue(num(d.coils))            end
    if map.input   then map.input:setValue(pct(d.inputPercent))     end
    if map.output  then map.output:setValue(pct(d.outputPercent))   end
    if map.process then map.process:setValue(num(d.processRate))    end
    if map.graph   then map.graph:push(d.processRate or 0)           end
  end,

  commands = {},
}

return M
