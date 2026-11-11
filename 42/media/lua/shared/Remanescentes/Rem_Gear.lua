-- Remanescentes - equipar quem anda com voce (e quem mora na sua base).
--
-- Conversa com um aliado:
--   "[Equipar] Usa esta arma."   a arma que esta na sua mao passa para ele (de verdade: sai
--                                do seu inventario). A arma que ele tinha volta para voce.
--                                Arma branca de duas maos usa as animacoes de taco; de uma
--                                mao, as de faca. Arma de fogo: so as que ele sabe usar
--                                (Rem_Ranged.GUNS); ele leva junto ate 2 caixas da municao
--                                certa que voce tiver.
--   "[Equipar] Toma municao."    caixas da municao da arma dele que voce tiver (ate 2).
-- A arma de quem morre cai no chao com o corpo.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Ranged"
local Rem = Remanescentes

local GE = Rem.module("Gear", {
    MAX_BOXES = 2,
})
local CFG = GE.CFG

Rem.BARKS.gear_thanks = { urgent = true, n = 3, cd = 0 }

local function line(key, ...) return { key = key, args = { ... } } end

function GE.isMine(npc)
    return npc.rec.faction == "aliados" and Rem.isFriendly(npc)
end

local function heldWeapon(player)
    local w = nil
    pcall(function() w = player:getPrimaryHandItem() end)
    if w and instanceof(w, "HandWeapon") then return w end
    return nil
end

local function isRanged(w)
    local r = false
    pcall(function() r = w:isRanged() end)
    return r
end

local function twoHanded(w)
    local r = false
    pcall(function() r = w:isTwoHandWeapon() or w:isRequiresEquippedBothHands() end)
    return r
end

-- Caixas de municao `ammo` no seu inventario.
local function ammoBoxes(player, ammo)
    local out = {}
    if not ammo then return out end
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it:getFullType() == ammo then table.insert(out, it) end
    end
    return out
end

function GE.canGiveWeapon(npc, player)
    return GE.isMine(npc) and heldWeapon(player) ~= nil
end

function GE.canGiveAmmo(npc, player)
    local g = npc.rec.firearm and Rem.Ranged.GUNS[npc.rec.firearm]
    return GE.isMine(npc) and g ~= nil and #ammoBoxes(player, g.ammo) > 0
end

-- Passa caixas de municao (ate MAX_BOXES). Retorna quantas.
function GE.takeAmmo(npc, player)
    local rec = npc.rec
    local g = rec.firearm and Rem.Ranged.GUNS[rec.firearm]
    if not g then return 0 end
    local RC = Rem.Ranged.CFG
    local n = 0
    for _, box in ipairs(ammoBoxes(player, g.ammo)) do
        if n >= CFG.MAX_BOXES or (rec.ammo or 0) >= RC.AMMO_MAX then break end
        player:getInventory():DoRemoveItem(box)
        rec.ammo = math.min(RC.AMMO_MAX, (rec.ammo or 0) + RC.ROUNDS_PER_BOX)
        n = n + 1
    end
    return n
end

-- Da a arma da sua mao. Retorna ok, fala.
function GE.giveWeapon(npc, player)
    local rec = npc.rec
    if not GE.isMine(npc) then return false, line("IGUI_Rem_Gear_no") end
    local w = heldWeapon(player)
    if not w then return false, line("IGUI_Rem_Gear_nothing") end
    local ft = w:getFullType()
    local inv = player:getInventory()
    if isRanged(w) then
        local gun = Rem.Ranged.GUNS[ft]
        if not gun then return false, line("IGUI_Rem_Gear_unknown_gun") end
        local old = rec.firearm
        if old then inv:AddItem(old) end
        rec.firearm, rec.ammoItem = ft, gun.ammo
        rec.ammo = rec.ammo or 0
        npc.gunOut = false
    else
        local old = rec.item
        if old then inv:AddItem(old) end
        rec.item = ft
        rec.wtype = twoHanded(w) and "bat" or "1h"
        Rem.safe(function()
            npc.z:setPrimaryHandItem(instanceItem(ft))
            npc.z:setVariable("RemWeapon", rec.wtype)
        end)
    end
    -- sai da sua mao e do seu inventario
    Rem.safe(function()
        if player:getSecondaryHandItem() == w then player:setSecondaryHandItem(nil) end
        player:setPrimaryHandItem(nil)
    end)
    inv:DoRemoveItem(w)
    -- o que cai quando ele morre
    Rem.safe(function()
        npc.z:clearItemsToSpawnAtDeath()
        if rec.item then npc.z:addItemToSpawnAtDeath(instanceItem(rec.item)) end
        if rec.firearm then npc.z:addItemToSpawnAtDeath(instanceItem(rec.firearm)) end
    end)
    local boxes = rec.firearm == ft and GE.takeAmmo(npc, player) or 0
    Rem.bark(npc, "gear_thanks", true)
    Rem.emit("playerDeed", "armed", npc)
    if rec.firearm == ft then return true, line("IGUI_Rem_Gear_gun_ok", w:getDisplayName(), tostring(rec.ammo or 0)) end
    return true, line("IGUI_Rem_Gear_ok", w:getDisplayName())
end

function GE.giveAmmo(npc, player)
    if not GE.canGiveAmmo(npc, player) then return false, line("IGUI_Rem_Gear_noammo") end
    GE.takeAmmo(npc, player)
    Rem.bark(npc, "gear_thanks", true)
    return true, line("IGUI_Rem_Gear_ammo_ok", tostring(npc.rec.ammo or 0))
end
