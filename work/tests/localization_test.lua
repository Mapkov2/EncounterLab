-- Lua 5.1 localization behavior and English source-catalog coverage.
local base = (arg and arg[1]) or "EncounterLab/"
local checks, failures = 0, 0
local function test(name, callback)
    checks = checks + 1
    local ok, message = pcall(callback)
    if ok then print("PASS " .. name)
    else failures = failures + 1; print("FAIL " .. name .. ": " .. tostring(message)) end
end

local function loadLocale(locale)
    GetLocale = locale and function() return locale end or nil
    local EL = {}
    assert(loadfile(base .. "Locale.lua"))("EncounterLab", EL)
    return EL
end

test("English on deDE without a translation", function()
    local EL = loadLocale("deDE")
    assert(EL.LOCALE == "deDE")
    assert(EL.L["Please wait until combat ends."] == "Please wait until combat ends.")
    assert(EL.F("Models: player %s / Rashok %s", "Loading", "Ready") == "Models: player Loading / Rashok Ready")
end)

test("missing locale API and unsupported locales use English", function()
    assert(loadLocale(nil).LOCALE == "enUS")
    assert(loadLocale("unknown").L["Rashok"] == "Rashok")
end)

test("missing keys are readable English", function()
    assert(loadLocale("deDE").L["A newly added English phrase."] == "A newly added English phrase.")
end)

test("registered active locale is visible to existing readers", function()
    local EL = loadLocale("frFR")
    local L = EL.L
    local accepted, rejected = EL.RegisterLocale("frFR", { ["Ready"] = "Pret" })
    assert(accepted == 1 and rejected == 0 and L["Ready"] == "Pret")
    assert(L["Loading"] == "Loading")
end)

test("inactive locale does not replace English", function()
    local EL = loadLocale("enUS")
    EL.RegisterLocale("frFR", { ["Ready"] = "Pret" })
    assert(EL.L["Ready"] == "Ready")
end)

test("English catalog cannot be overwritten by locale registration", function()
    local EL = loadLocale("enUS")
    local accepted, rejected = EL.RegisterLocale("enUS", { ["Ready"] = "Changed" })
    assert(accepted == 0 and rejected == 1 and EL.L["Ready"] == "Ready")
end)

test("all shipped formats accept identity translations and escaped percentages", function()
    local EL = loadLocale("frFR")
    local count = 0
    for _ in pairs(EL.LocaleCatalog) do count = count + 1 end
    local accepted, rejected = EL.RegisterLocale("frFR", EL.LocaleCatalog)
    assert(accepted == count and rejected == 0)
    assert(EL.RegisterLocale("frFR", { ["Speed: %d%%"] = "Vitesse : %d%%" }) == 1)
    assert(EL.F("Speed: %d%%", 75) == "Vitesse : 75%")
    accepted, rejected = EL.RegisterLocale("frFR", { ["Alive: %.1f%% · Hits: %d · Seed %d"] = "%d %.1f %d" })
    assert(accepted == 0 and rejected == 1, "mixed-type argument order must match")
end)

test("translated formats interpolate and permit field-width changes", function()
    local EL = loadLocale("frFR")
    local accepted, rejected = EL.RegisterLocale("frFR", {
        ["Models: player %s / Rashok %s"] = "Modeles : joueur %8s / Rashok %s",
    })
    assert(accepted == 1 and rejected == 0)
    assert(EL.F("Models: player %s / Rashok %s", "Pret", "Pret") == "Modeles : joueur     Pret / Rashok Pret")
end)

test("format argument changes are rejected independently", function()
    for _, candidate in ipairs({ "%s", "%d / %s", "%s / %s / %s", "%2$s / %1$s", "%s / %s %", "%9999999s / %s" }) do
        local EL = loadLocale("frFR")
        local accepted, rejected = EL.RegisterLocale("frFR", { ["Models: player %s / Rashok %s"] = candidate })
        assert(accepted == 0 and rejected == 1, candidate)
        assert(EL.F("Models: player %s / Rashok %s", "A", "B") == "Models: player A / Rashok B")
    end
end)

