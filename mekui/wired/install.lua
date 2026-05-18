--[[
  mekui/wired/install.lua
  Instalador para o sistema cabeado (instalação única).
  
  USO: Cole este arquivo no computador central e execute.
  Ou baixe direto:
    wget https://raw.githubusercontent.com/gabrielgz0/cc-ui/main/mekui/wired/install.lua install.lua
    install
]]

print("=== mekui wired install ===")
print("Instalacao unica - um computador, modem cabeado")
print("")

local BASE_URL = "https://raw.githubusercontent.com/gabrielgz0/mekui/main/mekui"

local files = {
  -- Core wired
  "wired/startup.lua",
  "wired/dashboards.lua",
  -- Widgets
  "widgets/gauge.lua",
  "widgets/stat.lua",
  "widgets/graph.lua",
  -- Utils
  "util/color.lua",
  "util/format.lua",
}

local function ensureDir(path)
  local dir = path:match("(.+)/[^/]+$")
  if dir and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function download(path)
  local url  = BASE_URL .. "/" .. path
  local dest = "mekui/" .. path
  ensureDir(dest)

  local ok, r = pcall(http.get, url, nil, true)
  if not ok or not r then
    print("[FAIL] " .. path)
    return false
  end

  local content = r.readAll()
  r.close()

  local h = fs.open(dest, "w")
  if not h then print("[FAIL] Escrita: " .. dest); return false end
  h.write(content)
  h.close()

  print("[OK] " .. path)
  return true
end

-- Cria estrutura de diretórios
for _, d in ipairs{"mekui", "mekui/wired", "mekui/widgets", "mekui/util"} do
  if not fs.exists(d) then fs.makeDir(d) end
end

-- Baixa arquivos
print("Baixando arquivos...")
local ok_count = 0
for _, f in ipairs(files) do
  if download(f) then ok_count = ok_count + 1 end
end
print("Baixados " .. ok_count .. "/" .. #files .. " arquivos")

-- Baixa config.lua apenas se não existir (não sobrescreve configuração do usuário)
local configPath = "mekui/wired/config.lua"
if fs.exists(configPath) then
  print("[SKIP] " .. configPath .. " (ja existe - nao sobrescrito)")
else
  if download("wired/config.lua") then
    print("[OK] config.lua criado com exemplo. EDITE-O antes de rodar.")
  end
end

-- Cria /startup que chama o módulo wired
print("\nCriando /startup...")
if fs.exists("/startup") then
  fs.copy("/startup", "/startup.backup")
  print("Backup salvo em /startup.backup")
end

local startupContent = [[-- gerado pelo mekui wired install
-- edite mekui/wired/config.lua para configurar os displays

-- garante que o diretório do mekui está no path
if not package or not package.path then
  -- CC:Tweaked usa require() nativo; apenas define o caminho base
end

local ok, err = pcall(function()
  -- Carrega o startup wired
  local fn, loadErr = loadfile("mekui/wired/startup.lua")
  if not fn then error(loadErr) end
  fn()
end)

if not ok then
  print("[mekui ERRO] " .. tostring(err))
  print("Pressione qualquer tecla...")
  os.pullEvent("key")
end
]]

local h = fs.open("/startup", "w")
if h then
  h.write(startupContent)
  h.close()
  print("[OK] /startup criado")
else
  print("[FAIL] Nao foi possivel criar /startup")
end

-- Mostra periféricos detectados
print("\n=== PERIFÉRICOS DETECTADOS ===")
local names = peripheral.getNames()
if #names == 0 then
  print("Nenhum periférico encontrado via rede.")
  print("Verifique se o modem cabeado esta conectado e ativo.")
else
  for _, name in ipairs(names) do
    local t = peripheral.getType(name)
    print("  " .. name .. " (" .. tostring(t) .. ")")
  end
end

print("\n=== INSTALAÇÃO CONCLUIDA ===")
print("1. Edite mekui/wired/config.lua com os nomes dos periféricos acima")
print("2. Reinicie o computador (Ctrl+R)")
print("")
print("Os nomes dos monitores e reatores aparecem na lista acima.")
print("Use-os exatamente como mostrado no config.lua")
