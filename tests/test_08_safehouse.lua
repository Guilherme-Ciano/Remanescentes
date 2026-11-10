-- Fase 3: safehouses (Rem_Safehouse) e papeis dos moradores (Rem_Roles).
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print

local function scene() Rem.emit("sceneUpdate", player, Rem.nowMs()) end

-- casa falsa 10x8 em (5000, 5000): interior com comodo, janelas e portas nas bordas
local HX, HY, HW, HH = 5000, 5000, 10, 8
local def = T.addBuilding(999, HX, HY, HW, HH)
for x = HX, HX + HW - 1 do
    for y = HY, HY + HH - 1 do
        T.indoorSq[x .. "," .. y] = true
        T.sqBuilding[x .. "," .. y] = def
    end
end
local windows = {}
for i = 0, 4 do
    table.insert(windows, T.addObject(HX + 1 + i * 2, HY, 0, "IsoWindow", { exterior = true }))     -- norte
end
local interiorWindow = T.addObject(HX + 4, HY + 4, 0, "IsoWindow", { exterior = false })
local southDoor = T.addObject(HX + 5, HY + HH - 1, 0, "IsoDoor", { exterior = true, open = true })
local northDoor = T.addObject(HX + 8, HY, 0, "IsoDoor", { exterior = true })
local fridge = T.addObject(HX + 2, HY + 2, 0, "container", { type = "fridge" })
local counter = T.addObject(HX + 3, HY + 2, 0, "container", { type = "counter" })
local closet = T.addObject(HX + 7, HY + 5, 0, "container", { type = "wardrobe" })

realPrint("40) Grupo com papeis")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
player.x, player.y = 5300, 5300   -- longe: nada acontece ainda
local g = Rem.createGroup("sobreviventes", HX + 5, HY + 4, "999", 4, def)
g.supplies = 5
local roles = {}
for _, id in ipairs(g.members) do local p = Rem.getPerson(id) roles[p.role] = (roles[p.role] or 0) + 1 end
check(roles.guarda == 1 and roles.cozinheiro == 1 and roles.morador == 2, "1 guarda, 1 cozinheiro, 2 moradores")
check(g.home.x1 == HX and g.home.x2 == HX + HW, "casa guarda o retangulo")

