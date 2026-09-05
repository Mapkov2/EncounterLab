local addonName, EL = ...
local L = EL.L
local events = CreateFrame("Frame")
local loaded=false

local function show(command)
    if not loaded then return end
    if command == "version" then EL.Print(EL.VERSION.." / "..EL.SCENARIO_VERSION); return end
    if InCombatLockdown() then EL.Print(L["Please wait until combat ends."]); return end
    if not EL.instance then EL.instance=EL.UI.New() end
    local ui=EL.instance
    if command == "scores" then ui:Show(); ui:ShowScores()
    elseif command == "mousetrace" then ui:Show(); ui.input:ArmTrace()
    elseif command == "help" then ui:Show(); ui:ShowHelp()
    elseif command == "debug" then ui:Show(); ui:ShowDiagnostics()
    elseif ui.frame:IsShown() then ui:Hide()
    else ui:Show() end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
events:SetScript("OnEvent",function(_,event,arg)
    if event=="PLAYER_LOGOUT" then
        if EL.instance then
            EL.instance.input:Release()
            EL.instance:RecordAbandoned()
        end
    elseif event=="ADDON_LOADED" and arg==addonName then
        local pending=type(EncounterLabDB)=="table" and EncounterLabDB.mouseRecovery
        pending=EL.MouseCapture.Recover(pending)
        EncounterLabDB=EL.Store.Initialize(EncounterLabDB)
        EncounterLabDB.mouseRecovery=pending
        loaded=true
        events:UnregisterEvent("ADDON_LOADED")
        SLASH_ENCOUNTERLAB1="/el"
        SLASH_ENCOUNTERLAB2="/encounterlab"
        SlashCmdList.ENCOUNTERLAB=function(message) show((message or ""):lower():match("^%s*(.-)%s*$")) end
        EL.Print(EL.F("Ready. /el opens the training arena. Version %s", EL.VERSION))
    elseif EL.instance and EL.instance.frame:IsShown() then
        -- Close our private window on restriction transitions, before they activate.
        -- No secret values or live encounter information enter the simulation.
        EL.instance:Hide(event=="PLAYER_REGEN_DISABLED" and L["Combat started"] or L["Game state changed"])
    end
end)
