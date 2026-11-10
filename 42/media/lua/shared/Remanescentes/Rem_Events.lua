-- Remanescentes - barramento de eventos interno do mod.
--
-- Modulos novos (encontros, safehouses, necessidades...) reagem ao que acontece sem
-- precisar mexer no codigo dos outros:
--
--   Rem.on("npcDied", function(npc) ... end)
--   Rem.off("npcDied", fn)
--   Rem.emit("meuEvento", a, b)
--
-- Cada handler roda protegido (Rem.safe): erro em um nao impede os outros.
--
-- Eventos emitidos pelo mod:
--   npcActivated(npc)        fim de Rem.activate (corpo ganhou o modo humano)
--   npcDeactivated(npc)      Rem.deactivate (corpo saiu de cena, morreu ou foi removido)
--   npcDied(npc)             OnZombieDead de um sobrevivente, antes de remover a pessoa
--   personCreated(rec, opts) Rem.newPerson (opts = tabela recebida por newPerson)
--   personRemoved(rec)       Rem.removePerson (e Rem.dismissAll)
--   groupCreated(g, def)     Rem.createGroup, com g.members ja preenchido (def = BuildingDef ou nil)
--   groupRemoved(g)          grupo acabou (Rem.simulateWorld) ou Rem.dismissAll
--   worldHour(hour)          depois de cada hora simulada em Rem.simulateWorld
--   sceneUpdate(player, now) fim de cada Rem.updateScene
--   worldSeeded(player)      depois de Rem.seedWorld semear o mundo
--
-- Sem require: e carregado pelo Rem_Core antes de tudo e nao depende de nada.
Remanescentes = Remanescentes or {}
local Rem = Remanescentes

-- [nome] = { fn, fn, ... } na ordem de registro
Rem.handlers = Rem.handlers or {}

-- Registra fn para o evento. Registrar a mesma fn duas vezes nao duplica. Retorna fn.
function Rem.on(eventName, fn)
    if type(eventName) ~= "string" or type(fn) ~= "function" then return nil end
    local list = Rem.handlers[eventName]
    if not list then
        list = {}
        Rem.handlers[eventName] = list
    end
    for _, f in ipairs(list) do
        if f == fn then return fn end
    end
    table.insert(list, fn)
    return fn
end

function Rem.off(eventName, fn)
    local list = Rem.handlers[eventName]
    if not list then return false end
    for i = #list, 1, -1 do
        if list[i] == fn then
            table.remove(list, i)
            return true
        end
    end
    return false
end

-- Chama todos os handlers do evento, cada um protegido.
function Rem.emit(eventName, ...)
    local list = Rem.handlers[eventName]
    if not list or #list == 0 then return end
    -- copia: um handler pode chamar Rem.on/Rem.off durante o emit
    local copy = {}
    for i, f in ipairs(list) do copy[i] = f end
    for _, f in ipairs(copy) do
        if Rem.safe then
            Rem.safe(f, ...)
        else
            local ok, err = pcall(f, ...)
            if not ok then print("[Remanescentes] ERRO: " .. tostring(err)) end
        end
    end
end
