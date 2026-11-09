-- Testes offline do Remanescentes: simula a API do Project Zomboid e roda a logica do mod.
-- Uso (na pasta do mod):  lua5.1 tests/run_tests.lua
-- Nao testa animacoes nem o motor real; isso so no jogo (ver TESTING.md).

local MOD = "42/media/lua/"

-- ------------------------------------------------------------------ mocks basicos
local clock = 0
local events = {}
Events = setmetatable({}, { __index = function(t, name)
    local ev = { list = {} }
    function ev.Add(fn) table.insert(ev.list, fn) end
    function ev.Remove(fn) end
    events[name] = ev
    rawset(t, name, ev)
    return ev
end })
local function fire(name, ...)
    if events[name] then for _, fn in ipairs(events[name].list) do fn(...) end end
end

SandboxVars = { Remanescentes = { SpawnChance = 0, MaxActive = 8, NPCHealth = 3.0,
    NPCDamageMultiplier = 1.0, ZombieDamage = 0.15, FriendlyFire = false, DebugMenu = true, Verbose = true } }

local logs = {}
local realPrint = print
print = function(s) table.insert(logs, s) end
function getText(k, ...) return k end
function isClient() return false end
function isServer() return false end
function getTimestampMs() return clock end
local rnd = 0
function ZombRand(a, b) if b then return a end return 0 end
function ZombRandFloat(a, b) return (a + b) / 2 end
function getGameTime() return { getWorldAgeHours = function() return 1 end } end
function instanceof(o, cls) return o and o._class == cls end

local store = {}
BloodBodyPartType = { MAX = { index = function() return 3 end }, FromIndex = function(i) return i end }
ModData = { getOrCreate = function(k) store[k] = store[k] or {}; return store[k] end }

