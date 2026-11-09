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

local function defaults()
    return { MaxActive = 12, NPCHealth = 3.0, NPCDamageMultiplier = 1.0, ZombieDamage = 0.15,
        FriendlyFire = false, DebugMenu = true, Verbose = true, ZombieSightRange = 10,
        NPCNoiseMultiplier = 1.0, FleeHealthPercent = 30, Barks = true, ZombieAttackMode = 1,
        NPCVsPlayerDamage = 1.0, WorldGroups = 0, RaiderPercent = 20, ScavengeDeathChance = 0,
        LootLeftPercent = 0 }
end
SandboxVars = { Remanescentes = defaults() }

local logs = {}
local realPrint = print
print = function(s) table.insert(logs, s) end
function getText(k, ...) return k end
function isClient() return false end
function isServer() return false end
function getTimestampMs() return clock end
-- sorteio deterministico que varia (ciclo), para nao escolher sempre o mesmo predio
local rngCounter = 0
function ZombRand(a, b)
    rngCounter = rngCounter + 1
    if b then return a + (rngCounter % math.max(1, b - a)) end
    return rngCounter % math.max(1, a)
end
function ZombRandFloat(a, b) return (a + b) / 2 end
local worldHours, timeOfDay = 100, 12
function getGameTime()
    return { getWorldAgeHours = function() return worldHours end, getTimeOfDay = function() return timeOfDay end }
end
function instanceof(o, cls) return type(o) == "table" and o._class == cls end

local daylight = 1.0
function getClimateManager() return { getDayLightStrength = function() return daylight end } end

local sounds = {}
function addSound(src, x, y, z, radius, volume) table.insert(sounds, { src = src, radius = radius }) end

local store = {}
BloodBodyPartType = { MAX = { index = function() return 3 end }, FromIndex = function(i) return i end }
BodyPartType = { MAX = "MAX", ToIndex = function() return 17 end, FromIndex = function(i) return i end }
ModData = { getOrCreate = function(k) store[k] = store[k] or {}; return store[k] end }

