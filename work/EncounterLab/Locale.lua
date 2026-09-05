local _, EL = ...

-- English is both the source language and the fallback on every client locale.
-- Keep complete phrases here; locale files translate these exact English keys.
local english = {
    "Two camps of 10 start at separate bosses, with shuffled positions, number counts and reactions. The bosses move to the center during the reveal. All 2s meet there; 1s ping and jump and 3s seek them across both camps. Visible 1+3 pairs can clear after the 1 pings. A simulated 3 waits for your manual ping if you have 1.\n\nThe addition and concealment rules follow the encounter. The 10/10 split, shuffled numbers across both camps, spawn positions, bot reactions, contact size and the default 2-second reveal are training values awaiting live calibration. Room scenery is a native model approximation. The main phase, raid damage and healing are not simulated.\n\nNormal always uses a 2-second reveal. Practice can change it below. Successful full-raid clears are ranked by your matching time, on a separate random-role board for each reveal duration.",
    "Your number (1, 2 or 3) and starting camp are drawn each attempt. Both bosses run to the center when Helical Toxins appears. Count your green orbs when Helical Toxins appears. Each player has four orbs; the rest are red. Other players' orbs are shrouded shortly afterwards.\n\n3: go around the center to a pinging 1 from either camp and touch them. Keep the middle clear for the 2s.\n2: move to the center between the bosses and touch another 2.\n1: ping yourself and keep jumping. A 3 comes to you. You must manually ping and jump after the reveal, before contact. Missing either action fails the attempt.\n\nOnly 2+2, 3+1 and 1+3 clear both players. Every other active contact immediately wipes the raid. Unresolved toxins expire after 30 seconds.\n\nClick the dedicated PING YOURSELF button when you have 1. The practice-ability key does not ping. Pings and square speech bubbles are simulated inside the arena.",

    "1: ping yourself and keep jumping",
    "3: go around the center to a pinging 1",
    "Both camps: 2s to the center, 1s ping and jump, 3s find a pinging 1.",
    "Click PING YOURSELF to announce your 1.",

    "Two camps of 10 start at separate bosses, with shuffled positions, number counts and reactions. The bosses move to the center during the reveal. All 2s meet there; 3s ping and 1s seek them across both camps. Nearby visible 1+3 pairs can clear early. A simulated 1 waits for your manual ping if you have 3.\n\nThe addition and concealment rules follow the encounter. The 10/10 split, shuffled numbers across both camps, spawn positions, bot reactions, contact size and the default 2-second reveal are training values awaiting live calibration. Room scenery is a native model approximation. The main phase, raid damage and healing are not simulated.\n\nNormal always uses a 2-second reveal. Practice can change it below. Successful full-raid clears are ranked by your matching time, on a separate random-role board for each reveal duration.",
    "Your number (1, 2 or 3) and starting camp are drawn each attempt. Both bosses run to the center when Helical Toxins appears. Count your green orbs when Helical Toxins appears. Each player has four orbs; the rest are red. Other players' orbs are shrouded shortly afterwards.\n\n1: find a pinging 3 from either camp and touch them.\n2: move to the center between the bosses and touch another 2.\n3: hold position and ping yourself. A 1 comes to you.\n\nOnly 2+2, 3+1 and 1+3 clear both players. Every other active contact immediately wipes the raid. Unresolved toxins expire after 30 seconds.\n\nClick the dedicated PING YOURSELF button when you have 3. The practice-ability key does not ping. Pings and square speech bubbles are simulated inside the arena.",

    "Click PING YOURSELF to announce your 3.",
    "PING YOURSELF",
    "Random: 1, 2 or 3",
    "Sentinels highscores - Random roles",
    "Start training to draw your number",
    "Your number appears with Helical Toxins",
    "Your number is drawn each attempt",

    "2: move to the center",
    "1: find a pinging 3 from either camp",
    "3: hold position and ping yourself",
    "Both camps: 2s to the center, 3s ping, 1s find a pinging 3.",
    "Center - all 2s meet here",
    "Ping when your active number is 3.",
    "Start in one of two raid camps. Both bosses run to the center when Helical Toxins appears. Count your green orbs when Helical Toxins appears. Each player has four orbs; the rest are red. Other players' orbs are shrouded shortly afterwards.\n\n1: find a pinging 3 from either camp and touch them.\n2: move to the center between the bosses and touch another 2.\n3: hold position and ping yourself. A 1 comes to you.\n\nOnly 2+2, 3+1 and 1+3 clear both players. Every other active contact immediately wipes the raid. Unresolved toxins expire after 30 seconds.\n\nUse the Ping button or your practice-ability key (F by default). Pings and square speech bubbles are simulated inside the arena.",
    "Two camps of 10 start at separate bosses. The bosses move to the center during the reveal. All 2s meet there; 3s ping and 1s seek them across both camps. Nearby visible 1+3 pairs can clear early.\n\nThe addition and concealment rules follow the encounter. The 10/10 split, shuffled numbers across both camps, spawn positions, bot reactions, contact size and the default 2-second reveal are training values awaiting live calibration. Room scenery is a native model approximation. The main phase, raid damage and healing are not simulated.\n\nNormal always uses a 2-second reveal. Practice can change it below. Successful full-raid clears are ranked by your matching time, separately for each number and reveal duration.",

    "Your side - 2s meet under this boss",
    "1: ping yourself and hold position",
    "20 players - combine to exactly 4",
    "Two groups of 10 start pre-spread at separate bosses. Stay on your side: 1 holds and pings, 2 meets under its own boss, 3 finds a pinging 1. Nearby visible 1+3 pairs can clear early.\n\nThe addition and concealment rules follow the encounter. The 10/10 split, balanced numbers per side, spawn positions, bot reactions, contact size and the default 2-second reveal are training values awaiting live calibration. Room scenery is a native model approximation. The main phase, raid damage and healing are not simulated.\n\nNormal always uses a 2-second reveal. Practice can change it below. Successful full-raid clears are ranked by your matching time, separately for each number and reveal duration.",
    "2: move under your boss",
    "Stay on your boss side. 1s hold and ping; 2s under your boss; 3s find a 1.",
    "3: find a pinging 1 on your side",
    "Blood of Ula'tek",
    "Breath of Ula'tek",
    "Center",
    "Choose your number and start training",
    "Clear",
    "Entombed Sentinels - Mythic",
    "Entombed Sentinels",
    "Fastest personal match wins. Only successful 20-player clears qualify. Paused and practice runs use separate boards.",
    "Left the training arena",
    "Mythic - Helical Toxins",
    "On my way",
    "Ping when your active number is 1.",
    "Raid failed - retry the intermission",
    "Start pre-spread with your group at its boss. Count your green orbs when Helical Toxins appears. Each player has four orbs; the rest are red. Other players' orbs are shrouded shortly afterwards.\n\n1: hold position, jump and ping yourself. A 3 comes to you.\n2: move under your own boss and touch another 2.\n3: find a pinging 1 on your side and touch them.\n\nOnly 2+2, 3+1 and 1+3 clear both players. Every other active contact immediately wipes the raid. Unresolved toxins expire after 30 seconds.\n\nUse the Ping button or your practice-ability key (F by default). Pings and square speech bubbles are simulated inside the arena.",
    "Sentinels - Mythic intermission",
    "Contact did not total 4",
    "Missing ping and jump",
    "Missing ping",
    "Missing jump",
    "RAID WIPE\n%s\n[%s] Retry",
    "Toxins cleared",
    "Toxins expired",
    "Your number",

    "X",
    "Choose an encounter. Its drills and settings appear in the training menu.\n\nRashok: lava waves and frontals.\nSszorak: dodge moving Tempest tornadoes.\nSentinels: Mythic toxin pairing.",
    "Dodge the moving tornadoes while keeping Sszorak in view.\n\nChoose a starting point below. Each starting point has its own local leaderboard.\n\nA tornado hit ends the clean attempt. Revive to continue, review the mistake in replay or retry the latest checkpoint. Checkpoint retries are unranked.",
    "Fell off the platform",
    "Final",
    "Loading Sszorak model",
    "Middle",
    "Sszorak - Tempest",
    "Starting point",
    "Tempest - tornado dodging",
    "Tempest-only solo practice with native WoW models.\n\nContact counts as a failed dodge; raid health, damage and stacking slows are not simulated.\n\nSszorak uses his actual boss model and Tempest cast effect. A native whirlwind represents each tornado. Paths and collision sizes are training values awaiting live calibration.",
    "Encounters",
    "Drill options",
    "Use Drill options for checkpoints and instructions.",
    "+1 second",
    "-1 second",
    "About this drill",
    "Blown off the platform",
    "Checkpoint restored. This attempt is unranked.",
    "Choose an encounter",
    "Combined",
    "Drill for next run",
    "Encounters / drills",
    "Final volley",
    "Mistake replay",
    "Move to the center",
    "Play",
    "Preparation",
    "Rashok - change encounter",
    "Replay becomes available after a mistake.",
    "Retry checkpoint",
    "Return to training",
    "Revived at the center. Watch the active mechanics.",
    "Second volley",
    "Spare",
    "Speed: 50%",
    "Sszorak",
    "Sszorak - change encounter",
    "Sszorak training",
    "Start",
    "Start a Sszorak drill first.",
    "Start selected drill",
    "Tempest",
    "Tempest tornado",
    "Use Encounters / drills for checkpoints and instructions.",
    "Wind",
    "Wind 1",
    "Wind 2",
    "Wind 3",
    "Comparison saved. Use /reload, then report that the recording is ready.",
    "Recording XPractice for 10 seconds. Keep the target in view while strafing with the right mouse button.",
    "Enable XPractice in the addon list and reload before starting the comparison.",
    "Open XPractice with /xp, enter a practice scene, then strafe around a target while holding the right mouse button for 10 seconds.",
    "Comparison 1/2: start EncounterLab training and keep Rashok in view while strafing with the right mouse button for 10 seconds.",
    "Comparison interrupted. Use /el mousecompare to start again.",
    "Mouse trace armed. Start training and hold a mouse button for 10 seconds.",
    "Mouse trace saved. Use /reload to write the local recording.",
    "Native terrain",
    "Loaded pool models",
    "Loaded wave models",
    "Fallback",
    "Another view is already using the mouse.",
    "The previous mouse settings could not be restored yet.",
    "The cursor position is unavailable.",
    "Mouse settings are unavailable.",
    "WoW did not accept the temporary mouse settings.",
    "WoW limited the mouse-speed setting. Adjust Mouse sensitivity in Controls if turning feels too fast.",
    "+",
    "Ã—",
    "A hit kills the practice player. Time keeps running; Revive lets you continue the same sequence. Jumping does not avoid horizontal lava collisions.",
    "Abilities require a running session and a living player.",
    "Abilities",
    "Active waves",
    "All seeds",
    "Assisted",
    "Backward",
    "Blink",
    "Bonus wave",
    "Boss display ID",
    "Boss model",
    "Calibrated",
    "Chat opened: click the arena, then press Pause to resume",
    "Check your player's state",
    "Choose a loop and start training",
    "Close",
    "Combat started",
    "Controls",
    "Custom bindings",
    "Daily seed",
    "Diagnostics",
    "Editing run seed",
    "EncounterLab",
    "Escape opens or closes the training menu. F11 switches between fullscreen and windowed mode. Change bindings in Controls; your WoW bindings are never modified.",
    "Focus changed: click the arena, then press Pause to resume",
    "Forward",
    "Frontal - move out of its path",
    "Frontal",
    "Fullscreen [F11]",
    "Game state changed",
    "Gateway placed",
    "Gateway",
    "Help",
    "Highscores",
    "Hit outlines: off",
    "Hit outlines: on",
    "How to practice",
    "Immunity",
    "Invalid projection",
    "Invert Y: off",
    "Invert Y: on",
    "Jump",
    "Lava pool",
    "Lava wave",
    "Lava waves",
    "Left-click a landing point; Escape cancels.",
    "Loading",
    "Mechanics practice",
    "Menu",
    "Models come from the installed WoW client. Camera, hit areas and mouse behavior still need to be checked in game.",
    "Move within 5 yards of a gateway endpoint",
    "Movement abilities",
    "Movement ability",
    "Movement uses your WoW keyboard bindings by default. Standard keys: W/S forward/back, A/D turn, Q/E strafe, Space jump. Right mouse turns your character and changes turn keys to strafe. Left mouse rotates only the camera; both mouse buttons run forward. Scroll to zoom.",
    "Native actors",
    "Native projection unavailable",
    "No completed ranked runs yet.",
    "No runs saved yet.",
    "Normal runs at 100% speed. Practice settings, pauses and movement abilities have separate leaderboards. Stay inside the gold 75-yard boundary to rank.",
    "Normal",
    "Not loaded",
    "On cooldown",
    "Outside the arena: this run is unranked. Restart for a ranked attempt.",
    "Overflow",
    "Pause",
    "Paused\nPress Pause or close the menu to continue",
    "Pausing counts as assistance. This run uses the Assisted leaderboard.",
    "Place a gateway first",
    "Place a teleport point first",
    "Place gateway",
    "Place teleport point",
    "Player is dead or training is paused",
    "Player model",
    "Please wait until combat ends.",
    "Practice / Assisted",
    "Practice",
    "Preparing 3D scene\nOpen Diagnostics if models do not appear",
    "Press a new key; Escape cancels.",
    "Projection",
    "Random seed",
    "Ranked by survival, perfect bonus, then dead time and hits. Interrupted runs and arena exits appear in history only.",
    "Rashok Â· Lava waves",
    "Rashok",
    "Ready",
    "Recent runs",
    "Rendering error; input released",
    "Rendering limit reached. Run paused and unranked; please report the diagnostics.",
    "Reset custom bindings",
    "Restart same run",
    "Resume",
    "Return to arena",
    "Revive",
    "Revived. Time keeps running and lava is still dangerous.",
    "Roll",
    "Run seed",
    "Saved to history; no leaderboard rank.",
    "Scores stay on this WoW account. A daily seed gives a repeatable sequence. Combat and zone changes close training.",
    "Slam - a lava pool is forming",
    "Slam",
    "Sprint",
    "Start or resume a run first.",
    "Start training",
    "Starting loop",
    "Strafe left",
    "Strafe right",
    "Target: WoW 12.1 / Interface 120100",
    "Targeted leap",
    "Teleport point placed",
    "Teleport",
    "Text input: click the arena, then press Pause to resume",
    "The daily seed gives everyone the same sequence.",
    "This seed",
    "Training is available after combat.",
    "Turn left",
    "Turn right",
    "Unbound",
    "Unknown",
    "Unresolved",
    "Use your WoW movement keys, or choose custom bindings. Click a binding to change it. Escape and F11 are reserved.",
    "Walk / run",
    "Wave capacity",
    "Windowed mode [F11]",
    "WoW bindings",
    "WoW movement bindings Â· Drag to look Â· Mouse wheel to zoom",
    "YOU",
}