-- lista estilo Java
local function JList(t)
    return { _t = t, size = function(self) return #self._t end, get = function(self, i) return self._t[i + 1] end }
end

-- ------------------------------------------------------------------ mundo falso
local zombies = {}
local nextPid = 100

local function newWeapon(id)
    local stats = { ["Base.BaseballBat"] = { 0.8, 1.1, 1.25 }, ["Base.HuntingKnife"] = { 0.6, 1.2, 0.9 } }
    local s = stats[id] or { 0.5, 1.0, 1.0 }
    return { _class = "HandWeapon", id = id,
        getMinDamage = function() return s[1] end, getMaxDamage = function() return s[2] end,
        getMaxRange = function() return s[3] end,
        getSwingSound = function() return "Swing" end, getZombieHitSound = function() return "Hit" end }
end
function instanceItem(id) return newWeapon(id) end

local function newZombie(x, y, z)
    nextPid = nextPid + 1
    local o = { x = x, y = y, z = z, hp = 1.5, dead = false, useless = false, vars = {}, pid = nextPid,
        target = nil, moving = false, inWorld = true, path = nil, said = {}, onFloor = false }
    function o:getX() return self.x end
    function o:getY() return self.y end
    function o:getZ() return self.z end
    function o:getHealth() return self.hp end
    function o:setHealth(h) self.hp = h end
    function o:isDead() return self.dead end
    function o:Kill(k) self.dead = true; fire("OnZombieDead", self) end
    function o:setUseless(b) self.useless = b end
    function o:isUseless() return self.useless end
    function o:setNoTeeth() end
    function o:setTarget(t) self.target = t end
    function o:getTarget() return self.target end
    function o:setVariable(k, v) self.vars[k] = v end
    function o:setAvoidDamage(b) self.avoid = b end
    function o:setPrimaryHandItem(i) self.hand = i end
    function o:getPrimaryHandItem() return self.hand end
    function o:clearItemsToSpawnAtDeath() end
    function o:addItemToSpawnAtDeath() end
    function o:resetModelNextFrame() end
    function o:getPersistentOutfitID() return self.pid end
    function o:Say(s) table.insert(self.said, s) end
    function o:pathToLocationF(x, y, z) error("nao usar zombie:pathToLocationF (cai em walktoward)") end
    function o:pathToCharacter(c) self.path = { c.x, c.y }; self.chasing = c end
    function o:getPathFindBehavior2()
        local me = self
        return {
            pathToLocationF = function(_, x, y, z) me.path = { x, y } end,
            cancel = function() me.path = nil end,
        }
    end
    function o:getVariableBoolean(k) return self.vars[k] == true end
    function o:isFemale() return false end
    function o:getHumanVisual()
        local me = self
        return { setSkinTextureName = function(_, n) me.skin = n end, removeBlood = function() end, removeDirt = function() end }
    end
    function o:getItemVisuals()
        local me = self
        local iv = { setBlood = function(_, p, v) me.cleaned = true end, setDirt = function() end }
        return JList({ iv })
    end
    function o:resetModel() end
    function o:faceThisObject() end
    function o:playSound() end
    function o:splatBloodFloor() end
    function o:setStaggerBack() end
    function o:isOnFloor() return self.onFloor end
    function o:isExistInTheWorld() return self.inWorld end
    function o:getCurrentSquare() return self.inWorld and {} or nil end
    table.insert(zombies, o)
    return o
end

function addZombiesInOutfit(x, y, z) return JList({ newZombie(x, y, z) }) end

local player = { x = 10, y = 10, z = 0, said = {} }
function player:getX() return self.x end
function player:getY() return self.y end
function player:getZ() return self.z end
function player:isDead() return false end
function player:Say(s) table.insert(self.said, s) end
function getPlayer() return player end

function getCell()
    return {
        getZombieList = function()
            local live = {}
            for _, z in ipairs(zombies) do if z.inWorld then table.insert(live, z) end end
            return JList(live)
        end,
        getGridSquare = function() return nil end,
    }
end

-- require simples apontando para a pasta do mod
local loaded = {}
function require(name)
    if loaded[name] then return end
    loaded[name] = true
    for _, base in ipairs({ MOD .. "shared/", MOD .. "client/" }) do
        local f = io.open(base .. name .. ".lua")
        if f then f:close(); dofile(base .. name .. ".lua"); return end
    end
end

-- ------------------------------------------------------------------ framework de teste
local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; realPrint("  ok   " .. msg)
    else failed = failed + 1; realPrint("  FAIL " .. msg) end
end
local function tick(ms, n)
    for _ = 1, (n or 1) do clock = clock + ms; fire("OnTick") end
end

-- ------------------------------------------------------------------ carrega o mod
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Combat"
require "Remanescentes/Rem_Brain"
local Rem = Remanescentes
fire("OnInitGlobalModData", true)

realPrint("1) Spawn")
local npc = Rem.spawn(12, 12, 0, { mode = "follow", item = "Base.BaseballBat", wtype = "bat" })
check(npc ~= nil, "spawn retorna npc")
check(npc.z.useless == true, "zumbi virou 'inutil' (sem IA de zumbi)")
check(npc.z.vars.RemNPC == true and npc.z.vars.RemWeapon == "bat", "variaveis de animacao setadas")
check(npc.z.hp == 3.0, "vida do sandbox aplicada")
check(Rem.recordCount() == 1, "registro salvo no ModData")
check(npc.z.avoid == true, "sem fogo amigo por padrao")
check(npc.z.skin and npc.z.skin:sub(1, 9) == "MaleBody0", "pele humana aplicada (" .. tostring(npc.z.skin) .. ")")
check(npc.z.cleaned == true, "roupa limpa de sangue/sujeira")
check(npc.rec.skin == npc.z.skin, "pele salva no registro (mesma apos load)")

realPrint("2) Seguir o jogador")
player.x, player.y = 30, 30
tick(300)
check(npc.z.path and npc.z.path[1] == 30, "anda ate o jogador quando longe")
check(npc.z.vars.bPathfind == true, "forca estado pathfind (nao walktoward)")
npc.z.vars.bPathfind = false -- jogo terminou o caminho
player.x, player.y = 12, 12; npc.z.x, npc.z.y = 12, 13
tick(300)
check(npc.moving == false, "percebe que chegou e para")

realPrint("3) Combate contra zumbi")
npc.z.x, npc.z.y = 30, 31
local enemy = newZombie(30, 32, 0) -- a 1 tile
local hp0 = enemy.hp
tick(300)
check(npc.z.vars.RemAttack == true, "inicia animacao de ataque")
tick(100, 5)
check(enemy.hp < hp0 or enemy.dead, "aplica dano no zumbi")
tick(100, 30)
check(enemy.dead, "mata o zumbi depois de alguns golpes")
check(npc.z.vars.RemAttack == false, "termina animacao de ataque")

realPrint("4) Zumbi distante e atraido")
local far = newZombie(30, 36, 0)
tick(1100)
check(far.chasing == npc.z, "zumbi ocioso persegue o sobrevivente")

realPrint("5) Zumbis ferem e matam o sobrevivente")
far.dead = true
local biter = newZombie(30.5, 31.3, 0)
npc.z.hp = 0.2
npc.nextAttack = clock + 999999 -- impede o npc de reagir, para testar a morte
for _ = 1, 10 do tick(1600) end
check(npc.z.dead, "sobrevivente morre")
check(Rem.recordCount() == 0, "registro removido ao morrer")
check(Rem.activeCount == 0, "runtime limpo")

realPrint("6) Save/load: chunk descarrega e recarrega")
local n2 = Rem.spawn(40, 40, 0, { mode = "stay" })
local pid = n2.z.pid
n2.z.inWorld = false
tick(300)
check(Rem.activeCount == 0, "descarregado sai da lista ativa")
check(Rem.recordCount() == 1, "registro continua salvo")
local reloaded = newZombie(40, 40, 0); reloaded.pid = pid; reloaded.useless = false
fire("OnZombieUpdate", reloaded)
check(Rem.active[reloaded] ~= nil and reloaded.useless, "zumbi recarregado volta a ser sobrevivente")
check(reloaded.skin == n2.rec.skin, "mesma pele depois de recarregar")
local stranger = newZombie(41, 41, 0)
fire("OnZombieUpdate", stranger)
check(Rem.active[stranger] == nil, "zumbi comum nao e afetado")

realPrint("7) Remover todos")
Rem.dismissAll = Rem.dismissAll
reloaded.removeFromWorld = function(s) s.inWorld = false end
reloaded.removeFromSquare = function() end
Rem.dismissAll()
check(Rem.recordCount() == 0 and Rem.activeCount == 0, "remove tudo")

realPrint(string.format("\n%d ok, %d falhas", passed, failed))
if failed > 0 then
    realPrint("\nLog do mod:"); for _, l in ipairs(logs) do realPrint("  " .. l) end
    os.exit(1)
end
