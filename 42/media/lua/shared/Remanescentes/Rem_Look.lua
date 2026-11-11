-- Remanescentes - aparencia humana que dura.
--
-- O corpo dos sobreviventes e um zumbi: cada golpe que levam e cada zumbi que matam suja o
-- rosto e a roupa de sangue, e o jogo pode trocar a pele de volta para a de zumbi quando o
-- modelo e refeito. Coberto de sangue, um aliado fica com "cara de zumbi" e assusta.
-- Aqui, quem esta calmo ha um tempo se limpa (como qualquer sobrevivente faria), e a pele
-- humana e reaplicada se o jogo tiver trocado.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
local Rem = Remanescentes

local LK = Rem.module("Look", {
    CHECK_MS = 4000,
    CALM_MS = 15000,          -- sem lutar nem apanhar ha esse tempo: limpa o sangue
    BLOOD_MIN = 0.05,
})
local CFG = LK.CFG

local function calm(npc, now)
    local last = math.max(npc.attackUntil or 0, npc.hitUntil or 0, npc.shootUntil or 0, npc.lastCombatAt or 0)
    return now - last >= CFG.CALM_MS and not npc.fleeing
end

-- Retorna true se mexeu na aparencia.
function LK.refresh(npc, now)
    local z, rec = npc.z, npc.rec
    local visual = z:getHumanVisual()
    if not visual then return false end
    local changed = false
    if rec.skin then
        local cur = nil
        pcall(function() cur = visual:getSkinTexture() end)
        if cur ~= rec.skin then
            visual:setSkinTextureName(rec.skin)
            changed = true
        end
    end
    if calm(npc, now) then
        local blood = 0
        pcall(function() blood = visual:getTotalBlood() end)
        if blood > CFG.BLOOD_MIN then
            visual:removeBlood()
            visual:removeDirt()
            local items = z:getItemVisuals()
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
            changed = true
        end
    end
    if changed then z:resetModelNextFrame() end
    return changed
end

-- quem bate ou apanha fica "em combate"
Rem.on("zombieHitNPC", function(npc, zombie, now) npc.lastCombatAt = now end)

local nextCheck = 0
Events.OnTick.Add(function()
    if not Rem.isAuthority() or Rem.activeCount == 0 then return end
    local now = Rem.nowMs()
    if now < nextCheck then return end
    nextCheck = now + CFG.CHECK_MS
    for _, npc in pairs(Rem.active) do Rem.safe(LK.refresh, npc, now) end
end)
