--[[
  mekui/wired/install.lua
  Instalador com deteccao automatica de perifericos.
  Gera o config.lua preenchido com tudo que encontrar na rede.

  USO:
    wget https://raw.githubusercontent.com/gabrielgz0/mekui/main/mekui/wired/install.lua install.lua
    install
]]

local BASE_URL = "https://raw.githubusercontent.com/gabrielgz0/mekui/main/mekui"

-- ════════════════════════════════════════════════════════════════
-- Mapeamento: tipo do periférico -> tipo do dashboard
-- ════════════════════════════════════════════════════════════════
local DEVICE_MAP = {
  fissionReactorLogicAdapter = "fission",
  fusionReactorLogicAdapter  = "fusion",
  turbineValve               = "turbine",
  inductionPort              = "battery",
  spsPort                    = "sps",
}

-- ════════════════════════════════════════════════════════════════
-- DOWNLOAD
-- ════════════════════════════════════════════════════════════════

local function ensureDir(path)
  local dir = path:match("(.+)/[^/]+$")
  if dir and not fs.exists(dir) then fs.makeDir(dir) end
end

local function download(path)
  local url  = BASE_URL .. "/" .. path
  local dest = "mekui/" .. path
  ensureDir(dest)

  local ok, r = pcall(http.get, url, nil, true)
  if not ok or not r then print("[FAIL] " .. path); return false end

  local content = r.readAll()
  r.close()

  local h = fs.open(dest, "w")
  if not h then print("[FAIL] escrita: " .. dest); return false end
  h.write(content)
  h.close()

  print("[OK] " .. path)
  return true
end

-- ════════════════════════════════════════════════════════════════
-- DETECÇÃO DE PERIFÉRICOS
-- ════════════════════════════════════════════════════════════════

local function detectPeripherals()
  local monitors = {}
  local devices  = {}

  for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "monitor" then
      table.insert(monitors, name)
    elseif DEVICE_MAP[t] then
      table.insert(devices, { name = name, ptype = t, dtype = DEVICE_MAP[t] })
    end
  end

  return monitors, devices
end

-- ════════════════════════════════════════════════════════════════
-- GERAÇÃO DO CONFIG.LUA
-- ════════════════════════════════════════════════════════════════

local function generateConfig(monitors, devices)
  local lines = {}

  table.insert(lines, "--[[")
  table.insert(lines, "  mekui/wired/config.lua")
  table.insert(lines, "  Gerado automaticamente pelo instalador.")
  table.insert(lines, "  Ajuste os monitors conforme necessario.")
  table.insert(lines, "]]")
  table.insert(lines, "")
  table.insert(lines, "local config = {}")
  table.insert(lines, "")
  table.insert(lines, "config.poll_rate = 1.0")
  table.insert(lines, "")
  table.insert(lines, "config.displays = {")

  local monIdx = 1

  for _, dev in ipairs(devices) do
    local mon = monitors[monIdx] or ("monitor_" .. (monIdx - 1))
    monIdx = monIdx + 1

    table.insert(lines, "  {")
    table.insert(lines, '    monitor = "' .. mon .. '",')
    table.insert(lines, '    device  = "' .. dev.name .. '",')
    table.insert(lines, '    type    = "' .. dev.dtype .. '",')
    table.insert(lines, "  },")
    table.insert(lines, "")
  end

  -- Monitores sobrando sem dispositivo: deixa comentado como lembrete
  while monIdx <= #monitors do
    table.insert(lines, "  -- monitor disponivel sem dispositivo: " .. monitors[monIdx])
    monIdx = monIdx + 1
  end

  table.insert(lines, "}")
  table.insert(lines, "")
  table.insert(lines, "return config")

  return table.concat(lines, "\n")
end

-- ════════════════════════════════════════════════════════════════
-- MAIN
-- ════════════════════════════════════════════════════════════════

print("=== mekui wired install ===")
print("")

-- Cria diretórios
for _, d in ipairs{"mekui","mekui/wired","mekui/widgets","mekui/util"} do
  if not fs.exists(d) then fs.makeDir(d) end
end

-- Baixa arquivos do repo
local files = {
  "wired/startup.lua",
  "wired/dashboards.lua",
  "widgets/gauge.lua",
  "widgets/stat.lua",
  "widgets/graph.lua",
  "util/color.lua",
  "util/format.lua",
}

print("Baixando arquivos...")
local ok_count = 0
for _, f in ipairs(files) do
  if download(f) then ok_count = ok_count + 1 end
end
print(ok_count .. "/" .. #files .. " arquivos baixados\n")

-- Detecta periféricos
print("Detectando perifericos na rede...")
local monitors, devices = detectPeripherals()

print("  Monitores : " .. #monitors)
for _, m in ipairs(monitors) do print("    - " .. m) end

print("  Dispositivos: " .. #devices)
for _, d in ipairs(devices) do print("    - " .. d.name .. " (" .. d.dtype .. ")") end
print("")

-- Gera config.lua
local configPath = "mekui/wired/config.lua"
local skip = false

if fs.exists(configPath) then
  print("config.lua ja existe. Sobrescrever? (s/n)")
  local ans = read()
  if ans ~= "s" and ans ~= "S" then
    print("[SKIP] config.lua mantido")
    skip = true
  end
end

if not skip then
  if #devices == 0 then
    print("[AVISO] Nenhum dispositivo encontrado na rede.")
    print("  Verifique se o modem cabeado esta ligado e os cabos conectados.")
  end
  if #monitors == 0 then
    print("[AVISO] Nenhum monitor encontrado na rede.")
  end

  local content = generateConfig(monitors, devices)
  local h = fs.open(configPath, "w")
  if h then
    h.write(content)
    h.close()
    print("[OK] config.lua gerado automaticamente")
  else
    print("[FAIL] Nao foi possivel salvar config.lua")
  end
end

-- Cria /startup
print("\nCriando /startup...")
if fs.exists("/startup") then
  fs.copy("/startup", "/startup.backup")
  print("  backup salvo em /startup.backup")
end

local startup = [[local ok, err = pcall(function()
  local fn, e = loadfile("mekui/wired/startup.lua")
  if not fn then error(e) end
  fn()
end)
if not ok then
  print("[mekui ERRO] " .. tostring(err))
  os.pullEvent("key")
end
]]

local h = fs.open("/startup", "w")
if h then h.write(startup); h.close(); print("[OK] /startup criado") end

-- Resumo
print("\n=== CONCLUIDO ===")
if #devices > 0 then
  print("Config gerado com " .. #devices .. " dispositivo(s).")
  print("Revise mekui/wired/config.lua e ajuste os monitors se necessario.")
else
  print("Edite mekui/wired/config.lua manualmente com seus perifericos.")
end
print("Reinicie com Ctrl+R para iniciar.")
