--[[
  mekui/wired/config.lua
  ╔══════════════════════════════════════════════════════════════╗
  ║  CONFIGURAÇÃO ÚNICA - edite apenas este arquivo              ║
  ║  Um único computador, modem cabeado, tudo na mesma rede.    ║
  ╚══════════════════════════════════════════════════════════════╝

  COMO FUNCIONA:
    - Todos os periféricos (reatores, bateria, monitores) estão
      conectados via modem cabeado à mesma rede.
    - Este computador (onde o startup.lua roda) descobre todos
      os periféricos automaticamente pelo nome de rede.
    - Você só precisa informar qual monitor renderiza cada estrutura.

  COMO DESCOBRIR OS NOMES DOS PERIFÉRICOS:
    No computador central, rode: peripheral.getNames()
    Exemplos de nomes típicos:
      "monitor_0", "monitor_1", "monitor_2"
      "fissionReactorLogicAdapter_0"
      "fusionReactorLogicAdapter_0"
      "inductionPort_0"

  DISPLAYS:
    Cada entrada em "displays" define uma tela independente.
    O campo "monitor" é o nome do monitor na rede cabeada.
    O campo "device" é o nome do periférico na rede cabeada.
    O campo "type" define o dashboard a usar.
]]

local config = {}

-- ════════════════════════════════════════════════════════════════
-- TAXA DE ATUALIZAÇÃO (em segundos)
-- ════════════════════════════════════════════════════════════════
config.poll_rate = 1.0

-- ════════════════════════════════════════════════════════════════
-- DISPLAYS
-- Cada entrada = um monitor mostrando uma estrutura.
-- ════════════════════════════════════════════════════════════════
config.displays = {

  {
    monitor = "monitor_0",                         -- nome do monitor na rede
    device  = "fissionReactorLogicAdapter_0",      -- nome do periférico na rede
    type    = "fission",                           -- tipo do dashboard
    -- widgets = {"status","fuel","waste","burn","heat","graph"},  -- opcional: filtra widgets
  },

  {
    monitor = "monitor_1",
    device  = "fusionReactorLogicAdapter_0",
    type    = "fusion",
  },

  {
    monitor = "monitor_2",
    device  = "inductionPort_0",
    type    = "battery",
  },

  --[[
  -- Exemplo: segundo monitor para o mesmo reator de fissão
  {
    monitor = "monitor_3",
    device  = "fissionReactorLogicAdapter_0",
    type    = "fission",
    widgets = {"status", "graph"},   -- só status e gráfico neste monitor
  },

  -- Exemplo: turbina
  {
    monitor = "monitor_4",
    device  = "turbineValve_0",
    type    = "turbine",
  },
  ]]
}

return config
