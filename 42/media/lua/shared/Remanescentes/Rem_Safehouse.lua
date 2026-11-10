-- Remanescentes - Fase 4: safehouses de verdade.
--
-- Quando a casa de um grupo carrega perto do jogador (uma vez por grupo):
--   * barrica POR DENTRO parte das janelas e portas externas (mais em sobreviventes/
--     saqueadores, menos em civis), deixa uma porta principal fechada e trancada;
--   * guarda um estoque real (comida/agua/remedio) em ate 3 conteineres da casa, na
--     proporcao dos suprimentos do grupo, e marca o resto da casa como ja saqueado
--     (eles moram ali e consumiram o que tinha);
--   * empilha corpos de zumbis do lado de fora (sinal de que tem gente viva ali);
-- Em cena:
--   * a noite os moradores ficam DENTRO da casa (comportamento "home_indoors") e ha
--     luz acesa la dentro (luz de runtime, nao vai para o save);
--   * sobrevivente travado numa porta fechada abre a porta (corpos sao zumbis, que nao
--     abrem portas sozinhos); moradores tem a chave da propria casa.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_World"
require "Remanescentes/Rem_Brain"
local Rem = Remanescentes

Rem.Safehouse = Rem.Safehouse or {}
local S = Rem.Safehouse

S.CFG = {
    PREPARE_RADIUS = 60,     -- prepara a casa quando o jogador chega a essa distancia
    PLANKS_MIN = 2,
    PLANKS_MAX = 4,
    STASH_CONTAINERS = 3,
    STASH_MIN_ITEMS = 2,
    STASH_MAX_ITEMS = 14,
    STUCK_MOVE = 0.3,        -- andou menos que isso desde a ultima checagem = travado
    DOOR_RADIUS = 1,         -- procura portas em volta do travado
    NIGHT_START = 20,
    NIGHT_END = 7,
    INDOOR_PRIORITY = 250,   -- entre "stay" (200) e a rotina do grupo (300)
    SLEEP_DIST = 1.3,        -- deita ao chegar a essa distancia do seu canto
}

-- fracao das aberturas externas barricadas, por faccao (+ENGINEER_BONUS se tiver engenheiro)
S.FORTIFY = { civis = 0.35, sobreviventes = 0.8, saqueadores = 0.7, aliados = 0.6, seita = 0.95, errantes = 0.3 }
S.ENGINEER_BONUS = 0.2

-- corpos de zumbi empilhados na frente: { min, max }
S.CORPSES = { civis = { 0, 2 }, sobreviventes = { 2, 5 }, saqueadores = { 1, 4 }, seita = { 3, 6 }, errantes = { 0, 1 } }

-- o que cada tipo de grupo guarda (coerente com quem mora ali)
S.STASH = {
    -- familias: comida enlatada, agua, remedios
    default = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedCorn", "Base.CannedChili", "Base.CannedPeas",
        "Base.Crackers", "Base.Cereal", "Base.Rice", "Base.Pasta", "Base.WaterRationCan", "Base.WaterRationCan",
        "Base.Bandage", "Base.Pills", "Base.PillsVitamins", "Base.Disinfectant", "Base.Matches" },
    -- milicia: armas e municao, alem de comida
    sobreviventes = { "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.308Bullets", "Base.Pistol", "Base.Shotgun",
        "Base.HuntingKnife", "Base.Machete", "Base.TinnedBeans", "Base.CannedChili", "Base.WaterRationCan",
        "Base.WaterRationCan", "Base.Bandage", "Base.Nails", "Base.Plank" },
    -- saqueadores: coisas roubadas e drogas
    saqueadores = { "Base.Wallet", "Base.Money", "Base.Money", "Base.Necklace_Gold", "Base.CigarettePack",
        "Base.CigarettePack", "Base.Whiskey", "Base.PillsBeta", "Base.PillsAntiDep", "Base.Crowbar",
        "Base.TinnedBeans", "Base.BeefJerky", "Base.Crisps", "Base.WaterRationCan" },
    -- seita: loot raro
    seita = { "Base.Antibiotics", "Base.Antibiotics", "Base.Katana", "Base.Necklace_Gold", "Base.HuntingRifle",
        "Base.308Bullets", "Base.Candle", "Base.Book", "Base.Rice", "Base.WaterRationCan", "Base.WaterRationCan" },
    -- errantes: pouco e leve
    errantes = { "Base.BeefJerky", "Base.Crackers", "Base.WaterRationCan", "Base.Bandage", "Base.Matches", "Base.HandTorch" },
}