-- EL.F phrases are separate so ordinary percentages in help text are never
-- interpreted as printf directives (for example, the words "100% speed").
local formats = {
    "New attempt [%s]",

    "%.1f s / %d of 20 clear",
    "%d. %.2f s / Seed %d",
    "20 / 20 clear\nYour match: %.2f s\n[%s] Retry",
    "Attempt failed\n%s\n[%s] Retry",
    "Helical Toxins in %.1f",
    "Number %d",
    "Ping yourself [%s]",
    "Practice reveal: %d s",
    "Restart [%s]",
    "Sentinels / %.2f s / Seed %d",
    "Sentinels highscores - Number %d",

    "%s / %d tornadoes / %.1f s",
    "Highscores: %s",
    "Replay %.1f / %.1f s",
    "Sszorak / %s / %s",
    "Reference recording stopped: %s. Use /reload to save the available samples.",
    "Mouse control could not start: %s",
    "%.1f%% survived\n%d hits Â· Perfect!",
    "%.1f%% survived\n%d hits",
    "%d attempts Â· %d completed Â· %d perfect",
    "%d.  %.2f%% alive Â· %d hits Â· %d points Â· Seed %d",
    "%s Â· %.1f s",
    "%s Â· %d pools Â· %d waves",
    "%s Â· Interrupted",
    "%s Â· Practice ability",
    "%s: %s (%ds)",
    "%s: %s",
    "Ability unavailable: %s",
    "Alive: %.1f%% Â· Hits: %d Â· Seed %d",
    "Choose an ability for [%s] or the middle mouse button. These practice abilities use separate scores.",
    "Diagnostics Â· %s",
    "Highscores Â· Loop %d",
    "Hit!\n[%s] Revive\n%s",
    "Key is already assigned: %s",
    "Loop %d Â· %.1f%% Â· %d hits Â· Seed %d Â· %s",
    "Loop %d Â· %s Â· Bonus",
    "Loop %d Â· %s",
    "Loop %d Â· Seed %d Â· Stay inside the gold 75-yard boundary for a ranked score.",
    "Loop %d",
    "Models: player %s / Rashok %s",
    "WoW camera speed: %.0f%%",
    "Pause [%s]",
    "Rank %d - Personal best!",
    "Rank %d",
    "Ready. /el opens the training arena. Version %s",
    "Revive [%s]",
    "Scenario: %s",
    "Speed: %d%%",
    "Training closed: %s",
}

