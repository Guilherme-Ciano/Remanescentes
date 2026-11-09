-- Remanescentes - pessoas e corpos: criar pessoa, dar corpo (materializar), tirar corpo
-- (desmaterializar), re-associar corpo apos load e tratar a morte.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Barks"
local Rem = Remanescentes

-- ---------------------------------------------------------------- pessoa (dados)
-- opts: name, faction, groupId, item, wtype, outfit, mode, stealth, x, y, z, hostileToPlayer
function Rem.newPerson(opts)
    opts = opts or {}
    local faction = opts.faction or "civis"
    local loadout = Rem.pick(Rem.LOADOUTS)
    if opts.item then loadout = { item = opts.item, wtype = opts.wtype or "1h" } end
    local maxH = Rem.cfg("NPCHealth", 3.0)
    local p = {
        id = Rem.newId("p"),
        name = opts.name or Rem.pick(Rem.NAMES),
        faction = faction,
        groupId = opts.groupId,
        item = loadout.item,
        wtype = loadout.wtype,
        outfit = opts.outfit or Rem.pick(Rem.factionDef(faction).outfits),
        mode = opts.mode or (opts.groupId and "group" or "wander"),
        stealth = opts.stealth == true,
        hostileToPlayer = opts.hostileToPlayer,
        x = opts.x, y = opts.y, z = opts.z or 0,
        homeX = math.floor(opts.x or 0), homeY = math.floor(opts.y or 0), homeZ = math.floor(opts.z or 0),
        maxHealth = maxH,
        hp = maxH,
        created = Rem.worldHours(),
        onScene = false,
    }
    Rem.getStore().people[p.id] = p
    return p
end

-- ---------------------------------------------------------------- aparencia
-- O jogo escolhe pele podre (M_ZedBody0X_levelN) para qualquer zumbi, a menos que
-- skinTextureName esteja definido. Peles humanas: MaleBody01..05 / FemaleBody01..05.
function Rem.applyHumanLook(zombie, rec)
    if rec.female == nil then rec.female = zombie:isFemale() end
    if not rec.skin then
        rec.skin = (rec.female and "FemaleBody0" or "MaleBody0") .. tostring(ZombRand(1, 6))
    end
    local visual = zombie:getHumanVisual()
    visual:setSkinTextureName(rec.skin)
    visual:removeBlood()
    visual:removeDirt()
    local items = zombie:getItemVisuals()
    local parts = BloodBodyPartType.MAX:index()
    for i = 0, items:size() - 1 do
        local iv = items:get(i)
        if iv then
            for p = 0, parts - 1 do
                local part = BloodBodyPartType.FromIndex(p)
                iv:setBlood(part, 0)
                iv:setDirt(part, 0)
            end
        end
    end
    zombie:resetModel()
end

-- ---------------------------------------------------------------- ativar um corpo
-- Liga o "modo humano" num IsoZombie para a pessoa rec.
function Rem.activate(zombie, rec)
    if Rem.active[zombie] then return Rem.active[zombie] end

    Rem.safe(Rem.applyHumanLook, zombie, rec)
    zombie:setUseless(true)        -- desliga visao/audicao/perseguicao de zumbi
    zombie:setNoTeeth(true)        -- nao morde
    zombie:setTarget(nil)
    zombie:setVariable("RemNPC", true)
    zombie:setVariable("RemWeapon", rec.wtype or "1h")
    zombie:setVariable("RemAttack", false)
    zombie:setVariable("RemHit", false)
    zombie:setVariable("RemRun", false)
    zombie:setVariable("RemSneak", rec.stealth == true)

    if rec.item then
        local item = instanceItem(rec.item)
        if item then
            zombie:setPrimaryHandItem(item)
            zombie:clearItemsToSpawnAtDeath()
            zombie:addItemToSpawnAtDeath(instanceItem(rec.item))
        end
    end
    zombie:setHealth(rec.hp or rec.maxHealth or Rem.cfg("NPCHealth", 3.0))
    zombie:resetModelNextFrame()

    rec.pid = zombie:getPersistentOutfitID()
    rec.onScene = true

    local npc = {
        z = zombie,
        key = rec.id,
        rec = rec,
        nextThink = 0, nextPath = 0, nextAggro = 0,
        attackUntil = 0, hitAt = 0, attackTarget = nil, nextAttack = 0,
        hitUntil = 0,
        lastPathX = nil, lastPathY = nil,
        lastSay = 0,
        running = false,
        sneaking = rec.stealth == true,
    }
    Rem.active[zombie] = npc
    Rem.activeCount = Rem.activeCount + 1
    Rem.applyFriendlyFire(npc)
    Rem.debug("ativado " .. tostring(rec.name) .. " (" .. tostring(rec.faction) .. ") id=" .. rec.id)
    return npc
end

-- Fogo amigo: amigos sao protegidos (a menos que o sandbox permita); hostis apanham.
function Rem.applyFriendlyFire(npc)
    local protect = Rem.isFriendly(npc) and not Rem.cfg("FriendlyFire", false)
    npc.z:setAvoidDamage(protect)
end

function Rem.deactivate(zombie)
    local npc = Rem.active[zombie]
    if npc then
        Rem.active[zombie] = nil
        Rem.activeCount = math.max(0, Rem.activeCount - 1)
        npc.rec.onScene = false
        if Rem.releaseHunters then Rem.releaseHunters(npc) end
    end
end

