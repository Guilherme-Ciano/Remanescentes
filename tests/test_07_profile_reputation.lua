-- Fase 2: ficha do sobrevivente, personalidade, atitude e reputacao (Rem_Profile, Rem_Reputation).
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie = T.check, T.tick, T.fire, T.newZombie
local player, realPrint = T.player, T.print

local function byPlayer(z) z.getAttackedBy = function() return player end end
local function scene() Rem.emit("sceneUpdate", player, Rem.nowMs()) end

realPrint("30) Ficha completa")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
player.x, player.y = 3000, 3000
local civ = Rem.spawn(3005, 3005, 0, { faction = "civis", mode = "wander" })
local r = civ.rec
check(r.profile and r.age >= 18 and r.age <= 70, "idade 18-70 (" .. tostring(r.age) .. ")")
check(Rem.Profile.findProfession(r.profession) ~= nil and r.professionUI ~= nil, "profissao do jogo (" .. tostring(r.profession) .. ")")
check(Rem.Profile.ARCHETYPES[r.archetype] ~= nil, "arquetipo valido (" .. tostring(r.archetype) .. ")")
local okTraits = true
for _, t in ipairs(Rem.Profile.TRAITS) do
    local v = r.personality[t]
    if type(v) ~= "number" or v < 0 or v > 10 then okTraits = false end
end
check(okTraits, "personalidade: 5 tracos de 0 a 10")
check(r.moral and r.fome == 0 and r.cansaco == 0, "estado inicial (moral, fome, cansaco)")
check((Rem.temperOf(civ) == "medroso") == (civ.rec.personality.coragem < 6), "civil e medroso (a menos que seja de fibra)")
check(type(Rem.profileText(r)) == "string", "texto da ficha")

local cop = Rem.spawn(3006, 3005, 0, { faction = "civis", profession = "base:policeofficer", archetype = "atirador" })
check(cop.rec.outfit == "Police", "policial usa farda")
check(cop.rec.firearm ~= nil and cop.rec.ammoItem ~= nil and cop.rec.ammo > 0, "atirador carrega arma de fogo e municao")
check(cop.rec.item == "Base.HuntingKnife" or cop.rec.item == "Base.KitchenKnife", "atirador luta com faca por enquanto")
local doc = Rem.spawn(3007, 3005, 0, { faction = "civis", profession = "base:doctor" })
check(doc.rec.outfit == "Doctor" and doc.rec.archetype == "medico", "medico de jaleco, arquetipo medico")
local sneak = Rem.spawn(3008, 3005, 0, { faction = "civis", archetype = "furtivo" })
check(sneak.rec.stealth == true, "furtivo anda agachado")
local forced = Rem.spawn(3009, 3005, 0, { faction = "civis", item = "Base.BaseballBat", wtype = "bat", outfit = "Tourist" })
check(forced.rec.item == "Base.BaseballBat" and forced.rec.outfit == "Tourist", "arma/roupa escolhidas por quem criou valem")

realPrint("31) Personalidade e faccao decidem a atitude")
local brave = Rem.Profile.temperFor("civis", { agressividade = 2, confianca = 5, coragem = 2, ganancia = 3, lealdade = 5 })
check(brave == "medroso", "civil covarde: medroso")
check(Rem.Profile.temperFor("saqueadores", { agressividade = 9, confianca = 1, coragem = 2, ganancia = 9, lealdade = 2 }) == "cauteloso",
    "saqueador covarde: cauteloso")
check(Rem.Profile.temperFor("sobreviventes", { agressividade = 9, confianca = 1, coragem = 9, ganancia = 5, lealdade = 5 }) == "agressivo",
    "miliciano esquentado: agressivo")
check(Rem.Profile.temperFor("aliados", { agressividade = 9, confianca = 9, coragem = 1, ganancia = 1, lealdade = 9 }) == "defensivo",
    "aliado e sempre defensivo")
local mil = Rem.spawn(3010, 3010, 0, { faction = "sobreviventes", mode = "wander" })
check(mil.rec.attitude == "neutro" and not Rem.isHostileToPlayer(mil), "milicia comeca neutra (" .. tostring(mil.rec.attitude) .. ")")
local thug = Rem.spawn(3020, 3020, 0, { faction = "saqueadores", mode = "wander" })
check(thug.rec.attitude == "hostil" and Rem.isHostileToPlayer(thug), "saqueador comeca hostil")
check(civ.rec.attitude ~= "hostil", "civil nao e hostil (" .. tostring(civ.rec.attitude) .. ")")
local ally = Rem.spawn(3011, 3011, 0, { faction = "aliados", mode = "follow" })
check(ally.z.avoid == true and civ.z.avoid == false and mil.z.avoid == false,
    "so seus aliados sao protegidos dos seus golpes")

