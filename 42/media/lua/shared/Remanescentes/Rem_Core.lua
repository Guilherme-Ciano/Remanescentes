-- Remanescentes - nucleo: config, log, registro persistente.
-- Tecnica: cada sobrevivente e um IsoZombie "inutil" (setUseless) com roupa humana,
-- animacoes humanas (AnimSets/zombie com condicao RemNPC) e um cerebro em Lua.

Remanescentes = Remanescentes or {}
local Rem = Remanescentes

Rem.VERSION = "0.1.0"
Rem.MODDATA_KEY = "Remanescentes"

-- Sobreviventes carregados no mundo agora: [IsoZombie] = npc (estado de runtime)
Rem.active = Rem.active or {}
Rem.activeCount = Rem.activeCount or 0

-- ---------------------------------------------------------------- config
function Rem.cfg(name, default)
    local sv = SandboxVars and SandboxVars.Remanescentes
    if sv and sv[name] ~= nil then return sv[name] end
    return default
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

-- ---------------------------------------------------------------- autoridade
-- Fase 1: so singleplayer (e, no futuro, o servidor). Clientes MP nao rodam o cerebro.
function Rem.isAuthority()
    return not isClient()
end

function Rem.nowMs()
    return getTimestampMs()
end

-- ---------------------------------------------------------------- registro persistente
-- Guardado em ModData global (vai junto com o save). Chave = persistentOutfitID do zumbi,
-- que sobrevive a save/load, para reconhecer o sobrevivente quando o chunk recarrega.
function Rem.getStore()
    local store = ModData.getOrCreate(Rem.MODDATA_KEY)
    store.npcs = store.npcs or {}
    store.version = Rem.VERSION
    return store
end

function Rem.keyOf(zombie)
    return tostring(zombie:getPersistentOutfitID())
end

function Rem.getRecord(key)
    return Rem.getStore().npcs[key]
end

function Rem.setRecord(key, rec)
    Rem.getStore().npcs[key] = rec
end

function Rem.removeRecord(key)
    Rem.getStore().npcs[key] = nil
end

function Rem.recordCount()
    local n = 0
    for _ in pairs(Rem.getStore().npcs) do n = n + 1 end
    return n
end

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

function Rem.say(npc, textKey, ...)
    if npc and npc.z then
        Rem.safe(function(...) npc.z:Say(getText(textKey, ...)) end, ...)
    end
end

Rem.NAMES = {
    "Ana", "Bruno", "Carla", "Diego", "Elisa", "Fabio", "Gabriela", "Heitor", "Iara", "Joao",
    "Karen", "Lucas", "Marina", "Nelson", "Olivia", "Pedro", "Raquel", "Sergio", "Tania", "Vitor",
    "Bill", "Kate", "Marcus", "Tess", "Dwight", "Rosa", "Hank", "Jill", "Owen", "Wendy",
}

-- Equipamento inicial. wtype escolhe o conjunto de animacoes (ver AnimSets).
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

function Rem.pick(list)
    return list[ZombRand(#list) + 1]
end

Events.OnInitGlobalModData.Add(function(isNewGame)
    local store = Rem.getStore()
    Rem.log("v" .. Rem.VERSION .. " carregado. Sobreviventes registrados: " .. Rem.recordCount())
end)