local function JList(t)
    return { _t = t, size = function(self) return #self._t end, get = function(self, i) return self._t[i + 1] end }
end

-- predios do "mapa"
local buildingDefs = {}
local function addBuilding(id, x, y, w, h)
    local d = { id = id, x = x, y = y, w = w, h = h }
    function d:getX() return self.x end
    function d:getY() return self.y end
    function d:getW() return self.w end
    function d:getH() return self.h end
    function d:getID() return self.id end
    table.insert(buildingDefs, d)
    return d
end
function getWorld()
    return { getMetaGrid = function() return { getBuildings = function() return JList(buildingDefs) end } end }
end

-- ------------------------------------------------------------------ personagens falsos
local zombies = {}
local nextPid = 100

local function newWeapon(id)
    local stats = { ["Base.BaseballBat"] = { 0.8, 1.1, 1.25 }, ["Base.HuntingKnife"] = { 0.6, 1.2, 0.9 } }
    local s = stats[id] or { 0.5, 1.0, 1.0 }
    return { _class = "HandWeapon", id = id,
        getMinDamage = function() return s[1] end, getMaxDamage = function() return s[2] end,
        getMaxRange = function() return s[3] end, getSoundRadius = function() return 15 end,
        getSwingSound = function() return "Swing" end, getZombieHitSound = function() return "Hit" end }
end
function instanceItem(id) return newWeapon(id) end

local function vec(x, y) return { getX = function() return x end, getY = function() return y end } end

local function newZombie(x, y, z, fx, fy)
    nextPid = nextPid + 1
    local o = { x = x, y = y, z = z, hp = 1.5, dead = false, useless = false, vars = {}, pid = nextPid,
        target = nil, inWorld = true, path = nil, said = {}, onFloor = false, fx = fx or 0, fy = fy or -1,
        canSee = true, noTeeth = false, attacking = false, outcome = "" }
    function o:getX() return self.x end
    function o:getY() return self.y end
    function o:getZ() return self.z end
    function o:getHealth() return self.hp end
    function o:setHealth(h) self.hp = h end
    function o:isDead() return self.dead end
    function o:Kill(k) self.dead = true; fire("OnZombieDead", self) end
    function o:setUseless(b) self.useless = b end
    function o:isUseless() return self.useless end
    function o:setNoTeeth(b) self.noTeeth = b end
    function o:setTarget(t) self.target = t end
    function o:getTarget() return self.target end
    function o:setVariable(k, v) self.vars[k] = v end
    function o:getVariableBoolean(k) return self.vars[k] == true end
    function o:setAvoidDamage(b) self.avoid = b end
    function o:setPrimaryHandItem(i) self.hand = i end
    function o:getPrimaryHandItem() return self.hand end
    function o:clearItemsToSpawnAtDeath() end
    function o:addItemToSpawnAtDeath() end
    function o:resetModelNextFrame() end
    function o:getPersistentOutfitID() return self.pid end
    function o:Say(s) table.insert(self.said, s) end
    function o:pathToLocationF() error("nao usar zombie:pathToLocationF (cai em walktoward)") end
    function o:pathToCharacter(c) self.path = { c.x, c.y }; self.chasing = c end
    function o:getPathFindBehavior2()
        local me = self
        return { pathToLocationF = function(_, x, y, z) me.path = { x, y } end, cancel = function() me.path = nil end }
    end
    function o:getForwardDirection() return vec(self.fx, self.fy) end
    function o:CanSee(other) return self.canSee end
    function o:faceLocationF() end
    function o:isFemale() return false end
    function o:getHumanVisual()
        local me = self
        return { setSkinTextureName = function(_, n) me.skin = n end, removeBlood = function() end, removeDirt = function() end }
    end
    function o:getItemVisuals()
        local me = self
        return JList({ { setBlood = function() me.cleaned = true end, setDirt = function() end } })
    end
    function o:resetModel() end
    function o:faceThisObject() end
    function o:playSound() end
    function o:splatBloodFloor() end
    function o:setStaggerBack() end
    function o:isOnFloor() return self.onFloor end
    function o:isExistInTheWorld() return self.inWorld end
    function o:getCurrentSquare() return self.inWorld and {} or nil end
    function o:isAttacking() return self.attacking end
    function o:getAttackOutcome() return self.outcome end
    function o:removeFromWorld() self.inWorld = false end
    function o:removeFromSquare() end
    table.insert(zombies, o)
    return o
end

function addZombiesInOutfit(x, y, z, n, outfit) local zz = newZombie(x, y, z); zz.outfit = outfit; return JList({ zz }) end

-- jogador com partes do corpo
local parts = {}
local player = { _class = "IsoPlayer", x = 10, y = 10, z = 0, said = {}, sneaking = false }
function player:getX() return self.x end
function player:getY() return self.y end
function player:getZ() return self.z end
function player:isDead() return false end
function player:isSneaking() return self.sneaking end
function player:Say(s) table.insert(self.said, s) end
function player:playSound() end
function player:splatBloodFloor() end
function player:setAttackedBy(a) self.attackedBy = a end
function player:teleportTo(x, y, z) self.x, self.y, self.z = x, y, z end
function player:getBodyDamage()
    return { getBodyPart = function(_, i)
        parts[i] = parts[i] or { damage = 0,
            AddDamage = function(s, d) s.damage = s.damage + d end,
            setCut = function(s, b, noInf) s.cut = b; s.noInfection = noInf end,
            setScratched = function(s, b, noInf) s.scratched = b; s.noInfection = noInf end }
        return parts[i]
    end }
end
function getPlayer() return player end

local function square(x, y, z)
    return { getX = function() return math.floor(x) end, getY = function() return math.floor(y) end,
        getZ = function() return z end, isFree = function() return true end, getBuilding = function() return nil end }
end

function getCell()
    return {
        getZombieList = function()
            local live = {}
            for _, z in ipairs(zombies) do if z.inWorld and not z.dead then table.insert(live, z) end end
            return JList(live)
        end,
        getGridSquare = function(_, x, y, z) return square(x, y, z) end,
    }
end

local function clearZombies(keep)
    for _, z in ipairs(zombies) do if not (keep and keep[z]) then z.inWorld = false end end
end

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
local function saidPrefix(z, prefix)
    for _, s in ipairs(z.said) do if s:sub(1, #prefix) == prefix then return true end end
    return false
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- ------------------------------------------------------------------ carrega o mod
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Combat"
require "Remanescentes/Rem_Brain"
require "Remanescentes/Rem_World"
local Rem = Remanescentes

-- migracao: save da 0.2 com store.npcs
store.Remanescentes = { npcs = { ["555"] = { name = "Velho", item = "Base.Hammer", wtype = "1h", mode = "stay", homeX = 5, homeY = 5, homeZ = 0 } } }
fire("OnInitGlobalModData", false)

realPrint("0) Migracao da 0.2")
local s = Rem.getStore()
check(s.npcs == nil and Rem.personCount() == 1, "store.npcs vira store.people")
local migrated
for _, p in pairs(s.people) do migrated = p end
check(migrated.faction == "aliados" and migrated.pid == 555 and migrated.x == 5, "pessoa migrada como aliada, com pid e posicao")
Rem.removePerson(migrated.id)

tick(5000) -- passa o periodo de carencia do mundo

realPrint("1) Spawn e aparencia")
local npc = Rem.spawn(12, 12, 0, { faction = "aliados", mode = "follow", item = "Base.BaseballBat", wtype = "bat" })
check(npc ~= nil and npc.rec.id ~= nil, "spawn cria pessoa com id")
check(npc.z.useless == true and npc.z.noTeeth == true, "corpo e zumbi inutil e sem dentes")
check(npc.z.vars.RemNPC == true and npc.z.vars.RemWeapon == "bat", "variaveis de animacao")
check(npc.z.skin and npc.z.skin:sub(1, 9) == "MaleBody0" and npc.z.cleaned, "pele humana e roupa limpa")
check(npc.z.avoid == true, "aliado protegido de fogo amigo")
check(npc.rec.pid == npc.z.pid and npc.rec.onScene, "pessoa sabe qual corpo e o dela")
check(saidPrefix(npc.z, "IGUI_Rem_Bark_hello_"), "cumprimenta")

realPrint("2) Seguir: correr longe, andar perto, agachar junto")
player.x, player.y = 30, 30
tick(300)
check(npc.z.path and npc.z.path[1] == 30 and npc.z.vars.bPathfind == true, "anda via pathfind ate o jogador")
check(npc.running, "corre quando longe")
npc.z.x, npc.z.y = 26, 26
tick(1100)
check(not npc.running, "anda quando perto")
npc.z.vars.bPathfind = false; npc.z.x, npc.z.y = 30, 31
player.sneaking = true
tick(300)
check(npc.z.vars.RemSneak == true, "agacha quando o jogador agacha")
player.sneaking = false
tick(300)
check(npc.rec.x == 30 and npc.rec.y == 31, "posicao sincronizada na pessoa")

realPrint("3) Combate contra zumbi")
npc.lastBark = nil; npc.barkAt = {}
local enemy = newZombie(30, 32, 0)
sounds = {}
tick(300); tick(100, 45)
check(enemy.dead, "mata o zumbi")
check(#sounds > 0, "golpes fazem barulho")
check(saidPrefix(npc.z, "IGUI_Rem_Bark_kill_"), "comenta a morte")

realPrint("4) Ataque REAL dos zumbis: mira, dentes e troca de alvo")
clearZombies({ [npc.z] = true }); Rem.hunting = {}
npc.nextAttack = clock + 9999999 -- npc nao revida nestes testes
local hunter = newZombie(30, 25, 0, 0, 1)
tick(600)
check(hunter.target == npc.z, "zumbi mira o sobrevivente (setTarget)")
check(hunter.noTeeth == true, "atacante fica sem dentes enquanto mira o sobrevivente")
local hp0 = npc.z.hp
hunter.attacking = true; hunter.outcome = "start"; tick(20)
hunter.outcome = "success"; tick(20)
check(npc.z.hp < hp0, "acerto real (outcome=success) causa dano")
check(npc.z.vars.RemHit == true, "sobrevivente faz animacao de golpe")
local hp1 = npc.z.hp
tick(20)
check(npc.z.hp == hp1, "mesmo acerto nao conta duas vezes")
hunter.attacking = false; tick(20); hunter.attacking = true; tick(20)
check(npc.z.hp < hp1, "novo ciclo de ataque conta de novo")
tick(600)
check(npc.z.vars.RemHit == false, "reacao ao golpe termina")
hunter.target = player; tick(20)
check(hunter.noTeeth == false, "trocou para o jogador: DENTES DE VOLTA no mesmo tick")
check(Rem.hunting[hunter] == nil, "e esquece o sobrevivente")
hunter.target = nil
npc.z.hp = 3.0

realPrint("5) Ataque simulado (opcao do sandbox)")
SandboxVars.Remanescentes.ZombieAttackMode = 2
clearZombies({ [npc.z] = true }); Rem.hunting = {}
local biter = newZombie(30.5, 31.4, 0)
tick(600)
check(biter.vars.RemZAttack == true and npc.z.hp < 3.0, "bote animado + dano")
check(biter.target == nil and biter.noTeeth == false, "modo simulado nao mexe em alvo/dentes")
tick(800)
check(biter.vars.RemZAttack == false, "animacao termina")
SandboxVars.Remanescentes.ZombieAttackMode = 1
npc.z.hp = 3.0

realPrint("6) Saqueador hostil ataca o jogador")
clearZombies({ [npc.z] = true }); Rem.hunting = {}
npc.rec.mode = "stay"; npc.rec.homeX, npc.rec.homeY = 30, 31
local raider = Rem.spawn(30, 36, 0, { faction = "saqueadores", item = "Base.BaseballBat", wtype = "bat" })
check(raider.z.avoid == false, "hostil pode ser ferido pelo jogador")
raider.nextAttack = 0
npc.z.inWorld = false; tick(20); -- tira o aliado da cena para isolar o duelo
player.x, player.y = 30, 37
tick(300)
check(raider.attackTarget == player or raider.z.path ~= nil, "hostil vai/ataca o jogador")
check(saidPrefix(raider.z, "IGUI_Rem_Bark_threat_"), "ameaca o jogador")
tick(100, 6)
local hurt = nil
for _, p in pairs(parts) do if p.damage > 0 then hurt = p end end
check(hurt ~= nil, "jogador leva dano numa parte do corpo")
check(hurt and (hurt.cut or hurt.scratched) and hurt.noInfection == true, "ferimento de arma SEM infeccao")

realPrint("7) Sobrevivente x sobrevivente (faccoes rivais)")
npc.z.inWorld = true
local ally = Rem.active[npc.z]
if not ally then ally = Rem.activate(npc.z, npc.rec) end
player.x, player.y = 45, 45 -- jogador afastado (mas dentro da cena), so os dois
raider.z.x, raider.z.y = 30, 32
ally.nextAttack = 0; raider.nextAttack = 0
local rhp = raider.z.hp
tick(300); tick(100, 30)
check(raider.z.hp < rhp or raider.z.dead, "aliado ataca o saqueador")
check(ally.z.hp < 3.0 or raider.attackTarget == ally.z or raider.z.dead, "saqueador revida no aliado")

realPrint("8) Morte solta os zumbis que cacavam")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 45, 45
ally = Rem.spawn(30, 31, 0, { faction = "aliados", mode = "stay" })
ally.rec.homeX, ally.rec.homeY = 30, 31
local h2 = newZombie(30, 28, 0, 0, 1)
ally.nextAttack = clock + 9999999
tick(600)
check(h2.noTeeth == true, "zumbi cacando sem dentes")
ally.z.hp = 0.01
Rem.damageNPC(ally, 1)
tick(20)
check(ally.z.dead and h2.noTeeth == false, "sobrevivente morreu: zumbi volta a ter dentes")
check(Rem.getPerson(ally.rec.id) == nil, "pessoa removida")

-- ------------------------------------------------------------------ mundo vivo
realPrint("9) Semeadura: grupos em predios reais")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 1000, 1000
addBuilding(1, 1100, 1000, 10, 10)   -- 105 tiles
addBuilding(2, 1000, 1200, 8, 8)     -- ~204
addBuilding(3, 1010, 1010, 6, 6)     -- muito perto do jogador (nao serve)
addBuilding(4, 1130, 1000, 10, 10)   -- alvo de saque perto do 1
SandboxVars.Remanescentes.WorldGroups = 2
Rem.getStore().seeded = false -- simula um save novo
tick(2000)
check(Rem.groupCount() >= 1, "grupos criados (" .. Rem.groupCount() .. ")")
local g = select(1, Rem.nearestGroup(1105, 1005))
check(g and g.home and g.home.bid ~= "3", "nao nasce grupo colado no jogador")
check(g and #g.members >= 1 and Rem.getPerson(g.members[1]).groupId == g.id, "membros pertencem ao grupo")

realPrint("10) Simulacao fora de cena: fome, saque, volta")
g.supplies = 0.5
local sup0 = g.supplies
Rem.simulateWorld(1)
check(g.supplies < sup0 or g.activity == "scavenge", "consome suprimentos")
-- forca saida para saquear
g.supplies = 0; g.activity = "home"
for _ = 1, 12 do if g.activity == "home" then Rem.simulateWorld(1) end end
check(g.activity == "scavenge" and g.target, "sai para saquear com pouca comida")
local tgtBid = g.target.bid
for _ = 1, 4 do worldHours = worldHours + 1; Rem.simulateWorld(1) end
check(Rem.getStore().looted[tgtBid] ~= nil, "predio alvo marcado como saqueado")
check(g.supplies > 0, "ganhou suprimentos")
for _ = 1, 4 do worldHours = worldHours + 1; Rem.simulateWorld(1) end
check(g.activity == "home", "voltou para casa")

realPrint("11) Casa saqueada fica vazia de verdade")
local emptied = false
local container = { getSourceGrid = function() return { getBuilding = function() return { getDef = function() return { getID = function() return tonumber(tgtBid) end } end } end } end,
    removeAllItems = function() emptied = true end }
fire("OnFillContainer", "kitchen", "fridge", container)
check(emptied, "conteiner de predio saqueado e esvaziado")

realPrint("12) Materializar perto, desmaterializar longe")
for _, id in ipairs(g.members) do local p = Rem.getPerson(id); p.x, p.y = g.home.x, g.home.y end
player.x, player.y = g.home.x + 20, g.home.y
tick(1600)
local member = Rem.getPerson(g.members[1])
check(member.onScene and Rem.activeCount >= 1, "membro ganhou corpo ao jogador chegar perto")
local body
for z, n in pairs(Rem.active) do if n.rec == member then body = z end end
body.x = body.x + 1
player.x, player.y = g.home.x + 200, g.home.y
tick(1600)
check(not member.onScene and member.pid == nil, "longe: corpo removido, pessoa continua")
check(math.abs(member.x - (g.home.x + 1)) < 3, "posicao do corpo salva na pessoa")
check(body.inWorld == false, "zumbi do corpo saiu do mundo")

realPrint("13) Re-associar corpo salvo depois de um load")
local saved = newZombie(member.x, member.y, 0)
member.pid = saved.pid
member.onScene = false
Rem.invalidatePidIndex()
fire("OnZombieUpdate", saved)
check(Rem.active[saved] ~= nil and saved.useless, "zumbi salvo vira a pessoa de novo (sem duplicar)")
local stranger = newZombie(5, 5, 0)
fire("OnZombieUpdate", stranger)
check(Rem.active[stranger] == nil, "zumbi comum nao e afetado")

realPrint("14) Ataque de saqueadores fora de cena")
Rem.dismissAll(); clearZombies()
local victims = Rem.createGroup("civis", 2000, 2000, "v", 2)
local gang = Rem.createGroup("saqueadores", 2100, 2000, "r", 4)
victims.supplies = 10
gang.supplies = 0
player.x, player.y = 0, 0
gang.activity = "raid"; gang.target = { x = 2000, y = 2000, z = 0, victim = victims.id }
for _ = 1, 3 do worldHours = worldHours + 1; Rem.simulateWorld(1) end
check(#victims.members < 2 or gang.supplies > 0, "ataque resolvido: mortes e/ou suprimentos roubados")
check(gang.activity == "return" or gang.activity == "home", "saqueadores voltam para casa")

realPrint("15) Remover tudo")
Rem.dismissAll()
check(Rem.personCount() == 0 and Rem.groupCount() == 0 and Rem.activeCount == 0, "limpo")

realPrint(string.format("\n%d ok, %d falhas", passed, failed))
if failed > 0 then
    realPrint("\nLog do mod (ultimas 40):")
    for i = math.max(1, #logs - 40), #logs do realPrint("  " .. logs[i]) end
    os.exit(1)
end
