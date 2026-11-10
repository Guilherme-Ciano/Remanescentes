-- Remanescentes - registros de extensao que nao dependem de nada:
--   * comportamentos do cerebro (Rem.registerBehavior; quem roda e o Rem_Brain);
--   * opcoes do menu de clique direito (Rem.registerDebugOption / Rem.registerNpcOption).
--
-- ---- comportamentos
--   Rem.registerBehavior({ name = "comer", priority = 250, run = function(npc, ctx, now) ... end })
-- run retorna true se tratou o tick (encerra o think). Menor priority roda primeiro;
-- mesma priority: ordem de registro. Re-registrar o mesmo name substitui.
-- Padrao (Rem_Behaviors.lua): follow 100, stay 200, group 300, wander 900.
--
-- ---- menu
-- Fica em shared para que qualquer modulo (shared ou client) possa registrar opcoes; o
-- Rem_ContextMenu (client) so le as listas e monta o menu.
--
--   Rem.registerDebugOption("ContextMenu_Rem_X", function(x, y, z, player) ... end)
--       entra no submenu "Ferramentas de teste" (so com DebugMenu ligado).
--   Rem.registerNpcOption("ContextMenu_Rem_Y", function(npc) ... end, function(npc) return ... end)
--       entra no submenu de cada sobrevivente perto do clique; condition(npc) opcional.
--
-- Ordem de exibicao = ordem de registro. Registrar de novo a mesma chave substitui a opcao
-- (mantendo a posicao). As opcoes padrao sao registradas pelo Rem_Commands, que o
-- Rem_Core carrega, entao elas sempre vem antes das opcoes de outros modulos.
--
-- Sem require: e carregado pelo Rem_Core e nao depende de nada.
Remanescentes = Remanescentes or {}
local Rem = Remanescentes

Rem.debugOptions = Rem.debugOptions or {}  -- { { labelKey=, fn= }, ... }
Rem.npcOptions = Rem.npcOptions or {}      -- { { labelKey=, fn=, condition= }, ... }

local function upsert(list, entry)
    for i, e in ipairs(list) do
        if e.labelKey == entry.labelKey then
            list[i] = entry
            return entry
        end
    end
    table.insert(list, entry)
    return entry
end

-- fn(x, y, z, player): x, y = centro do quadrado clicado
function Rem.registerDebugOption(labelKey, fn)
    if type(labelKey) ~= "string" or type(fn) ~= "function" then return nil end
    return upsert(Rem.debugOptions, { labelKey = labelKey, fn = fn })
end

-- fn(npc); condition(npc) -> bool (opcional; sem ela a opcao sempre aparece)
function Rem.registerNpcOption(labelKey, fn, condition)
    if type(labelKey) ~= "string" or type(fn) ~= "function" then return nil end
    return upsert(Rem.npcOptions, { labelKey = labelKey, fn = fn, condition = condition })
end

function Rem.unregisterDebugOption(labelKey)
    for i = #Rem.debugOptions, 1, -1 do
        if Rem.debugOptions[i].labelKey == labelKey then table.remove(Rem.debugOptions, i) end
    end
end

function Rem.unregisterNpcOption(labelKey)
    for i = #Rem.npcOptions, 1, -1 do
        if Rem.npcOptions[i].labelKey == labelKey then table.remove(Rem.npcOptions, i) end
    end
end

-- ---------------------------------------------------------------- comportamentos do cerebro
Rem.behaviors = Rem.behaviors or {}  -- { { name=, priority=, run=, seq= }, ... } ja ordenada
Rem.behaviorSeq = Rem.behaviorSeq or 0

local function sortBehaviors()
    table.sort(Rem.behaviors, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.seq < b.seq
    end)
end

function Rem.unregisterBehavior(name)
    for i = #Rem.behaviors, 1, -1 do
        if Rem.behaviors[i].name == name then table.remove(Rem.behaviors, i) end
    end
end

-- def = { name = string, priority = number, run = function(npc, ctx, now) -> bool }
function Rem.registerBehavior(def)
    if type(def) ~= "table" or type(def.name) ~= "string" or type(def.run) ~= "function" then
        print("[Remanescentes] registerBehavior: def invalida (precisa de name e run)")
        return nil
    end
    Rem.unregisterBehavior(def.name)
    Rem.behaviorSeq = Rem.behaviorSeq + 1
    local entry = { name = def.name, priority = tonumber(def.priority) or 500, run = def.run,
        seq = Rem.behaviorSeq, def = def }
    table.insert(Rem.behaviors, entry)
    sortBehaviors()
    return entry
end

function Rem.getBehavior(name)
    for _, b in ipairs(Rem.behaviors) do
        if b.name == name then return b end
    end
    return nil
end

-- Copia da lista, na ordem em que os comportamentos rodam.
function Rem.getBehaviors()
    local out = {}
    for i, b in ipairs(Rem.behaviors) do out[i] = b end
    return out
end
