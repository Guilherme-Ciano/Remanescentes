-- Remanescentes - faccoes e hostilidade.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

-- hostileToPlayer: ataca o jogador ao ve-lo.
-- enemies: faccoes que esta ataca. A relacao e simetrica (ver Rem.factionsHostile).
-- outfits/loot: aparencia e equipamento tipicos.
-- groupNames: (opcional) nomes de grupo usados pelo mundo vivo (ver Rem_World).
-- temper: como encara zumbis (ver Rem_Brain):
--   agressivo  ataca qualquer zumbi que veja
--   cauteloso  luta so contra ameacas; foge se estiver em desvantagem
--   defensivo  luta so contra ameacas a si ou ao jogador, ou quando o jogador comeca a briga
--   medroso    evita briga: foge, e so bate se estiver encurralado
Rem.FACTIONS = Rem.FACTIONS or {}

-- Registra (ou substitui) uma faccao. def no formato acima:
--   { hostileToPlayer = bool, enemies = { outra = true }, temper = "cauteloso",
--     outfits = { ... }, groupNames = { ... } (opcional, nomes de grupo no mundo vivo) }
-- Campos ausentes recebem padroes seguros. Retorna a def registrada.
function Rem.registerFaction(name, def)
    if type(name) ~= "string" or type(def) ~= "table" then return nil end
    def.enemies = def.enemies or {}
    def.outfits = def.outfits or Rem.OUTFITS
    if def.hostileToPlayer == nil then def.hostileToPlayer = false end
    Rem.FACTIONS[name] = def
    return def
end

Rem.registerFaction("aliados", {
    hostileToPlayer = false, enemies = { saqueadores = true }, temper = "defensivo",
    outfits = Rem.OUTFITS,
})
Rem.registerFaction("civis", {
    hostileToPlayer = false, enemies = { saqueadores = true }, temper = "medroso",
    outfits = { "Generic01", "Generic02", "Generic03", "Generic04", "Generic05", "Tourist", "Farmer", "Doctor", "Chef", "Nurse" },
})
Rem.registerFaction("sobreviventes", {
    hostileToPlayer = false, enemies = { saqueadores = true }, temper = "cauteloso",
    outfits = { "Camper", "Hunter", "Ranger", "Mechanic", "ConstructionWorker", "Police", "Biker" },
})
Rem.registerFaction("saqueadores", {
    hostileToPlayer = true, enemies = { aliados = true, civis = true, sobreviventes = true }, temper = "agressivo",
    outfits = { "Bandit", "Bandit_Early", "Bandit_Mid", "Bandit_Late", "Thug", "Biker" },
})

function Rem.factionDef(name)
    return Rem.FACTIONS[name] or Rem.FACTIONS.civis
end

function Rem.factionsHostile(a, b)
    if a == b then return false end
    local da, db = Rem.factionDef(a), Rem.factionDef(b)
    return (da.enemies[b] or db.enemies[a]) == true
end

function Rem.temperOf(npc)
    return npc.rec.temper or Rem.factionDef(npc.rec.faction).temper or "cauteloso"
end

-- npc = estado de runtime (tem .rec com a pessoa)
function Rem.isHostileToPlayer(npc)
    if npc.rec.hostileToPlayer ~= nil then return npc.rec.hostileToPlayer end
    return Rem.factionDef(npc.rec.faction).hostileToPlayer
end

function Rem.npcsHostile(a, b)
    -- rixa pessoal (ex.: dois civis brigando por comida, Rem_Ambient)
    if (a.rec.foeId and a.rec.foeId == b.rec.id) or (b.rec.foeId and b.rec.foeId == a.rec.id) then return true end
    return Rem.factionsHostile(a.rec.faction, b.rec.faction)
end

-- Amigo do jogador: protegido de fogo amigo, segue ordens.
function Rem.isFriendly(npc)
    return not Rem.isHostileToPlayer(npc)
end
