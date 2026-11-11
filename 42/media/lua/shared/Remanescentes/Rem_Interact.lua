-- Remanescentes - Fase E: interacao com os sobreviventes (logica; a janela fica em
-- client/Remanescentes/Rem_DialogUI.lua).
--
-- E1 conversar  : resposta pela atitude/personalidade; como o grupo esta (do que precisa);
--                 onde fica outro grupo (direcao e distancia), se confiarem em voce.
-- E2 trocar     : seus itens x estoque do grupo (ou o que a pessoa carrega). Valor pela
--                 NECESSIDADE do grupo (ferido -> remedio vale mais; fome -> comida; pouca
--                 municao -> municao). Eles cobram uma margem que cai com a reputacao.
-- E3 abrigo     : com reputacao alta, voce pode ficar na casa deles uns dias (porta aberta
--                 para voce, sem aviso de territorio).
-- E4 recrutar   : lealdade + reputacao decidem; quem aceita vira seu aliado (segue voce).
--                 Comandos de seguidor: seguir, esperar, guardar posicao, saquear aqui,
--                 liberar.
-- E5 missoes    : buscar comida/remedio/municao, limpar zumbis da rua, achar alguem que
--                 sumiu. Recompensa: itens, reputacao ou a localizacao de outro grupo.
-- E6 ameacar    : com arma na mao. Medrosos entregam (reputacao despenca); corajosos
--                 reagem.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Reputation"
require "Remanescentes/Rem_Safehouse"
require "Remanescentes/Rem_Scavenge"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes

local IA = Rem.module("Interact", {
    TALK_HOLD_MS = 6000,      -- conversando: o NPC para e olha para voce por esse tempo
    TALK_PRIORITY = 30,
    INFO_RADIUS = 700,        -- grupos que ele conhece
    INFO_TRUST = 20,          -- reputacao para contar onde ficam outros grupos
    MARKUP = 1.25,            -- margem deles no inicio (cai com a reputacao)
    MARKUP_REP_DIVISOR = 400, -- rep 100 -> margem 1.0
    TRADE_REP = 2,
    SHELTER_REP = 50,
    SHELTER_HOURS = 72,
    JOIN_THRESHOLD = 95,      -- (0.12: era 60; quase todo mundo aceitava na primeira conversa)
    MAX_FOLLOWERS = 4,        -- quantos aliados seguem voce ao mesmo tempo
    JOIN_COOLDOWN_HOURS = 24,
    QUEST_REP = 15,
    QUEST_HOURS = 72,
    CLEAR_RADIUS = 25,
    CLEAR_COUNT = 8,
    LOST_DIST = { 80, 160 },
    THREAT_COURAGE = 4,       -- coragem ate isso: entrega
    THREAT_REP = -30,
    THREAT_FIGHT_REP = -15,
    THREAT_GIVE = 3,
    LOOT_PRIORITY = 110,
    GUARD_PRIORITY = 120,
    GIVE_DIST = 2.5,
    LOOT_MAX_MS = 150000,     -- seguidor saqueando: tempo maximo antes de voltar com o que achou
    LOOT_LEASH = 45,          -- voce se afastou isso: ele larga e volta
    GIFT_HOURS = 6,           -- um presente por pessoa a cada tantas horas
    GIFT_REP = 2,
    GIFT_BOND = { 4, 15 },    -- vinculo ganho: minimo e maximo (cresce com o valor do item)
    JOIN_BOND_WEIGHT = 1.5,   -- o que mais pesa: o que voce fez por ESTA pessoa
    ASK_BOND = 25,            -- vinculo para ele te dar algo quando voce pede
    ASK_REP = 50,             -- (ou reputacao alta com o grupo)
    ASK_HOURS = 24,
    ASK_COST = 5,             -- pedir gasta um pouco da boa vontade
    ASK_HURT_BELOW = 70,      -- sua saude abaixo disso: ele te da remedio; senao, comida
    MATERIALS_QUEST_BELOW = 4,
})
local CFG = IA.CFG

Rem.BARKS.deal = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.loot_nothing = { urgent = true, n = 2, cd = 0 }

-- ---------------------------------------------------------------- utilidades
local function groupOf(npc) return npc.rec.groupId and Rem.getStore().groups[npc.rec.groupId] end
local function membersOf(g)
    local out = {}
    for _, id in ipairs(g.members) do local p = Rem.getPerson(id) if p then table.insert(out, p) end end
    return out
end
local function activeOf(rec)
    for _, npc in pairs(Rem.active) do if npc.rec == rec then return npc end end
    return nil
end
local function line(key, ...) return { key = key, args = { ... } } end

-- ---------------------------------------------------------------- variedade e tom das falas
-- Cada resposta pode ter varias versoes (<chave>_1.._n, IA.VARIANTS) e um tom pela
-- personalidade: "cold" (agressivo/desconfiado) ou "scared" (medroso), quando existir
-- <chave>_cold / <chave>_scared. A escolha e feita uma vez por resposta (IA.finalize), para
-- o historico da conversa e o balao no mundo mostrarem a mesma frase.
IA.VARIANTS = {
    IGUI_Rem_Talk_hi_friendly = 4, IGUI_Rem_Talk_hi_neutral = 4, IGUI_Rem_Talk_hi_cold = 4, IGUI_Rem_Talk_hi_scared = 3,
    IGUI_Rem_Talk_hi_ally = 3, IGUI_Rem_Talk_hi_surrendered = 3,
    IGUI_Rem_Talk_need_medical = 3, IGUI_Rem_Talk_need_food = 3, IGUI_Rem_Talk_need_ammo = 3, IGUI_Rem_Talk_need_none = 4,
    IGUI_Rem_Talk_need_none_cold = 2, IGUI_Rem_Talk_need_none_scared = 2,
    IGUI_Rem_Talk_info = 3, IGUI_Rem_Talk_info_none = 3, IGUI_Rem_Talk_info_distrust = 3, IGUI_Rem_Talk_info_distrust_cold = 2,
    IGUI_Rem_Talk_refuse = 3, IGUI_Rem_Talk_bye = 4, IGUI_Rem_Talk_bye_cold = 3, IGUI_Rem_Talk_bye_scared = 2,
    IGUI_Rem_Trade_done = 3, IGUI_Rem_Trade_done_cold = 2, IGUI_Rem_Trade_unfair = 3, IGUI_Rem_Trade_unfair_cold = 2,
    IGUI_Rem_Shelter_yes = 3, IGUI_Rem_Shelter_no = 3, IGUI_Rem_Shelter_no_cold = 2, IGUI_Rem_Shelter_trade = 2,
    IGUI_Rem_Join_yes = 3, IGUI_Rem_Join_no = 3, IGUI_Rem_Join_no_cold = 2, IGUI_Rem_Join_group = 3,
    IGUI_Rem_Threat_comply = 3, IGUI_Rem_Threat_fight = 3, IGUI_Rem_Threat_unarmed = 2,
    IGUI_Rem_Quest_reward_item = 3, IGUI_Rem_Quest_reward_info = 2, IGUI_Rem_Quest_lost_found = 3,
    IGUI_Rem_Gift_thanks = 3, IGUI_Rem_Gift_thanks_cold = 2, IGUI_Rem_Gift_thanks_scared = 2,
    IGUI_Rem_Gift_none = 2, IGUI_Rem_Gift_enough = 2,
    IGUI_Rem_About_refuse = 3,
    IGUI_Rem_Goal_hide = 2, IGUI_Rem_Goal_clear = 2, IGUI_Rem_Goal_scavenge = 2,
    IGUI_Rem_Goal_fortify = 2, IGUI_Rem_Goal_materials = 2,
    IGUI_Rem_Ask_yes = 2, IGUI_Rem_Ask_no = 2,
    IGUI_Rem_Talk_hi_grudge = 3, IGUI_Rem_Talk_hi_saved = 3, IGUI_Rem_Talk_hi_gift = 2, IGUI_Rem_Talk_hi_quest = 2,
    IGUI_Rem_Talk_hi_traded = 2, IGUI_Rem_Talk_hi_close = 3,
}
IA.TONED = {
    IGUI_Rem_Talk_need_none = true, IGUI_Rem_Talk_info_distrust = true, IGUI_Rem_Talk_bye = true,
    IGUI_Rem_Trade_done = true, IGUI_Rem_Trade_unfair = true, IGUI_Rem_Shelter_no = true, IGUI_Rem_Join_no = true,
    IGUI_Rem_Gift_thanks = true,
}

