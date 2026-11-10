-- Fase 3 completa: entrada garantida, portas dos moradores, saque real, estoque vivo,
-- sinais de vida (placa, caveira, barril, gerador, fogueira), tiro dos atiradores, sono.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print

local function scene() Rem.emit("sceneUpdate", player, Rem.nowMs()) end
local function countItems(objs)
    local n = 0
    for _, o in ipairs(objs) do n = n + #o.container.items end
    return n
end

-- casa falsa: interior com comodo; devolve o def
local function house(id, x, y, w, h)
    local def = T.addBuilding(id, x, y, w, h)
    for i = x, x + w - 1 do
        for j = y, y + h - 1 do
            T.indoorSq[i .. "," .. j] = true
            T.sqBuilding[i .. "," .. j] = def
        end
    end
    return def
end

realPrint("50) Sempre ha uma entrada")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local dNo = house(7001, 7000, 7000, 8, 6)
local wins = {}
for i = 0, 3 do table.insert(wins, T.addObject(7001 + i * 2, 7000, 0, "IsoWindow", { exterior = true })) end
local southWin = T.addObject(7004, 7005, 0, "IsoWindow", { exterior = true })
local gNo = Rem.createGroup("seita", 7004, 7003, "7001", 4, dNo)   -- seita barrica quase tudo
player.x, player.y = 7004, 7020
scene()
check(gNo.home.fortified, "(cenario) casa sem porta preparada")
check(southWin.barricade == nil and gNo.home.entrance and gNo.home.entrance.window, "sem porta: a janela mais ao sul fica livre como entrada")
local others = 0
for _, w in ipairs(wins) do if w.barricade then others = others + 1 end end
check(others >= 3, "as outras janelas sao barricadas (" .. others .. "/4)")

realPrint("51) Moradores abrem, passam e trancam a porta")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local dD = house(7101, 7100, 7100, 10, 8)
local door = T.addObject(7105, 7107, 0, "IsoDoor", { exterior = true })
T.addObject(7102, 7102, 0, "container", { type = "fridge" })
local gD = Rem.createGroup("sobreviventes", 7105, 7104, "7101", 3, dD)   -- milicia: neutra, tranca
player.x, player.y = 7105, 7130
scene()
check(door.locked and not door.open and gD.home.mainDoor, "(cenario) porta principal trancada")
local walker = Rem.materialize(Rem.getPerson(gD.members[3]))
walker.z.x, walker.z.y = 7105.5, 7105.9
walker.moving = true; walker.z.vars.bPathfind = true
T.clock = T.clock + 400; Rem.Safehouse.manageDoors(T.clock)
check(door.open and not door.locked, "morador andando ate a porta: destranca e abre")
walker.z.x, walker.z.y = 7105.5, 7112
T.clock = T.clock + 400; Rem.Safehouse.manageDoors(T.clock)
check(door.open, "nao fecha na cara de quem acabou de passar")
T.clock = T.clock + 3000; Rem.Safehouse.manageDoors(T.clock)
check(not door.open and door.locked, "depois que passou: fecha e tranca")
walker.moving = false; walker.z.vars.bPathfind = false
walker.z.x, walker.z.y = 7105.5, 7106.2   -- parado colado na porta (guarda)
T.clock = T.clock + 3000; Rem.Safehouse.manageDoors(T.clock)
check(not door.open, "morador parado perto nao abre a porta")
-- grupo amigavel: porta fechada mas destrancada para voce
Rem.changeRep(gD.id, 100, "teste")
walker.z.x, walker.z.y = 7105.5, 7105.9
walker.moving = true; walker.z.vars.bPathfind = true
T.clock = T.clock + 400; Rem.Safehouse.manageDoors(T.clock)
walker.moving = false; walker.z.vars.bPathfind = false
walker.z.x, walker.z.y = 7105.5, 7112
T.clock = T.clock + 3000; Rem.Safehouse.manageDoors(T.clock)
check(not door.open and not door.locked, "grupo amigavel: porta fechada, mas destrancada para voce")

