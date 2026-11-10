-- Medicao de desempenho (fora da suite): 12 sobreviventes, N zumbis, 10 s de jogo.
-- Uso: lua5.1 tests/bench/bench.lua [zumbis]
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
T_MOD_DIR = dir .. "/../../"
local T = dofile(dir .. "/../mocks.lua")
next = nil
for _, m in ipairs({ "Rem_Core", "Rem_Factions", "Rem_Spawn", "Rem_Combat", "Rem_Brain", "Rem_World", "Rem_Profile",
    "Rem_Reputation", "Rem_Safehouse", "Rem_Roles", "Rem_Scavenge", "Rem_Ranged", "Rem_Signals", "Rem_Awareness",
    "Rem_Mugging", "Rem_Body", "Rem_Timeline", "Rem_Ambient", "Rem_Infection", "Rem_Regions", "Rem_Evolution",
    "Rem_Relations", "Rem_Interact" }) do require("Remanescentes/" .. m) end
local Rem = Remanescentes
SandboxVars.Remanescentes.Verbose = false
local N = tonumber(arg[1]) or 800
T.player.x, T.player.y = 50000, 50000
for i = 1, 12 do Rem.spawn(50000 + (i % 4) * 3, 50000 + math.floor(i / 4) * 3, 0, { faction = (i % 3 == 0) and "saqueadores" or "civis" }) end
for i = 1, N do T.newZombie(50000 + (i * 7) % 120 - 60, 50000 + (i * 13) % 120 - 60, 0) end
local t0 = os.clock()
for _ = 1, 600 do T.tick(1000 / 60) end   -- 10 s a 60 fps
local dt = os.clock() - t0
io.stdout:write(string.format("%d zumbis, 12 NPCs: %.1f ms por segundo de jogo (%.3f ms por frame)\n", N, dt * 100, dt * 1000 / 600))