function IA.tone(npc)
    if not npc then return nil end
    local rec = npc.rec
    if rec.faction == "aliados" then return nil end
    if Rem.trait(rec, "coragem") <= 3 then return "scared" end
    if Rem.trait(rec, "agressividade") >= 7 or rec.attitude == "hostil" then return "cold" end
    return nil
end

-- Escolhe tom e variacao da fala (uma vez). Retorna a mesma tabela.
function IA.finalize(l, npc)
    if not l or l.final then return l end
    local key = l.key
    local tone = IA.TONED[key] and IA.tone(npc)
    if tone and IA.VARIANTS[key .. "_" .. tone] then key = key .. "_" .. tone end
    local n = IA.VARIANTS[key]
    if n then key = key .. "_" .. tostring(ZombRand(1, n + 1)) end
    l.key, l.final = key, true
    return l
end

function IA.text(l)
    if not l then return "" end
    if not l.final then IA.finalize(l, l.npc) end   -- nunca mostra uma chave sem variacao
    return getText(l.key, unpack(l.args or {}))
end

-- O NPC conversando para e olha para voce.
function IA.hold(npc, now)
    npc.talkingUntil = (now or Rem.nowMs()) + CFG.TALK_HOLD_MS
end

function IA.talkBehavior(npc, ctx, now)
    if not npc.talkingUntil or now > npc.talkingUntil then return false end
    Rem.stopMoving(npc)
    if ctx.player then Rem.safe(function() npc.z:faceThisObject(ctx.player) end) end
    return true
end

-- ---------------------------------------------------------------- E1 conversar
function IA.canTalk(npc)
    if npc.rec.surrendered then return true end
    if Rem.isHostileToPlayer(npc) then return false, line("IGUI_Rem_Talk_refuse") end
    return true
end

function IA.greeting(npc)
    local rec = npc.rec
    local att = rec.attitude or (Rem.attitudeOf and Rem.attitudeOf(rec)) or "neutro"
    local l = (not rec.surrendered) and Rem.Bonds and Rem.Bonds.greeting(npc) or nil   -- lembra de voce
    if l then return IA.finalize(l, npc) end
    l = (not rec.surrendered) and Rem.Fame and Rem.Fame.greeting(npc) or nil         -- ja ouviu falar de voce
    if l then return IA.finalize(l, npc) end
    if rec.surrendered then l = line("IGUI_Rem_Talk_hi_surrendered")
    elseif rec.faction == "aliados" then l = line("IGUI_Rem_Talk_hi_ally", tostring(rec.name))
    elseif Rem.trait(rec, "coragem") <= 3 then l = line("IGUI_Rem_Talk_hi_scared", tostring(rec.name))
    elseif att == "amigavel" then l = line("IGUI_Rem_Talk_hi_friendly", tostring(rec.name))
    elseif Rem.trait(rec, "agressividade") >= 7 then l = line("IGUI_Rem_Talk_hi_cold")
    else l = line("IGUI_Rem_Talk_hi_neutral", tostring(rec.name)) end
    return IA.finalize(l, npc)
end

-- Do que o grupo da pessoa precisa agora.
function IA.needs(npc)
    local needs = { food = false, medical = false, ammo = false }
    local g = groupOf(npc)
    local list = g and membersOf(g) or { npc.rec }
    if g and (g.supplies or 0) < #list * 2 then needs.food = true end
    for _, p in ipairs(list) do
        local a = activeOf(p)
        local frac = a and Rem.healthFraction(a) or ((p.hp or 1) / (p.maxHealth or 1))
        if frac < 0.6 or p.infectedAt then needs.medical = true end
        if p.firearm and (p.ammo or 0) < 6 then needs.ammo = true end
    end
    -- economia da regiao: escassez, guerra, gosto da faccao (Rem_Territory)
    if Rem.Territory and g then needs.mods = Rem.Territory.priceMods(g) end
    return needs
end

function IA.status(npc)
    -- preso; quem segue voce com fome ou cansado (Rem_Needs) fala disso primeiro
    if npc.rec.prisoner then return line("IGUI_Rem_Prisoner_status") end
    local mil = Rem.Military and Rem.Military.status(npc)        -- soldado: noticias oficiais
    if mil then return mil end
    local ND = Rem.Needs
    if ND and ND.tracked(npc.rec) and not npc.rec.groupId then
        if ND.hunger(npc.rec) >= ND.CFG.ASK_FOOD_AT then return line("IGUI_Rem_Needs_status_hungry") end
        if ND.tired(npc.rec) >= ND.CFG.ASK_SLEEP_AT then return line("IGUI_Rem_Needs_status_tired") end
    end
    -- grupo em guerra (Rem_War) fala disso primeiro
    local war = Rem.War and Rem.War.status(npc)
    if war then return war end
    -- o que o grupo esta fazendo agora (Rem_Director) vem antes do que falta
    local g = groupOf(npc)
    local n = IA.needs(npc)
    if g and Rem.Director and g.home and g.home.x1 and not npc.rec.lost and not n.medical then
        local goal = g.goal
        if not goal then goal = Rem.Director.choose(g, nil) end
        if goal == "scavenge" and g.needs and g.needs.food < Rem.Director.CFG.FOOD_URGENT
            and Rem.Director.materials(g) < 1 and g.activity == "home" then
            return line("IGUI_Rem_Goal_materials")
        end
        if goal and goal ~= "routine" and goal ~= "heal" and goal ~= "fortify" then return line("IGUI_Rem_Goal_" .. goal) end
        -- obra em andamento (Rem_BaseBuild): "Estamos levantando uma cerca em volta da casa."
        local BB = Rem.BaseBuild
        if BB and g.home.plan then
            for _, p in ipairs(BB.projectsFor(g)) do
                if (g.home.plan[p] or 0) > 0 then
                    if Rem.Director.materials(g) < (BB.CFG.COST[p] or 1) then return line("IGUI_Rem_Goal_materials") end
                    return line("IGUI_Rem_Goal_build", getText("IGUI_Rem_Project_" .. p))
                end
            end
        end
        if goal == "fortify" then return line("IGUI_Rem_Goal_fortify") end
    end
    if n.medical then return line("IGUI_Rem_Talk_need_medical") end
    if n.food then return line("IGUI_Rem_Talk_need_food") end
    if n.ammo then return line("IGUI_Rem_Talk_need_ammo") end
    return line("IGUI_Rem_Talk_need_none")
