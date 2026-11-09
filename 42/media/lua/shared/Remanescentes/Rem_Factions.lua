-- Remanescentes - faccoes e hostilidade.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

-- hostileToPlayer: ataca o jogador ao ve-lo.
-- enemies: faccoes que esta ataca. A relacao e simetrica (ver Rem.factionsHostile).
-- outfits/loot: aparencia e equipamento tipicos.
Rem.FACTIONS = {
    aliados = {
        hostileToPlayer = false, enemies = { saqueadores = true },
        outfits = Rem.OUTFITS,
    },
    civis = {
        hostileToPlayer = false, enemies = { saqueadores = true },
        outfits = { "Generic01", "Generic02", "Generic03", "Generic04", "Generic05", "Tourist", "Farmer", "Doctor", "Chef", "Nurse" },
    },
    sobreviventes = {
        hostileToPlayer = false, enemies = { saqueadores = true },
        outfits = { "Camper", "Hunter", "Ranger", "Mechanic", "ConstructionWorker", "Police", "Biker" },
    },
    saqueadores = {
        hostileToPlayer = true, enemies = { aliados = true, civis = true, sobreviventes = true },
        outfits = { "Bandit", "Bandit_Early", "Bandit_Mid", "Bandit_Late", "Thug", "Biker" },
    },
}

function Rem.factionDef(name)
    return Rem.FACTIONS[name] or Rem.FACTIONS.civis
end

function Rem.factionsHostile(a, b)
    if a == b then return false end
    local da, db = Rem.factionDef(a), Rem.factionDef(b)
    return (da.enemies[b] or db.enemies[a]) == true
end

-- npc = estado de runtime (tem .rec com a pessoa)
function Rem.isHostileToPlayer(npc)
    if npc.rec.hostileToPlayer ~= nil then return npc.rec.hostileToPlayer end
    return Rem.factionDef(npc.rec.faction).hostileToPlayer
end

function Rem.npcsHostile(a, b)
    return Rem.factionsHostile(a.rec.faction, b.rec.faction)
end

-- Amigo do jogador: protegido de fogo amigo, segue ordens.
function Rem.isFriendly(npc)
    return not Rem.isHostileToPlayer(npc)
end
