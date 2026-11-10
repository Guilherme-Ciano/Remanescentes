-- Menu de clique direito (secao 15). Deixa T.newMenu/T.openMenu/T.findOpt para outros testes.
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie, square = T.check, T.tick, T.fire, T.newZombie, T.square
local clearZombies, saidPrefix, addBuilding = T.clearZombies, T.saidPrefix, T.addBuilding
local player, parts, logs, store, events = T.player, T.parts, T.logs, T.store, T.events
local realPrint = T.print

realPrint("15) Menu de clique direito")
T.menus = {}
function T.newMenu()
    local m = { options = {} }
    function m:addOption(name, target, fn, ...) local o = { name = name, target = target, fn = fn, args = { ... } }
        table.insert(self.options, o); return o end
    function m:addSubMenu(opt, sub) opt.sub = sub end
    table.insert(T.menus, m)
    return m
end
ISContextMenu = { getNew = function(_, parent) return T.newMenu() end }
require "Remanescentes/Rem_ContextMenu"
T.menuFn = events.OnFillWorldObjectContextMenu and events.OnFillWorldObjectContextMenu.list[1]
check(T.menuFn ~= nil, "menu registrado")
function T.findOpt(m, name)
    for _, o in ipairs(m.options) do if o.name == name then return o end end
end
function T.openMenu(x, y)
    local ctx = T.newMenu()
    local sq = square(x, y, 0)
    local ok, err = pcall(T.menuFn, 0, ctx, { { getSquare = function() return sq end } }, false)
    return ok, err, ctx
end
Rem.dismissAll(); clearZombies()
local ok1, err1, ctx1 = T.openMenu(50, 50)
check(ok1, "abrir menu sem ninguem perto nao da erro " .. tostring(err1 or ""))
local root1 = T.findOpt(ctx1, "ContextMenu_Rem_Title")
check(root1 and root1.sub and T.findOpt(root1.sub, "ContextMenu_Rem_Debug") ~= nil, "menu tem ferramentas de teste")
local ally2 = Rem.spawn(60, 60, 0, { faction = "aliados", mode = "follow" })
local ok2, err2, ctx2 = T.openMenu(60, 60)
check(ok2, "abrir menu perto de um aliado nao da erro " .. tostring(err2 or ""))
local root2 = T.findOpt(ctx2, "ContextMenu_Rem_Title")
local hasAllyEntry = false
for _, o in ipairs(root2.sub.options) do if o.sub and T.findOpt(o.sub, "ContextMenu_Rem_Follow") then hasAllyEntry = true end end
check(hasAllyEntry, "aliado perto aparece no menu com ordens")
local dbg = T.findOpt(root2.sub, "ContextMenu_Rem_Debug").sub
for _, o in ipairs(dbg.options) do
    if o.name == "ContextMenu_Rem_NearestGroup" or o.name == "ContextMenu_Rem_ListGroups" then
        local okc, errc = pcall(o.fn, o.target, unpack(o.args))
        check(okc, o.name .. " roda sem erro " .. tostring(errc or ""))
    end
end