-- ---------------------------------------------------------------- utilidades
local function hasRect(h)
    return h and h.x1 ~= nil
end

-- Os quadrados da casa ja existem? (cantos e centro)
function S.isLoaded(h)
    if not hasRect(h) then return false end
    local cell = getCell()
    local z = h.z or 0
    return cell:getGridSquare(h.x1, h.y1, z) ~= nil and cell:getGridSquare(h.x2 - 1, h.y2 - 1, z) ~= nil
        and cell:getGridSquare(math.floor(h.x), math.floor(h.y), z) ~= nil
end

-- Chama fn(sq) para cada quadrado do retangulo (com 1 tile de folga: portas e janelas
-- externas podem pertencer ao quadrado de fora).
function S.forEachSquare(h, z, fn)
    local cell = getCell()
    for x = h.x1 - 1, h.x2 do
        for y = h.y1 - 1, h.y2 do
            local sq = cell:getGridSquare(x, y, z)
            if sq then fn(sq) end
        end
    end
end

local function objectsOf(sq)
    local out = {}
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do table.insert(out, objs:get(i)) end
    return out
end

-- Rem.safe devolve so "ok"; aqui queremos o resultado da funcao (nil se deu erro).
local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then Rem.log("ERRO: " .. tostring(res)) return nil end
    return res
end

local function hasEngineer(g)
    local people = Rem.getStore().people
    for _, id in ipairs(g.members) do
        local p = people[id]
        if p and p.archetype == "engenheiro" then return true end
    end
    return false
end

local function isInside(sq)
    return sq ~= nil and sq:getRoom() ~= nil
end

-- ---------------------------------------------------------------- barricadas
-- Barricada do lado de DENTRO: o jogo (IsoDoor.addRandomBarricades) usa
-- AddBarricadeToObject(obj, addOpposite) com addOpposite=true quando o lado de fora e o
-- quadrado oposto. Aqui fazemos o contrario: se o quadrado do objeto e interno, a
-- barricada fica nele (false); senao, no oposto (true).
function S.barricadeInside(obj, planks)
    if obj:isBarricaded() or not obj:isBarricadeAllowed() then return false end
    local addOpposite = not isInside(obj:getSquare())
    local b = IsoBarricade.AddBarricadeToObject(obj, addOpposite)
    if not b then return false end
    for _ = 1, planks do
        if b:canAddPlank() then b:addPlank(nil, nil) end
    end
    return true
end

local function closeDoor(door)
    if door:IsOpen() then door:ToggleDoorSilent() end
end

-- Barrica e tranca a casa do grupo. Retorna { windows=, doors=, locked= }.
-- ---------------------------------------------------------------- casas de saves antigos
-- Grupos criados antes da 0.3.1 nao tem o retangulo da casa. Recupera pelo ID do predio
-- (bid) ou pelo predio que esta na posicao da casa. Serve tambem para alvos de saque.
function S.defForBid(bid)
    if not bid then return nil end
    local list = getWorld():getMetaGrid():getBuildings()
    for i = 0, list:size() - 1 do
        local d = list:get(i)
        if tostring(d:getID()) == tostring(bid) then return d end
    end
    return nil
end

