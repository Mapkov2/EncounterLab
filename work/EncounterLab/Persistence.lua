local _, EL = ...

-- Local records only. No result is uploaded or represented as a global score.
local Store = {}
EL.Store = Store
Store.VERSION = EL.SCENARIO_VERSION or EL.VERSION or "1"
local SCHEMA, HISTORY_LIMIT, BOARD_LIMIT, PARTITION_LIMIT = 1, 50, 10, 128
local MAX_TIME, MAX_TOTAL, MAX_SEED = 7200, 1000000000000, 2147483646
local floor, min, max = math.floor, math.min, math.max

local function number(value, default, low, high)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return default
    end
    return min(high, max(low, value))
end

local function integer(value, default, low, high)
    return floor(number(value, default, low, high))
end

local function copy(value)
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    return result
end

local function version(value)
    if type(value) == "number" then
        value = tostring(number(value, 1, 0, 999999))
    end
    if type(value) ~= "string" or #value == 0 or #value > 48 then return "1" end
    if not value:match("^[%w%._%-]+$") then return "1" end
    return value
end

local function mode(value)
    if value == "practice" or value == "assisted" then return value end
    return "reference"
end

local abilities = { blink=true, roll=true, sprint=true, leap=true, teleport_set=true, teleport=true, gateway_set=true, gateway=true, immunity=true }
local bindingOrder = { "forward", "backward", "left", "right", "turnLeft", "turnRight", "jump", "walk", "revive", "ability", "pause" }
local defaultBindings = { forward="W", backward="S", left="Q", right="E", turnLeft="A", turnRight="D", jump="SPACE", walk="NUMPADDIVIDE", revive="R", ability="F", pause="P" }
local function bindings(input)
    input = type(input) == "table" and input or {}
    local result, used = {}, {}
    for _, action in ipairs(bindingOrder) do
        local key = input[action]
        if type(key) == "string" and #key >= 1 and #key <= 20 and key:match("^[A-Z0-9%-]+$") and
            key ~= "ESCAPE" and key ~= "F11" and key ~= "ENTER" and key ~= "SLASH" and key ~= "TAB" and key ~= "LALT" and key ~= "RALT" and not used[key] then
            result[action], used[key] = key, true
        end
    end
    for _, action in ipairs(bindingOrder) do
        if not result[action] then
            local key = defaultBindings[action]
            if used[key] then
                for index = 1, 12 do
                    if index ~= 11 and not used["F" .. index] then key = "F" .. index; break end
                end
            end
            result[action], used[key] = key, true
        end
    end
    return result
end
local function copyOptions(value)
    local result = copy(value)
    result.bindings = copy(value.bindings)
    return result
end
local function options(input)
    input = type(input) == "table" and input or {}
    local result = {
        scenario = (input.scenario == "sszorak" or input.scenario == "sentinels") and input.scenario or "rashok",
        sentinelsNumber = integer(input.sentinelsNumber, 0, 0, 3),
        sentinelsReveal = integer(input.sentinelsReveal, 2, 1, 5),
        sszorakDrill = "tempest",
        sszorakCheckpoint = integer(input.sszorakCheckpoint, 1, 1, 3),
        loop = integer(input.loop, 1, 1, 3),
        mode = input.mode == "practice" and "practice" or "reference",
        speed = number(input.speed, 1, 0.25, 2),
        hints = input.hints == true,
        mouseSensitivity = number(input.mouseSensitivity, 0.006, 0.001, 0.03),
        invertY = input.invertY == true,
        fullscreen = input.fullscreen ~= false,
        bindingPreset = input.bindingPreset == "custom" and "custom" or "wow",
        selectedAbility = abilities[input.selectedAbility] and input.selectedAbility or "blink",
        windowWidth = integer(input.windowWidth, 1200, 640, 3840),
        windowHeight = integer(input.windowHeight, 760, 480, 2160),
        bindings = bindings(input.bindings),
    }
    if input.seed ~= nil then result.seed = integer(input.seed, 1, 1, MAX_SEED) end
    return result
end

