-- Remanescentes - ordens de combate para quem anda com voce.
--
-- Postura (rec.stance), pela conversa ("[Combate] ...") ou para todos (clique direito):
--   normal      decide sozinho (o padrao)
--   hold        segurar fogo: nao atira, nao vai atras de ninguem; so se defende de quem
--               esta colado nele
--   aggressive  atacar a vontade: vai atras de todo zumbi a vista (mais longe de voce)
--   retreat     recuar para a base: corre para a sua base sem parar para brigar (so
--               reage encurralado). Chegando la, fica esperando.
-- Alvo marcado: clique direito num zumbi (ou num hostil) -> "Aliados: ataquem este!". Por
-- FOCUS_MS, quem segue voce larga o resto e vai nele.
-- Prisioneiros (Rem_Prisoners) nunca brigam: fogem de zumbi colado.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Commands"
local Rem = Remanescentes

local OR = Rem.module("Orders", {
    STANCES = { "normal", "hold", "aggressive" },
    FOCUS_MS = 20000,
    FOCUS_RANGE = 25,
    HOLD_CLOSE = 1.8,         -- segurando fogo: so reage a quem estiver colado
    RETREAT_PRIORITY = 90,    -- antes de seguir voce (100)
    RETREAT_ARRIVE = 4,
    PRISONER_FLEE = 4,
})
local CFG = OR.CFG

Rem.BARKS.stance_hold = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.stance_aggressive = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.stance_normal = { urgent = true, n = 2, cd = 0 }
Rem.BARKS.retreat = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.retreat_done = { urgent = true, n = 2, cd = 0 }
Rem.BARKS.focus = { urgent = true, n = 3, cd = 0 }

local function line(key, ...) return { key = key, args = { ... } } end

-- Quem segue voce (nao mora na base, nao esta preso).
function OR.isFollower(npc)
    local rec = npc.rec
    return rec.faction == "aliados" and not rec.groupId and not rec.prisoner and Rem.isFriendly(npc)
end

function OR.followers()
    local out = {}
    for _, npc in pairs(Rem.active) do if OR.isFollower(npc) then table.insert(out, npc) end end
    table.sort(out, function(a, b) return tostring(a.rec.id) < tostring(b.rec.id) end)
    return out
end

function OR.stanceOf(rec) return rec.stance or "normal" end

-- ---------------------------------------------------------------- postura
function OR.setStance(npc, stance)
    local rec = npc.rec
    rec.stance = (stance ~= "normal") and stance or nil
    if stance ~= "retreat" then rec.retreating = nil end
    Rem.bark(npc, "stance_" .. stance, true)
    return true
end

local function base()
    return Rem.PlayerBase and Rem.PlayerBase.get() or nil
end

function OR.canRetreat() return base() ~= nil end

function OR.retreat(npc)
    local g = base()
    if not g then return false, line("IGUI_Rem_Base_none") end
    npc.rec.stance = "retreat"
    npc.rec.retreating = true
    Rem.bark(npc, "retreat", true)
    return true, line("IGUI_Rem_Order_retreat")
end

-- Ordem para todos os que seguem voce. Retorna quantos.
function OR.orderAll(stance)
    local n = 0
    for _, npc in ipairs(OR.followers()) do
        if stance == "retreat" then
            if OR.retreat(npc) then n = n + 1 end
        elseif OR.stanceOf(npc.rec) ~= stance then
            OR.setStance(npc, stance)
            n = n + 1
        end
    end
    return n
end

-- Opcoes de conversa "order_stance_*" / "order_retreat". Retorna ok, fala.
function OR.order(id, npc)
    if id == "order_retreat" then return OR.retreat(npc) end
    local stance = id:sub(14)      -- (depois de "order_stance_")
    OR.setStance(npc, stance)
    return true, line("IGUI_Rem_Order_stance_" .. stance)
end

-- Botoes de combate da conversa (para quem segue voce).
function OR.dialogOptions(npc)
    local out = {}
    local cur = OR.stanceOf(npc.rec)
    for _, s in ipairs(CFG.STANCES) do
        if s ~= cur then table.insert(out, "order_stance_" .. s) end
    end
    if OR.canRetreat() and cur ~= "retreat" then table.insert(out, "order_retreat") end
    return out
end

-- ---------------------------------------------------------------- alvo marcado
OR.focus = nil

local function alive(obj)
    local ok, res = pcall(function() return not obj:isDead() and obj:isExistInTheWorld() end)
    return ok and res
end

function OR.isFocus(obj)
    local f = OR.focus
    return f ~= nil and obj ~= nil and f.obj == obj and Rem.nowMs() < f.untilMs
end