-- Salva o estado do corpo na pessoa (posicao, vida).
function Rem.syncRecord(npc)
    local z, rec = npc.z, npc.rec
    rec.x, rec.y, rec.z = z:getX(), z:getY(), z:getZ()
    rec.hp = z:getHealth()
end

-- ---------------------------------------------------------------- materializar
local function findFreeSquare(x, y, z)
    local cell = getCell()
    for r = 0, 4 do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local sq = cell:getGridSquare(math.floor(x) + dx, math.floor(y) + dy, z)
                    if sq and sq:isFree(false) then return sq end
                end
            end
        end
    end
    return nil
end

-- Da um corpo a pessoa, na posicao salva dela. Retorna npc ou nil.
function Rem.materialize(rec)
    if not Rem.isAuthority() or rec.onScene then return nil end
    local sq = findFreeSquare(rec.x, rec.y, math.floor(rec.z or 0))
    if not sq then return nil end
    local list = addZombiesInOutfit(sq:getX(), sq:getY(), sq:getZ(), 1, rec.outfit or "Generic01",
        rec.female == nil and 50 or (rec.female and 100 or 0),
        false, false, false, false, false, false, rec.hp or rec.maxHealth or 3.0)
    if not list or list:size() == 0 then
        Rem.log("falha ao materializar " .. tostring(rec.name))
        return nil
    end
    local npc = Rem.activate(list:get(0), rec)
    Rem.debug("materializado " .. rec.name .. " em " .. sq:getX() .. "," .. sq:getY())
    return npc
end

-- Tira o corpo (longe do jogador). A pessoa continua existindo no papel.
function Rem.dematerialize(npc)
    Rem.syncRecord(npc)
    local zombie = npc.z
    Rem.deactivate(zombie)
    npc.rec.pid = nil
    Rem.safe(function()
        zombie:removeFromWorld()
        zombie:removeFromSquare()
    end)
    Rem.debug("desmaterializado " .. tostring(npc.rec.name))
end

-- ---------------------------------------------------------------- criar (debug/eventos)
-- Cria pessoa + corpo ja no quadrado (x, y, z).
function Rem.spawn(x, y, z, opts)
    if not Rem.isAuthority() then return nil end
    opts = opts or {}
    opts.x, opts.y, opts.z = x, y, z
    local rec = Rem.newPerson(opts)
    local npc = Rem.materialize(rec)
    if not npc then
        Rem.removePerson(rec.id)
        return nil
    end
    Rem.bark(npc, "hello", true)
    Rem.log("criado " .. rec.name .. " (" .. rec.faction .. ", " .. rec.outfit .. ", " .. rec.item .. ") em " .. x .. "," .. y)
    return npc
end

-- Remove pessoa e corpo, sem deixar corpo no chao (debug).
function Rem.dismiss(npc)
    if not npc then return end
    local zombie = npc.z
    Rem.removePerson(npc.rec.id)
    Rem.deactivate(zombie)
    Rem.safe(function()
        zombie:removeFromWorld()
        zombie:removeFromSquare()
    end)
end

function Rem.dismissAll()
    local list = {}
    for _, npc in pairs(Rem.active) do table.insert(list, npc) end
    for _, npc in ipairs(list) do Rem.dismiss(npc) end
    local store = Rem.getStore()
    store.people = {}
    store.groups = {}
    -- seeded continua true: o mundo nao ressemeia na hora (so cresce pelo EveryDays)
    Rem.log("todas as pessoas e grupos removidos")
end

-- ---------------------------------------------------------------- re-associar apos load
-- Quem estava em cena ao salvar volta como zumbi comum no chunk. Reconhecemos pelo
-- persistentOutfitID (salvo em rec.pid) e religamos o modo humano. Cada zumbi e
-- checado uma vez so.
local checked = {}
local checkedCount = 0
local pidIndex = nil  -- [pid] = rec, reconstruido quando necessario

function Rem.invalidatePidIndex() pidIndex = nil end

local function getPidIndex()
    if not pidIndex then
        pidIndex = {}
        for _, rec in pairs(Rem.getStore().people) do
            if rec.pid and not rec.onScene then pidIndex[rec.pid] = rec end
        end
    end
    return pidIndex
end

function Rem.tryReclaim(zombie)
    local rec = getPidIndex()[zombie:getPersistentOutfitID()]
    if rec and not rec.onScene and not zombie:isDead() then
        pidIndex = nil
        Rem.activate(zombie, rec)
        Rem.debug("re-associado " .. tostring(rec.name))
        return true
    end
    return false
end

Events.OnZombieUpdate.Add(function(zombie)
    if Rem.active[zombie] or checked[zombie] then return end
    checked[zombie] = true
    checkedCount = checkedCount + 1
    if Rem.isAuthority() then Rem.tryReclaim(zombie) end
end)

Events.EveryTenMinutes.Add(function()
    if checkedCount > 2000 then
        checked = {}
        checkedCount = 0
    end
    pidIndex = nil
end)

-- ---------------------------------------------------------------- morte
Events.OnZombieDead.Add(function(zombie)
    local npc = Rem.active[zombie]
    if not npc then return end
    Rem.log((npc.rec.name or "?") .. " morreu")
    local player = getPlayer()
    if player and Rem.dist(player, zombie) < 30 and Rem.isFriendly(npc) then
        player:Say(getText("IGUI_Rem_Died", npc.rec.name or "?"))
    end
    Rem.deactivate(zombie)
    Rem.removePerson(npc.rec.id)
end)
