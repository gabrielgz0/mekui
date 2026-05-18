--[[
  mekui/wired/startup.lua
  ╔═══════════════════════════════════════════════════════════════╗
  ║  INSTALAÇÃO ÚNICA - copie para /startup neste computador     ║
  ║  Edite apenas mekui/wired/config.lua para configurar.        ║
  ╚═══════════════════════════════════════════════════════════════╝

  REQUISITOS:
    - Este computador deve ter um modem cabeado (Wired Modem)
    - Todos os periféricos (reatores, monitores) devem estar
      conectados na mesma rede cabeada via cabos e modems
    - Rode peripheral.getNames() para ver os nomes disponíveis
]]

-- ════════════════════════════════════════════════════════════════
-- CARREGA DEPENDÊNCIAS
-- ════════════════════════════════════════════════════════════════

local config     = require("mekui.wired.config")
local dashboards = require("mekui.wired.dashboards")

-- ════════════════════════════════════════════════════════════════
-- INICIALIZA MODEM CABEADO
-- ════════════════════════════════════════════════════════════════

local function findWiredModem()
  -- Prefere modem cabeado; cai no wireless se não achar
  for _, side in ipairs{"top","bottom","left","right","front","back"} do
    if peripheral.isPresent(side) then
      local t = peripheral.getType(side)
      if t == "modem" then
        local m = peripheral.wrap(side)
        -- modem cabeado tem o método getNameLocal(); wireless não tem
        if m and m.getNameLocal then
          return m, side
        end
      end
    end
  end
  -- Fallback: qualquer modem
  for _, side in ipairs{"top","bottom","left","right","front","back"} do
    if peripheral.isPresent(side) then
      local t = peripheral.getType(side)
      if t == "modem" then
        return peripheral.wrap(side), side
      end
    end
  end
  return nil, nil
end

local modem, modemSide = findWiredModem()
if not modem then
  error("[mekui] Modem cabeado não encontrado! Conecte um Wired Modem a este computador.")
end

-- Ativa o modem para que a rede cabeada funcione
if modem.open then modem.open(0) end

print("[mekui] Modem em: " .. modemSide)
print("[mekui] Periféricos na rede:")
for _, name in ipairs(peripheral.getNames()) do
  print("  - " .. name)
end

-- ════════════════════════════════════════════════════════════════
-- INICIALIZA DISPLAYS
-- Cada display = { monitor, device, dashboard, order, map }
-- ════════════════════════════════════════════════════════════════

local displays = {}

for i, cfg in ipairs(config.displays) do
  -- Conecta monitor
  local monitor = peripheral.wrap(cfg.monitor)
  if not monitor then
    print("[AVISO] Monitor '" .. cfg.monitor .. "' não encontrado, pulando.")
  else
    -- Conecta dispositivo
    local device = peripheral.wrap(cfg.device)
    if not device then
      print("[AVISO] Dispositivo '" .. cfg.device .. "' não encontrado, pulando.")
    else
      -- Carrega dashboard
      local dash = dashboards.types[cfg.type]
      if not dash then
        print("[AVISO] Tipo de dashboard '" .. tostring(cfg.type) .. "' desconhecido, pulando.")
      else
        local order, map = dash.widgets(cfg)
        table.insert(displays, {
          cfg     = cfg,
          monitor = monitor,
          device  = device,
          dash    = dash,
          order   = order,
          map     = map,
          data    = nil,   -- últimos dados coletados
        })
        print("[OK] " .. cfg.type .. " -> " .. cfg.monitor)
      end
    end
  end
end

if #displays == 0 then
  error("[mekui] Nenhum display inicializado. Verifique o config.lua e os periféricos conectados.")
end

print("\n[mekui] " .. #displays .. " display(s) ativo(s). Iniciando...\n")

-- ════════════════════════════════════════════════════════════════
-- RENDERIZAÇÃO DE UM DISPLAY NO MONITOR
-- ════════════════════════════════════════════════════════════════

local function renderDisplay(disp)
  local mon = disp.monitor
  mon.setBackgroundColor(colors.black)
  mon.clear()

  local mw, mh = mon.getSize()

  -- Calcula altura total dos widgets para centralizar
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

-- ════════════════════════════════════════════════════════════════
-- COLETA DADOS E ATUALIZA WIDGETS DE UM DISPLAY
-- ════════════════════════════════════════════════════════════════

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

-- Primeira coleta e renderização imediata
for _, disp in ipairs(displays) do
  pollDisplay(disp)
  renderDisplay(disp)
end

local timer = os.startTimer(config.poll_rate)

while true do
  local ev = {os.pullEvent()}

  if ev[1] == "timer" and ev[2] == timer then
    timer = os.startTimer(config.poll_rate)

    for _, disp in ipairs(displays) do
      pollDisplay(disp)
      renderDisplay(disp)
    end

  elseif ev[1] == "terminate" then
    -- Limpa todos os monitores ao sair
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