realPrint("51b) Save antigo e casa barricada pelo jogo")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local dOld = house(7151, 7150, 7150, 10, 8)
local vDoor = T.addObject(7155, 7157, 0, "IsoDoor", { exterior = true })
local vDoor2 = T.addObject(7158, 7150, 0, "IsoDoor", { exterior = true })
-- o jogo barricou as duas portas por fora
for _, d in ipairs({ vDoor, vDoor2 }) do
    local b = { planks = 3 }
    d.barricade, d.barricadeOpposite = b, true
    function d:getBarricadeOnSameSquare() return nil end
    function d:getBarricadeOnOppositeSquare() return self.barricade end
    function b:getSquare() return { transmitRemoveItemFromSquare = function() d.barricade = nil end } end
end
T.addObject(7152, 7152, 0, "container", { type = "fridge" })
local inside1 = T.newZombie(7153, 7153, 0)
local inside2 = T.newZombie(7157, 7155, 0)
local outsideZ = T.newZombie(7155, 7170, 0)
-- grupo "antigo": sem retangulo da casa (como na 0.3.0)
local gOld = Rem.createGroup("civis", 7155, 7154, "7151", 2)
check(gOld.home.x1 == nil, "(cenario) grupo de save antigo, sem retangulo")
player.x, player.y = 7155, 7185
scene()
check(gOld.home.x1 == 7150 and gOld.home.x2 == 7160, "retangulo recuperado pelo ID do predio")
check(gOld.home.fortified and gOld.home.stocked, "casa de save antigo e preparada")
check(gOld.home.mainDoor and vDoor.barricade == nil, "porta principal: tabuas do jogo removidas (entrada livre)")
check(vDoor2.barricade ~= nil, "outra porta continua barricada")
check(not inside1.inWorld and not inside2.inWorld, "zumbis dentro da casa removidos (os moradores limparam)")
check(outsideZ.inWorld, "zumbi do lado de fora continua")
local gPos = Rem.createGroup("civis", 7155, 7154, nil, 1)
Rem.Safehouse.fillRect(gPos.home)
check(gPos.home.x1 == nil or gPos.home.bid ~= nil, "sem bid: tenta achar o predio pela posicao")

realPrint("51c) Recriar grupos do mundo")
local keep = Rem.spawn(7160, 7190, 0, { faction = "aliados", mode = "follow" })
T.addBuilding(7171, 7300, 7400, 8, 8)
T.addBuilding(7172, 7420, 7200, 8, 8)
SandboxVars.Remanescentes.WorldGroups = 2
local bpg9, rural9 = Rem.Regions.CFG.BUILDINGS_PER_GROUP, Rem.Regions.CFG.RURAL_BELOW
Rem.Regions.CFG.BUILDINGS_PER_GROUP, Rem.Regions.CFG.RURAL_BELOW = 1, 0
local n = Rem.reseedWorld(player)
Rem.Regions.CFG.BUILDINGS_PER_GROUP, Rem.Regions.CFG.RURAL_BELOW = bpg9, rural9
local stale = false
for _, g in pairs(Rem.getStore().groups) do if g.id == gOld.id then stale = true end end
check(not stale and n >= 1, "grupos antigos trocados por novos (" .. n .. ")")
check(Rem.getPerson(keep.rec.id) ~= nil and Rem.active[keep.z], "seus aliados ficam")
local rectsOk = true
for _, g in pairs(Rem.getStore().groups) do if not g.home.x1 then rectsOk = false end end
check(rectsOk, "grupos novos ja nascem com o retangulo da casa")
SandboxVars.Remanescentes.WorldGroups = 0

realPrint("52) Sinais de vida")
local SG = Rem.Signals
local savedPlan = SG.PLAN.sobreviventes
SG.PLAN.sobreviventes = { sign = 100, signText = { "keepout" }, skull = 100, barrel = 100, generator = 100, campfire = 100 }
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local dS = house(7201, 7200, 7200, 10, 8)
T.addObject(7205, 7207, 0, "IsoDoor", { exterior = true })
local gS = Rem.createGroup("sobreviventes", 7205, 7204, "7201", 3, dS)
player.x, player.y = 7205, 7230
T.timeOfDay = 12
scene()
local decor = gS.home.decor
check(decor and decor.sign and decor.skull and decor.barrel and decor.generator and decor.campfire, "placa, caveira, barril, gerador e fogueira")
local outside = true
for _, k in ipairs({ "sign", "skull", "barrel", "generator", "campfire" }) do
    local d = decor[k]
    if T.indoorSq[d.x .. "," .. d.y] then outside = false end
