--[[
  mekui/wired/startup.lua
  INSTALACAO UNICA - copie para /startup neste computador.
  Edite apenas mekui/wired/config.lua para configurar.
]]

-- ════════════════════════════════════════════════════════════════
-- MODEM: ativa antes de qualquer peripheral.getNames()
-- ════════════════════════════════════════════════════════════════

local function findWiredModem()
  for _, side in ipairs{"top","bottom","left","right","front","back"} do
    if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
      local m = peripheral.wrap(side)
      if m and m.getNameLocal then return m, side end
    end
  end
  for _, side in ipairs{"top","bottom","left","right","front","back"} do
    if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
      return peripheral.wrap(side), side
    end
  end
  return nil, nil
end

local modem, modemSide = findWiredModem()
if not modem then error("[mekui] Modem cabeado nao encontrado!") end
modem.open(0)

print("[mekui] Modem em: " .. modemSide)
print("[mekui] Perifericos na rede:")
for _, name in ipairs(peripheral.getNames()) do
  print("  - " .. name)
end

-- ════════════════════════════════════════════════════════════════
-- CARREGA DEPENDENCIAS
-- ════════════════════════════════════════════════════════════════

local function load_module(path)
  local fn, err = loadfile(path)
  if not fn then error("Erro ao carregar " .. path .. ": " .. tostring(err)) end
  return fn()
end

local config     = load_module("mekui/wired/config.lua")
local dashboards = load_module("mekui/wired/dashboards.lua")

-- ════════════════════════════════════════════════════════════════
-- SISTEMA DE BOTÕES
-- Cada display tem uma lista de botões com hitbox e callback.
-- ════════════════════════════════════════════════════════════════

--[[
  Botão: { label, x, y, w, h, bg, fg, action }
  action(device, disp) -> chamado ao tocar
]]

local function drawButton(mon, btn, pressed)
  local bg = pressed and colors.gray or btn.bg
  local fg = btn.fg or colors.white
  mon.setBackgroundColor(bg)
  mon.setTextColor(fg)
  -- preenche área do botão
  for row = btn.y, btn.y + btn.h - 1 do
    mon.setCursorPos(btn.x, row)
    mon.write(string.rep(" ", btn.w))
  end
  -- texto centralizado verticalmente
  local labelRow = btn.y + math.floor(btn.h / 2)
  local labelX   = btn.x + math.floor((btn.w - #btn.label) / 2)
  mon.setCursorPos(math.max(btn.x, labelX), labelRow)
  mon.write(btn.label)
  mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.white)
end

local function hitTest(btn, x, y)
  return x >= btn.x and x < btn.x + btn.w
     and y >= btn.y and y < btn.y + btn.h
end

-- ════════════════════════════════════════════════════════════════
-- BOTÕES POR TIPO DE DASHBOARD
-- Retorna lista de botões posicionados no canto inferior do monitor
-- ════════════════════════════════════════════════════════════════

local function buildButtons(dtype, device, mw, mh)
  if dtype == "fission" then
    -- sem botões por enquanto
    return {}
  end

  -- outros tipos: sem botões por enquanto
  return {}
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
        local mw, mh    = monitor.getSize()
        local buttons   = buildButtons(cfg.type, device, mw, mh)

        table.insert(displays, {
          cfg     = cfg,
          monitor = monitor,
          device  = device,
          dash    = dash,
          order   = order,
          map     = map,
          buttons = buttons,
          data    = nil,
        })
        local btnCount = #buttons > 0 and (" + " .. #buttons .. " botoes") or ""
        print("[OK] " .. cfg.type .. " -> " .. cfg.monitor .. btnCount)
      end
    end
  end
end

if #displays == 0 then
  error("[mekui] Nenhum display inicializado. Verifique config.lua e perifericos.")
end

print("\n[mekui] " .. #displays .. " display(s) ativo(s). Iniciando...\n")

-- ════════════════════════════════════════════════════════════════
-- RENDERIZAÇÃO
-- ════════════════════════════════════════════════════════════════

local function renderDisplay(disp, pressedBtn)
  local mon = disp.monitor
  mon.setBackgroundColor(colors.black)
  mon.clear()
  local mw, mh = mon.getSize()

  -- Área útil: reserva espaço para botões na base
  local btnH     = (#disp.buttons > 0) and 4 or 0
  local usableMH = mh - btnH

  -- Calcula altura total dos widgets
  local total_h = 0
  for _, e in ipairs(disp.order) do
    local h = e.widget.getRenderedHeight and e.widget:getRenderedHeight() or 2
    total_h = total_h + h + 1
  end
  total_h = math.max(0, total_h - 1)

  local y = math.max(1, math.floor((usableMH - total_h) / 2))
  for _, e in ipairs(disp.order) do
    local w = e.widget
    local h = w.getRenderedHeight and w:getRenderedHeight() or 2
    local rw = (w._width or 20) + ((w._border == true) and 2 or 0)
    local ox = math.max(1, math.floor((mw - rw) / 2) + 1)
    w:draw(mon, ox, y)
    y = y + h + 1
  end

  -- Desenha botões
  for _, btn in ipairs(disp.buttons) do
    drawButton(mon, btn, btn == pressedBtn)
  end
end

-- ════════════════════════════════════════════════════════════════
-- POLL
-- ════════════════════════════════════════════════════════════════

local function pollDisplay(disp)
  local ok, data = pcall(disp.dash.collect, disp.device)
  if ok and data then
    disp.data = data
    disp.dash.update(disp.map, data)
  end
end

-- ════════════════════════════════════════════════════════════════
-- IDENTIFICA DISPLAY PELO NOME DO MONITOR (para monitor_touch)
-- ════════════════════════════════════════════════════════════════

local function findDisplayByMonitor(monName)
  for _, disp in ipairs(displays) do
    if disp.cfg.monitor == monName then return disp end
  end
  return nil
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

  -- ── tick de atualização ─────────────────────────────────────
  if ev[1] == "timer" and ev[2] == timer then
    timer = os.startTimer(config.poll_rate or 1)
    for _, disp in ipairs(displays) do
      pollDisplay(disp)
      renderDisplay(disp)
    end

  -- ── toque no monitor ────────────────────────────────────────
  elseif ev[1] == "monitor_touch" then
    -- ev: monitor_touch, monitorName, x, y
    local monName = ev[2]
    local tx, ty  = ev[3], ev[4]
    local disp    = findDisplayByMonitor(monName)

    if disp then
      for _, btn in ipairs(disp.buttons) do
        if hitTest(btn, tx, ty) then
          -- feedback visual: redesenha com botão pressionado
          renderDisplay(disp, btn)
          sleep(0.1)

          -- executa ação
          pcall(btn.action, disp.device, disp)

          -- atualiza dados e redesenha normalmente
          pollDisplay(disp)
          renderDisplay(disp)
          break
        end
      end
    end

  -- ── encerrar ────────────────────────────────────────────────
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