end

local DIRS = { "E", "SE", "S", "SW", "W", "NW", "N", "NE" }
function IA.direction(fx, fy, tx, ty)
    local a = math.atan2(ty - fy, tx - fx)          -- y cresce para o sul no PZ
    -- (na Lua do jogo, -1 % 8 da -1, nao 7: normaliza a mao)
    local i = math.floor((a / (math.pi / 4)) + 0.5)
    while i < 0 do i = i + 8 end
    while i >= 8 do i = i - 8 end
    return DIRS[i + 1] or "N"
end

-- Conta onde fica outro grupo que voce ainda nao conhece.
function IA.groupInfo(npc, player)
    if (Rem.repOf and Rem.repOf(npc.rec) or 0) < CFG.INFO_TRUST and npc.rec.faction ~= "aliados" then
        return line("IGUI_Rem_Talk_info_distrust")
    end
    local known = Rem.getStore().knownGroups or {}
    Rem.getStore().knownGroups = known
    local best, bestD = nil, CFG.INFO_RADIUS
    for _, g in pairs(Rem.getStore().groups) do
        if g.id ~= npc.rec.groupId and not known[g.id] and g.home then
            local d = Rem.dist2(npc.z:getX(), npc.z:getY(), g.home.x, g.home.y)
            if d < bestD then best, bestD = g, d end
        end
    end
    if not best then return line("IGUI_Rem_Talk_info_none") end
    known[best.id] = true
    Rem.MapMarks.markGroup(best, npc)          -- "deixa eu marcar no seu mapa"
    return line("IGUI_Rem_Talk_info", getText("IGUI_Rem_Faction_" .. best.faction),
        getText("IGUI_Rem_Dir_" .. IA.direction(player:getX(), player:getY(), best.home.x, best.home.y)),
        tostring(math.floor(bestD / 10) * 10)), best
end

-- ---------------------------------------------------------------- E2 trocar
-- Valor base por categoria (como o jogo exibe: getDisplayCategory).
IA.VALUE = { Food = 3, Water = 3, FirstAid = 4, Ammo = 5, Weapon = 6, WeaponCrafted = 3, Tool = 3,
    Literature = 1, Clothing = 1, Container = 2, Electronics = 2, Material = 1, Junk = 0.5 }
IA.FIREARMS = { ["Base.Pistol"] = 14, ["Base.Pistol2"] = 14, ["Base.Shotgun"] = 16, ["Base.HuntingRifle"] = 18, ["Base.VarmintRifle"] = 15 }

local function categoryOf(item)
    local dc = "Junk"
    pcall(function() dc = item:getDisplayCategory() or "Junk" end)
    local food = false
    pcall(function() food = item:isFood() end)
    if food and dc ~= "Water" then dc = "Food" end
    return dc
end

-- Valor de um item para o grupo do npc (antes da margem).
function IA.value(item, needs)
    local ft = item:getFullType()
    if IA.FIREARMS[ft] then return IA.FIREARMS[ft] end
    local cat = categoryOf(item)
    local v = IA.VALUE[cat] or 0.5
    if needs then
        if needs.food and (cat == "Food" or cat == "Water") then v = v * 1.8 end
        if needs.medical and cat == "FirstAid" then v = v * 2 end
        if needs.ammo and cat == "Ammo" then v = v * 1.8 end
        if needs.mods and needs.mods[cat] then v = v * needs.mods[cat] end
    end
    return v
end

function IA.markup(npc)
    if Rem.Alliance and Rem.Alliance.isAllied(groupOf(npc)) then return 1.0 end   -- aliados: preco justo
    local rep = Rem.repOf and Rem.repOf(npc.rec) or 0
    return math.max(1.0, CFG.MARKUP - rep / CFG.MARKUP_REP_DIVISOR)
end

-- Item "virtual" para o que a pessoa carrega (rec.carry guarda so o tipo).
local function carriedItem(ft)
    local it = instanceItem(ft)
    return it
end

-- O que a pessoa tem para oferecer: o estoque da casa (se ela esta perto e a casa esta
-- carregada), mais o que ela carrega (saque, rec.carry) e o que tem nos bolsos
-- (rec.pockets, Rem_Profile). Cada entrada: { item, container } ou { item, src, idx }.
function IA.theirItems(npc)
    local out = {}
    local g = groupOf(npc)
    local conts = g and g.home and Rem.Safehouse.stashContainers(g.home)
    if conts and #conts > 0 and Rem.dist2(npc.z:getX(), npc.z:getY(), g.home.x, g.home.y) < 40 then
        for _, c in ipairs(conts) do
            local items = c:getItems()
            for i = 0, items:size() - 1 do table.insert(out, { item = items:get(i), container = c }) end
        end
    end
    for _, src in ipairs({ "carry", "pockets" }) do
        for i, ft in ipairs(npc.rec[src] or {}) do
            local it = carriedItem(ft)
            if it then table.insert(out, { item = it, src = src, idx = i, carryIndex = (src == "carry") and i or nil }) end
        end
    end
    return out
end

-- Passa itens dele para voce (entradas de IA.theirItems). Retorna quantos sairam do
-- estoque da casa (para as contas do estoque).
function IA.takeFromNpc(npc, entries, player)
    local inv = player:getInventory()
    local gone = { carry = {}, pockets = {} }
    local fromStash = 0
    for _, e in ipairs(entries) do
        if e.container then
            e.container:DoRemoveItem(e.item)
            inv:AddItem(e.item)
            fromStash = fromStash + 1
        elseif e.src then
            gone[e.src][e.idx] = true
            inv:AddItem(e.item:getFullType())
        end
    end
    for _, src in ipairs({ "carry", "pockets" }) do
        local keep = {}
        for i, ft in ipairs(npc.rec[src] or {}) do if not gone[src][i] then table.insert(keep, ft) end end
        if npc.rec[src] then npc.rec[src] = keep end
    end
    return fromStash
end

-- O que voce pode oferecer: inventario principal, sem itens equipados nem favoritos.
function IA.playerItems(player)
    local out = {}
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local skip = false
        pcall(function() skip = it:isEquipped() or it:isFavorite() or player:isEquipped(it) end)
        if not skip then table.insert(out, { item = it }) end
    end
    return out
end