function S.fillRect(t)
    if not t or t.x1 then return t ~= nil and t.x1 ~= nil end
    local def = S.defForBid(t.bid)
    if not def then
        local ok, d = pcall(function() return getWorld():getMetaGrid():getBuildingAt(math.floor(t.x), math.floor(t.y)) end)
        if ok then def = d end
    end
    if not def then return false end
    t.bid = t.bid or tostring(def:getID())
    t.x1, t.y1 = def:getX(), def:getY()
    t.x2, t.y2 = def:getX() + def:getW(), def:getY() + def:getH()
    return true
end

-- Tira a barricada (dos dois lados) de uma porta: a entrada nunca pode ficar fechada com
-- tabuas (casas barricadas pelo proprio jogo vem assim).
function S.unbarricade(obj)
    local removed = 0
    -- (nao usar ipairs: o primeiro lado pode ser nil e o ipairs pararia ali)
    local sides = { obj:getBarricadeOnSameSquare(), obj:getBarricadeOnOppositeSquare() }
    for i = 1, 2 do
        local b = sides[i]
        if b then
            local sq = b:getSquare()
            if sq then sq:transmitRemoveItemFromSquare(b) removed = removed + 1 end
        end
    end
    return removed
end

-- Os moradores limparam a casa: zumbis comuns dentro dela somem.
function S.clearZombiesInside(h)
    local list = getCell():getZombieList()
    local gone = {}
    for i = 0, list:size() - 1 do
        local zb = list:get(i)
        if not Rem.active[zb] and not zb:isDead() then
            local x, y = zb:getX(), zb:getY()
            if x >= h.x1 and x < h.x2 and y >= h.y1 and y < h.y2 then table.insert(gone, zb) end
        end
    end
    for _, zb in ipairs(gone) do
        Rem.safe(function() zb:removeFromWorld() zb:removeFromSquare() end)
    end
    return #gone
end

function Rem.fortifyHome(g)
    local h = g.home
    local res = { windows = 0, doors = 0, locked = 0 }
    if not hasRect(h) then return res end
    local frac = S.FORTIFY[g.faction] or 0.5
    local extraPlank = 0
    if hasEngineer(g) then
        frac = math.min(1, frac + S.ENGINEER_BONUS)
        extraPlank = 1
    end
    local windows, doors, seen = {}, {}, {}
    for z = 0, 1 do
        S.forEachSquare(h, z, function(sq)
            for _, obj in ipairs(objectsOf(sq)) do
                if not seen[obj] then
                    seen[obj] = true
                    if instanceof(obj, "IsoWindow") and obj:isExterior() then
                        table.insert(windows, obj)
                    elseif instanceof(obj, "IsoDoor") and obj:isExterior() then
                        table.insert(doors, obj)
                    end
                end
            end
        end)
    end
    local function planks() return math.min(4, ZombRand(S.CFG.PLANKS_MIN, S.CFG.PLANKS_MAX + 1) + extraPlank) end
    -- entrada: SEMPRE fica uma passagem. A porta externa mais ao sul e a principal (fechada,
    -- trancada, nunca barricada; moradores tem a chave). Sem porta externa, a janela mais
    -- ao sul fica sem tabuas.
    -- prefere porta sem tabuas; entre iguais, a mais ao sul
    table.sort(doors, function(a, b)
        local ab, bb = a:isBarricaded(), b:isBarricaded()
        if ab ~= bb then return not ab end
        return a:getSquare():getY() > b:getSquare():getY()
    end)
    if doors[1] and doors[1]:isBarricaded() then
        res.unbarricaded = try(S.unbarricade, doors[1])
    end
    res.cleared = try(S.clearZombiesInside, h) or 0
    local entranceWindow = nil
    if #doors == 0 and #windows > 0 then
        table.sort(windows, function(a, b) return a:getSquare():getY() > b:getSquare():getY() end)
        entranceWindow = windows[1]
        if entranceWindow:isBarricaded() then try(S.unbarricade, entranceWindow) end
        local sq = entranceWindow:getSquare()
        h.entrance = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), window = true }
    end
    for _, w in ipairs(windows) do
        if w ~= entranceWindow and ZombRandFloat(0, 1) < frac and try(S.barricadeInside, w, planks()) then
            res.windows = res.windows + 1
        end
    end
    for i, d in ipairs(doors) do
        Rem.safe(closeDoor, d)
        if i == 1 then
            local sq = d:getSquare()
            h.mainDoor = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
            h.entrance = h.mainDoor
            Rem.safe(function() d:setLocked(S.locksOut(g)) end)
            res.locked = res.locked + 1
        elseif ZombRandFloat(0, 1) < frac and try(S.barricadeInside, d, planks()) then
            res.doors = res.doors + 1
        else
            Rem.safe(function() d:setLocked(true) end)
            res.locked = res.locked + 1
        end
    end
    res.corpses = S.pileCorpses(g)
    h.fortified = true
    Rem.emit("homeFortified", g, res)
    Rem.debug(string.format("casa do grupo %s preparada: %d janelas, %d portas barricadas, %d trancadas, %d corpos, %d zumbis tirados de dentro",
        g.id, res.windows, res.doors, res.locked, res.corpses, res.cleared or 0))
    return res
