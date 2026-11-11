-- Testes offline do Remanescentes: simula a API do Project Zomboid e roda a logica do mod.
-- Uso (na pasta do mod):  lua5.1 tests/run_tests.lua
-- Nao testa animacoes nem o motor real; isso so no jogo (ver TESTING.md).
--
-- Estrutura:
--   tests/mocks.lua      mocks da API do jogo + utilitarios (check, tick, fire, newZombie...)
--   tests/test_*.lua     testes por tema, carregados AUTOMATICAMENTE em ordem alfabetica.
--                        Cada arquivo recebe a tabela T (local T = ...). Os test_0N_* rodam
--                        em sequencia e compartilham estado (mundo, relogio, sorteio).
-- Para adicionar testes, basta criar tests/test_<tema>.lua.
-- REM_TRACE=arquivo grava o registro de checks/caminhos/variaveis (comparar execucoes).

local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
T_MOD_DIR = dir .. "/../"
local T = dofile(dir .. "/mocks.lua")

-- ------------------------------------------------------------------ carrega o mod
-- Lista explicita dos modulos do mod (os demais vem pelos require de cada um).
-- No jogo TODOS os .lua carregam juntos; aqui tambem.
next = nil -- o Kahlua (Lua do jogo) nao tem next(); falha aqui se o mod usar
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Combat"
require "Remanescentes/Rem_Brain"
require "Remanescentes/Rem_World"
require "Remanescentes/Rem_Profile"
require "Remanescentes/Rem_Reputation"
require "Remanescentes/Rem_Safehouse"
require "Remanescentes/Rem_Roles"
require "Remanescentes/Rem_Scavenge"
require "Remanescentes/Rem_Ranged"
require "Remanescentes/Rem_Signals"
require "Remanescentes/Rem_Awareness"
require "Remanescentes/Rem_Mugging"
require "Remanescentes/Rem_Body"
require "Remanescentes/Rem_Timeline"
require "Remanescentes/Rem_Ambient"
require "Remanescentes/Rem_Infection"
require "Remanescentes/Rem_Regions"
require "Remanescentes/Rem_Evolution"
require "Remanescentes/Rem_Relations"
require "Remanescentes/Rem_Interact"
require "Remanescentes/Rem_Persona"
require "Remanescentes/Rem_Bonds"
require "Remanescentes/Rem_Banter"
require "Remanescentes/Rem_Stories"
require "Remanescentes/Rem_Routine"
require "Remanescentes/Rem_Tactics"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_Doors"
require "Remanescentes/Rem_Companion"
require "Remanescentes/Rem_Look"
require "Remanescentes/Rem_PlayerBase"
require "Remanescentes/Rem_BaseBuild"
require "Remanescentes/Rem_BaseEvents"
require "Remanescentes/Rem_GroupLife"
require "Remanescentes/Rem_Gear"
require "Remanescentes/Rem_Alliance"
require "Remanescentes/Rem_Director"
require "Remanescentes/Rem_Needs"
require "Remanescentes/Rem_Watch"
require "Remanescentes/Rem_Orders"
require "Remanescentes/Rem_Prisoners"
require "Remanescentes/Rem_Skills"
require "Remanescentes/Rem_Friends"
require "Remanescentes/Rem_Wounds"
require "Remanescentes/Rem_Spoils"
require "Remanescentes/Rem_Chronicle"
require "Remanescentes/Rem_Territory"
require "Remanescentes/Rem_War"
require "Remanescentes/Rem_Refugees"
require "Remanescentes/Rem_Caravans"
require "Remanescentes/Rem_Fame"
require "Remanescentes/Rem_Traumas"
require "Remanescentes/Rem_PersonalQuests"
require "Remanescentes/Rem_Council"
require "Remanescentes/Rem_Diplomacy"
require "Remanescentes/Rem_Fuel"
require "Remanescentes/Rem_Traps"
require "Remanescentes/Rem_Military"
require "Remanescentes/Rem_Radio"
require "Remanescentes/Rem_RareEvents"
-- os testes antigos das safehouses esperam casas ja fechadas (como a partir do dia 6);
-- test_21 liga a fortificacao gradual dos primeiros dias
Remanescentes.Director.CFG.INITIAL_MIN = 1

-- ------------------------------------------------------------------ roda os testes
local files = {}
local ls = io.popen('ls -1 "' .. dir .. '"')
for name in ls:lines() do
    if name:match("^test_.*%.lua$") then table.insert(files, name) end
end
ls:close()
table.sort(files)

for _, name in ipairs(files) do
    local chunk, err = loadfile(dir .. "/" .. name)
    local ok = chunk ~= nil
    if ok then ok, err = pcall(chunk, T) end
    if not ok then
        T.failed = T.failed + 1
        T.print("  FAIL " .. name .. " abortou: " .. tostring(err))
    end
end

-- Erros engolidos por Rem.safe (no jogo virariam comportamento silenciosamente quebrado)
-- tambem contam como falha. Os provocados de proposito pelos testes de contrato nao.
local swallowed = {}
for _, l in ipairs(T.logs) do
    local line = tostring(l)
    if line:find("ERRO", 1, true) and not line:find("proposital", 1, true) and not line:find("quebrado", 1, true) then
        table.insert(swallowed, line)
    end
end
T.check(#swallowed == 0, "nenhum erro engolido pelo Rem.safe durante os testes" ..
    (#swallowed > 0 and (" (" .. swallowed[1] .. ")") or ""))

local tracePath = os.getenv("REM_TRACE")
if tracePath then
    local f = io.open(tracePath, "w")
    for _, l in ipairs(T.trace) do f:write(l, "\n") end
    for _, l in ipairs(T.logs) do f:write("LOG ", tostring(l), "\n") end
    f:close()
end

T.print(string.format("\n%d ok, %d falhas", T.passed, T.failed))
if T.failed > 0 then
    T.print("\nLog do mod (ultimas 40):")
    for i = math.max(1, #T.logs - 40), #T.logs do T.print("  " .. tostring(T.logs[i])) end
    os.exit(1)
end