-- Saldo da troca (>= 0: aceitam). give/take = listas de entradas {item=...}.
function IA.balance(npc, give, take)
    local needs = IA.needs(npc)
    local mk = IA.markup(npc)
    local g, t = 0, 0
    for _, e in ipairs(give) do g = g + IA.value(e.item, needs) end
    for _, e in ipairs(take) do t = t + IA.value(e.item, needs) * mk end
    return g - t, g, t
end

function IA.trade(player, npc, give, take)
    if #give == 0 and #take == 0 then return false, line("IGUI_Rem_Trade_empty") end
    local bal = IA.balance(npc, give, take)
    if bal < 0 then return false, line("IGUI_Rem_Trade_unfair") end
    local g = groupOf(npc)
    local conts = g and g.home and Rem.Safehouse.stashContainers(g.home)
    local inv = player:getInventory()
    -- voce entrega
    for _, e in ipairs(give) do
        inv:DoRemoveItem(e.item)
        if conts and #conts > 0 and not e.toCarry then
            conts[1]:AddItem(e.item)
        else
            npc.rec.carry = npc.rec.carry or {}
            table.insert(npc.rec.carry, e.item:getFullType())
        end
    end
    -- voce recebe
    local fromStash = IA.takeFromNpc(npc, take, player)
    -- contas do estoque (o resto do mod nao confunde troca com consumo/roubo)
    if g and g.home and conts and #conts > 0 then
        local delta = #give - fromStash
        g.home.syncCount = math.max(0, (g.home.syncCount or 0) + delta)
        g.home.stashCount = math.max(0, (g.home.stashCount or 0) + delta)
        g.supplies = math.max(0, (g.supplies or 0) + delta / Rem.World.CFG.ITEMS_PER_SUPPLY)
    end
    if Rem.changeRep then Rem.changeRep(npc.rec.groupId or ("f:" .. npc.rec.faction), CFG.TRADE_REP, "troca") end
    if g then g.tradedAt = Rem.worldHours() end
    Rem.emit("playerDeed", "traded", npc)
    Rem.bark(npc, "deal", true)
    return true, line("IGUI_Rem_Trade_done")
end

-- ---------------------------------------------------------------- E3 abrigo
function IA.isGuest(g)
    return g ~= nil and g.guestUntil ~= nil and Rem.worldHours() < g.guestUntil
end

function IA.askShelter(npc)
    local g = groupOf(npc)
    if not g or not g.home or not g.home.x1 then return false, line("IGUI_Rem_Shelter_nohome") end
    if IA.isGuest(g) then return true, line("IGUI_Rem_Shelter_already") end
    local rep = Rem.repOf(npc.rec)
    local tradedToday = g.tradedAt and Rem.worldHours() - g.tradedAt < 24
    if rep >= CFG.SHELTER_REP or (rep >= CFG.INFO_TRUST and tradedToday) then
        g.guestUntil = Rem.worldHours() + CFG.SHELTER_HOURS
        Rem.MapMarks.markShelter(g, npc)
        return true, line("IGUI_Rem_Shelter_yes")
    end
    if rep >= CFG.INFO_TRUST then return false, line("IGUI_Rem_Shelter_trade") end
    return false, line("IGUI_Rem_Shelter_no")
end

-- ---------------------------------------------------------------- E4 recrutar
-- Disposicao de largar tudo e seguir voce (>= JOIN_THRESHOLD aceita). Ninguem segue um
-- estranho: pesa principalmente o vinculo pessoal; depois a personalidade e a fama.
--   sozinho no mundo (de passagem, errante, sem grupo)  +15
--   voce acabou de liberta-lo                           +25
--   tem casa e grupo                                    -25 (e -30 se o grupo ficaria com 1-2)
function IA.joinScore(npc)
    local rec = npc.rec
    local score = Rem.trait(rec, "lealdade") * 4 + Rem.trait(rec, "confianca") * 2
        + (Rem.repOf(rec) or 0) * 0.4 + (rec.bond or 0) * CFG.JOIN_BOND_WEIGHT
    local g = groupOf(npc)
    if not g or rec.transient or rec.faction == "errantes" then score = score + 15 end
    if rec.ambient == "freed" then score = score + 25 end
    if g and g.home then score = score - 25 end
    if g and #g.members <= 2 then score = score - 30 end
    if rec.surrendered then score = score - 20 end
    return score
end

-- Quem anda com voce (aliados que nao moram na sua base).
function IA.followerCount()
    local n = 0
    for _, p in pairs(Rem.getStore().people) do
        if p.faction == "aliados" and not p.groupId then n = n + 1 end
    end
    return n
end

function IA.recruit(npc)
    local rec = npc.rec
    local g = groupOf(npc)
    if g then
        for i = #g.members, 1, -1 do if g.members[i] == rec.id then table.remove(g.members, i) end end
        if Rem.changeRep and #g.members <= 3 then Rem.changeRep(g.id, -5, "levou um membro") end
    end
    rec.groupId, rec.transient, rec.ambient, rec.role = nil, nil, nil, nil
    rec.faction = "aliados"
    rec.temper = "defensivo"
    rec.hostileToPlayer = false
    rec.surrendered = nil
    rec.mode = "follow"
    rec.recruited = true
    Rem.clearRest(npc)
    Rem.applyFriendlyFire(npc)
    Rem.bark(npc, "follow", true)
    Rem.emit("playerDeed", "recruited", npc)
end

function IA.askJoin(npc)
    local rec = npc.rec
    if rec.faction == "aliados" then return true, line("IGUI_Rem_Join_already") end
    local hours = Rem.worldHours()
    if rec.askedJoinAt and hours - rec.askedJoinAt < CFG.JOIN_COOLDOWN_HOURS then
        return false, line("IGUI_Rem_Join_asked")
    end
    rec.askedJoinAt = hours
    if Rem.isHostileToPlayer(npc) and not rec.surrendered then return false, line("IGUI_Rem_Talk_refuse") end
    if IA.followerCount() >= CFG.MAX_FOLLOWERS then
        rec.askedJoinAt = nil
        return false, line("IGUI_Rem_Join_full")
    end
    if IA.joinScore(npc) >= CFG.JOIN_THRESHOLD then
        IA.recruit(npc)
        return true, line("IGUI_Rem_Join_yes")
    end
    if groupOf(npc) then return false, line("IGUI_Rem_Join_group") end
    return false, line("IGUI_Rem_Join_no")
end

-- Seguidor: guardar posicao (fica num ponto e defende em volta).
function IA.guard(npc)
    local rec = npc.rec
    rec.mode = "guard"
    rec.homeX, rec.homeY, rec.homeZ = math.floor(npc.z:getX()), math.floor(npc.z:getY()), math.floor(npc.z:getZ())
    Rem.bark(npc, "stay", true)
end

function IA.guardBehavior(npc, ctx, now)
    if npc.rec.mode ~= "guard" then return false end
    Rem.hangAround(npc, npc.rec.homeX + 0.5, npc.rec.homeY + 0.5, npc.rec.homeZ or 0, now, 1)
    return true
end

