-- Remanescentes - Fase C4: mortalidade real (mordidos viram zumbis).
--
-- * Cada acerto de zumbi num sobrevivente (evento "zombieHitNPC") tem chance de infectar
--   (sandbox NPCInfectionChance). O infectado avisa ("Fui mordido..."), passa mal na metade
--   do tempo e VIRA ZUMBI de 2 a 12 horas depois: o corpo dele deixa de ser humano, com a
--   mesma roupa (voce reconhece quem era). Medico nao cura.
-- * Longe de voce, ele vira zumbi no lugar onde estava; o zumbi aparece quando voce chegar.
-- * Morto por zumbis: o corpo levanta como zumbi alguns segundos depois (mesma roupa).
-- Sandbox NPCsTurn desliga tudo isso.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
local Rem = Remanescentes

local IN = Rem.module("Infection", {
    TURN_HOURS = { 2, 12 },
    SICK_AT = 0.5,              -- fracao do tempo em que comeca a passar mal
    ZOMBIE_KILL_WINDOW_MS = 5000,
    REANIMATE_MS = { 20000, 60000 },
    SPAWN_RADIUS = 45,
})
local CFG = IN.CFG

Rem.BARKS.bitten = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.sick = { urgent = true, n = 3, cd = 0 }

local function enabled() return Rem.cfg("NPCsTurn", true) end

local function turnedList()
    local s = Rem.getStore()
    s.turned = s.turned or {}
    return s.turned
end

IN.pending = IN.pending or {}   -- corpos que vao levantar (runtime)

-- ---------------------------------------------------------------- infeccao
function IN.infect(rec, hours)
    if rec.infectedAt then return false end
    rec.infectedAt = hours or Rem.worldHours()
    rec.turnAfter = ZombRandFloat(CFG.TURN_HOURS[1], CFG.TURN_HOURS[2])
    return true
end

Rem.on("zombieHitNPC", function(npc, zombie, now)
    npc.zombieHitAt = now
    if not enabled() then return end
    if ZombRand(100) < Rem.cfg("NPCInfectionChance", 25) and IN.infect(npc.rec) then
        Rem.bark(npc, "bitten", true)
        Rem.debug(tostring(npc.rec.name) .. " foi infectado (vira em " .. string.format("%.1f", npc.rec.turnAfter) .. " h)")
    end
end)

-- ---------------------------------------------------------------- virar zumbi
local function zombieSkin(female)
    return (female and "F_ZedBody0" or "M_ZedBody0") .. tostring(ZombRand(1, 5)) .. "_level" .. tostring(ZombRand(1, 4))
end

-- Em cena: o corpo deixa de ser sobrevivente e vira um zumbi comum.
function IN.turnNow(npc)
    local z, rec = npc.z, npc.rec
    Rem.deactivate(z)
    Rem.safe(function()
        for _, v in ipairs({ "RemNPC", "RemAttack", "RemHit", "RemRun", "RemSneak", "RemAim", "RemShoot" }) do
            z:setVariable(v, false)
        end
        z:setVariable("RemRest", "")
        z:setVariable("RemGun", "")
        z:setPrimaryHandItem(nil)
        z:setAvoidDamage(false)
        z:setNoTeeth(false)
        z:setUseless(false)
        local visual = z:getHumanVisual()
        visual:setSkinTextureName(zombieSkin(rec.female))
        z:resetModel()
    end)
    Rem.debug(tostring(rec.name) .. " virou zumbi")
    Rem.removePerson(rec.id)
end

-- Fora de cena: vira zumbi no papel (aparece quando voce chegar perto).
function IN.turnOffscene(rec)
    table.insert(turnedList(), { x = rec.x, y = rec.y, z = rec.z or 0, outfit = rec.outfit, female = rec.female })
    Rem.debug(tostring(rec.name) .. " virou zumbi (fora de cena)")
    Rem.removePerson(rec.id)
end

local function activeOf(rec)
    for _, npc in pairs(Rem.active) do if npc.rec == rec then return npc end end
    return nil
end

function IN.update(hours)
    if not enabled() then return end
    local list = {}
    for _, rec in pairs(Rem.getStore().people) do
        if rec.infectedAt then table.insert(list, rec) end
    end
    for _, rec in ipairs(list) do
        local t = hours - rec.infectedAt
        local npc = activeOf(rec)
        if t >= rec.turnAfter then
            if npc then IN.turnNow(npc) else IN.turnOffscene(rec) end
        elseif t >= rec.turnAfter * CFG.SICK_AT and not rec.sick then
            rec.sick = true
            if npc then Rem.bark(npc, "sick", true) end
        end
    end
end

-- ---------------------------------------------------------------- zumbis "no papel" aparecem
local function spawnZombie(e)
    addZombiesInOutfit(math.floor(e.x), math.floor(e.y), math.floor(e.z or 0), 1, e.outfit or "Generic01",
        e.female == nil and 50 or (e.female and 100 or 0), false, false, false, false, false, false, 1.0)
end

function IN.spawnTurned(player)
    local list = turnedList()
    local px, py = player:getX(), player:getY()
    for i = #list, 1, -1 do
        local e = list[i]
        if Rem.dist2(px, py, e.x, e.y) < CFG.SPAWN_RADIUS
            and getCell():getGridSquare(math.floor(e.x), math.floor(e.y), math.floor(e.z or 0)) then
            Rem.safe(spawnZombie, e)
            table.remove(list, i)
        end
    end
end

-- ---------------------------------------------------------------- morto por zumbis
Rem.on("npcDied", function(npc)
    if not enabled() then return end
    if not npc.zombieHitAt or Rem.nowMs() - npc.zombieHitAt > CFG.ZOMBIE_KILL_WINDOW_MS then return end
    local z, rec = npc.z, npc.rec
    table.insert(IN.pending, { x = z:getX(), y = z:getY(), z = z:getZ(), outfit = rec.outfit, female = rec.female,
        at = Rem.nowMs() + ZombRand(CFG.REANIMATE_MS[1], CFG.REANIMATE_MS[2]) })
end)

local function removeCorpse(e)
    local sq = getCell():getGridSquare(math.floor(e.x), math.floor(e.y), math.floor(e.z or 0))
    if not sq then return false end
    local bodies = sq:getDeadBodys()
    for i = 0, bodies:size() - 1 do
        local b = bodies:get(i)
        if b and (not e.outfit or b:getOutfitName() == e.outfit) then
            sq:removeCorpse(b, false)
            return true
        end
    end
    return false
end

function IN.reanimatePending(now)
    for i = #IN.pending, 1, -1 do
        local e = IN.pending[i]
        if now >= e.at then
            table.remove(IN.pending, i)
            if removeCorpse(e) then
                Rem.safe(spawnZombie, e)
                Rem.debug("um corpo levantou como zumbi")
            elseif not getCell():getGridSquare(math.floor(e.x), math.floor(e.y), math.floor(e.z or 0)) then
                table.insert(turnedList(), e)     -- area descarregou: aparece depois
            end
        end
    end
end

-- ---------------------------------------------------------------- ganchos
Rem.on("worldHour", function(hour) Rem.safe(IN.update, Rem.worldHours()) end)
Rem.on("sceneUpdate", function(player, now)
    Rem.safe(IN.spawnTurned, player)
    Rem.safe(IN.reanimatePending, now)
end)