realPrint("32) Reputacao: golpear, raiva passa, matar")
local key = "f:civis"
local rep0 = Rem.getRep(key)
fire("OnHitZombie", civ.z, player, nil, nil)
check(Rem.getRep(key) == rep0 - 10, "golpe: -10 (" .. rep0 .. " -> " .. Rem.getRep(key) .. ")")
check(civ.rec.hostileToPlayer == true, "golpeado fica com raiva (hostil)")
T.clock = T.clock + Rem.Reputation.CFG.ANGER_MS + 10
scene()
check(civ.rec.hostileToPlayer == false, "raiva passa depois de um tempo")
local victim = Rem.spawn(3030, 3030, 0, { faction = "civis" })
byPlayer(victim.z)
victim.z:Kill(player)
check(Rem.getRep(key) == rep0 - 50, "matar membro: -40")
check(Rem.getRep(key) >= -100, "reputacao limitada a -100..100")
Rem.changeRep(key, 500, "teste")
check(Rem.getRep(key) == 100, "teto 100")
Rem.changeRep(key, -1000, "teste")
check(Rem.getRep(key) == -100, "piso -100")
Rem.changeRep(key, 110, "teste")

realPrint("33) Reputacao: ajudar e matar saqueador")
T.clearZombies(); Rem.hunting = {}
local g = Rem.createGroup("civis", 3100, 3100, nil, 2)
local member = nil
for _, npc in pairs(Rem.active) do if npc.rec.groupId == g.id then member = npc end end
if not member then member = Rem.materialize(Rem.getPerson(g.members[1])) end
local repG = Rem.getRep(g.id)
local zed = newZombie(member.z.x, member.z.y - 2, 0, 0, 1)
Rem.hunting[zed] = { npc = member, lastSeen = T.clock, nextPath = T.clock + 99999, real = false }
byPlayer(zed)
zed:Kill(player)
check(Rem.getRep(g.id) == repG + 2, "matou zumbi que cacava um membro: +2")
local raider = Rem.spawn(3101, 3101, 0, { faction = "saqueadores" })
byPlayer(raider.z)
raider.z:Kill(player)
check(Rem.getRep(g.id) == repG + 5, "matou saqueador perto: +3")

realPrint("34) Milicia territorial: aviso e expulsao")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local base = Rem.createGroup("sobreviventes", 3500, 3500, "350", 3,
    { getX = function() return 3495 end, getY = function() return 3495 end, getW = function() return 10 end, getH = function() return 10 end })
local guard = Rem.materialize(Rem.getPerson(base.members[1]))
check(guard ~= nil, "(cenario) guarda em cena")
local repB = Rem.getRep(base.id)
player.x, player.y = 3540, 3540
scene()
check(Rem.Reputation.state[base.id] == nil or Rem.Reputation.state[base.id].warnedAt == nil, "fora da base: sem aviso")
player.x, player.y = 3498, 3507
scene()
check(T.saidPrefix(guard.z, "IGUI_Rem_Bark_warn_"), "entrou na base: manda ir embora")
check(not guard.rec.hostileToPlayer, "ainda nao ataca")
T.clock = T.clock + Rem.Reputation.CFG.WARN_GRACE_MS + 10
scene()
check(Rem.getRep(base.id) == repB - 10 and guard.rec.hostileToPlayer == true, "insistiu: -10 e o grupo ataca")
player.x, player.y = 3600, 3600
T.clock = T.clock + Rem.Reputation.CFG.ANGER_MS + 10
scene()
check(not guard.rec.hostileToPlayer, "saiu e esperou: voltam a ser neutros")

realPrint("35) Sorteio de faccoes e tamanho dos grupos")
local seen = {}
local tl = Rem.getStore().timeline
local tlStart = tl.startHours
tl.startHours = Rem.worldHours() - 24 * 20   -- dia 20: saqueadores ja existem
local realFloat = ZombRandFloat
local k = 0
ZombRandFloat = function(a, b) k = k + 1 return a + (b - a) * ((k * 0.37) % 1) end -- o mock devolve sempre o meio
for _ = 1, 200 do seen[Rem.randomFaction()] = true end
ZombRandFloat = realFloat
tl.startHours = tlStart
check(seen.saqueadores and seen.civis and seen.sobreviventes, "sorteio inclui civis, milicia e saqueadores")
local sizesOk = true
for _, f in ipairs({ "civis", "sobreviventes", "saqueadores", "seita", "errantes" }) do
    for _ = 1, 10 do
        local n = Rem.groupSizeFor(f)
        local rng = Rem.World.GROUP_SIZE[f]
        if n < rng[1] or n > rng[2] then sizesOk = false end
    end
end
check(sizesOk and Rem.World.GROUP_SIZE.civis[1] >= 2 and Rem.World.GROUP_SIZE.sobreviventes[2] == 6, "safehouses com 2 a 6 moradores")
check(Rem.FACTIONS.seita ~= nil and Rem.FACTIONS.errantes ~= nil, "faccoes seita e errantes existem")
Rem.dismissAll()