realPrint("41) Casa preparada quando o jogador chega perto")
scene()
check(not g.home.fortified, "longe: casa ainda nao preparada")
player.x, player.y = HX + 5, HY + HH + 20
scene()
check(g.home.fortified and g.home.stocked, "perto: casa preparada")
local barricaded = 0
for _, w in ipairs(windows) do if w.barricade then barricaded = barricaded + 1 end end
check(barricaded >= 3, "milicia barrica a maioria das janelas (" .. barricaded .. "/5)")
check(interiorWindow.barricade == nil, "janela interna nao e barricada")
local inside = true
for _, w in ipairs(windows) do if w.barricade and w.barricadeOpposite ~= false then inside = false end end
check(inside, "barricada fica do lado de dentro")
check(not southDoor.open and southDoor.locked and southDoor.barricade == nil, "porta principal (sul): fechada e trancada")
check(g.home.mainDoor and g.home.mainDoor.y == HY + HH - 1, "porta principal registrada")
check(northDoor.barricade ~= nil or northDoor.locked, "outra porta: barricada ou trancada")
local items = #fridge.container.items + #counter.container.items + #closet.container.items
check(items >= Rem.Safehouse.CFG.STASH_MIN_ITEMS, "estoque guardado nos conteineres (" .. items .. " itens)")
check(fridge.container.explored, "conteiner do estoque marcado como explorado (o jogo nao gera loot por cima)")
check(#g.home.stash >= 1, "posicao do estoque registrada")
local hasAmmo = false
for _, c in ipairs({ fridge, counter, closet }) do
    for _, it in ipairs(c.container.items) do if it.id:find("Bullets") or it.id:find("Shells") or it.id:find("308") or it.id == "Base.Pistol" or it.id == "Base.Shotgun" then hasAmmo = true end end
end
check(hasAmmo, "milicia guarda armas/municao")
check(Rem.getStore().looted["999"] ~= nil, "resto da casa conta como saqueado (moradores consumiram)")
check(#T.corpses >= 2, "corpos de zumbis empilhados na frente (" .. #T.corpses .. ")")
local corpsesOutside = true
for _, c in ipairs(T.corpses) do if T.indoorSq[c.x .. "," .. c.y] then corpsesOutside = false end end
check(corpsesOutside, "corpos ficam do lado de fora")
local before = #T.corpses
scene()
check(#T.corpses == before, "preparar so uma vez")

realPrint("42) Luz a noite")
T.timeOfDay = 22
scene()
local lit = 0
for _ in pairs(T.lights) do lit = lit + 1 end
check(lit == 1, "noite: luz acesa na casa")
T.timeOfDay = 12
scene()
lit = 0
for _ in pairs(T.lights) do lit = lit + 1 end
check(lit == 0, "dia: luz apagada")

realPrint("43) Papeis em cena")
-- moradores em cena
player.x, player.y = HX + 5, HY + HH + 10
local guardNpc, cookNpc
for _, id in ipairs(g.members) do
    local p = Rem.getPerson(id)
    local npc = Rem.materialize(p)
    if p.role == "guarda" then guardNpc = npc elseif p.role == "cozinheiro" then cookNpc = npc end
end
guardNpc.z.x, guardNpc.z.y = HX + 1, HY + 1
cookNpc.z.x, cookNpc.z.y = HX + 8, HY + 6
tick(300)
check(guardNpc.z.path and math.floor(guardNpc.z.path[1]) == HX + 5 and math.floor(guardNpc.z.path[2]) == HY + HH - 2,
    "guarda vai para a porta principal (posto do lado de dentro)")
check(cookNpc.z.path and math.floor(cookNpc.z.path[1]) == HX + 2 and math.floor(cookNpc.z.path[2]) == HY + 2,
    "cozinheiro vai para a cozinha (geladeira)")
T.timeOfDay = 23
cookNpc.rec.indoorSpot = nil
tick(300)
check(cookNpc.rec.indoorSpot ~= nil and T.indoorSq[cookNpc.rec.indoorSpot.x .. "," .. cookNpc.rec.indoorSpot.y],
    "a noite o cozinheiro fica dentro de casa")
T.timeOfDay = 12

realPrint("44) Porta: quem trava abre; tranca so para morador")
local door2 = T.addObject(5200, 5200, 0, "IsoDoor", { exterior = true, locked = true })
local outsider = Rem.spawn(5200, 5201, 0, { faction = "civis", mode = "wander" })
outsider.moving = true; outsider.z.vars.bPathfind = true
scene(); scene()
check(not door2.open, "porta trancada de outro predio: estranho nao abre")
door2.locked = false
scene()
check(door2.open, "porta destrancada: sobrevivente travado abre")
southDoor.open = false; southDoor.locked = true
guardNpc.z.x, guardNpc.z.y = HX + 5, HY + HH - 2
guardNpc.moving = true; guardNpc.z.vars.bPathfind = true
T.sqBuilding[(HX + 5) .. "," .. (HY + HH - 1)] = def
scene(); scene()
check(southDoor.open, "morador tem a chave da propria casa")

realPrint("45) Medico cura companheiro")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
player.x, player.y = 5600, 5600
local mg = Rem.createGroup("civis", 5610, 5610, nil, 2)
local medic = Rem.materialize(Rem.getPerson(mg.members[1]))
local hurt = Rem.materialize(Rem.getPerson(mg.members[2]))
medic.rec.archetype = "medico"
hurt.rec.archetype = "brigao"
medic.z.x, medic.z.y = 5610, 5610
hurt.z.x, hurt.z.y = 5614, 5610
hurt.z.hp = hurt.rec.maxHealth * 0.3
tick(300)
check(medic.z.path and math.floor(medic.z.path[1]) == 5614, "medico vai ate o ferido")
medic.z.x = 5613.5
local hp0 = hurt.z.hp
tick(300)
check(hurt.z.hp > hp0 and T.saidPrefix(medic.z, "IGUI_Rem_Bark_heal_"), "medico cura e avisa")

realPrint("46) Ser visto mexendo no estoque")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local g2 = Rem.createGroup("civis", HX + 5, HY + 4, "999", 2, def)
g2.home.fortified, g2.home.stocked = false, false
fridge.container.items = {}; counter.container.items = {}; closet.container.items = {}
fridge.container.explored = false
player.x, player.y = HX + 5, HY + 3
scene()
check(g2.home.stocked, "(cenario) casa dos civis preparada")
local witness = Rem.materialize(Rem.getPerson(g2.members[1]))
witness.z.x, witness.z.y = HX + 6, HY + 3
scene()  -- conta o estoque
local rep0 = Rem.getRep(g2.id)
local stolenFrom = nil
for _, c in ipairs({ fridge, counter, closet }) do if #c.container.items > 0 then stolenFrom = c end end
table.remove(stolenFrom.container.items)
scene()
check(Rem.getRep(g2.id) == rep0 - 15, "visto roubando: -15")
check(T.saidPrefix(witness.z, "IGUI_Rem_Bark_thief_"), "grita ladrao")
check(witness.rec.hostileToPlayer == true, "grupo fica com raiva")
Rem.dismissAll()
