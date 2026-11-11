-- Lutar ou fugir (Rem_Tactics): cada um pesa o perigo contra o que acha que aguenta.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local TC = Rem.Tactics

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    player.x, player.y = 100, 100
end
local function person(x, y, faction, coragem, extra)
    local opts = { faction = faction, mode = "stay",
        personality = { agressividade = 3, confianca = 5, coragem = coragem, ganancia = 3, lealdade = 5 } }
    for k, v in pairs(extra or {}) do opts[k] = v end
    if Rem.dist2(player.x, player.y, x, y) > 40 then player.x, player.y = x, y + 20 end   -- perto o bastante para ele existir
    local npc = Rem.spawn(x, y, 0, opts)
    npc.rec.moral = 50
    return npc
end
local function horde(x, y, n)
    local list = {}
    for i = 1, n do
        local z = T.newZombie(x + (i - 1) * 0.6, y, 0, 0, -1)
        table.insert(list, z)
    end
    return list
end
local function near(a, b) return math.abs(a - b) < 0.001 end
local function aware(list, npc)
    for _, z in ipairs(list) do Rem.startHunt(z, npc, T.clock) end
end

realPrint("170) Um civil comum encara um zumbi; foge de varios")
fresh()
local joe = person(41000, 41000, "civis", 4)
check(Rem.temperOf(joe) == "medroso" and TC.capacity(joe) >= 1 and TC.capacity(joe) < 2, "civil comum aguenta um zumbi, nao dois (" .. string.format("%.2f", TC.capacity(joe)) .. ")")
local one = horde(41000, 41001.5, 1)
aware(one, joe)
tick(300, 2)
check(not joe.fleeing and (joe.attackTarget == one[1] or joe.nextAttack > T.clock or joe.z.path), "um zumbi so: ele luta")
T.clearZombies({ [joe.z] = true }); Rem.hunting = {}
joe.fleeing, joe.attackUntil, joe.hitAt, joe.nextAttack = false, 0, 0, 0
local three = horde(41000, 41002, 3)
aware(three, joe)
tick(300, 2)
check(joe.fleeing and joe.running, "tres zumbis: ele foge")
check(joe.tactic and joe.tactic.threat == 3, "(perigo contado: " .. tostring(joe.tactic and joe.tactic.threat) .. ")")

realPrint("171) Covarde foge de tudo; valente fica")
fresh()
local coward = person(41100, 41000, "civis", 1)
aware(horde(41100, 41001.5, 1), coward)
tick(300, 2)
check(coward.fleeing, "covarde foge ate de um zumbi")
fresh()
local brave = person(41200, 41000, "civis", 8)
check(Rem.temperOf(brave) == "cauteloso", "civil de fibra nao e 'medroso'")
aware(horde(41200, 41001.5, 2), brave)
tick(300, 2)
check(not brave.fleeing, "e encara dois zumbis sozinho")

realPrint("172) Juntos aguentam mais")
fresh()
local a = person(41300, 41000, "civis", 4)
local alone = TC.capacity(a)
local b = person(41302, 41000, "civis", 4)
local c = person(41301, 41002, "civis", 4)
check(near(TC.power(a), 1 + 2 * TC.CFG.ALLY_WEIGHT) and TC.capacity(a) > alone * 2, "tres juntos: cada um se sente mais forte")
aware(horde(41300, 41001.5, 3), a)
tick(300, 2)
check(not a.fleeing, "tres civis juntos nao fogem de tres zumbis")
check(b.z.path ~= nil or b.attackTarget ~= nil or b.nextAttack > T.clock, "e os outros vem ajudar quem esta sendo atacado")
b.fleeing = true
check(near(TC.power(a), 1 + TC.CFG.ALLY_WEIGHT), "quem esta fugindo nao conta como apoio")
b.fleeing = false
local raider = Rem.spawn(41303, 41003, 0, { faction = "saqueadores", mode = "stay" })
check(near(TC.power(a), 1 + 2 * TC.CFG.ALLY_WEIGHT), "inimigo nao conta como apoio")
Rem.dismiss(raider)
player.x, player.y = 41300, 41003
check(near(TC.power(a), 1 + 2 * TC.CFG.ALLY_WEIGHT + TC.CFG.PLAYER_WEIGHT), "voce por perto tambem da coragem")

-- ninguem deixa o outro apanhar sozinho
fresh()
local victim = person(41350, 41000, "civis", 5)
local helper = person(41354, 41000, "civis", 5)
local biter = T.newZombie(41351, 41000, 0, -1, 0)     -- de costas para o ajudante, em cima da vitima
biter.canSee = false
Rem.startHunt(biter, victim, T.clock)
helper.z.path, helper.attackTarget = nil, nil
tick(300, 2)
check(helper.z.path ~= nil and math.abs(helper.z.path[1] - biter.x) < 1.5, "zumbi atacando um companheiro por perto: ele vai ajudar")

realPrint("173) Ferido, sem moral, em casa, veterano")
fresh()
local n = person(41400, 41000, "sobreviventes", 6)
local base = TC.nerve(n)
n.z.hp = n.rec.maxHealth * 0.4
check(TC.nerve(n) < base, "ferido tem menos nervo")
n.z.hp = n.rec.maxHealth
n.rec.moral = 10
check(TC.nerve(n) < base, "moral baixo tambem pesa")
n.rec.moral = 50
n.rec.level = 3
check(math.abs(TC.nerve(n) - base * (1 + 3 * TC.CFG.LEVEL_BONUS)) < 0.001, "veterano e mais firme")
n.rec.level = 0
local def = T.addBuilding(41501, 41500, 41000, 10, 8)
local g = Rem.createGroup("civis", 41505, 41004, "41501", 2, def)
player.x, player.y = 41505, 41010
local home = Rem.materialize(Rem.getPerson(g.members[1]))
home.rec.moral = 50
home.z.x, home.z.y = 41505, 41004
local inside = TC.nerve(home)
check(TC.atHome(home), "(cenario) dentro de casa")
home.z.x = 41560
check(not TC.atHome(home) and math.abs(inside - TC.nerve(home) * TC.CFG.HOME_BONUS) < 0.001, "defendendo a casa, todo mundo e mais valente")

realPrint("174) Humanos hostis pesam mais; fugindo, so volta com folga")
fresh()
local civ = person(41600, 41000, "civis", 4)
local thug = Rem.spawn(41603, 41000, 0, { faction = "saqueadores", mode = "stay" })
check(TC.threat(civ, thug.z) == TC.CFG.HUMAN_THREAT and TC.decide(civ, thug.z, 3, T.clock) == "flee", "um civil sozinho foge de um saqueador")
local f1 = person(41601, 41001, "civis", 4)
local f2 = person(41599, 41001, "civis", 4)
check(TC.decide(civ, thug.z, 3, T.clock) == "fight", "tres civis juntos enfrentam um saqueador")
Rem.dismiss(f1)
civ.crowd = 0
local cap = TC.capacity(civ)
Rem.dismiss(thug)
civ.crowd = math.floor(cap)                 -- no limite do que aguenta
check(TC.decide(civ, nil, 0, T.clock) == "fight", "no limite: fica")
civ.fleeing = true
check(TC.decide(civ, nil, 0, T.clock) == "flee", "mas quem ja fugiu so volta quando o perigo cai com folga")
civ.crowd = 0
check(TC.decide(civ, T.newZombie(41600, 41002, 0), 2, T.clock) == "fight", "perigo menor: volta a lutar")
fresh()