end
check(outside, "tudo do lado de fora da casa")
local function hasSprite(d, sprite)
    for _, o in ipairs(T.sqObjects[d.x .. "," .. d.y .. ",0"] or {}) do if o.sprite == sprite then return true end end
    return false
end
check(hasSprite(decor.sign, SG.SPRITES.sign) and hasSprite(decor.skull, SG.SPRITES.skull) and hasSprite(decor.barrel, SG.SPRITES.barrel),
    "objetos colocados no mapa")
player.x, player.y = decor.sign.x + 0.5, decor.sign.y + 1.5
scene()
check(T.halo[#T.halo] == "IGUI_Rem_Sign_keepout", "chegou perto: le a placa")
local nHalo = #T.halo
scene()
check(#T.halo == nHalo, "nao repete a leitura a cada segundo")
player.x, player.y = 7205, 7230
local gen = T.generators[#T.generators]
scene()
check(gen and not gen.active, "de dia o gerador fica desligado")
local fire = T.campfires[decor.campfire.x .. "," .. decor.campfire.y]
check(fire and fire.isLit, "de dia, com gente em casa: fogueira acesa no quintal")
T.timeOfDay = 22
scene()
check(gen.active, "a noite, com gente em casa: gerador ligado")
gS.activity = "scavenge"
scene()
check(not gen.active, "casa vazia: gerador desligado")
gS.activity = "home"; T.timeOfDay = 12
SG.PLAN.sobreviventes = savedPlan

realPrint("53) Saque de verdade: ir, abrir armario, pegar, voltar, guardar")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local dH = house(7301, 7300, 7300, 10, 8)
T.addObject(7305, 7307, 0, "IsoDoor", { exterior = true })
local stashBox = T.addObject(7302, 7302, 0, "container", { type = "fridge" })
local dT = house(7401, 7400, 7300, 8, 6)            -- predio alvo, a 100 tiles
local cab = T.addObject(7402, 7302, 0, "container", { type = "counter" })
local gH = Rem.createGroup("civis", 7305, 7304, "7301", 3, dH)
gH.supplies = 3
player.x, player.y = 7350, 7310
scene()
check(gH.home.stocked and #gH.home.stash >= 1, "(cenario) casa com estoque")
gH.activity = "scavenge"
gH.target = { x = 7404, y = 7303, z = 0, bid = "7401", x1 = 7400, y1 = 7300, x2 = 7408, y2 = 7306 }
local guardP, looterP
for _, id in ipairs(gH.members) do
    local p = Rem.getPerson(id)
    if p.role == "guarda" then guardP = p elseif p.role == "morador" then looterP = p end
end
local guard = Rem.materialize(guardP)
local looter = Rem.materialize(looterP)
guard.z.x, guard.z.y = 7305, 7304
looter.z.x, looter.z.y = 7404, 7304
tick(300)
check(not (guard.z.path and guard.z.path[1] > 7350), "o guarda fica tomando conta da casa")
check(looter.z.path and math.floor(looter.z.path[1]) == 7402 and math.floor(looter.z.path[2]) == 7302, "saqueador vai ate o armario")
looter.z.x, looter.z.y = 7402.5, 7302.5
local filled0 = T.filled
tick(300)
check(#cab.container.items == 0 and not cab.container.explored, "(antes) armario ainda fechado, sem loot gerado")
tick(300, 10)   -- revirando
check(T.filled == filled0 + 1 and cab.container.explored, "abriu o armario: loot gerado como para o jogador")
local carry = looter.rec.carry or {}
local gotFood, gotSofa = false, false
for _, ft in ipairs(carry) do
    if ft == "Base.TinnedBeans" then gotFood = true end
    if ft == "Base.Sofa" then gotSofa = true end
end
check(gotFood and not gotSofa, "pega comida/remedio, deixa o que nao serve (" .. table.concat(carry, ",") .. ")")
check(#cab.container.items == 1, "os itens sairam de verdade do armario")
tick(300, 4)
check(looter.lootDoneBid == "7401", "sem mais armarios: espera o grupo")
-- volta para casa e guarda
gH.activity = "home"
gH.target = nil
local sup0 = gH.supplies
local stash0 = countItems({ stashBox })
looter.z.x, looter.z.y = 7305, 7304
tick(300)
check(looter.rec.carry == nil, "chegou em casa: guardou o que trouxe")
check(countItems({ stashBox }) == stash0 + #carry, "itens apareceram no estoque")
check(math.abs(gH.supplies - (sup0 + #carry / 2)) < 0.01, "suprimentos do grupo sobem (2 itens = 1 pessoa-dia)")

realPrint("54) Estoque vivo: consumo, saque fora de cena, roubo")
local SC = Rem.Scavenge
gH.supplies = 1
SC.syncStash(gH)
local n1 = countItems({ stashBox })
check(n1 <= 1 * 2 + SC.CFG.CONSUME_SLACK, "o grupo comeu: estoque cai para o que os suprimentos justificam (" .. n1 .. ")")
gH.pendingItems = 4
gH.supplies = gH.supplies + 2
SC.syncStash(gH)
check(countItems({ stashBox }) == n1 + 4 and gH.pendingItems == 0, "saque feito fora de cena aparece no estoque")
local supB = gH.supplies
table.remove(stashBox.container.items)
table.remove(stashBox.container.items)
SC.syncStash(gH)
check(math.abs(gH.supplies - (supB - 1)) < 0.01, "itens levados do estoque somem dos suprimentos do grupo")
check(gH.home.stashCount == countItems({ stashBox }), "consumo nao conta como roubo (contador sincronizado)")

realPrint("55) Saem para saquear de tempos em tempos, mesmo com comida")
local W = Rem.World
local odds = W.CFG.ROUTINE_SCAVENGE_ODDS
W.CFG.ROUTINE_SCAVENGE_ODDS = 1
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
T.addBuilding(7501, 7500, 7500, 8, 8)
local gR = Rem.createGroup("civis", 7450, 7500, nil, 3)
gR.supplies = 50
Rem.simulateWorld(1)
check(gR.activity == "scavenge" and gR.target and gR.target.x1, "com estoque cheio ainda saem para saquear (alvo com retangulo)")
W.CFG.ROUTINE_SCAVENGE_ODDS = odds

realPrint("56) Atirador")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
player.x, player.y = 7600, 7600
local ally = Rem.spawn(7600, 7601, 0, { faction = "aliados", mode = "stay", archetype = "atirador" })
ally.rec.firearm, ally.rec.ammo = "Base.Pistol", 10
ally.rec.homeX, ally.rec.homeY = 7600, 7601
local z1 = T.newZombie(7600, 7607, 0, 0, -1)
Rem.hunting[z1] = { npc = ally, lastSeen = T.clock, nextPath = T.clock + 99999, real = false }
T.sounds = {}
tick(300); tick(100, 12)
check(ally.rec.ammo == 10 and not ally.gunOut, "um zumbi so: amigo nao atira (barulho atrai mais)")
local z2 = T.newZombie(7601, 7605.5, 0, 0, -1)
local z3 = T.newZombie(7599, 7605.5, 0, 0, -1)
Rem.hunting[z2] = { npc = ally, lastSeen = T.clock, nextPath = T.clock + 99999, real = false }
Rem.hunting[z3] = { npc = ally, lastSeen = T.clock, nextPath = T.clock + 99999, real = false }
ally.nextAttack = T.clock + 9999999
local hp2 = z2.hp
local minHit0 = Rem.Ranged.CFG.MIN_HIT
Rem.Ranged.CFG.MIN_HIT = 100   -- sorteio do mock e um contador; aqui interessa o efeito do acerto
tick(300)
check(ally.gunOut and ally.z.vars.RemGun == "handgun" and ally.z.vars.RemAim == true, "varios zumbis: saca a pistola e mira")
tick(100, 40)
check(ally.rec.ammo < 10, "atira (municao gasta: " .. ally.rec.ammo .. ")")
local loud = false
for _, snd in ipairs(T.sounds) do if snd.radius >= 100 then loud = true end end
check(loud, "o tiro faz barulho de verdade (raio 100)")
check(z2.dead or z2.hp < hp2 or z3.dead or z1.dead, "acerta zumbis")
Rem.Ranged.CFG.MIN_HIT = minHit0
-- sem municao
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
SandboxVars.Remanescentes.RaiderMugging = false   -- aqui interessa o tiro (assalto: test_11)
local raider = Rem.spawn(7700, 7700, 0, { faction = "saqueadores", mode = "wander", archetype = "atirador" })
raider.z.fx, raider.z.fy = 0, 1   -- de frente para voce (de costas nao te ve)
raider.rec.firearm, raider.rec.ammo = "Base.Pistol", 6
raider.nextAttack = T.clock + 9999999
player.x, player.y = 7700, 7707
for k, part in pairs(T.parts) do T.parts[k] = nil end
local minHit = Rem.Ranged.CFG.MIN_HIT
Rem.Ranged.CFG.MIN_HIT = 100   -- o sorteio do mock e um contador; aqui interessa o ferimento
tick(300); tick(100, 80)
Rem.Ranged.CFG.MIN_HIT = minHit
local shot = false
for _, part in pairs(T.parts) do if part.bullet then shot = true end end
check(raider.rec.ammo < 6, "hostil atira em voce (municao " .. raider.rec.ammo .. ")")
check(shot, "voce leva ferimento a bala (bala alojada)")
raider.rec.ammo = 1
raider.nextShot = 0
tick(300); tick(100, 20)
check(raider.rec.ammo == 0 and not raider.gunOut and T.saidPrefix(raider.z, "IGUI_Rem_Bark_noammo_"), "acabou a municao: guarda a arma e avisa")
-- recua quando o inimigo chega perto demais
raider.rec.ammo = 5
player.x, player.y = 7700, 7702.2
raider.z.x, raider.z.y = 7700, 7700
raider.shootUntil = nil
tick(300)
check(raider.z.path and raider.z.path[2] < 7700, "inimigo perto demais: recua para atirar")

realPrint("57) Dormir a noite, sentar de dia")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local dZ = house(7801, 7800, 7800, 8, 6)
local gZ = Rem.createGroup("civis", 7804, 7803, "7801", 3, dZ)
player.x, player.y = 7804, 7830
local sleeperP
for _, id in ipairs(gZ.members) do local p = Rem.getPerson(id) if p.role == "morador" then sleeperP = p end end
local sleeper = Rem.materialize(sleeperP)
T.timeOfDay = 23
tick(300)
local spot = sleeperP.indoorSpot
check(spot ~= nil, "(cenario) canto para dormir")
sleeper.z.x, sleeper.z.y = spot.x + 0.5, spot.y + 0.5
sleeper.moving = false; sleeper.z.vars.bPathfind = false
tick(300)
check(sleeper.rest == "sleep" and sleeper.z.vars.RemRest == "sleep", "chegou no canto a noite: deita para dormir")
T.timeOfDay = 9
tick(300); tick(300)
check(sleeper.rest ~= "sleep", "amanheceu: levanta")
Rem.moveTo(sleeper, sleeper.z.x + 3, sleeper.z.y, 0, T.clock + 99999, "walk")
check(sleeper.rest == nil and sleeper.z.vars.RemRest == "", "andar desfaz a pose de descanso")

realPrint("58) Armas de duas maos usam animacao que existe")
local bad = 0
for _ = 1, 40 do
    local r = Rem.newPerson({ faction = "civis", archetype = "brigao" })
    if r.wtype ~= "1h" and r.wtype ~= "bat" then bad = bad + 1 end
    Rem.removePerson(r.id)
end
check(bad == 0, "nenhuma arma com tipo de animacao inexistente")
T.timeOfDay = 12
Rem.dismissAll()
