-- Remanescentes - a "ficha" de cada sobrevivente (Fase 2).
--
-- Gerada quando a pessoa nasce (evento "personCreated") e salva junto dela em ModData:
--   identidade : nome (ja existia), idade, profissao do jogo (base:policeofficer...),
--                roupa coerente com a profissao (policial de farda, medico de jaleco)
--   arquetipo  : brigao | atirador | furtivo | medico | engenheiro (define arma e papel)
--   personalidade (0-10): agressividade, confianca, coragem, ganancia, lealdade
--   estado     : fome, cansaco, moral (0-100), municao (atiradores)
--
-- A personalidade decide o temperamento (como encara zumbis) e, junto com a reputacao
-- do grupo (Rem_Reputation), a atitude com o jogador: hostil, neutro ou amigavel.
--
-- Atiradores: tiro de NPC ainda nao existe. Eles carregam a arma de fogo e a municao
-- (caem quando morrem; rec.firearm/rec.ammo ficam prontos para o combate a distancia) e,
-- por enquanto, lutam com uma faca.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
local Rem = Remanescentes

Rem.Profile = Rem.Profile or {}
local P = Rem.Profile

P.TRAITS = { "agressividade", "confianca", "coragem", "ganancia", "lealdade" }

-- ---------------------------------------------------------------- profissoes
-- id do jogo (character_professions.txt), chave de nome (UI_prof_*), roupas validas
-- (media/clothing/clothing.xml) e peso de cada arquetipo.
P.PROFESSIONS = {
    { id = "base:policeofficer", ui = "UI_prof_policeoff", outfits = { "Police" }, arch = { atirador = 6, brigao = 3 } },
    { id = "base:fireofficer", ui = "UI_prof_fireoff", outfits = { "Fireman" }, arch = { brigao = 6, engenheiro = 2 } },
    { id = "base:doctor", ui = "UI_prof_Doctor", outfits = { "Doctor" }, arch = { medico = 10 } },
    { id = "base:nurse", ui = "UI_prof_Nurse", outfits = { "Nurse" }, arch = { medico = 10 } },
    { id = "base:chef", ui = "UI_prof_Chef", outfits = { "Chef" }, arch = { brigao = 3, furtivo = 3 } },
    { id = "base:burgerflipper", ui = "UI_prof_BurgerFlipper", outfits = { "Chef", "Gas2Go" }, arch = { furtivo = 5, brigao = 2 } },
    { id = "base:farmer", ui = "UI_prof_Farmer", outfits = { "Farmer" }, arch = { brigao = 4, atirador = 2 } },
    { id = "base:rancher", ui = "UI_prof_rancher", outfits = { "Farmer" }, arch = { atirador = 4, brigao = 3 } },
    { id = "base:mechanics", ui = "UI_prof_Mechanics", outfits = { "Mechanic" }, arch = { engenheiro = 7, brigao = 2 } },
    { id = "base:repairman", ui = "UI_prof_Repairman", outfits = { "Mechanic" }, arch = { engenheiro = 8 } },
    { id = "base:electrician", ui = "UI_prof_Electrician", outfits = { "Mechanic", "Fossoil" }, arch = { engenheiro = 8 } },
    { id = "base:metalworker", ui = "UI_prof_MetalWorker", outfits = { "Mechanic" }, arch = { engenheiro = 6, brigao = 3 } },
    { id = "base:smither", ui = "UI_prof_Smither", outfits = { "Mechanic", "Survivalist" }, arch = { brigao = 5, engenheiro = 3 } },
    { id = "base:carpenter", ui = "UI_prof_Carpenter", outfits = { "ConstructionWorker" }, arch = { engenheiro = 7, brigao = 2 } },
    { id = "base:constructionworker", ui = "UI_prof_constructionworker", outfits = { "ConstructionWorker" }, arch = { brigao = 5, engenheiro = 4 } },
    { id = "base:engineer", ui = "UI_prof_Engineer", outfits = { "OfficeWorkerSkirt", "Generic01" }, arch = { engenheiro = 8 } },
    { id = "base:lumberjack", ui = "UI_prof_Lumberjack", outfits = { "Hunter", "Camper" }, arch = { brigao = 8 } },
    { id = "base:fisherman", ui = "UI_prof_Fisherman", outfits = { "Fisherman" }, arch = { furtivo = 4, brigao = 3 } },
    { id = "base:parkranger", ui = "UI_prof_parkranger", outfits = { "Ranger" }, arch = { atirador = 5, furtivo = 3 } },
    { id = "base:securityguard", ui = "UI_prof_securityguard", outfits = { "Security" }, arch = { brigao = 6, atirador = 2 } },
    { id = "base:fitnessinstructor", ui = "UI_prof_FitnessInstructor", outfits = { "FitnessInstructor" }, arch = { brigao = 7 } },
    { id = "base:veteran", ui = "UI_prof_Veteran", outfits = { "Veteran", "ArmyCamoGreen" }, arch = { atirador = 8, brigao = 2 } },
    { id = "base:burglar", ui = "UI_prof_Burglar", outfits = { "Thug", "Generic02" }, arch = { furtivo = 8 } },
    { id = "base:tailor", ui = "UI_prof_Tailor", outfits = { "Generic03", "Generic04" }, arch = { furtivo = 5, medico = 2 } },
    { id = "base:unemployed", ui = "UI_prof_unemployed", outfits = { "Generic01", "Generic02", "Generic05", "Tourist", "Student" }, arch = { brigao = 3, furtivo = 3 } },
}