-- Recovery is deliberately small and cycle safe; it is not a deep clone of an
-- unknown SavedVariables schema. The original global is assigned by Bootstrap.
local function recoverySnapshot(input)
    local seen, remaining = {}, 160
    local function visit(value, depth)
        local kind = type(value)
        if kind == "string" then return value:sub(1, 512) end
        if kind == "boolean" then return value end
        if kind == "number" then return number(value, 0, -MAX_TOTAL, MAX_TOTAL) end
        if kind ~= "table" or depth == 0 or seen[value] or remaining <= 0 then return nil end
        seen[value] = true
        local result, count = {}, 0
        for key, item in pairs(value) do
            if remaining <= 0 or count >= 24 then break end
            if (type(key) == "string" and #key <= 80) or
                (type(key) == "number" and key >= 1 and key <= 1000 and key == floor(key)) then
                remaining, count = remaining - 1, count + 1
                result[key] = visit(item, depth - 1)
            end
        end
        return result
    end
    return visit(input, 3)
end

local function finiteTime(value)
    return type(value) == "number" and value == value and value >= 0 and value <= MAX_TIME
end

local function normalizeResult(input)
    if type(input) ~= "table" then return nil, "invalid_result" end
    if input.mode ~= "reference" and input.mode ~= "practice" and input.mode ~= "assisted" then
        return nil, "invalid_mode"
    end
    if not finiteTime(input.elapsed) or not finiteTime(input.aliveTime) or not finiteTime(input.deadTime) then
        return nil, "invalid_time"
    end
    local duration = input.aliveTime + input.deadTime
    if duration > MAX_TIME or math.abs(duration - input.elapsed) > 0.25 then
        return nil, "inconsistent_time"
    end
    if type(input.loop) ~= "number" or input.loop ~= floor(input.loop) or input.loop < 1 or input.loop > 3 then
        return nil, "invalid_loop"
    end
    local assisted = input.assisted == true or input.hints == true or input.paused == true
    if input.speed ~= nil and input.speed ~= 1 then assisted = true end
    local bucket = mode(input.mode)
    if bucket == "reference" and assisted then bucket = "assisted" end
    if type(input.deaths) ~= "number" or input.deaths ~= input.deaths or input.deaths < 0 or input.deaths > 100000 or input.deaths ~= floor(input.deaths) then
        return nil, "invalid_deaths"
    end
    local deaths = integer(input.deaths, 0, 0, 100000)
    if input.deadTime > 0 then deaths = max(1, deaths) end
    local completed = input.completed == true and input.interrupted ~= true and duration > 0
    local survival = duration > 0 and input.aliveTime / duration or 0
    local entry = {
        version = version(input.version), mode = bucket, loop = input.loop,
        seed = integer(input.seed, 1, 1, MAX_SEED), elapsed = duration,
        aliveTime = input.aliveTime, deadTime = input.deadTime, deaths = deaths,
        completed = completed, interrupted = input.interrupted == true,
        assisted = assisted or bucket ~= "reference", arenaExit = input.arenaExit == true,
        bonus = input.bonus == true and input.loop == 1,
        perfect = completed and input.perfect == true and deaths == 0 and input.deadTime == 0,
        survival = survival, survivalPercent = survival * 100,
        -- Own display score: one million points for 100% survival. The board
        -- comparator uses the unrounded fraction, then completion achievements.
        score = floor(survival * 1000000 + 0.5),
        highscoreEligible = input.highscoreEligible == true,
        serial = integer(input.serial, 0, 0, MAX_TOTAL),
        timestamp = integer(input.timestamp, 0, 0, MAX_TOTAL),
    }
    if entry.version:match("^sentinels%-") then
        entry.matchTime = number(input.matchTime, 30, 0, 30)
        entry.highscoreEligible = entry.highscoreEligible and entry.perfect and finiteTime(input.matchTime) and input.matchTime<=30
    end
    if entry.arenaExit then entry.reason = "arena_exit"
    elseif entry.interrupted then entry.reason = "interrupted"
    elseif not completed then entry.reason = "incomplete"
    elseif not entry.highscoreEligible then entry.reason = "unranked"
    else entry.reason = "ranked" end
    entry.highscoreEligible = entry.reason == "ranked"
    return entry
end

-- Loop and scenario version have independent boards. Percentage is primary;
-- equal percentages prefer bonus, perfect, less dead time, then fewer deaths.
-- Earlier records win exact ties, so repeating a tie never reports a new best.
local function better(a, b)
    if a.version:match("^sentinels%-") and a.matchTime~=b.matchTime then return (a.matchTime or 30)<(b.matchTime or 30) end
    if a.survival ~= b.survival then return a.survival > b.survival end
    if a.bonus ~= b.bonus then return a.bonus end
    if a.perfect ~= b.perfect then return a.perfect end
    if a.deadTime ~= b.deadTime then return a.deadTime < b.deadTime end
    if a.deaths ~= b.deaths then return a.deaths < b.deaths end
    return a.serial < b.serial
end

local function keyFor(ver, bucket, loop, seed)
    return ver .. "|" .. bucket .. "|" .. tostring(loop) .. "|" .. (seed and tostring(seed) or "all")
end

local function trimPartitions(db)
    local keys = {}
    for key in pairs(db.boards) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local left, right = db.boards[a].updatedSerial, db.boards[b].updatedSerial
        if left ~= right then return left > right end
        return a < b
    end)
    for index = PARTITION_LIMIT + 1, #keys do db.boards[keys[index]] = nil end
