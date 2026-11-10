-- Remanescentes - nucleo: config, log, modelo de dados persistente.
--
-- Tecnica: cada sobrevivente "em cena" e um IsoZombie "inutil" (setUseless) com roupa e
-- pele humanas, animacoes humanas (AnimSets/zombie com condicao RemNPC) e um cerebro em Lua.
--
-- Mundo em duas camadas (single player):
--   * no papel: store.people / store.groups vivem no ModData do save; uma simulacao
--     horaria move grupos, consome suprimentos, saqueia predios reais e mata gente.
--   * em cena: perto do jogador, cada pessoa ganha um corpo (IsoZombie) controlado pelo
--     cerebro; longe, o corpo e removido e a pessoa volta a ser so dados.

--
-- Pontos de extensao (para modulos novos):
--   Rem.on/off/emit           barramento de eventos (Rem_Events.lua)
--   Rem.registerBehavior      comportamentos do cerebro (Rem_Brain.lua)
--   Rem.registerFaction       faccoes (Rem_Factions.lua)
--   Rem.registerDebugOption / Rem.registerNpcOption   menu de clique direito (Rem_Registry.lua)
--   Rem.<Modulo>.CFG          constantes de ajuste de cada modulo (Rem.module)

Remanescentes = Remanescentes or {}
local Rem = Remanescentes

require "Remanescentes/Rem_Events"
require "Remanescentes/Rem_Registry"

Rem.VERSION = "0.7.0"
Rem.MODDATA_KEY = "Remanescentes"

-- Pessoas com corpo agora: [IsoZombie] = npc (estado de runtime, nao salvo)
Rem.active = Rem.active or {}
Rem.activeCount = Rem.activeCount or 0

-- ---------------------------------------------------------------- config
function Rem.cfg(name, default)
    local sv = SandboxVars and SandboxVars.Remanescentes
    if sv and sv[name] ~= nil then return sv[name] end
    return default
end

-- Dificuldade dos sobreviventes (sandbox NPCDifficulty: 1 facil, 2 normal, 3 dificil).
-- dmg: multiplica o dano em voce; acc: soma na chance de acerto dos tiros;
-- sight: multiplica o alcance de visao contra voce.
Rem.DIFFICULTY = {
    { dmg = 0.6, acc = -15, sight = 0.8 },
    { dmg = 1.0, acc = 0, sight = 1.0 },
    { dmg = 1.4, acc = 10, sight = 1.15 },
}
function Rem.difficulty()
    return Rem.DIFFICULTY[Rem.cfg("NPCDifficulty", 2)] or Rem.DIFFICULTY[2]
end

-- ---------------------------------------------------------------- log
function Rem.log(msg)
    print("[Remanescentes] " .. tostring(msg))
end

function Rem.debug(msg)
    if Rem.cfg("Verbose", false) then Rem.log(msg) end
end

-- Chamada protegida: um erro num sobrevivente nao pode derrubar o jogo.
function Rem.safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Rem.log("ERRO: " .. tostring(err)) end
    return ok, err
end

-- Single player: tudo roda localmente. Em cliente de multiplayer o mod fica inerte.
function Rem.isAuthority()
    return not isClient()
end

function Rem.nowMs()
    return getTimestampMs()
end

function Rem.worldHours()
    return getGameTime():getWorldAgeHours()
end

-- ---------------------------------------------------------------- modulos
-- Tabela publica de um modulo (Rem.Brain, Rem.World...) com as constantes de ajuste em
-- .CFG. defaults so preenche chaves que ainda nao existem: outro modulo ou um teste pode
-- ajustar Rem.Brain.CFG.THINK_MS antes ou depois do carregamento. Os modulos leem
-- M.CFG.<CHAVE> no momento do uso.
function Rem.module(name, defaults)
    local m = Rem[name]
    if type(m) ~= "table" then
        m = {}
        Rem[name] = m
    end
    m.CFG = m.CFG or {}
    if defaults then
        for k, v in pairs(defaults) do
            if m.CFG[k] == nil then m.CFG[k] = v end
        end
    end
    return m
end

-- ---------------------------------------------------------------- dados persistentes
-- store.people[id] = pessoa   (ver Rem.newPerson)
-- store.groups[id] = grupo    (ver Rem_World.lua)
-- store.looted[buildingId] = horaDoSaque
local storeCache = nil

function Rem.getStore()
    local store = ModData.getOrCreate(Rem.MODDATA_KEY)
    if storeCache ~= store then
        storeCache = store
        store.people = store.people or {}
        store.groups = store.groups or {}
        store.looted = store.looted or {}
        store.nextId = store.nextId or 1
        Rem.migrate(store)
    end
    store.version = Rem.VERSION
    return store