-- Seguidor: saquear o predio do quadrado indicado e trazer para voce.
function IA.lootHere(npc, sq)
    local b = sq and sq:getBuilding()
    local def = b and b:getDef()
    if not def then return false, line("IGUI_Rem_Loot_nobuilding") end
    local rec = npc.rec
    rec.mode = "loot"
    rec.lootTarget = { x = def:getX() + def:getW() / 2, y = def:getY() + def:getH() / 2, z = 0, bid = tostring(def:getID()),
        x1 = def:getX(), y1 = def:getY(), x2 = def:getX() + def:getW(), y2 = def:getY() + def:getH() }
    npc.lootDoneBid, npc.lootStart, npc.fLootCont, npc.lootUntil = nil, nil, nil, nil
    Rem.clearRest(npc)
    return true, line("IGUI_Rem_Loot_ok")
end

function IA.lootBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "loot" or not rec.lootTarget then return false end
    local t = rec.lootTarget
    local SC = Rem.Scavenge
    local player = ctx.player
    npc.lootStart = npc.lootStart or now
    local full = rec.carry and #rec.carry >= SC.CFG.CARRY_MAX
    local tooLong = now - npc.lootStart > CFG.LOOT_MAX_MS
    local tooFar = player and Rem.dist(npc.z, player) > CFG.LOOT_LEASH
    if full or tooLong or tooFar or npc.lootDoneBid == t.bid then
        -- volta e entrega
        if not player then return false end
        if Rem.dist(npc.z, player) > CFG.GIVE_DIST then
            Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, Rem.travelGait(npc, Rem.dist(npc.z, player)))
            return true
        end
        if IA.giveCarry(npc, player) == 0 then Rem.bark(npc, "loot_nothing", true) end
        rec.mode, rec.lootTarget = "follow", nil
        npc.lootStart, npc.fLootCont, npc.lootUntil, npc.lootDoneBid = nil, nil, nil, nil
        return true
    end
    local cur = npc.fLootCont      -- armario atual (o predio fica em rec.lootTarget)
    if not cur then
        cur = SC.pickContainer(npc, t)
        if not cur then npc.lootDoneBid = t.bid return true end
        cur.since = now
        npc.fLootCont = cur
    end
    local cx, cy = cur.sq:getX() + 0.5, cur.sq:getY() + 0.5
    if Rem.dist2(npc.z:getX(), npc.z:getY(), cx, cy) > SC.CFG.TOUCH then
        if now - (cur.since or now) > SC.CFG.STUCK_MS then      -- nao consegue chegar: proximo
            t.visited = t.visited or {}
            t.visited[cur.key] = true
            npc.fLootCont, npc.lootUntil = nil, nil
            return true
        end
        -- armario fica num quadrado solido: vai ate o quadrado livre ao lado
        local sx, sy, sz = Rem.standSquare(cur.sq, npc.z:getX(), npc.z:getY())
        local d = Rem.dist2(npc.z:getX(), npc.z:getY(), sx, sy)
        Rem.moveTo(npc, sx, sy, sz, now, (d > 8) and Rem.travelGait(npc, d) or Rem.baseGait(npc))
        return true
    end
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceLocationF(cx, cy) end)
    if not npc.lootUntil then npc.lootUntil = now + SC.CFG.SEARCH_MS return true end
    if now < npc.lootUntil then return true end
    Rem.safe(SC.takeFrom, npc, cur.c)
    t.visited = t.visited or {}
    t.visited[cur.key] = true
    npc.fLootCont, npc.lootUntil = nil, nil
    return true
end

function IA.giveCarry(npc, player)
    local n = 0
    for _, ft in ipairs(npc.rec.carry or {}) do
        Rem.safe(function() player:getInventory():AddItem(ft) end)
        n = n + 1
    end
    npc.rec.carry = nil
    if n > 0 then Rem.bark(npc, "loot_home", true) end
    return n
end

-- Seguidor: liberar (vai embora, vira gente de passagem).
function IA.release(npc, player)
    local rec = npc.rec
    if Rem.PlayerBase then Rem.PlayerBase.leave(rec) end
    rec.faction = "civis"
    rec.recruited = nil
    rec.mode = "ambient"
    rec.ambient = "walker"
    rec.transient = true
    rec.expiresAt = Rem.worldHours() + 3
    local dx, dy = npc.z:getX() - player:getX(), npc.z:getY() - player:getY()
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    rec.destX = math.floor(npc.z:getX() + dx / len * 50)
    rec.destY = math.floor(npc.z:getY() + dy / len * 50)
    if Rem.Reputation then Rem.Reputation.apply(rec) end
    Rem.applyFriendlyFire(npc)
end

-- ---------------------------------------------------------------- E5 missoes
local function quests()
    local s = Rem.getStore()
    s.quests = s.quests or {}
    return s.quests
end

function IA.questOf(npc)
    local q = npc.rec.groupId and quests()[npc.rec.groupId]
    if q and Rem.worldHours() > q.expiresAt then
        quests()[npc.rec.groupId] = nil
        return nil
    end
    return q
end

IA.FETCH = {
    food = { cats = { Food = true, Water = true }, count = 4 },
    medical = { cats = { FirstAid = true }, count = 2 },
    ammo = { cats = { Ammo = true }, count = 1 },
    -- tabuas e pregos para fechar as janelas (Rem_Director)
    materials = { cats = {}, types = { ["Base.Plank"] = true, ["Base.Nails"] = true, ["Base.NailsBox"] = true }, count = 4 },
}

-- Cria uma missao conforme a necessidade do grupo.
function IA.offerQuest(npc)
    local g = groupOf(npc)
    if not g then return nil, line("IGUI_Rem_Quest_nogroup") end
    local q = IA.questOf(npc)
    if q then return q, line("IGUI_Rem_Quest_" .. q.kind .. "_remind", tostring(q.count - (q.progress or 0))) end
    local needs = IA.needs(npc)
    local kind
    if needs.medical then kind = "medical"
    elseif needs.food then kind = "food"
    elseif needs.ammo then kind = "ammo"
    elseif Rem.Director and g.home and g.home.x1 and (g.needs and g.needs.safety or 0) >= Rem.Director.CFG.SAFETY_WORK
        and Rem.Director.materials(g) < CFG.MATERIALS_QUEST_BELOW then kind = "materials"
    elseif Rem.Director and g.goal == "clear" then kind = "clear"
    else kind = (ZombRand(2) == 0) and "clear" or "lost" end
    q = { kind = kind, group = g.id, expiresAt = Rem.worldHours() + CFG.QUEST_HOURS, progress = 0 }
    if IA.FETCH[kind] then
        q.count = IA.FETCH[kind].count
    elseif kind == "clear" then
        q.count, q.x, q.y = CFG.CLEAR_COUNT, g.home.x, g.home.y
    elseif kind == "lost" then
        local def, bx, by = Rem.pickBuilding(g.home.x, g.home.y, CFG.LOST_DIST[1], CFG.LOST_DIST[2])
        if not def then
            kind, q.kind, q.count, q.x, q.y = "clear", "clear", CFG.CLEAR_COUNT, g.home.x, g.home.y
        else
            local p = Rem.newPerson({ faction = g.faction, groupId = g.id, mode = "stay", x = bx, y = by })
            p.homeX, p.homeY = math.floor(bx), math.floor(by)
            p.hp = (p.maxHealth or 2) * 0.5
            p.lost = g.id
            table.insert(g.members, p.id)
            q.count, q.memberId, q.x, q.y = 1, p.id, bx, by
            q.dir = IA.direction(g.home.x, g.home.y, bx, by)
            q.dist = math.floor(Rem.dist2(g.home.x, g.home.y, bx, by) / 10) * 10
        end
    end
    quests()[g.id] = q
    -- marca no seu mapa: onde esta quem sumiu / a rua a limpar; e a casa de quem pediu
    if q.x then Rem.MapMarks.markQuest(q, npc) end
    Rem.MapMarks.markGroup(g, npc)
    if kind == "lost" then
        return q, line("IGUI_Rem_Quest_lost", getText("IGUI_Rem_Dir_" .. q.dir), tostring(q.dist))
    end
    return q, line("IGUI_Rem_Quest_" .. kind, tostring(q.count))