test("percentages in plain text are never interpreted as format arguments", function()
    local EL = loadLocale("frFR")
    assert(EL.RegisterLocale("frFR", { ["Ready"] = "100% pret" }) == 1)
    assert(EL.L["Ready"] == "100% pret")
    local accepted, rejected = EL.RegisterLocale("frFR", { ["Ready"] = "100% speed" })
    assert(accepted == 1 and rejected == 0 and EL.L["Ready"] == "100% speed")
end)

test("partial registration accepts valid phrases and snapshots values", function()
    local EL = loadLocale("frFR")
    local entries = { ["Ready"] = "Pret", ["Loading"] = false, ["Unknown"] = "", ["Unknown English key"] = "Value" }
    local accepted, rejected = EL.RegisterLocale("frFR", entries)
    assert(accepted == 1 and rejected == 3)
    entries.Ready = "Mutated"
    assert(EL.L["Ready"] == "Pret" and EL.L["Loading"] == "Loading")
    assert(EL.RegisterLocale("frFR", { ["Loading"] = "Chargement" }) == 1)
    assert(EL.L["Ready"] == "Pret" and EL.L["Loading"] == "Chargement")
end)

test("invalid registrations do not break startup", function()
    local EL = loadLocale("frFR")
    for _, candidate in ipairs({ 1, true, "" }) do
        local accepted, rejected = EL.RegisterLocale(candidate, {})
        assert(accepted == 0 and rejected == 1)
    end
    assert(EL.RegisterLocale("frFR", false) == 0)
    assert(EL.RegisterLocale(nil, {}) == 0)
end)

test("bad runtime arguments return a readable English format", function()
    local EL = loadLocale("frFR")
    local key = "Models: player %s / Rashok %s"
    EL.RegisterLocale("frFR", { [key] = "Modeles : joueur %s / Rashok %s" })
    assert(EL.F(key) == key)
    assert(EL.F("Uncataloged count: %d", {}) == "Uncataloged count: %d")
end)

test("every direct UI phrase is included in the central English catalog", function()
    local EL = loadLocale("enUS")
    for _, filename in ipairs({ "Bootstrap.lua", "Renderer.lua", "Input.lua", "Interface.lua", "TrainingUI.lua", "TempestRenderer.lua", "SentinelsUI.lua", "SentinelsRenderer.lua" }) do
        local file = assert(io.open(base .. filename, "r"))
        local source = file:read("*a")
        file:close()
        -- Source conventions intentionally use double-quoted complete English keys.
        for literal in source:gmatch('L%[("[^\n]-")%]') do
            local key = assert(loadstring("return " .. literal))()
            assert(EL.LocaleCatalog[key], filename .. " missing catalog key: " .. key)
        end
        for literal in source:gmatch('EL%.F%(("[^\n]-")%s*[,)]') do
            local key = assert(loadstring("return " .. literal))()
            assert(EL.LocaleCatalog[key], filename .. " missing format key: " .. key)
            assert(EL.LocaleFormats[key], filename .. " format key is not in the formats list: " .. key)
        end
        if filename == "Interface.lua" then
            for _, helper in ipairs({ "label", "button" }) do
                for literal in source:gmatch(helper .. '%([^,\n]+,%s*("[^\n]-")%s*[,)]') do
                    local key = assert(loadstring("return " .. literal))()
                    if key ~= "" then
                        assert(EL.LocaleCatalog[key], filename .. " missing " .. helper .. " key: " .. key)
                    end
                end
            end
        end
    end
end)

print(string.format("LOCALIZATION %d checks; %d failed. Source behavior only; no live WoW proof.", checks, failures))
os.exit(failures == 0 and 0 or 1)