end

function Rem.newId(prefix)
    local store = Rem.getStore()
    local id = prefix .. tostring(store.nextId)
    store.nextId = store.nextId + 1
    return id
end

-- 0.1/0.2 guardavam store.npcs[pid] = rec. Viram pessoas aliadas soltas.
function Rem.migrate(store)
    if not store.npcs then return end
    local n = 0
    for pid, rec in pairs(store.npcs) do
        local id = "p" .. tostring(store.nextId)
        store.nextId = store.nextId + 1
        rec.id = id
        rec.pid = tonumber(pid)
        rec.faction = rec.faction or "aliados"
        rec.x, rec.y, rec.z = rec.homeX, rec.homeY, rec.homeZ
        rec.onScene = false
        store.people[id] = rec
        n = n + 1
    end
    store.npcs = nil
    Rem.log("migrados " .. n .. " sobreviventes da versao anterior")
end

function Rem.getPerson(id)
    return Rem.getStore().people[id]
end

function Rem.removePerson(id)
    local store = Rem.getStore()
    local p = store.people[id]
    store.people[id] = nil
    if p and p.groupId then
        local g = store.groups[p.groupId]
        if g and g.members then
            for i = #g.members, 1, -1 do
                if g.members[i] == id then table.remove(g.members, i) end
            end
        end
    end
    if p then Rem.emit("personRemoved", p) end
end

function Rem.personCount()
    local n = 0
    for _ in pairs(Rem.getStore().people) do n = n + 1 end
    return n
end

-- compatibilidade com testes/ferramentas da 0.2
Rem.recordCount = Rem.personCount

-- ---------------------------------------------------------------- helpers
function Rem.isNPC(zombie)
    return zombie ~= nil and Rem.active[zombie] ~= nil
end

function Rem.dist(a, b)
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

function Rem.distXY(a, x, y)
    local dx, dy = a:getX() - x, a:getY() - y
    return math.sqrt(dx * dx + dy * dy)
end

function Rem.dist2(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

function Rem.say(npc, textKey, ...)
    if npc and npc.z then
        Rem.safe(function(...) npc.z:Say(getText(textKey, ...)) end, ...)
    end
end

function Rem.pick(list)
    return list[ZombRand(#list) + 1]
end

Rem.NAMES = {
    "Ana", "Bruno", "Carla", "Diego", "Elisa", "Fabio", "Gabriela", "Heitor", "Iara", "Joao",
    "Karen", "Lucas", "Marina", "Nelson", "Olivia", "Pedro", "Raquel", "Sergio", "Tania", "Vitor",
    "Bill", "Kate", "Marcus", "Tess", "Dwight", "Rosa", "Hank", "Jill", "Owen", "Wendy",
    "Ray", "Doris", "Earl", "Lena", "Mack", "Nora", "Clyde", "Ruth", "Gus", "Ivy",
}

-- Equipamento. wtype escolhe o conjunto de animacoes (ver tools/gen_animsets.sh).
Rem.LOADOUTS = {
    { item = "Base.BaseballBat", wtype = "bat" },
    { item = "Base.Crowbar", wtype = "bat" },
    { item = "Base.Axe", wtype = "bat" },
    { item = "Base.Plank", wtype = "bat" },
    { item = "Base.HuntingKnife", wtype = "1h" },
    { item = "Base.Hammer", wtype = "1h" },
    { item = "Base.KitchenKnife", wtype = "1h" },
}

Rem.OUTFITS = {
    "Generic01", "Generic02", "Generic03", "Generic04", "Generic05", "Camper", "Hunter",
    "Farmer", "Mechanic", "ConstructionWorker", "Ranger", "Biker", "Tourist", "Doctor", "Police",
}

Events.OnInitGlobalModData.Add(function(isNewGame)
    -- corpos nao sobrevivem a um load: tudo comeca fora de cena e e re-associado depois
    local store = Rem.getStore()
    for _, p in pairs(store.people) do p.onScene = false end
    Rem.active = {}
    Rem.activeCount = 0
    local g = 0
    for _ in pairs(store.groups) do g = g + 1 end
    Rem.log("v" .. Rem.VERSION .. " carregado. Pessoas: " .. Rem.personCount() .. ", grupos: " .. g)
end)

-- Opcoes padrao do menu (registradas aqui para virem antes das de outros modulos).
require "Remanescentes/Rem_Commands"