end

local statKeys = { "attempts", "completed", "interrupted", "ranked", "perfect", "deaths", "aliveTime", "deadTime", "arenaExits" }
function Store.Initialize(saved)
    local db = { schemaVersion = SCHEMA, options = options(), history = {}, boards = {}, stats = {}, serial = 0 }
    for _, key in ipairs(statKeys) do db.stats[key] = 0 end
    if type(saved) == "table" then
        db.options = options(saved.options)
        if saved.schemaVersion ~= SCHEMA then
            db.recovery = recoverySnapshot(saved)
        else
            db.serial = integer(saved.serial, 0, 0, MAX_TOTAL)
            if type(saved.stats) == "table" then
                for _, key in ipairs(statKeys) do db.stats[key] = number(saved.stats[key], 0, 0, MAX_TOTAL) end
            end
            if type(saved.history) == "table" then
                for index = 1, HISTORY_LIMIT do
                    local entry = normalizeResult(saved.history[index])
                    if entry then
                        db.history[#db.history + 1] = entry
                        db.serial = max(db.serial, entry.serial)
                    end
                end
            end
            if type(saved.boards) == "table" then
                local scanned = 0
                for _, board in pairs(saved.boards) do
                    scanned = scanned + 1
                    if scanned > PARTITION_LIMIT * 2 then break end
                    if type(board) == "table" and type(board.entries) == "table" then
                        local ver, bucket = version(board.version), mode(board.mode)
                        local loop = integer(board.loop, 1, 1, 3)
                        local seed = board.seed and integer(board.seed, 1, 1, MAX_SEED) or nil
                        local clean = { version = ver, mode = bucket, loop = loop, seed = seed, entries = {}, updatedSerial = 0 }
                        for index = 1, BOARD_LIMIT do
                            local entry = normalizeResult(board.entries[index])
                            if entry and entry.highscoreEligible and entry.version == ver and entry.mode == bucket and
                                entry.loop == loop and (not seed or entry.seed == seed) then
                                clean.entries[#clean.entries + 1] = entry
                                clean.updatedSerial = max(clean.updatedSerial, entry.serial)
                                db.serial = max(db.serial, entry.serial)
                            end
                        end
                        if #clean.entries > 0 then
                            table.sort(clean.entries, better)
                            db.boards[keyFor(ver, bucket, loop, seed)] = clean
                        end
                    end
                end
            end
            if type(saved.recovery) == "table" then db.recovery = recoverySnapshot(saved.recovery) end
        end
    end
    trimPartitions(db)
    Store.db = db
    return db
end

local function database()
    return Store.db or Store.Initialize(nil)
end

function Store.GetOptions()
    return copyOptions(database().options)
end

function Store.SaveOptions(changes)
    local db, merged = database(), Store.GetOptions()
    if type(changes) == "table" then
        for key in pairs(merged) do if key ~= "bindings" and changes[key] ~= nil then merged[key] = changes[key] end end
        if type(changes.bindings) == "table" then
            for _, action in ipairs(bindingOrder) do
                if changes.bindings[action] ~= nil then merged.bindings[action] = changes.bindings[action] end
            end
        end
        if changes.seed ~= nil then merged.seed = changes.seed end
    end
    db.options = options(merged)
    return copyOptions(db.options)
end

local function insertBoard(db, entry, seed)
    local key = keyFor(entry.version, entry.mode, entry.loop, seed)
    local board = db.boards[key]
    if not board then
        board = { version = entry.version, mode = entry.mode, loop = entry.loop, seed = seed, entries = {}, updatedSerial = entry.serial }
        db.boards[key] = board
    end
    local newBest = #board.entries == 0 or better(entry, board.entries[1])
    board.entries[#board.entries + 1] = copy(entry)
    board.updatedSerial = entry.serial
    table.sort(board.entries, better)
    local rank
    for index, item in ipairs(board.entries) do if item.serial == entry.serial then rank = index end end
    while #board.entries > BOARD_LIMIT do table.remove(board.entries) end
    if rank and rank > BOARD_LIMIT then rank = nil end
    return newBest, rank
end

function Store.RecordResult(result)
    local entry, errorReason = normalizeResult(result)
    if not entry then return { saved = false, reason = errorReason, newBest = false } end
    local db = database()
    db.serial = min(MAX_TOTAL, db.serial + 1)
    entry.serial = db.serial
    if type(time) == "function" then entry.timestamp = integer(time(), 0, 0, MAX_TOTAL) end
    table.insert(db.history, 1, copy(entry))
    while #db.history > HISTORY_LIMIT do table.remove(db.history) end
    local stats = db.stats
    stats.attempts = min(MAX_TOTAL, stats.attempts + 1)
    stats.deaths = min(MAX_TOTAL, stats.deaths + entry.deaths)
    stats.aliveTime = min(MAX_TOTAL, stats.aliveTime + entry.aliveTime)
    stats.deadTime = min(MAX_TOTAL, stats.deadTime + entry.deadTime)
    if entry.completed then stats.completed = min(MAX_TOTAL, stats.completed + 1) end
    if entry.interrupted then stats.interrupted = min(MAX_TOTAL, stats.interrupted + 1) end
    if entry.perfect then stats.perfect = min(MAX_TOTAL, stats.perfect + 1) end
    if entry.arenaExit then stats.arenaExits = min(MAX_TOTAL, stats.arenaExits + 1) end
    local newBest, rank = false, nil
    if entry.highscoreEligible then
        stats.ranked = min(MAX_TOTAL, stats.ranked + 1)
        newBest, rank = insertBoard(db, entry)
        insertBoard(db, entry, entry.seed)
        trimPartitions(db)
    end
    return { saved = true, reason = entry.reason, newBest = newBest, rank = rank, entry = copy(entry) }
end

function Store.GetBoard(bucket, loop, seed, scenarioVersion)
    local db = database()
    local ver = version(scenarioVersion or Store.VERSION)
    if seed ~= nil then seed = integer(seed, 1, 1, MAX_SEED) end
    local board = db.boards[keyFor(ver, mode(bucket), integer(loop, 1, 1, 3), seed)]
    local result = {}
    if board then for index, entry in ipairs(board.entries) do result[index] = copy(entry) end end
    return result
end

function Store.GetHistory()
    local result = {}
    for index, entry in ipairs(database().history) do result[index] = copy(entry) end
    return result
end

function Store.GetStats()
    return copy(database().stats)
end

function Store.GetDailySeed(dateString)
    if type(dateString) ~= "string" or not dateString:match("^%d%d%d%d%-%d%d%-%d%d$") then
        dateString = "1970-01-01"
    end
    local seed = 1729
    for index = 1, #dateString do seed = (seed * 31 + dateString:byte(index)) % MAX_SEED end
    return seed + 1
end
