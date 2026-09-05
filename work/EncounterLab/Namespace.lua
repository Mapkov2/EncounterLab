local addonName, EL = ...
EL.NAME = addonName or "EncounterLab"
EL.VERSION = "0.9.1"
EL.SCENARIO_VERSION = "rashok-lava-3"
EL.TARGET_INTERFACE = 120100
EL.COLOR = { accent = {.231, .510, .965}, background = {.020, .039, .071}, text = {.933, .957, 1} }

function EL.Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function EL.FormatTime(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

function EL.Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff3b82f6EncounterLab|r  " .. tostring(message))
    end
end
