-- NPC derrubado (no chao, levantando, cambaleando) nao pode atacar nem atirar.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print

local function playerDamage()
    local total = 0
    for _, p in pairs(T.parts) do total = total + (p.damage or 0) end
    return total
end

realPrint("60) Derrubado nao bate")
SandboxVars.Remanescentes.RaiderMugging = false
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
player.x, player.y = 8000, 8001
local thug = Rem.spawn(8000, 8000, 0, { faction = "saqueadores", mode = "wander", archetype = "brigao" })
thug.nextAttack = 0
for k in pairs(T.parts) do T.parts[k] = nil end
thug.z.onFloor = true
thug.z.state = "onground"
tick(300); tick(100, 30)
check(playerDamage() == 0 and thug.z.vars.RemAttack ~= true, "no chao: nao ataca")

realPrint("61) Caiu no meio do golpe: o golpe nao acerta")
thug.z.onFloor = false
thug.z.state = "idle"
thug.nextAttack = 0
tick(300)
check(thug.attackUntil > 0, "(cenario) de pe: comecou um golpe")
thug.z.onFloor = true
thug.z.state = "staggerback"
tick(100, 10)
check(playerDamage() == 0, "derrubado antes do impacto: sem dano")
check(thug.attackUntil == 0 and thug.z.vars.RemAttack == false, "golpe cancelado")

realPrint("61b) Caiu entre um pensamento e o impacto do golpe")
thug.z.onFloor = false
thug.z.state = "idle"
thug.nextAttack = 0
tick(300)
check(thug.hitAt > 0, "(cenario) golpe a caminho")
thug.nextThink = T.clock + 999999   -- o cerebro nao pensa de novo antes do impacto
thug.z.onFloor = true
thug.z.state = "onground"
tick(100, 6)
check(playerDamage() == 0, "o impacto de um golpe de quem ja caiu nao conta")
thug.nextThink = 0

realPrint("62) Levantando tambem nao bate; de pe volta a lutar")
thug.z.onFloor = false
thug.z.state = "getup"
tick(300); tick(100, 15)
check(playerDamage() == 0, "levantando: nao ataca")
thug.z.state = "idle"
thug.nextAttack = 0
tick(300); tick(100, 15)
check(playerDamage() > 0, "de pe de novo: volta a atacar")

realPrint("63) Atirador derrubado nao atira")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local gunner = Rem.spawn(8100, 8100, 0, { faction = "saqueadores", mode = "wander", archetype = "atirador" })
gunner.rec.firearm, gunner.rec.ammo = "Base.Pistol", 10
player.x, player.y = 8100, 8107
gunner.z.onFloor = true
gunner.z.state = "onground"
tick(300); tick(100, 30)
check(gunner.rec.ammo == 10, "no chao: nao atira")
Rem.dismissAll()
SandboxVars.Remanescentes.RaiderMugging = nil
