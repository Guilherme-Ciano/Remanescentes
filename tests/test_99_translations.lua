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
    local missingVar = {}
    for key, n in pairs(Rem.Interact.VARIANTS) do
        for i = 1, n do
            if not ui[key .. "_" .. i] then table.insert(missingVar, key .. "_" .. i) end
        end
    end
    check(#missingVar == 0, lang .. ": todas as variacoes das respostas tem texto " .. table.concat(missingVar, ", "))

    -- vida dos personagens: conversas, jeito, humor, lembrancas, historia, opcoes novas
    local missingLife = {}
    local function need(key) if not ui[key] then table.insert(missingLife, key) end end
    for topic, def in pairs(Rem.Banter.TOPICS) do
        for i = 1, def.n do
            for turn = 1, Rem.Banter.TURNS do need("IGUI_Rem_Banter_" .. topic .. "_" .. i .. "_" .. turn) end
        end
    end
    for _, q in ipairs(Rem.Persona.QUIRKS) do need("IGUI_Rem_Quirk_" .. q) end
    for _, m in ipairs({ "calmo", "ferido", "doente", "luto", "faminto", "animado", "abatido", "cansado" }) do need("IGUI_Rem_Mood_" .. m) end
    -- opcoes de conversa do pacote 0.18 (necessidades, combate, prisioneiros) e o painel
    for _, id in ipairs({ "feed", "nap", "order_stance_normal", "order_stance_hold", "order_stance_aggressive", "order_retreat",
        "prisoner_take", "prisoner_hold", "prisoner_interrogate", "prisoner_ransom", "prisoner_recruit", "prisoner_release" }) do
        need("IGUI_Rem_Opt_" .. id)
    end
    for _, st in ipairs(Rem.Orders.CFG.STANCES) do need("IGUI_Rem_Order_stance_" .. st) end
    for _, k in ipairs({ "IGUI_Rem_Panel_title", "IGUI_Rem_Panel_member", "IGUI_Rem_Panel_shift", "IGUI_Rem_Panel_prisoner",
        "IGUI_Rem_Panel_hint", "IGUI_Rem_Hint_prisoner", "IGUI_Rem_Prisoner_talk_raid" }) do need(k) end
    for kind in pairs(Rem.Bonds.REMEMBER) do need("IGUI_Rem_Mem_" .. kind) end
    for i = 1, Rem.Persona.STORY_LOST do need("IGUI_Rem_Story_lost_" .. i) end
    for i = 1, Rem.Persona.STORY_GOAL do need("IGUI_Rem_Story_goal_" .. i) end
    for _, k in ipairs({ "IGUI_Rem_About", "IGUI_Rem_Story_intro", "IGUI_Rem_Story_intro_none", "IGUI_Rem_Opt_about",
        "IGUI_Rem_Opt_gift", "IGUI_Rem_Map_siege", "IGUI_Rem_Profile_quirk", "IGUI_Rem_Profile_mood", "IGUI_Rem_Profile_bond",
        "IGUI_Rem_Profile_level", "IGUI_Rem_Profile_memories", "IGUI_Rem_Profile_nomem", "IGUI_Rem_Profile_story",
        "IGUI_Rem_Profile_nostory" }) do need(k) end
    if Rem.BaseBuild then
        for _, pj in ipairs(Rem.BaseBuild.PROJECTS) do
            need("IGUI_Rem_Project_" .. pj)
            need("IGUI_Rem_Journal_ev_done_" .. pj)
        end
    end
    check(#missingLife == 0, lang .. ": conversas, jeito, humor, lembrancas e historia tem texto " .. table.concat(missingLife, ", "))

    local cm = readJson(base .. lang .. "/ContextMenu.json") or {}
    local missingMenu = {}
    for _, o in ipairs(Rem.debugOptions or {}) do
        if not cm[o.labelKey or o.key or o.label or ""] then table.insert(missingMenu, tostring(o.labelKey or o.key or o.label)) end
    end
    for _, list in ipairs({ Rem.npcOptions or {}, Rem.playerOptions or {}, Rem.targetOptions or {} }) do
        for _, o in ipairs(list) do
            if not cm[o.labelKey or ""] then table.insert(missingMenu, tostring(o.labelKey)) end
        end
    end
    check(#missingMenu == 0, lang .. ": todas as opcoes de menu tem texto " .. table.concat(missingMenu, ", "))
    local missingGrp = {}
    for _, g in ipairs(Rem.DEBUG_GROUPS) do
        if not cm["ContextMenu_Rem_Grp_" .. g] then table.insert(missingGrp, g) end
    end
    check(#missingGrp == 0, lang .. ": todos os grupos das ferramentas de teste tem titulo " .. table.concat(missingGrp, ", "))

    local sb = readJson(base .. lang .. "/Sandbox.json") or {}
    local f = io.open(T.MOD .. "../sandbox-options.txt")
    local opts = f:read("*a")
    f:close()
    local missingSb = {}
    for name in opts:gmatch("option Remanescentes%.(%w+)") do
        if not sb["Sandbox_Remanescentes_" .. name] then table.insert(missingSb, name) end
    end
    check(#missingSb == 0, lang .. ": todas as opcoes de sandbox tem texto " .. table.concat(missingSb, ", "))
    local missingPage = {}
    for page in opts:gmatch("page = (%w+)") do
        if not sb["Sandbox_" .. page] then table.insert(missingPage, page) end
    end
    check(#missingPage == 0, lang .. ": todas as paginas do sandbox tem titulo " .. table.concat(missingPage, ", "))
end