-- profissoes mais comuns em cada faccao (peso extra)
P.FACTION_PROFESSIONS = {
    sobreviventes = { ["base:policeofficer"] = 4, ["base:veteran"] = 4, ["base:securityguard"] = 3, ["base:parkranger"] = 3 },
    saqueadores = { ["base:burglar"] = 6, ["base:unemployed"] = 4, ["base:securityguard"] = 1 },
    seita = { ["base:farmer"] = 3, ["base:rancher"] = 3, ["base:carpenter"] = 2 },
}

-- chance (%) de a roupa da FACCAO vencer a da profissao. Faccao que nao esta aqui
-- (registrada por outro modulo) sempre usa as roupas dela.
P.FACTION_OUTFIT_CHANCE = { aliados = 0, civis = 0, sobreviventes = 30, errantes = 20, seita = 50, saqueadores = 70 }

-- ---------------------------------------------------------------- arquetipos
-- wtype: "1h" (uma mao) ou "bat" (duas maos): sao as animacoes que existem (gen_animsets.sh)
P.ARCHETYPES = {
    brigao = { weapons = { { "Base.Axe", "bat" }, { "Base.Crowbar", "1h" }, { "Base.BaseballBat", "bat" }, { "Base.LeadPipe", "1h" }, { "Base.Shovel", "bat" }, { "Base.Machete", "1h" } } },
    atirador = { weapons = { { "Base.HuntingKnife", "1h" }, { "Base.KitchenKnife", "1h" } },
        firearms = { { "Base.Pistol", "Base.Bullets9mmBox" }, { "Base.Shotgun", "Base.ShotgunShellsBox" }, { "Base.HuntingRifle", "Base.308Bullets" } } },
    furtivo = { weapons = { { "Base.HuntingKnife", "1h" }, { "Base.KitchenKnife", "1h" } }, stealth = true },
    medico = { weapons = { { "Base.KitchenKnife", "1h" }, { "Base.Pipe", "1h" } } },
    engenheiro = { weapons = { { "Base.Hammer", "1h" }, { "Base.Wrench", "1h" }, { "Base.Crowbar", "1h" } } },
}

-- vida por arquetipo e roupas que protegem (farda, colete, roupa militar)
P.ARCH_HEALTH = { brigao = 1.0, atirador = 0.85, furtivo = 0.75, medico = 0.75, engenheiro = 0.9 }
P.ARMORED_OUTFITS = { Police = true, ArmyCamoGreen = true, Veteran = true, Security = true, Fireman = true }
P.ARMOR_BONUS = 1.25

-- ---------------------------------------------------------------- personalidade por faccao
-- { min, max } de cada traco
P.PERSONALITY = {
    aliados       = { agressividade = { 2, 6 }, confianca = { 6, 10 }, coragem = { 4, 8 }, ganancia = { 1, 4 }, lealdade = { 6, 10 } },
    civis         = { agressividade = { 0, 4 }, confianca = { 4, 9 }, coragem = { 1, 8 }, ganancia = { 1, 5 }, lealdade = { 4, 9 } },
    sobreviventes = { agressividade = { 3, 6 }, confianca = { 1, 5 }, coragem = { 5, 9 }, ganancia = { 2, 6 }, lealdade = { 5, 9 } },
    saqueadores   = { agressividade = { 7, 10 }, confianca = { 0, 3 }, coragem = { 4, 9 }, ganancia = { 6, 10 }, lealdade = { 1, 5 } },
    seita         = { agressividade = { 3, 9 }, confianca = { 0, 3 }, coragem = { 6, 10 }, ganancia = { 1, 4 }, lealdade = { 8, 10 } },
    errantes      = { agressividade = { 1, 8 }, confianca = { 2, 8 }, coragem = { 2, 8 }, ganancia = { 2, 8 }, lealdade = { 1, 7 } },
    -- faccao registrada por outro modulo: mediana, para o temperamento dela valer
    default       = { agressividade = { 3, 7 }, confianca = { 3, 7 }, coragem = { 4, 7 }, ganancia = { 3, 7 }, lealdade = { 3, 7 } },
}

