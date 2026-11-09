-- Remanescentes - criacao, ativacao, restauracao e remocao de sobreviventes.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

-- Liga o "modo humano" num IsoZombie. Chamado no spawn e quando o chunk recarrega.
function Rem.activate(zombie, rec, key)
    if Rem.active[zombie] then return Rem.active[zombie] end

    zombie:setUseless(true)        -- desliga visao/audicao/perseguicao de zumbi
    zombie:setNoTeeth(true)        -- nao morde
    zombie:setTarget(nil)
    zombie:setVariable("RemNPC", true)
    zombie:setVariable("RemWeapon", rec.wtype or "1h")
    zombie:setVariable("RemAttack", false)
    zombie:setAvoidDamage(not Rem.cfg("FriendlyFire", false))

    if rec.item then
        local item = instanceItem(rec.item)
        if item then
            zombie:setPrimaryHandItem(item)
            -- solta a arma ao morrer
            zombie:clearItemsToSpawnAtDeath()
            zombie:addItemToSpawnAtDeath(instanceItem(rec.item))
        end
    end
    zombie:resetModelNextFrame()

    local npc = {
        z = zombie,
        key = key,
        rec = rec,
        nextThink = 0,
        nextPath = 0,
        nextAggro = 0,
        attackUntil = 0,
        hitAt = 0,
        attackTarget = nil,
        nextAttack = 0,
        lastPathX = nil, lastPathY = nil,
        lastSay = 0,
    }
    Rem.active[zombie] = npc
    Rem.activeCount = Rem.activeCount + 1
    Rem.debug("ativado " .. tostring(rec.name) .. " key=" .. key)
    return npc
end

function Rem.deactivate(zombie)
    if Rem.active[zombie] then
        Rem.active[zombie] = nil
        Rem.activeCount = math.max(0, Rem.activeCount - 1)
    end
end

-- Cria um sobrevivente novo no quadrado (x, y, z).
-- opts: { item=, wtype=, outfit=, mode="follow"|"stay"|"wander", name= }
function Rem.spawn(x, y, z, opts)
    if not Rem.isAuthority() then return nil end
    opts = opts or {}
    local loadout = Rem.pick(Rem.LOADOUTS)
    if opts.item then loadout = { item = opts.item, wtype = opts.wtype or "1h" } end
    local outfit = opts.outfit or Rem.pick(Rem.OUTFITS)

    local list = addZombiesInOutfit(math.floor(x), math.floor(y), math.floor(z), 1, outfit, 50,
        false, false, false, false, false, false, Rem.cfg("NPCHealth", 3.0))
    if not list or list:size() == 0 then
        Rem.log("falha ao criar sobrevivente em " .. x .. "," .. y)
        return nil
    end
    local zombie = list:get(0)
    zombie:setHealth(Rem.cfg("NPCHealth", 3.0))

    local key = Rem.keyOf(zombie)
    local rec = {
        name = opts.name or Rem.pick(Rem.NAMES),
        item = loadout.item,
        wtype = loadout.wtype,
        mode = opts.mode or "wander",
        homeX = math.floor(x), homeY = math.floor(y), homeZ = math.floor(z),
        maxHealth = Rem.cfg("NPCHealth", 3.0),
        created = getGameTime():getWorldAgeHours(),
    }
    Rem.setRecord(key, rec)
    local npc = Rem.activate(zombie, rec, key)
    Rem.say(npc, "IGUI_Rem_SayHello")
    Rem.log("criado " .. rec.name .. " (" .. outfit .. ", " .. rec.item .. ") em " .. x .. "," .. y .. " key=" .. key)
    return npc
end

-- Remove do mundo sem deixar corpo (debug).
function Rem.dismiss(npc)
    if not npc then return end
    local zombie = npc.z
    Rem.removeRecord(npc.key)
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
    Rem.getStore().npcs = {}
    Rem.log("todos os sobreviventes removidos")
end

-- ---------------------------------------------------------------- restauracao apos load
-- Quando um chunk carrega, o zumbi volta como zumbi comum. Reconhecemos pelo
-- persistentOutfitID e religamos o modo humano. Cada zumbi e checado so uma vez.
local checked = {}
local checkedCount = 0

local function onZombieUpdate(zombie)
    if Rem.active[zombie] or checked[zombie] then return end
    checked[zombie] = true
    checkedCount = checkedCount + 1
    if not Rem.isAuthority() then return end
    local key = Rem.keyOf(zombie)
    local rec = Rem.getRecord(key)
    if rec and not zombie:isDead() then
        Rem.activate(zombie, rec, key)
        Rem.debug("restaurado " .. tostring(rec.name))
    end
end
Events.OnZombieUpdate.Add(onZombieUpdate)

-- Zumbis sao reciclados pelo jogo; limpamos o cache de vez em quando.
Events.EveryTenMinutes.Add(function()
    if checkedCount > 2000 then
        checked = {}
        checkedCount = 0
    end
end)

-- ---------------------------------------------------------------- morte
Events.OnZombieDead.Add(function(zombie)
    local npc = Rem.active[zombie]
    if not npc then return end
    Rem.log((npc.rec.name or "?") .. " morreu")
    local player = getPlayer()
    if player and Rem.dist(player, zombie) < 30 then
        player:Say(getText("IGUI_Rem_Died", npc.rec.name or "?"))
    end
    Rem.removeRecord(npc.key)
    Rem.deactivate(zombie)
end)

-- ---------------------------------------------------------------- spawn aleatorio
local function findSpawnSquare(player)
    local cell = getCell()
    for _ = 1, 20 do
        local ang = ZombRandFloat(0, 6.283)
        local d = ZombRand(25, 40)
        local x = math.floor(player:getX() + math.cos(ang) * d)
        local y = math.floor(player:getY() + math.sin(ang) * d)
        local sq = cell:getGridSquare(x, y, 0)
        if sq and sq:isOutside() and sq:isSolidFloor() and sq:isFree(false) then
            return sq
        end
    end
    return nil
end

Events.EveryTenMinutes.Add(function()
    if not Rem.isAuthority() or isServer() then return end -- MP: fase futura
    local chance = Rem.cfg("SpawnChance", 5)
    if chance <= 0 or Rem.recordCount() >= Rem.cfg("MaxActive", 8) then return end
    if ZombRand(100) >= chance then return end
    local player = getPlayer()
    if not player or player:isDead() then return end
    local sq = findSpawnSquare(player)
    if sq then
        Rem.spawn(sq:getX(), sq:getY(), sq:getZ(), { mode = "wander" })
    end
end)
