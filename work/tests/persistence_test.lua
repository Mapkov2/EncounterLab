local source = (arg and arg[1]) or "../EncounterLab/Persistence.lua"
local EL = { SCENARIO_VERSION = "test-1" }
assert(loadfile(source))("EncounterLab", EL)
local Store = EL.Store
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function result(changes)
    local value = {
        completed = true, mode = "reference", seed = 123, loop = 1,
        elapsed = 200, aliveTime = 200, deadTime = 0, deaths = 0,
        bonus = true, perfect = true, assisted = false, highscoreEligible = true,
        score = 999999999, version = "test-1", interrupted = false,
    }
    for key, item in pairs(changes or {}) do value[key] = item end
    return value
end
Store.Initialize(nil)
local settings = Store.GetOptions()
check(settings.loop == 1 and settings.speed == 1 and settings.mouseSensitivity == 0.006, "default options")
settings.loop = 3
check(Store.GetOptions().loop == 1, "options getters must not expose mutable saved state")
Store.SaveOptions({ loop = 3, speed = 0.5 })
Store.SaveOptions({ hints = true })
check(Store.GetOptions().loop == 3 and Store.GetOptions().speed == 0.5, "partial option updates")
Store.SaveOptions({ bindings = { forward="S", backward="W", ability="W", pause="ESCAPE" } })
local cleanBindings, seenKeys = Store.GetOptions().bindings, {}
for _, key in pairs(cleanBindings) do
    check(not seenKeys[key] and key ~= "ESCAPE", "bindings are unique and Escape remains reserved")
    seenKeys[key] = true
end
check(cleanBindings.forward == "S" and cleanBindings.backward == "W", "valid key swaps survive")
cleanBindings.forward = "X"
check(Store.GetOptions().bindings.forward == "S", "binding getter cannot mutate saved state")
local first = Store.RecordResult(result())
check(first.saved and first.newBest and first.rank == 1 and first.entry.score == 1000000, "derived score and first record")
check(not Store.RecordResult(result()).newBest, "exact tie is not a new personal best")
Store.RecordResult(result({ assisted = true }))
Store.RecordResult(result({ mode = "practice" }))
Store.RecordResult(result({ speed = 0.5 }))
Store.RecordResult(result({ version = "test-2" }))
Store.RecordResult(result({ loop = 2, bonus = false }))
check(#Store.GetBoard("reference", 1) == 2, "practice, assisted, speed, version and loop isolation")
check(#Store.GetBoard("assisted", 1) == 2 and #Store.GetBoard("practice", 1) == 1, "separate practice boards")
check(#Store.GetBoard("reference", 1, nil, "test-2") == 1, "explicit version access")
local exited = Store.RecordResult(result({ arenaExit = true }))
check(exited.saved and exited.reason == "arena_exit" and not exited.rank, "outside arena remains history only")
local interrupted = Store.RecordResult(result({ interrupted = true }))
check(interrupted.reason == "interrupted" and not interrupted.entry.perfect, "interrupted run cannot rank or be perfect")
local dead = Store.RecordResult(result({ deadTime = 20, aliveTime = 180, deaths = 0 }))
check(not dead.entry.perfect and dead.entry.deaths == 1, "death timing prevents fake perfection")
Store.RecordResult(result({ seed = 456, deadTime = 40, aliveTime = 160, deaths = 2 }))
check(#Store.GetBoard("reference", 1, 456) == 1, "seed board retains own results")
check(Store.GetBoard("reference", 1, 456)[1].survivalPercent == 80, "survival percent uses full measured duration")
local invalid = Store.RecordResult(result({ aliveTime = 0/0 }))
check(not invalid.saved and invalid.reason == "invalid_time", "NaN must be rejected")
check(not Store.RecordResult(result({ elapsed = math.huge })).saved, "infinity must be rejected")
check(not Store.RecordResult(result({ elapsed = 100 })).saved, "inconsistent durations must be rejected")
Store.RecordResult(result({ highscoreEligible = false }))
check(Store.GetHistory()[1].reason == "unranked", "explicit eligibility is required")
local before = Store.GetStats().attempts
for index = 1, 100 do Store.RecordResult(result({ seed = 456, aliveTime = 200 - index, deadTime = index })) end
check(#Store.GetHistory() == 50 and #Store.GetBoard("reference", 1) == 10, "bounded history and top ten")
check(#Store.GetBoard("reference", 1, 456) == 10, "same-seed board survives overall competition")
check(Store.GetStats().attempts == before + 100, "lifetime attempts survive history trimming")
local board = Store.GetBoard("reference", 1)
board[1].score = 0
check(Store.GetBoard("reference", 1)[1].score == 1000000, "board getters cannot mutate database")
local history = Store.GetHistory()
history[1].elapsed = 0
check(Store.GetHistory()[1].elapsed ~= 0, "history getters cannot mutate database")
local db = Store.Initialize(Store.db)
check(#Store.GetHistory() == 50 and #Store.GetBoard("reference", 1) == 10, "reload roundtrip")
for index = 1, 50 do Store.RecordResult(result({ version = "v" .. index, seed = index })) end
local partitionCount = 0
for _ in pairs(Store.db.boards) do partitionCount = partitionCount + 1 end
check(partitionCount <= 128, "partition cap covers separate encounter/drill boards")
local corrupt = { schemaVersion = 1, options = { speed = 0/0, seed = math.huge }, history = { false, result({ aliveTime = math.huge }) }, stats = { attempts = math.huge }, boards = { false } }
Store.Initialize(corrupt)
check(Store.GetOptions().speed == 1 and Store.GetStats().attempts == 0, "malformed saved variables are sanitized")
check(#Store.GetHistory() == 0, "corrupt history cannot create a score")
local future = { schemaVersion = 999, options = { loop = 2 }, note = "future database" }
future.cycle = future
Store.Initialize(future)
check(Store.db.recovery.note == "future database" and Store.GetOptions().loop == 2, "bounded future-schema recovery")
check(Store.GetDailySeed("2026-09-04") == Store.GetDailySeed("2026-09-04"), "daily determinism")
check(Store.GetDailySeed("2026-09-04") ~= Store.GetDailySeed("2026-09-05"), "different daily seeds")
check(Store.GetDailySeed(nil) >= 1 and Store.GetDailySeed(nil) <= 2147483646, "bounded fallback seed")
-- The movement clock changed in 0.6. Existing ranked results must retain their
-- old scenario partition when the addon loads with the new scenario version.
local previousEL = { SCENARIO_VERSION = "rashok-lava-2" }
assert(loadfile(source))("EncounterLab", previousEL)
previousEL.Store.Initialize(nil)
previousEL.Store.RecordResult(result({version="rashok-lava-2"}))
local currentEL = { SCENARIO_VERSION = "rashok-lava-3" }
assert(loadfile(source))("EncounterLab", currentEL)
local current = currentEL.Store
current.Initialize(previousEL.Store.db)
check(#current.GetBoard("reference",1)==0, "new movement scenario starts an independent board")
check(#current.GetBoard("reference",1,nil,"rashok-lava-2")==1, "old movement board survives upgrade")
current.RecordResult(result({version="rashok-lava-3"}))
check(#current.GetBoard("reference",1)==1 and #current.GetBoard("reference",1,nil,"rashok-lava-2")==1, "old and new movement results do not mix")
check(#current.GetHistory()==2 and current.GetHistory()[2].version=="rashok-lava-2", "upgrade retains old result in history")

print("persistence_test: " .. checks .. " checks passed")