function OR.attack(target, now)
    now = now or Rem.nowMs()
    OR.focus = { obj = target, untilMs = now + CFG.FOCUS_MS }
    local list = OR.followers()
    if list[1] then Rem.bark(list[1], "focus", true) end
    for _, npc in ipairs(list) do
        if OR.stanceOf(npc.rec) == "hold" or OR.stanceOf(npc.rec) == "retreat" then OR.setStance(npc, "normal") end
    end
    return #list
end

-- ---------------------------------------------------------------- filtro do cerebro
-- Chamado pelo Rem.think depois de achar o inimigo. Retorna inimigo, distancia, fugir?
function OR.filter(npc, enemy, d, now)
    local rec = npc.rec
    -- prisioneiro: nunca briga; foge de zumbi colado
    if rec.prisoner then
        if enemy and not Rem.active[enemy] and not Rem.isPlayerObj(enemy) and d <= CFG.PRISONER_FLEE then
            return enemy, d, true
        end
        return nil, nil, false
    end
    if not OR.isFollower(npc) then return enemy, d, false end
    -- alvo marcado por voce
    local f = OR.focus
    if f then
        if now >= f.untilMs or not alive(f.obj) then
            OR.focus = nil
        else
            local fd = Rem.dist(npc.z, f.obj)
            if fd <= CFG.FOCUS_RANGE and math.floor(f.obj:getZ()) == math.floor(npc.z:getZ()) then
                -- (quem esta colado nele continua se defendendo primeiro)
                if not enemy or d > CFG.HOLD_CLOSE or enemy == f.obj then return f.obj, fd, false end
            end
        end
    end
    local stance = OR.stanceOf(rec)
    if stance == "hold" or stance == "retreat" then
        if not enemy then return nil, nil, false end
        local close = d <= CFG.HOLD_CLOSE or npc.lastAttacker ~= nil and npc.lastAttacker.z == enemy
        if close and d <= Rem.reach(npc) + 0.5 then return enemy, d, false end
        return nil, nil, false
    end
    return enemy, d, false
end

-- ---------------------------------------------------------------- recuar
function OR.retreatBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.stance ~= "retreat" then return false end
    local g = base()
    if not g or rec.groupId or rec.prisoner then
        rec.stance, rec.retreating = nil, nil
        return false
    end
    local h = g.home
    local d = Rem.distXY(npc.z, h.x, h.y)
    local inside = h.x1 and npc.z:getX() >= h.x1 and npc.z:getX() <= h.x2 and npc.z:getY() >= h.y1 and npc.z:getY() <= h.y2
    if inside or d <= CFG.RETREAT_ARRIVE then
        rec.stance, rec.retreating = nil, nil
        Rem.Commands.setMode(npc, "stay")
        Rem.bark(npc, "retreat_done", true)
        return true
    end
    Rem.moveTo(npc, h.x, h.y, h.z or 0, now, "run")
    return true
end
Rem.registerBehavior({ name = "retreat", priority = CFG.RETREAT_PRIORITY, run = OR.retreatBehavior })

-- Quem recuava e saiu de cena no caminho: chegou na base e espera la.
function OR.hourly()
    local g = base()
    for _, rec in pairs(Rem.getStore().people) do
        if rec.stance == "retreat" and not rec.onScene then
            rec.stance, rec.retreating = nil, nil
            if g then
                rec.x, rec.y, rec.z = g.home.x + ZombRandFloat(-1, 1), g.home.y + ZombRandFloat(-1, 1), 0
                rec.homeX, rec.homeY, rec.homeZ = math.floor(rec.x), math.floor(rec.y), 0
                rec.mode, rec.pid = "stay", nil
            end
        end
    end
end
Rem.on("worldHour", function() Rem.safe(OR.hourly) end)

-- ---------------------------------------------------------------- menus
local function hasFollowers() return #OR.followers() > 0 end
Rem.registerPlayerOption("ContextMenu_Rem_AllHold", function() OR.orderAll("hold") end, hasFollowers)
Rem.registerPlayerOption("ContextMenu_Rem_AllAggressive", function() OR.orderAll("aggressive") end, hasFollowers)
Rem.registerPlayerOption("ContextMenu_Rem_AllNormal", function() OR.orderAll("normal") end, hasFollowers)
Rem.registerPlayerOption("ContextMenu_Rem_AllRetreat", function() OR.orderAll("retreat") end, function()
    return hasFollowers() and OR.canRetreat()
end)
Rem.registerTargetOption("ContextMenu_Rem_AttackThis", function(target) OR.attack(target) end, function() return hasFollowers() end)
Rem.registerNpcOption("ContextMenu_Rem_AttackThis", function(npc) OR.attack(npc.z) end, function(npc)
    return Rem.isHostileToPlayer(npc) and not npc.rec.surrendered and hasFollowers()
end)