end

-- Itens da sua mochila que servem para a missao de busca.
function IA.fetchItems(player, q)
    local spec = IA.FETCH[q.kind]
    if not spec then return {} end
    local out = {}
    for _, e in ipairs(IA.playerItems(player)) do
        if spec.cats[categoryOf(e.item)] or (spec.types and spec.types[e.item:getFullType()]) then table.insert(out, e) end
    end
    return out
end

function IA.complete(npc, player, q)
    quests()[q.group] = nil
    if Rem.changeRep then Rem.changeRep(q.group, CFG.QUEST_REP, "missao") end
    Rem.emit("playerDeed", "quest", npc)
    -- recompensa: o melhor item do estoque para voce, ou a localizacao de outro grupo
    local offer = IA.theirItems(npc)
    table.sort(offer, function(a, b) return IA.value(a.item) > IA.value(b.item) end)
    local reward = offer[1]
    if reward and IA.value(reward.item) >= 3 then
        IA.takeFromNpc(npc, { reward }, player)
        Rem.bark(npc, "thanks", true)
        return true, line("IGUI_Rem_Quest_reward_item", reward.item:getDisplayName())
    end
    local info = IA.groupInfo(npc, player)
    Rem.bark(npc, "thanks", true)
    return true, line("IGUI_Rem_Quest_reward_info", IA.text(info))
end

-- Entregar (missao de busca) ou avisar que terminou (limpar zumbis / achar alguem).
function IA.turnIn(npc, player)
    local q = IA.questOf(npc)
    if not q then return false, line("IGUI_Rem_Quest_none") end
    if IA.FETCH[q.kind] then
        local items = IA.fetchItems(player, q)
        if #items < q.count then return false, line("IGUI_Rem_Quest_" .. q.kind .. "_remind", tostring(q.count)) end
        local give = {}
        for i = 1, q.count do table.insert(give, items[i]) end
        local g = groupOf(npc)
        local conts = g and g.home and Rem.Safehouse.stashContainers(g.home)
        for _, e in ipairs(give) do
            player:getInventory():DoRemoveItem(e.item)
            if conts and #conts > 0 then conts[1]:AddItem(e.item) end
        end
        if g and q.kind == "materials" and Rem.Director then
            g.materials = Rem.Director.materials(g) + #give      -- vira trabalho nas janelas
        end
        if g and conts and #conts > 0 then
            g.home.syncCount = (g.home.syncCount or 0) + #give
            g.home.stashCount = (g.home.stashCount or 0) + #give
            g.supplies = (g.supplies or 0) + #give / Rem.World.CFG.ITEMS_PER_SUPPLY
        end
        return IA.complete(npc, player, q)
    end
    if (q.progress or 0) >= q.count then return IA.complete(npc, player, q) end
    return false, line("IGUI_Rem_Quest_" .. q.kind .. "_remind", tostring(q.count - (q.progress or 0)))
end

-- Limpar zumbis: conta os que voce mata perto da casa deles.
Events.OnZombieDead.Add(function(zombie)
    if Rem.active[zombie] then return end
    local by = nil
    pcall(function() by = zombie:getAttackedBy() end)
    if not by or not Rem.isPlayerObj(by) then return end
    for _, q in pairs(quests()) do
        if q.kind == "clear" and Rem.dist2(zombie:getX(), zombie:getY(), q.x, q.y) <= CFG.CLEAR_RADIUS then
            q.progress = (q.progress or 0) + 1
        end
    end
end)

-- Achar quem sumiu: falar com ele o faz voltar; chegando em casa, a missao conta.
function IA.findLost(npc)
    local rec = npc.rec
    if not rec.lost then return false end
    rec.mode = "group"
    Rem.bark(npc, "thanks", true)
    return true, line("IGUI_Rem_Quest_lost_found")
end

Rem.on("sceneUpdate", function()
    for _, q in pairs(quests()) do
        if q.kind == "lost" and (q.progress or 0) < 1 then
            local p = Rem.getPerson(q.memberId)
            local g = Rem.getStore().groups[q.group]
            if not p or not g then
                q.failed = true
            elseif p.mode == "group" and Rem.dist2(p.x or 0, p.y or 0, g.home.x, g.home.y) < 8 then
                q.progress = 1
                p.lost = nil
            end
        end
    end
end)

-- ---------------------------------------------------------------- E6 ameacar
local function playerArmed(player)
    local w = nil
    pcall(function() w = player:getPrimaryHandItem() end)
    return w ~= nil and instanceof(w, "HandWeapon")
end