-- ---------------------------------------------------------------- utilidades
local function weightedPick(weights)
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    if total <= 0 then return nil end
    local r = ZombRandFloat(0, total)
    local last = nil
    -- ordem estavel: percorre por nome
    local keys = {}
    for k in pairs(weights) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        last = k
        r = r - weights[k]
        if r <= 0 then return k end
    end
    return last
end

function P.findProfession(id)
    for _, p in ipairs(P.PROFESSIONS) do
        if p.id == id then return p end
    end
    return nil
end

function P.pickProfession(faction)
    local extra = P.FACTION_PROFESSIONS[faction] or {}
    local weights = {}
    for i, p in ipairs(P.PROFESSIONS) do
        weights[i] = 1 + (extra[p.id] or 0)
    end
    -- weightedPick usa chaves; indices numericos ordenam bem
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local r = ZombRandFloat(0, total)
    for i, w in ipairs(weights) do
        r = r - w
        if r <= 0 then return P.PROFESSIONS[i] end
    end
    return P.PROFESSIONS[#P.PROFESSIONS]
end

function P.rollPersonality(faction)
    local ranges = P.PERSONALITY[faction] or P.PERSONALITY.default
    local out = {}
    for _, t in ipairs(P.TRAITS) do
        local r = ranges[t] or { 0, 10 }
        out[t] = ZombRand(r[1], r[2] + 1)
    end
    return out
end

-- Temperamento (Rem_Brain): o da faccao, ajustado pela personalidade nos extremos.
function P.temperFor(faction, pers)
    local base = Rem.factionDef(faction).temper or "cauteloso"
    if faction == "aliados" then return base end          -- seguidores: o jogador decide a briga
    if pers.coragem <= 3 then
        return (base == "agressivo") and "cauteloso" or "medroso"   -- covarde
    end
    if base == "cauteloso" and pers.agressividade >= 8 and pers.coragem >= 8 then
        return "agressivo"                                          -- esquentado
    end
    if base == "medroso" and pers.coragem >= 6 then return "cauteloso" end   -- civil de fibra
    return base
end

-- ---------------------------------------------------------------- bolsos
P.POCKET_COMMON = { "Base.Crackers", "Base.BeefJerky", "Base.TinnedBeans", "Base.WaterRationCan", "Base.Crisps",
    "Base.CigarettePack", "Base.Matches", "Base.Candle", "Base.Bandage", "Base.Pills" }
P.POCKET_BY_ARCH = {
    medico = { "Base.Bandage", "Base.Disinfectant", "Base.Pills", "Base.Antibiotics" },
    engenheiro = { "Base.Nails", "Base.Hammer", "Base.Matches" },
    atirador = { "Base.Bullets9mmBox", "Base.ShotgunShellsBox" },
    furtivo = { "Base.HandTorch", "Base.BeefJerky" },
    brigao = { "Base.Whiskey", "Base.CigarettePack" },
}
P.POCKET_COUNT = { 1, 3 }

function P.rollPockets(rec)
    local out = {}
    for _ = 1, ZombRand(P.POCKET_COUNT[1], P.POCKET_COUNT[2] + 1) do
        table.insert(out, Rem.pick(P.POCKET_COMMON))
    end
    local extra = P.POCKET_BY_ARCH[rec.archetype or ""]
    if extra then table.insert(out, Rem.pick(extra)) end
    return out
end

-- ---------------------------------------------------------------- gerar a ficha
-- opts (opcional): personality, archetype, profession (id), age
function Rem.buildProfile(rec, opts)
    opts = opts or {}
    local faction = rec.faction or "civis"
    if rec.profile and not opts.force then return rec end

    -- identidade
    rec.age = opts.age or ZombRand(18, 71)
    local prof = (opts.profession and P.findProfession(opts.profession)) or P.pickProfession(faction)
    rec.profession = prof.id
    rec.professionUI = prof.ui

    -- arquetipo (pela profissao, ou forcado)
    local arch = opts.archetype or weightedPick(prof.arch) or "brigao"
    rec.archetype = arch
    local adef = P.ARCHETYPES[arch] or P.ARCHETYPES.brigao

    -- roupa coerente (a menos que a roupa tenha sido escolhida por quem criou a pessoa)
    if not opts.outfit then
        local factionWins = ZombRand(100) < (P.FACTION_OUTFIT_CHANCE[faction] or 100)
        if not factionWins then rec.outfit = Rem.pick(prof.outfits) end
    end

    -- arma pelo arquetipo (a menos que forcada)
    if not opts.item then
        local w = Rem.pick(adef.weapons)
        rec.item, rec.wtype = w[1], w[2]
    end
    if adef.firearms then
        local f = Rem.pick(adef.firearms)
        rec.firearm, rec.ammoItem = f[1], f[2]
        rec.ammo = ZombRand(3, 13)   -- pouca municao: cada tiro conta
    end
    if adef.stealth and opts.stealth == nil then rec.stealth = true end

    -- vida (Fase B5): base do sandbox x arquetipo x roupa de protecao
    if not opts.maxHealth then
        local mult = P.ARCH_HEALTH[arch] or 1
        rec.armored = P.ARMORED_OUTFITS[rec.outfit] == true
        if rec.armored then mult = mult * P.ARMOR_BONUS end
        rec.maxHealth = Rem.cfg("NPCHealth", 2.0) * mult
        rec.hp = rec.maxHealth
    end

    -- personalidade
    rec.personality = opts.personality or P.rollPersonality(faction)
    if not opts.temper then rec.temper = P.temperFor(faction, rec.personality) end

    -- estado
    rec.fome = rec.fome or 0
    rec.cansaco = rec.cansaco or 0
    rec.moral = rec.moral or (50 + ZombRand(30))

    -- o que leva nos bolsos (da para trocar, pedir, ou tomar a forca)
    if not rec.pockets then rec.pockets = P.rollPockets(rec) end

    rec.profile = true
    return rec
end

function Rem.trait(rec, name)
    local p = rec.personality
    return (p and p[name]) or 5
end

-- Texto curto da ficha (menu "Situacao").
function Rem.profileText(rec)
    local prof = rec.professionUI and getText(rec.professionUI) or "?"
    local arch = getText("IGUI_Rem_Arch_" .. tostring(rec.archetype or "brigao"))
    return string.format("%s, %d, %s (%s)", rec.name or "?", math.floor(rec.age or 0), prof, arch)
end

-- ---------------------------------------------------------------- ganchos
Rem.on("personCreated", function(rec, opts) Rem.buildProfile(rec, opts) end)

-- Itens extras ao morrer (arma de fogo e municao do atirador).
Rem.on("npcActivated", function(npc)
    local rec = npc.rec
    if rec.firearm then
        Rem.safe(function()
            npc.z:addItemToSpawnAtDeath(instanceItem(rec.firearm))
            if rec.ammoItem then npc.z:addItemToSpawnAtDeath(instanceItem(rec.ammoItem)) end
        end)
    end
end)

-- Pessoas de saves antigos ganham ficha na primeira vez que aparecem.
Rem.on("npcActivated", function(npc)
    if not npc.rec.profile then Rem.buildProfile(npc.rec, { outfit = true, item = true }) end
    if not npc.rec.pockets then npc.rec.pockets = P.rollPockets(npc.rec) end   -- saves de antes da 0.12
end)

-- ---------------------------------------------------------------- facções novas
-- Seita: rara, fechada, base muito fortificada e loot raro.
-- Errantes: sozinhos, viajando; atitude decidida pela personalidade.
Rem.registerFaction("seita", {
    hostileToPlayer = false, enemies = { saqueadores = true }, temper = "cauteloso",
    outfits = { "Priest", "Survivalist", "Farmer", "Generic05" },
    groupNames = { "Seita", "Irmandade", "Os Escolhidos" },
})
Rem.registerFaction("errantes", {
    hostileToPlayer = false, enemies = {}, temper = "cauteloso",
    outfits = { "Camper", "Hunter", "Biker", "Survivalist", "Tourist", "Generic01" },
    groupNames = { "Errante", "Viajante", "Andarilho" },
})