local catalog, formatKeys = {}, {}
for _, key in ipairs(english) do catalog[key] = key end
for _, key in ipairs(formats) do catalog[key] = key; formatKeys[key] = true end
EL.LocaleCatalog = catalog
EL.LocaleFormats = formatKeys
EL.LOCALE = (GetLocale and GetLocale()) or "enUS"

local locales = { enUS = catalog }
local sourceSignatures = {}

-- Lua 5.1 printf conversions only. Keep argument types and order unchanged;
-- translators may adjust field width and precision, but not add arguments.
local function signature(text)
    local result, cursor, valid = {}, 1, true
    while true do
        local start = text:find("%", cursor, true)
        if not start then break end
        if text:sub(start + 1, start + 1) == "%" then
            cursor = start + 2
        else
            local token = text:sub(start):match("^%%[-+ #0]*%d*%.?%d*[cdiouxXeEfgGqs]")
            if token then
                result[#result + 1] = token:sub(-1)
                cursor = start + #token
            else
                valid = false
                cursor = start + 1
            end
        end
    end
    return table.concat(result), valid
end

for key in pairs(formatKeys) do
    local arguments, valid = signature(key)
    sourceSignatures[key] = { arguments = arguments, valid = valid }
end

EL.L = setmetatable({}, {
    __index = function(_, key)
        local active = locales[EL.LOCALE]
        return (active and active[key]) or catalog[key] or key
    end,
})

-- Locale files load after this file and before the first UI module.
-- Returns accepted/rejected entry counts; a bad entry cannot break startup.
function EL.RegisterLocale(locale, entries)
    if type(locale) ~= "string" or locale == "" or locale == "enUS" or type(entries) ~= "table" then
        return 0, 1
    end
    local translated = locales[locale] or {}
    locales[locale] = translated
    local accepted, rejected = 0, 0
    for key, value in pairs(entries) do
        local source = sourceSignatures[key]
        local compatible = false
        if catalog[key] and type(value) == "string" and value ~= "" then
            compatible = true
            if source then
                local arguments, valid = signature(value)
                compatible = arguments == source.arguments and source.valid and valid
                if compatible then
                    local samples = {}
                    for index = 1, #arguments do
                        local conversion = arguments:sub(index, index)
                        samples[index] = (conversion == "s" or conversion == "q") and "sample" or 1
                    end
                    compatible = pcall(string.format, value, unpack(samples))
                end
            end
        end
        if compatible then
            translated[key] = value
            accepted = accepted + 1
        else
            rejected = rejected + 1
        end
    end
    return accepted, rejected
end

function EL.F(key, ...)
    local translated = EL.L[key]
    local ok, result = pcall(string.format, translated, ...)
    if ok then return result end
    -- Retain a usable English message if a translation or call is malformed.
    if translated ~= key then
        ok, result = pcall(string.format, key, ...)
        if ok then return result end
    end
    return key
end