end

-- Corpos de zumbis que os moradores mataram, empilhados uns 4 tiles para fora da porta
-- principal (ou do lado sul da casa).
function S.pileCorpses(g)
    local range = S.CORPSES[g.faction] or { 0, 2 }
    local n = ZombRand(range[1], range[2] + 1)
    if n <= 0 then return 0 end
    local h = g.home
    local bx, by
    if h.mainDoor then bx, by = h.mainDoor.x, h.mainDoor.y + 4
    else bx, by = math.floor((h.x1 + h.x2) / 2), h.y2 + 4 end
    local cell = getCell()
    local made = 0
    for i = 1, n do
        local sq = cell:getGridSquare(bx + ZombRand(-1, 2), by + ZombRand(-1, 2), 0)
        if sq and not sq:getRoom() and try(function() createRandomDeadBody(sq, 5) return true end) then
            made = made + 1
        end
    end
    return made
end

-- ---------------------------------------------------------------- estoque
local function stashScore(c)
    local t = c:getType() or ""
    if t == "fridge" or t == "freezer" then return 3 end
    if t == "counter" or t == "shelves" or t == "crate" or t == "wardrobe" then return 2 end
    return 1
end

-- Guarda suprimentos de verdade nos conteineres da casa. Retorna quantos itens.
function Rem.stockHome(g)
    local h = g.home
    if not hasRect(h) then return 0 end
    local found = {}
    S.forEachSquare(h, h.z or 0, function(sq)
        if isInside(sq) then
            for _, obj in ipairs(objectsOf(sq)) do
                local n = obj:getContainerCount()
                for i = 0, n - 1 do
                    local c = obj:getContainerByIndex(i)
                    if c then table.insert(found, { c = c, sq = sq, score = stashScore(c) + ZombRandFloat(0, 1) }) end
                end
            end
        end
    end)
    table.sort(found, function(a, b) return a.score > b.score end)
    local total = math.floor((g.supplies or 0) * Rem.World.CFG.ITEMS_PER_SUPPLY)
    total = math.max(S.CFG.STASH_MIN_ITEMS, math.min(S.CFG.STASH_MAX_ITEMS, total))
    local list = S.STASH[g.faction] or S.STASH.default
    local used = math.min(#found, S.CFG.STASH_CONTAINERS)
    h.stash = {}
    local added = 0
    if used > 0 then
        for k = 1, total do
            local slot = found[((k - 1) % used) + 1]
            if try(function() return slot.c:AddItem(list[ZombRand(#list) + 1]) ~= nil end) then added = added + 1 end
        end
        for i = 1, used do
            local slot = found[i]
            Rem.safe(function() slot.c:setExplored(true) end)  -- o jogo nao gera loot por cima
            table.insert(h.stash, { x = slot.sq:getX(), y = slot.sq:getY(), z = slot.sq:getZ(), type = slot.c:getType() })
        end
    end
    -- o resto da casa: moradores ja consumiram (OnFillContainer esvazia predios "saqueados")
    if h.bid then Rem.getStore().looted[h.bid] = Rem.worldHours() end
    h.stocked = true
    Rem.debug("estoque do grupo " .. g.id .. ": " .. added .. " itens em " .. used .. " conteineres")
    return added
end

-- Conteineres do estoque da casa (nil se algum quadrado ainda nao carregou).
function S.stashContainers(h)
    if not h or not h.stash then return nil end
    local cell = getCell()
    local out = {}
    for _, st in ipairs(h.stash) do
        local sq = cell:getGridSquare(st.x, st.y, st.z)
        if not sq then return nil end
        for _, obj in ipairs(objectsOf(sq)) do
            for c = 0, obj:getContainerCount() - 1 do
                local cont = obj:getContainerByIndex(c)
                if cont and cont:getType() == st.type then table.insert(out, cont) break end
            end
        end
    end
    return out
end

function S.stashCount(h)
    local list = S.stashContainers(h)
    if not list then return nil end
    local n = 0
    for _, c in ipairs(list) do n = n + c:getItems():size() end
    return n
end

-- Prepara (uma vez) as casas carregadas perto do jogador.
function Rem.prepareHomesNear(player)
    if not Rem.cfg("FortifyHomes", true) then return end
    local px, py = player:getX(), player:getY()
    for _, g in pairs(Rem.getStore().groups) do
        local h = g.home
        if h and not h.x1 and Rem.dist2(px, py, h.x, h.y) < S.CFG.PREPARE_RADIUS then S.fillRect(h) end
        if hasRect(h) and not (h.fortified and h.stocked)
            and Rem.dist2(px, py, h.x, h.y) < S.CFG.PREPARE_RADIUS and S.isLoaded(h) then
            if not h.fortified then Rem.safe(Rem.fortifyHome, g) end
            if not h.stocked then Rem.safe(Rem.stockHome, g) end
            h.fortified, h.stocked = true, true
        end
    end
end

-- ---------------------------------------------------------------- portas
local function residentOf(npc, sq)
    local g = npc.rec.groupId and Rem.getStore().groups[npc.rec.groupId]
    if not g or not g.home or not g.home.bid then return false end
    local b = sq:getBuilding()
    local def = b and b:getDef()
    return def ~= nil and tostring(def:getID()) == g.home.bid
end

-- Abre portas fechadas em volta do sobrevivente. Tranca so abre para quem mora ali.
function Rem.openDoorsAround(npc)
    local z = npc.z
    local cell = getCell()
    local cx, cy, cz = math.floor(z:getX()), math.floor(z:getY()), math.floor(z:getZ())
    local r = S.CFG.DOOR_RADIUS
    local opened = 0
    for dx = -r, r do
        for dy = -r, r do
            local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
            if sq then
                for _, obj in ipairs(objectsOf(sq)) do
                    if instanceof(obj, "IsoDoor") and not obj:IsOpen() and not obj:isBarricaded() then
                        local locked = obj:isLocked() or obj:isLockedByKey()
                        if not locked or residentOf(npc, sq) then
                            if locked then obj:setLocked(false) end
                            obj:ToggleDoorSilent()
                            opened = opened + 1
                        end
                    end
                end
            end
        end
    end
    return opened
end

-- Chamado a cada atualizacao de cena: quem esta tentando andar e nao sai do lugar abre
-- a porta da frente.
function Rem.unstickNPCs()
    for _, npc in pairs(Rem.active) do
        local z = npc.z
        local x, y = z:getX(), z:getY()
        if Rem.isMoving(npc) and npc.stuckX and Rem.dist2(x, y, npc.stuckX, npc.stuckY) < S.CFG.STUCK_MOVE then
            Rem.safe(Rem.openDoorsAround, npc)
        end
        npc.stuckX, npc.stuckY = x, y
    end
end

-- ---------------------------------------------------------------- dentro de casa a noite
local function isNight()
    local tod = getGameTime():getTimeOfDay()
    return tod >= S.CFG.NIGHT_START or tod < S.CFG.NIGHT_END
end

-- Um quadrado livre e interno da casa, sorteado e guardado na pessoa.
function S.indoorSpot(rec, h)
    if rec.indoorSpot then return rec.indoorSpot end
    local cell = getCell()
    for _ = 1, 25 do
        local x = ZombRand(h.x1, h.x2)
        local y = ZombRand(h.y1, h.y2)
        local sq = cell:getGridSquare(x, y, h.z or 0)
        if sq and isInside(sq) and sq:isFree(false) then
            rec.indoorSpot = { x = x, y = y, z = h.z or 0 }
            return rec.indoorSpot
        end
    end
    return nil
end

function S.indoorsBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "group" then return false end
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if not g or g.activity ~= "home" or not hasRect(g.home) or not isNight() then
        rec.indoorSpot = nil
        if npc.rest == "sleep" then Rem.clearRest(npc) end   -- amanheceu: levanta
        return false
    end
    local spot = S.indoorSpot(rec, g.home)
    if not spot then return false end
    local d = Rem.dist2(npc.z:getX(), npc.z:getY(), spot.x + 0.5, spot.y + 0.5)
    if npc.rest == "sleep" then return true end              -- dormindo: fica quieto
    if d <= S.CFG.SLEEP_DIST and not Rem.isMoving(npc) then
        Rem.setRest(npc, "sleep")                            -- chegou no canto: deita
        return true
    end
    Rem.moveTo(npc, spot.x + 0.5, spot.y + 0.5, spot.z, now, Rem.baseGait(npc))
    return true
end

-- ---------------------------------------------------------------- porta principal
-- Moradores abrem a porta principal quando chegam perto dela andando, e fecham/trancam
-- depois que ninguem mais esta passando (e o jogador nao esta na porta).
S.CFG.DOOR_OPEN_DIST = 1.8
S.CFG.DOOR_CLOSE_DIST = 2.6
S.CFG.DOOR_CLOSE_AFTER_MS = 2500
S.CFG.DOOR_TICK_MS = 300
S.doorState = S.doorState or {}   -- [groupId] = { openedAt = ms } (runtime)

function S.findDoorAt(pos)
    if not pos then return nil end
    local sq = getCell():getGridSquare(pos.x, pos.y, pos.z or 0)
    if not sq then return nil end
    for _, obj in ipairs(objectsOf(sq)) do
        if instanceof(obj, "IsoDoor") then return obj end
    end
    return nil
end

-- A porta fica trancada para voce, a menos que o grupo seja amigavel com voce.
function S.locksOut(g)
    if not Rem.attitudeOf then return true end
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p then return Rem.attitudeOf(p) ~= "amigavel" end
    end
    return true
end

function S.manageDoors(now)
    local player = getPlayer()
    local groups = Rem.getStore().groups
    -- quem esta em cena, por grupo
    local byGroup = {}
    for _, npc in pairs(Rem.active) do
        local gid = npc.rec.groupId
        if gid and groups[gid] and groups[gid].home and groups[gid].home.mainDoor then
            byGroup[gid] = byGroup[gid] or {}
            table.insert(byGroup[gid], npc)
        end
    end
    for gid, list in pairs(byGroup) do
        local h = groups[gid].home
        local door = S.findDoorAt(h.mainDoor)
        if door and not door:isBarricaded() then
            local dx, dy = h.mainDoor.x + 0.5, h.mainDoor.y + 0.5
            local passing, near = false, false
            for _, npc in ipairs(list) do
                local d = Rem.dist2(npc.z:getX(), npc.z:getY(), dx, dy)
                -- so quem esta andando conta (o guarda parado do lado de dentro nao segura a porta)
                if Rem.isMoving(npc) then
                    if d <= S.CFG.DOOR_CLOSE_DIST then near = true end
                    if d <= S.CFG.DOOR_OPEN_DIST then passing = true end
                end
            end
            local st = S.doorState[gid] or {}
            S.doorState[gid] = st
            if passing and not door:IsOpen() then
                if door:isLocked() then door:setLocked(false) end
                door:ToggleDoorSilent()
                st.openedAt = now
            elseif door:IsOpen() and st.openedAt and not near
                and now - st.openedAt >= S.CFG.DOOR_CLOSE_AFTER_MS
                and not (player and Rem.dist2(player:getX(), player:getY(), dx, dy) <= 1.5) then
                door:ToggleDoorSilent()
                door:setLocked(S.locksOut(groups[gid]))
                st.openedAt = nil
            end
        end
    end
end

local nextDoorTick = 0
Events.OnTick.Add(function()
    if not Rem.isAuthority() or Rem.activeCount == 0 then return end
    local now = Rem.nowMs()
    if now < nextDoorTick then return end
    nextDoorTick = now + S.CFG.DOOR_TICK_MS
    Rem.safe(S.manageDoors, now)
end)

-- ---------------------------------------------------------------- luz a noite
S.lights = S.lights or {}   -- [groupId] = { x, y, z } (runtime)

local function groupHome(g)
    if g.activity ~= "home" then return false end
    for _, id in ipairs(g.members) do
        if Rem.getPerson(id) then return true end
    end
    return false
end

function S.updateLights(player)
    local px, py = player:getX(), player:getY()
    local night = isNight()
    local groups = Rem.getStore().groups
    for gid, g in pairs(groups) do
        local h = g.home
        local want = night and h and h.fortified and h.x1 and groupHome(g)
            and Rem.dist2(px, py, h.x, h.y) < S.CFG.PREPARE_RADIUS
        local cur = S.lights[gid]
        if want and not cur then
            local z = h.z or 0
            local x, y = math.floor(h.x), math.floor(h.y)
            local sq = getCell():getGridSquare(x, y, z)
            if sq and try(function() getCell():removeLamppost(x, y, z); getCell():addLamppost(x, y, z, 1.0, 0.8, 0.55, 7) return true end) then
                S.lights[gid] = { x = x, y = y, z = z }
            end
        elseif cur and not want then
            Rem.safe(function() getCell():removeLamppost(cur.x, cur.y, cur.z) end)
            S.lights[gid] = nil
        end
    end
    -- grupo que acabou
    for gid, cur in pairs(S.lights) do
        if not groups[gid] then
            Rem.safe(function() getCell():removeLamppost(cur.x, cur.y, cur.z) end)
            S.lights[gid] = nil
        end
    end
end

-- ---------------------------------------------------------------- ganchos
Rem.registerBehavior({ name = "home_indoors", priority = S.CFG.INDOOR_PRIORITY, run = S.indoorsBehavior })

Rem.on("sceneUpdate", function(player, now)
    Rem.prepareHomesNear(player)
    Rem.unstickNPCs()
    S.updateLights(player)
end)

Rem.registerDebugOption("ContextMenu_Rem_FortifyNearest", function(x, y, z, player)
    local g = Rem.nearestGroup(player:getX(), player:getY())
    if not g then return end
    g.home.fortified, g.home.stocked = false, false
    if S.isLoaded(g.home) then
        local r = Rem.fortifyHome(g)
        local n = Rem.stockHome(g)
        player:Say(string.format("%s: %d janelas, %d portas, %d itens", g.id, r.windows, r.doors, n))
    else
        player:Say("Casa do grupo " .. g.id .. " ainda nao carregou; chegue mais perto.")
    end
end)
