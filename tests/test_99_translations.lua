-- Traducoes: nada que trave o jogo, nada faltando.
--  * "%" solto (sem ser %% ou %1..%9) derruba a tela do sandbox/menus no jogo
--    (UnknownFormatConversionException) - ja aconteceu uma vez.
--  * toda fala (Rem.BARKS), opcao de sandbox e opcao de menu registrada tem texto em PTBR e EN.
local T = ...
local Rem = Remanescentes
local check, realPrint = T.check, T.print

realPrint("99) Traducoes")
local base = T.MOD .. "shared/Translate/"

local function readJson(path)
    local f = io.open(path)
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    local keys = {}
    for k, v in s:gmatch('"([^"]+)"%s*:%s*"(.-)"%s*[,}\n]') do keys[k] = v end
    return keys, s
end

for _, lang in ipairs({ "PTBR", "EN" }) do
    local bad = {}
    for _, file in ipairs({ "Sandbox.json", "IG_UI.json", "ContextMenu.json" }) do
        local keys = readJson(base .. lang .. "/" .. file) or {}
        for k, v in pairs(keys) do
            local stripped = v:gsub("%%%%", ""):gsub("%%%d", "")
            if stripped:find("%%") then table.insert(bad, file .. ":" .. k) end
        end
    end
    check(#bad == 0, lang .. ": nenhum % solto nas traducoes " .. table.concat(bad, ", "))

    local ui = readJson(base .. lang .. "/IG_UI.json") or {}
    local missing = {}
    for cat, def in pairs(Rem.BARKS) do
        for i = 1, def.n do
            if not ui["IGUI_Rem_Bark_" .. cat .. "_" .. i] then table.insert(missing, cat .. "_" .. i) end
        end
    end
    check(#missing == 0, lang .. ": todas as falas tem texto " .. table.concat(missing, ", "))

    local cm = readJson(base .. lang .. "/ContextMenu.json") or {}
    local missingMenu = {}
    for _, o in ipairs(Rem.debugOptions or {}) do
        if not cm[o.labelKey or o.key or o.label or ""] then table.insert(missingMenu, tostring(o.labelKey or o.key or o.label)) end
    end
    for _, o in ipairs(Rem.npcOptions or {}) do
        if not cm[o.labelKey or o.key or o.label or ""] then table.insert(missingMenu, tostring(o.labelKey or o.key or o.label)) end
    end
    check(#missingMenu == 0, lang .. ": todas as opcoes de menu tem texto " .. table.concat(missingMenu, ", "))

    local sb = readJson(base .. lang .. "/Sandbox.json") or {}
    local f = io.open(T.MOD .. "../sandbox-options.txt")
    local opts = f:read("*a")
    f:close()
    local missingSb = {}
    for name in opts:gmatch("option Remanescentes%.(%w+)") do
        if not sb["Sandbox_Remanescentes_" .. name] then table.insert(missingSb, name) end
    end
    check(#missingSb == 0, lang .. ": todas as opcoes de sandbox tem texto " .. table.concat(missingSb, ", "))
end
