--[[
  mekui/wired/startup.lua
  INSTALACAO UNICA - copie para /startup neste computador.
  Edite apenas mekui/wired/config.lua para configurar.
]]

-- ════════════════════════════════════════════════════════════════
-- ATIVA MODEM CABEADO antes de qualquer peripheral.getNames()
-- O modem precisa estar aberto para a rede cabeada aparecer.
-- ════════════════════════════════════════════════════════════════

local function findWiredModem()
  for _, side in ipairs{"top","bottom","left","right","front","back"} do
    if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
      local m = peripheral.wrap(side)
      if m and m.getNameLocal then   -- getNameLocal = exclusivo do modem cabeado
        return m, side
      end
    end
  end
  -- fallback: qualquer modem
  for _, side in ipairs{"top","bottom","left","right","front","back"} do
    if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
      return peripheral.wrap(side), side
    end
  end
  return nil, nil
end

local modem, modemSide = findWiredModem()
if not modem then
  error("[mekui] Modem cabeado nao encontrado!")
end
modem.open(0)   -- abre canal; isso ativa a rede e libera peripheral.getNames()

print("[mekui] Modem em: " .. modemSide)
print("[mekui] Perifericos na rede:")
for _, name in ipairs(peripheral.getNames()) do
  print("  - " .. name)
end

-- ════════════════════════════════════════════════════════════════
-- CARREGA DEPENDENCIAS via loadfile
-- (require() pode nao funcionar dependendo de como o startup foi
--  invocado; loadfile com caminho explicito e mais confiavel)
-- ════════════════════════════════════════════════════════════════

local function load_module(path)
  local fn, err = loadfile(path)
  if not fn then error("Erro ao carregar " .. path .. ": " .. tostring(err)) end
  return fn()
end

local config     = load_module("mekui/wired/config.lua")
local dashboards = load_module("mekui/wired/dashboards.lua")

-- dashboards.lua usa require() internamente para widgets/utils.
-- Garante que o path inclui a raiz do computador.
if package and package.path and not package.path:find("/?.lua") then
  package.path = "/?.lua;/mekui/?.lua;" .. package.path
end

-- ════════════════════════════════════════════════════════════════
-- INICIALIZA DISPLAYS
-- ════════════════════════════════════════════════════════════════

local displays = {}

for _, cfg in ipairs(config.displays) do
  local monitor = peripheral.wrap(cfg.monitor)
  if not monitor then
    print("[AVISO] Monitor '" .. cfg.monitor .. "' nao encontrado, pulando.")
  else
    local device = peripheral.wrap(cfg.device)
    if not device then
      print("[AVISO] Dispositivo '" .. cfg.device .. "' nao encontrado, pulando.")
    else
      local dash = dashboards.types[cfg.type]
      if not dash then
        print("[AVISO] Tipo '" .. tostring(cfg.type) .. "' desconhecido, pulando.")
      else
        local order, map = dash.widgets(cfg)
        table.insert(displays, {
          cfg     = cfg,
          monitor = monitor,
          device  = device,
          dash    = dash,
          order   = order,
          map     = map,
        })
        print("[OK] " .. cfg.type .. " -> " .. cfg.monitor)
      end
    end
  end
end

if #displays == 0 then
  error("[mekui] Nenhum display inicializado. Verifique config.lua e perifericos.")
end

print("\n[mekui] " .. #displays .. " display(s) ativo(s). Iniciando...\n")

-- ════════════════════════════════════════════════════════════════
-- RENDERIZACAO
-- ════════════════════════════════════════════════════════════════

local function renderDisplay(disp)
  local mon = disp.monitor
  mon.setBackgroundColor(colors.black)
  mon.clear()
  local mw, mh = mon.getSize()

  local total_h = 0
  for _, e in ipairs(disp.order) do
    local h = e.widget.getRenderedHeight and e.widget:getRenderedHeight() or 2
    total_h = total_h + h + 1
  end
  total_h = math.max(0, total_h - 1)

  local y = math.max(1, math.floor((mh - total_h) / 2))
  for _, e in ipairs(disp.order) do
    local w = e.widget
    local h = w.getRenderedHeight and w:getRenderedHeight() or 2
    local rw = (w._width or 20) + ((w._border ~= false) and 2 or 0)
    local ox = math.max(1, math.floor((mw - rw) / 2) + 1)
    w:draw(mon, ox, y)
    y = y + h + 1
  end
end

local function pollDisplay(disp)
  local ok, data = pcall(disp.dash.collect, disp.device)
  if ok and data then
    disp.data = data
    disp.dash.update(disp.map, data)
  end
end

-- ════════════════════════════════════════════════════════════════
-- LOOP PRINCIPAL
-- ════════════════════════════════════════════════════════════════

for _, disp in ipairs(displays) do
  pollDisplay(disp)
  renderDisplay(disp)
end

local timer = os.startTimer(config.poll_rate or 1)

while true do
  local ev = {os.pullEvent()}

  if ev[1] == "timer" and ev[2] == timer then
    timer = os.startTimer(config.poll_rate or 1)
    for _, disp in ipairs(displays) do
      pollDisplay(disp)
      renderDisplay(disp)
    end

  elseif ev[1] == "terminate" then
    for _, disp in ipairs(displays) do
      disp.monitor.clear()
      disp.monitor.setCursorPos(1, 1)
      disp.monitor.setTextColor(colors.white)
      disp.monitor.write("mekui offline")
    end
    print("[mekui] Encerrado.")
    break
  end
end