function IA.threaten(npc, player)
    if not playerArmed(player) then return false, line("IGUI_Rem_Threat_unarmed") end
    local rec = npc.rec
    local key = rec.groupId or ("f:" .. tostring(rec.faction))
    if Rem.trait(rec, "coragem") <= CFG.THREAT_COURAGE or rec.surrendered then
        local offer = IA.theirItems(npc)
        table.sort(offer, function(a, b) return IA.value(a.item) > IA.value(b.item) end)
        local take = {}
        for i = 1, math.min(CFG.THREAT_GIVE, #offer) do table.insert(take, offer[i]) end
        IA.takeFromNpc(npc, take, player)
        if Rem.changeRep then Rem.changeRep(key, CFG.THREAT_REP, "ameaca") end
        Rem.emit("playerDeed", "threatened", npc)
        Rem.bark(npc, "surrender", true)
        return true, line("IGUI_Rem_Threat_comply", tostring(#take))
    end
    if Rem.changeRep then Rem.changeRep(key, CFG.THREAT_FIGHT_REP, "ameaca") end
    Rem.emit("playerDeed", "threatened", npc)
    if Rem.angerGroup then Rem.angerGroup(key) end
    Rem.bark(npc, "angry", true)
    return false, line("IGUI_Rem_Threat_fight")
end

-- ---------------------------------------------------------------- presente
-- Dar algo sem pedir nada: o item mais util para eles agora (comida, agua, remedio ou
-- municao). Sobe o vinculo com a pessoa (Rem_Bonds), um pouco a reputacao e o moral.
IA.GIFT_CATEGORIES = { Food = true, Water = true, FirstAid = true, Ammo = true }

function IA.pickGift(npc, player)
    local needs = IA.needs(npc)
    local best, bestV = nil, 0
    for _, e in ipairs(IA.playerItems(player)) do
        if IA.GIFT_CATEGORIES[categoryOf(e.item)] then
            local v = IA.value(e.item, needs)
            if v > bestV then best, bestV = e, v end
        end
    end
    return best, bestV
end

function IA.gift(npc, player)
    local rec = npc.rec
    local hours = Rem.worldHours()
    if rec.giftAt and hours - rec.giftAt < CFG.GIFT_HOURS then return false, line("IGUI_Rem_Gift_enough") end
    local e, v = IA.pickGift(npc, player)
    if not e then return false, line("IGUI_Rem_Gift_none") end
    local name = e.item:getDisplayName()
    local g = groupOf(npc)
    local conts = g and g.home and Rem.Safehouse.stashContainers(g.home)
    player:getInventory():DoRemoveItem(e.item)
    if conts and #conts > 0 and Rem.dist2(npc.z:getX(), npc.z:getY(), g.home.x, g.home.y) < 40 then
        conts[1]:AddItem(e.item)
        g.home.syncCount = (g.home.syncCount or 0) + 1
        g.home.stashCount = (g.home.stashCount or 0) + 1
        g.supplies = (g.supplies or 0) + 1 / Rem.World.CFG.ITEMS_PER_SUPPLY
    else
        rec.carry = rec.carry or {}
        table.insert(rec.carry, e.item:getFullType())
    end
    rec.giftAt = hours
    local bond = math.max(CFG.GIFT_BOND[1], math.min(CFG.GIFT_BOND[2], math.floor(CFG.GIFT_BOND[1] + v * 2)))
    if Rem.changeRep then Rem.changeRep(rec.groupId or ("f:" .. tostring(rec.faction)), CFG.GIFT_REP, "presente") end
    Rem.emit("playerDeed", "gift", npc, bond)
    return true, line("IGUI_Rem_Gift_thanks", name)
end

-- ---------------------------------------------------------------- pedir ajuda
-- O vinculo vale alguma coisa: quem gosta de voce te da comida, ou remedio se voce estiver
-- ferido. Uma vez por dia por pessoa; gasta um pouco da boa vontade.
function IA.askHelp(npc, player)
    local rec = npc.rec
    local hours = Rem.worldHours()
    if rec.askedHelpAt and hours - rec.askedHelpAt < CFG.ASK_HOURS then return false, line("IGUI_Rem_Ask_wait") end
    local trusted = rec.faction == "aliados" or (rec.bond or 0) >= CFG.ASK_BOND or (Rem.repOf(rec) or 0) >= CFG.ASK_REP
    if not trusted then return false, line("IGUI_Rem_Ask_no") end
    local health = 100
    pcall(function() health = player:getBodyDamage():getOverallBodyHealth() end)
    local want = (health < CFG.ASK_HURT_BELOW) and { FirstAid = true } or { Food = true, Water = true }
    local pick = nil
    for _, e in ipairs(IA.theirItems(npc)) do
        if want[categoryOf(e.item)] and (not pick or IA.value(e.item) > IA.value(pick.item)) then pick = e end
    end
    if not pick then return false, line("IGUI_Rem_Ask_nothing") end
    local name = pick.item:getDisplayName()
    if IA.takeFromNpc(npc, { pick }, player) > 0 then
        local g = groupOf(npc)
        if g and g.home then
            g.home.syncCount = math.max(0, (g.home.syncCount or 0) - 1)
            g.home.stashCount = math.max(0, (g.home.stashCount or 0) - 1)
            g.supplies = math.max(0, (g.supplies or 0) - 1 / Rem.World.CFG.ITEMS_PER_SUPPLY)
        end
    end
    rec.askedHelpAt = hours
    if Rem.Bonds and rec.faction ~= "aliados" then Rem.Bonds.add(rec, "asked", -CFG.ASK_COST) end
    return true, line("IGUI_Rem_Ask_yes", name)
end

-- Por que nao deu certo (linha de sistema na conversa): { key, args } ou nil.
function IA.hint(id, npc)
    local rec = npc.rec
    local rep = math.floor(Rem.repOf(rec) or 0)
    if id == "info" then return line("IGUI_Rem_Hint_rep", tostring(rep), tostring(CFG.INFO_TRUST)) end
    if id == "shelter" then return line("IGUI_Rem_Hint_rep", tostring(rep), tostring(CFG.SHELTER_REP)) end
    if id == "join" then
        if IA.followerCount() >= CFG.MAX_FOLLOWERS then return line("IGUI_Rem_Hint_full", tostring(CFG.MAX_FOLLOWERS)) end
        return line("IGUI_Rem_Hint_join", tostring(math.floor(IA.joinScore(npc))), tostring(CFG.JOIN_THRESHOLD))
    end
    if id == "ask" then return line("IGUI_Rem_Hint_bond", tostring(math.floor(rec.bond or 0)), tostring(CFG.ASK_BOND)) end
    if id == "order_base" and Rem.PlayerBase then return Rem.PlayerBase.hint(npc) end
    if id == "ally" and Rem.Alliance then return Rem.Alliance.hint(npc) end
    if id == "prisoner_recruit" and Rem.Prisoners then return Rem.Prisoners.recruitHint(npc) end
    if id == "pact" and Rem.Diplomacy then return Rem.Diplomacy.pactHint(npc) end
    if id == "trauma_talk" and Rem.Traumas then return Rem.Traumas.hint(npc) end
    if id == "order_follow" and Rem.PlayerBase and Rem.PlayerBase.isMember(rec) then
        return line("IGUI_Rem_Hint_full", tostring(CFG.MAX_FOLLOWERS))
    end
    return nil
end

-- ---------------------------------------------------------------- opcoes da conversa
-- Quais botoes aparecem na janela de conversa (ordem de exibicao).
function IA.dialogOptions(npc, player)
    local rec = npc.rec
    local out = {}
    local function add(id) table.insert(out, id) end
    if not IA.canTalk(npc) then add("bye") return out end
    -- preso (Rem_Prisoners): so o que se faz com um prisioneiro
    if rec.prisoner and Rem.Prisoners then
        add("status")
        if Rem.Persona then add("about") end
        for _, id in ipairs(Rem.Prisoners.dialogOptions(npc, player)) do add(id) end
        if Rem.Diplomacy and Rem.Diplomacy.canTribute(npc) then add("tribute") end
        add("bye")
        return out
    end
    add("status")
    if rec.surrendered and Rem.Prisoners then
        for _, id in ipairs(Rem.Prisoners.dialogOptions(npc, player)) do add(id) end
    end
    if Rem.Persona then add("about") end
    add("info")
    add("trade")
    if not rec.surrendered then add("gift") end
    if not rec.surrendered then add("ask") end
    if rec.ambient == "visitor" and Rem.PlayerBase and Rem.PlayerBase.get() and Rem.BaseEvents then add("accept_visitor") end
    local own = Rem.PlayerBase and Rem.PlayerBase.isMember(rec)
    if rec.groupId and not rec.lost and not own then add("shelter") end
    if rec.faction ~= "aliados" then add("join") end
    if rec.lost then add("findlost") end
    if rec.groupId and not rec.lost and not own then
        local q = IA.questOf(npc)
        if q then add("turnin") else add("quest") end
    end
    if Rem.Alliance and Rem.Alliance.canAsk(npc) and not rec.lost then add("ally") end
    if Rem.War and not rec.lost and Rem.War.canSide(npc) then add("war_side") end
    if Rem.Refugees and Rem.Refugees.canInvite(npc) then add("refugee_invite") end
    if Rem.Diplomacy and not rec.lost then for _, id in ipairs(Rem.Diplomacy.dialogOptions(npc)) do add(id) end end
    if Rem.PersonalQuests then for _, id in ipairs(Rem.PersonalQuests.dialogOptions(npc, player)) do add(id) end end
    if Rem.Traumas and Rem.Traumas.canTalk(npc) then add("trauma_talk") end
    if rec.faction ~= "aliados" then add("threaten") end
    -- ordens (so para quem segue voce)
    if Rem.Gear and rec.faction == "aliados" then
        if Rem.Gear.canGiveWeapon(npc, player) then add("gear_weapon") end
        if Rem.Gear.canGiveAmmo(npc, player) then add("gear_ammo") end
    end
    -- fome e cansaco (Rem_Needs)
    if Rem.Needs and rec.faction == "aliados" then
        if Rem.Needs.canFeed(npc, player) then add("feed") end
        if Rem.Needs.canNap(npc) then add("nap") end
    end
    if own then
        -- morador da sua base: tarefa na base, ou voltar a andar com voce
        for _, job in ipairs(Rem.PlayerBase.JOBS) do
            if rec.job ~= job then add("order_job_" .. job) end
        end
        add("order_follow")
        if rec.recruited then add("order_release") end
    elseif rec.faction == "aliados" and Rem.Companion then
        if rec.mode ~= "follow" then add("order_follow") end
        if rec.mode ~= "stay" then add("order_stay") end
        if rec.mode ~= "guard" then add("order_guard") end
        if rec.mode ~= "loot" then add("order_loot") end
        if Rem.PlayerBase and Rem.PlayerBase.get() then add("order_base") end
        if Rem.Orders then for _, id in ipairs(Rem.Orders.dialogOptions(npc)) do add(id) end end
        if rec.recruited then add("order_release") end
    end
    add("bye")
    return out
end

local function second(_, b) return b end   -- (sem select(): a Lua do jogo so garante select("#"))

-- Executa uma opcao. Retorna a fala de resposta (tabela {key, args}), ja com tom e
-- variacao escolhidos.
function IA.choose(id, npc, player)
    return IA.finalize(IA.chooseRaw(id, npc, player), npc)
end

local function knownCount()
    local n = 0
    for _ in pairs(Rem.getStore().knownGroups or {}) do n = n + 1 end
    return n
end

-- IA.last = { id, ok }: se a ultima escolha deu certo (a janela mostra o motivo quando nao).
function IA.chooseRaw(id, npc, player)
    IA.hold(npc)
    IA.last = { id = id, ok = true }
    local function res(ok, l)
        IA.last.ok = ok and true or false
        return l
    end
    if id == "status" then return IA.status(npc) end
    if id == "about" and Rem.Persona then return Rem.Persona.about(npc) end
    if id == "gift" then return res(IA.gift(npc, player)) end
    if id == "ask" then return res(IA.askHelp(npc, player)) end
    if id == "info" then
        local known = knownCount()
        local l = IA.groupInfo(npc, player)
        IA.last.ok = knownCount() > known
        return l
    end
    if id == "shelter" then return res(IA.askShelter(npc)) end
    if id == "join" then return res(IA.askJoin(npc)) end
    if id == "quest" then return second(IA.offerQuest(npc)) end
    if id == "turnin" then return res(IA.turnIn(npc, player)) end
    if id == "findlost" then return second(IA.findLost(npc)) end
    if id == "threaten" then return second(IA.threaten(npc, player)) end
    if id == "accept_visitor" and Rem.BaseEvents then return res(Rem.BaseEvents.accept(npc)) end
    if id == "ally" and Rem.Alliance then return res(Rem.Alliance.propose(npc)) end
    if id == "gear_weapon" and Rem.Gear then return res(Rem.Gear.giveWeapon(npc, player)) end
    if id == "gear_ammo" and Rem.Gear then return res(Rem.Gear.giveAmmo(npc, player)) end
    if id == "war_side" and Rem.War then return res(Rem.War.side(npc)) end
    if id == "pact" and Rem.Diplomacy then return res(Rem.Diplomacy.pact(npc)) end
    if id == "tribute" and Rem.Diplomacy then return res(Rem.Diplomacy.tribute(npc)) end
    if id:sub(1, 3) == "pq_" and Rem.PersonalQuests then return res(Rem.PersonalQuests.choose(id, npc, player)) end
    if id == "trauma_talk" and Rem.Traumas then return res(Rem.Traumas.talk(npc)) end
    if id == "refugee_invite" and Rem.Refugees then return res(Rem.Refugees.invite(npc)) end
    if id == "feed" and Rem.Needs then return res(Rem.Needs.feed(npc, player)) end
    if id == "nap" and Rem.Needs then return res(Rem.Needs.nap(npc)) end
    if id:sub(1, 9) == "prisoner_" and Rem.Prisoners then return res(Rem.Prisoners.choose(id, npc, player)) end
    if (id:sub(1, 13) == "order_stance_" or id == "order_retreat") and Rem.Orders then return res(Rem.Orders.order(id, npc)) end
    if Rem.PlayerBase and (id == "order_base" or id:sub(1, 10) == "order_job_"
        or (id == "order_follow" and Rem.PlayerBase.isMember(npc.rec))) then
        local ok, l = Rem.PlayerBase.order(id, npc, player)
        IA.last.ok = ok and true or false
        return l
    end
    if id:sub(1, 6) == "order_" and Rem.Companion then
        local l = Rem.Companion.order(id, npc, player)
        if l then return l end
    end
    return line("IGUI_Rem_Talk_bye")
end

-- ---------------------------------------------------------------- ganchos
-- Hospede: a porta fica aberta para voce e o territorio nao reclama (Rem_Safehouse,
-- Rem_Reputation consultam IA.isGuest).
Rem.registerBehavior({ name = "talking", priority = CFG.TALK_PRIORITY, run = IA.talkBehavior })
Rem.registerBehavior({ name = "follower_loot", priority = CFG.LOOT_PRIORITY, run = IA.lootBehavior })
Rem.registerBehavior({ name = "guard", priority = CFG.GUARD_PRIORITY, run = IA.guardBehavior })
