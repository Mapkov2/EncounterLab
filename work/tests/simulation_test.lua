-- Run from the work directory: lua tests/simulation_test.lua
local EL = {}
assert(loadfile("EncounterLab/Simulation.lua"))("EncounterLab", EL)
local Simulation = EL.Simulation
local passed = 0
local function ok(value, label)
    assert(value, label)
    passed = passed + 1
end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    passed = passed + 1
end
local function near(actual, expected, label, epsilon)
    assert(math.abs(actual - expected) <= (epsilon or 1e-8), label .. ": expected " .. expected .. ", got " .. actual)
    passed = passed + 1
end
local function advanceTo(sim, time, input)
    while sim.state.time + 1e-9 < time and sim.state.status == "running" do
        sim:Advance(math.min(0.5, time - sim.state.time), input or {})
    end
end
local function isolate(sim)
    -- Test fixtures remove scheduled hazards only to probe a single rule precisely.
    sim._queue, sim._queueIndex = {}, 1
    sim.state.pools, sim.state.waves = {}, {}
    -- Unit movement/hazard fixtures choose their own origin independently of spawn.
    sim.state.player.x, sim.state.player.y, sim.state.player.yaw = 0, 0, 0
    sim.state.player.displayYaw, sim.state.player.previousDisplayYaw = 0, 0
end

do
    local pools = {
        { -44.43, -23.36 }, { -57.85, 0.67 }, { -38.26, -4.57 },
        { -29.36, 14.93 }, { -10.22, 56.44 }, { -34.73, 34.97 },
        { -6.39, 26.75 }, { 55.21, 6.95 }, { 30.95, 16.67 },
    }
    local targets = {
        { -21.10, -0.42 }, { -20.14, 9.35 }, { -4.51, 4.37 },
        { -8.64, 21.97 }, { -3.16, 26.48 }, { -0.33, 9.57 },
        { 19.40, 7.07 }, { 32.94, -2.39 }, { 32.17, -1.79 },
    }
    local sim = Simulation.New({})
    near(sim.state.player.x, 24.32, "fresh player x")
    near(sim.state.player.y, 14.44, "fresh player y")
    near(sim.state.player.yaw, -5 * math.pi / 6, "fresh player facing minus 150 degrees")
    near(sim.state.boss.x, 0, "fresh boss x")
    near(sim.state.boss.y, 0, "fresh boss y")
    near(sim.state.boss.yaw, math.pi / 6, "fresh boss facing 30 degrees")
    sim.state.player.x, sim.state.player.y = 500, 500
    for index = 1, 9 do
        local start = 1 + 19.75 * (index - 1)
        advanceTo(sim, start)
        local boss, origin = sim.state.boss, pools[index]
        local x, y = boss.x, boss.y
        local dx, dy = origin[1] - x, origin[2] - y
        local distance = math.sqrt(dx * dx + dy * dy)
        near(sim.state.slam.x, origin[1], "announced pool x " .. index)
        near(sim.state.slam.y, origin[2], "announced pool y " .. index)
        near(math.cos(boss.yaw), dx / distance, "boss faces announcement x " .. index)
        near(math.sin(boss.yaw), dy / distance, "boss faces announcement y " .. index)
        advanceTo(sim, start + 5)
        near(boss.x, x, "boss holds cast location x " .. index)
        near(boss.y, y, "boss holds cast location y " .. index)
        advanceTo(sim, start + 5.25)
        local landX, landY = origin[1] - dx / distance * 10, origin[2] - dy / distance * 10
        near(boss.x, x + (landX - x) / 3, "leap is one third complete x " .. index)
        near(boss.y, y + (landY - y) / 3, "leap is one third complete y " .. index)
        equal(#sim.state.pools, index - 1, "pool waits for landing " .. index)
        advanceTo(sim, start + 5.75)
        local pool = sim.state.pools[index]
        near(pool.x, origin[1], "stationary pool origin x " .. index)
        near(pool.y, origin[2], "stationary pool origin y " .. index)
        near(boss.x, landX, "boss landing x " .. index)
        near(boss.y, landY, "boss landing y " .. index)
        near(math.sqrt((boss.x - pool.x)^2 + (boss.y - pool.y)^2), 10,
            "pool and boss landing separated by ten yards " .. index)
        if index % 3 == 0 then
            advanceTo(sim, start + 7.75)
            local frontal = sim.state.frontal
            near(frontal.x, landX, "frontal originates at actual boss landing x " .. index)
            near(frontal.y, landY, "frontal originates at actual boss landing y " .. index)
            local yaw = frontal.yaw
            sim.state.player.x, sim.state.player.y = -sim.state.player.x, -sim.state.player.y
            advanceTo(sim, start + 12.5)
            near(boss.x, landX, "frontal holds boss x " .. index)
            near(boss.y, landY, "frontal holds boss y " .. index)
            near(boss.yaw, yaw, "frontal holds boss facing " .. index)
            near(frontal.yaw, yaw, "frontal holds hit direction " .. index)
        end
        local moveAt = start + (index % 3 == 0 and 13.75 or 7.75)
        advanceTo(sim, moveAt)
        near(boss.x, landX, "reposition starts without early movement x " .. index)
        near(boss.y, landY, "reposition starts without early movement y " .. index)
        equal(sim._bossMove.starts, moveAt, "reposition begins at prescribed time " .. index)
        local target = targets[index]
        local travel = math.sqrt((target[1] - landX)^2 + (target[2] - landY)^2)
        advanceTo(sim, moveAt + 0.5)
        near(math.sqrt((boss.x - landX)^2 + (boss.y - landY)^2), math.min(7, travel),
            "reposition moves fourteen yards per second " .. index)
        advanceTo(sim, start + 19.5)
        near(boss.x, target[1], "reposition arrives x " .. index)
        near(boss.y, target[2], "reposition arrives y " .. index)
        equal(sim._bossMove, nil, "reposition stops on arrival " .. index)
        near(pool.x, origin[1], "pool stays at origin after boss departs x " .. index)
        near(pool.y, origin[2], "pool stays at origin after boss departs y " .. index)
    end
end

do
    -- A nearby cast reaches the pool itself instead of overshooting or backing up.
    local sim = Simulation.New({})
    sim.state.boss.x, sim.state.boss.y = -47.43, -27.36
    sim.state.player.x, sim.state.player.y = 500, 500
    advanceTo(sim, 6.75)
    near(sim.state.boss.x, -44.43, "within-ten-yard leap lands at pool x")
    near(sim.state.boss.y, -23.36, "within-ten-yard leap lands at pool y")
end

do
    for _, kind in ipairs({ "slam", "frontal" }) do
        local sim = Simulation.New({})
        isolate(sim)
        sim.state.player.x, sim.state.player.y = 500, 500
        sim.state.boss.x, sim.state.boss.y = 200, 0
        sim:_processEvent({ kind = "reposition", index = 1, time = 0 })
        sim._queue = { { time = 1, kind = kind, index = 1 } }
        advanceTo(sim, 1)
        local x, y, yaw = sim.state.boss.x, sim.state.boss.y, sim.state.boss.yaw
        near(math.sqrt((x - 200)^2 + y^2), 14, kind .. " advances moving boss exactly to cast start")
        equal(sim._bossMove, nil, kind .. " cancels tactical movement")
        advanceTo(sim, 5.5)
        near(sim.state.boss.x, x, kind .. " stops moving boss x during cast")
        near(sim.state.boss.y, y, kind .. " stops moving boss y during cast")
        near(sim.state.boss.yaw, yaw, kind .. " holds boss yaw during cast")
    end
end

do
    local sim = Simulation.New({ seed = 23 })
    sim.state.player.x, sim.state.player.y = 500, 500
    advanceTo(sim, 6.75)
    equal(#sim.state.pools, 1, "first landing pool")
    equal(sim.state.emissionCount, 1, "first global emission")
    equal(#sim.state.waves, 10, "first ten waves")
    advanceTo(sim, 178.75)
    equal(#sim.state.pools, 9, "nine persistent pools")
    equal(sim.state.emissionCount, 27, "twenty-seven global emissions")
    equal(sim.state.lastEmissionWaveCount, 90, "final global emission has ninety waves")
    equal(sim.state.deaths, 1, "frontal has no distance cap")
    advanceTo(sim, 189.75)
    equal(sim.state.status, "finished", "regular finish")
    equal(sim:GetResult().elapsed, 189.75, "regular elapsed")
    ok(not sim:GetResult().bonus, "death disqualifies bonus")
    near(sim.state.aliveTime + sim.state.deadTime, sim.state.elapsed, "all timeline time accounted")
    equal(sim:GetResult().score, math.floor(sim.state.aliveTime / sim.state.elapsed * 100), "floor alive percentage")
end

do
    for loop = 2, 3 do
        local sim = Simulation.New({ loop = loop })
        equal(sim.state.time, (loop - 1) * 59.25, "selected loop start")
        equal(#sim.state.pools, (loop - 1) * 3, "selected loop preplaced pools")
        equal(#sim.state.waves, 0, "preplaced pools do not emit")
        equal(sim.state.emissionCount, 0, "no historical emissions replayed")
        near(sim.state.boss.x, 0, "selected loop resets boss x")
        near(sim.state.boss.y, 0, "selected loop resets boss y")
        near(sim.state.boss.yaw, math.pi / 6, "selected loop resets boss facing")
        near(sim.state.player.x, 24.32, "selected loop resets player x")
        near(sim.state.player.y, 14.44, "selected loop resets player y")
        near(sim.state.player.yaw, -5 * math.pi / 6, "selected loop resets player facing")
        equal(sim._bossMove, nil, "selected loop does not replay previous reposition")
        equal(sim._bossLeap, nil, "selected loop does not replay previous leap")
        advanceTo(sim, 189.75)
        near(sim:GetResult().elapsed, 189.75 - (loop - 1) * 59.25, "selected loop elapsed")
        equal(sim.state.emissionCount, (4 - loop) * 9 + 1, "selected loop remaining absolute emissions")
        ok(not sim:GetResult().bonus, "selected loops do not qualify for bonus")
    end
end

do
    local sim = Simulation.New({})
    sim.state.player.x, sim.state.player.y = 500, 500
    advanceTo(sim, 48.25)
    local frontal = sim.state.frontal
    local locked = frontal.yaw
    sim.state.player.x, sim.state.player.y = -500, -500
    advanceTo(sim, 52)
    equal(sim.state.frontal.yaw, locked, "frontal direction stays locked")
    advanceTo(sim, 53.25)
    ok(not sim.state.player.dead, "moving behind locked frontal avoids it")
    equal(sim.state.frontal, nil, "frontal clears after hit")
end

do
    local function signature(fps, seed)
        local sim = Simulation.New({ seed = seed })
        sim.state.player.x, sim.state.player.y = 200, 200
        for frame = 1, fps * 25 do sim:Advance(1 / fps, { forward = 1, strafe = 1, turn = 0.2 }) end
        local chunks = { string.format("%.9f/%.9f/%.9f/%d/%d", sim.state.time,
            sim.state.player.x, sim.state.player.y, sim.state.emissionCount, #sim.state.waves) }
        for _, wave in ipairs(sim.state.waves) do
            chunks[#chunks + 1] = string.format("%d:%.9f:%.9f", wave.id, wave.x, wave.y)
        end
        return table.concat(chunks, "|")
    end
    local s60 = signature(60, 4567)
    equal(signature(30, 4567), s60, "30 and 60 FPS identical")
    equal(signature(144, 4567), s60, "144 and 60 FPS identical")
    equal(signature(60, 4567), s60, "same seed resets reproducibly")
    ok(signature(60, 4568) ~= s60, "different seed changes wave phases")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim.state.pools[1] = { x = 0, y = 0, radius = 10, createdAt = -1 }
    sim.state.player.x, sim.state.player.z = 10, 12
    sim:Advance(1 / 60, {})
    ok(sim.state.player.dead, "pool boundary inclusive and ignores jump height")
    equal(sim.state.deaths, 1, "death counts once")
    sim:Advance(0.5, { forward = 1 })
    equal(sim.state.deaths, 1, "remaining dead does not add deaths")
    near(sim.state.player.x, 17, "dead pool victim moves with knockback")
    ok(sim.state.player.z > 0, "dead pool victim remains airborne during knockback")
    sim.state.player.x = 10
    ok(sim:Revive(), "revive succeeds")
    sim:Advance(1 / 60, { forward = 1 })
    equal(sim.state.deaths, 2, "revive grants no pool invulnerability")
    sim.state.player.x = 10.001
    sim:Revive()
    sim:Advance(1 / 60, {})
    ok(not sim.state.player.dead, "outside pool radius survives")
    near(sim.state.aliveTime + sim.state.deadTime, sim.state.elapsed, "revive accounting")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim:_addWave(3.875, 0, math.pi / 2)
    sim.state.waves[1].dx, sim.state.waves[1].dy = 0, 0
    sim.state.player.z = 9
    sim:Advance(1 / 60, {})
    ok(sim.state.player.dead, "wave boundary inclusive and ignores jump height")
    sim.state.waves[1].x, sim.state.waves[1].previousX = 3.876, 3.876
    sim:Revive()
    sim:Advance(1 / 60, {})
    ok(not sim.state.player.dead, "outside wave radius survives")
    sim.state.waves = {}
    sim:_addWave(90, 20, 0)
    sim:Advance(1 / 60, {})
    ok(sim.state.waves[1].fadeStartedAt ~= nil, "crossing square extent starts fade")
    sim:Advance(0.5, {})
    near(sim.state.waves[1].alpha, 0.5, "fade lasts one second")
    sim:Advance(0.5, {})
    equal(#sim.state.waves, 0, "faded waves removed")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim.state.player.x, sim.state.player.y = 10, 10
    ok(sim:_frontalHit({ x = 0, y = 0, yaw = 0 }), "45 degree frontal boundary inclusive")
    sim.state.player.y = 10.001
    ok(not sim:_frontalHit({ x = 0, y = 0, yaw = 0 }), "outside frontal angle survives")
    sim.state.player.x, sim.state.player.y = 900, 0
    ok(sim:_frontalHit({ x = 0, y = 0, yaw = 0 }), "frontal infinite range")
    sim.state.player.x, sim.state.player.y = 0, 0
    sim:Advance(0.5, { forward = 1, strafe = 1 })
    near(math.sqrt(sim.state.player.x^2 + sim.state.player.y^2), 3.5, "diagonal speed normalized")
    sim.state.player.x, sim.state.player.y = 0, 0
    sim:Advance(0.5, { forward = -1 })
    near(sim.state.player.x, -2.25, "backward speed 4.5")
    sim:Advance(0.5, { turn = 1 })
    near(sim.state.player.yaw, 1.25, "turn speed 2.5")
end

do
    local sim = Simulation.New({ mode = "practice", timeScale = 0.5 })
    sim:Advance(0.5, {})
    near(sim.state.elapsed, 0.25, "half speed")
    sim:SetPaused(true)
    sim:Advance(0.5, {})
    near(sim.state.elapsed, 0.25, "pause freezes encounter")
    sim:SetPaused(false)
    sim:Advance(0.5, {})
    near(sim.state.elapsed, 0.5, "resume continues encounter")
    sim:Advance(2, {})
    equal(sim.state.status, "paused", "large frame gap pauses")
    near(sim.state.elapsed, 0.5, "large frame gap does not skip events")
    ok(sim.state.interrupted and sim.state.assisted, "interrupted run marked")
    sim.options.timeScale = 1
    sim:SetPaused(false)
    advanceTo(sim, 189.75)
    ok(not sim:GetResult().highscoreEligible, "interrupted run excluded from highscores")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    ok(sim:UseAbility("blink"), "blink available")
    near(sim.state.player.x, 20, "blink twenty")
    ok(not sim:UseAbility("blink"), "blink cooldown")
    ok(sim.state.assisted, "mobility marks assisted")
    ok(sim:UseAbility("teleport_set"), "set teleport")
    sim.state.player.x = 0
    ok(sim:UseAbility("teleport"), "use teleport")
    near(sim.state.player.x, 20, "teleport endpoint")
    ok(sim:UseAbility("gateway_set", 60, 0), "set gateway")
    ok(sim:UseAbility("gateway"), "use gateway")
    near(sim.state.player.x, 60, "gateway endpoint")
    ok(sim:UseAbility("immunity"), "immunity ability")
    sim.state.pools[1] = { x = 60, y = 0, createdAt = -1 }
    sim:Advance(1 / 60, {})
    ok(sim.state.player.dead, "immunity does not prevent pool death")
    sim:Destroy()
    local time = sim.state.time
    sim:Advance(0.5, {})
    equal(sim.state.time, time, "destroyed simulation cannot advance")
end

do
    local sim = Simulation.New({ seed = 123 })
    -- Isolated qualification fixture preserves the production bonus/finish schedule.
    local queue = {}
    for _, event in ipairs(sim._queue) do
        if event.time >= 183.75 then queue[#queue + 1] = event end
    end
    sim._queue, sim._queueIndex = queue, 1
    sim.state.player.x, sim.state.player.y = 500, 500
    advanceTo(sim, 183.75)
    ok(sim.state.bonus, "perfect loop one qualifies")
    advanceTo(sim, 185.75)
    equal(#sim.state.waves, 168, "bonus creates eight times twenty-one waves")
    equal(sim.state.bonusWaveCount, 168, "bonus emitted count")
    local first, second = sim.state.waves[1], sim.state.waves[2]
    near(math.sqrt((first.x-second.x)^2 + (first.y-second.y)^2), 24, "bonus spacing twenty-four")
    near(math.sqrt(first.dx^2 + first.dy^2), 14, "bonus wave speed fourteen")
    for wall = 0, 7 do
        local yaw = sim.state.bonusRotation + wall * math.pi / 4
        local dx, dy = math.cos(yaw), math.sin(yaw)
        for point = -10, 10 do
            local wave = sim.state.waves[wall * 21 + point + 11]
            near(wave.x * dx + wave.y * dy, -80, "bonus wall starts eighty yards behind travel")
            near(-wave.x * dy + wave.y * dx, 24 * point + 6, "bonus wall has six-yard tangent offset")
            near(wave.dx, 14 * dx, "bonus wall travels forward x")
            near(wave.dy, 14 * dy, "bonus wall travels forward y")
        end
    end
    advanceTo(sim, 189.75)
    equal(sim.state.status, "running", "bonus continues past regular finish")
    ok(sim.state.frontal ~= nil, "bonus frontal starts at 189.75")
    local frontal = sim.state.frontal
    sim.state.player.x = frontal.x - math.cos(frontal.yaw) * 500
    sim.state.player.y = frontal.y - math.sin(frontal.yaw) * 500
    advanceTo(sim, 196.75)
    equal(sim.state.status, "finished", "bonus finish at 196.75")
    ok(sim:GetResult().bonus and sim:GetResult().perfect, "perfect bonus result")
    equal(sim:GetResult().score, 100, "perfect score")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim:Advance(1 / 144, { jump = true })
    ok(sim.state.player.z > 0, "jump responds in the first input frame")
    sim:Advance(1 / 144, { jump = false })
    sim:Advance(1 / 144, { jump = false })
    ok(sim.state.player.z > 0, "one-render-frame jump survives until fixed tick")
    sim:_kill("Test")
    sim:SetPaused(true)
    sim:Revive()
    equal(sim.state.status, "paused", "revive preserves explicit pause")
    local time = sim.state.time
    sim:Advance(0.5, { forward = 1 })
    equal(sim.state.time, time, "revive cannot resume paused time")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim.state.player.x = 75
    sim:Advance(1 / 60, {})
    ok(not sim.state.arenaExit, "rank ring boundary inclusive")
    sim.state.player.x = 75.001
    sim:Advance(1 / 60, {})
    ok(sim.state.arenaExit, "leaving rank ring marks run")
    ok(not sim.state.player.dead, "rank ring never kills player")
    sim.state.player.x = 0
    sim:Advance(1 / 60, {})
    ok(sim.state.arenaExit, "rank ring departure remains sticky")
    sim:_finish()
    ok(not sim:GetResult().highscoreEligible, "rank ring departure excludes highscore")
    equal(sim:GetResult().version, "rashok-lava-3", "score stores scenario version")
end

do
    local sim = Simulation.New({ seed = 13 })
    isolate(sim)
    sim:_addPool(1, true)
    sim:_addPool(2, true)
    sim:_emit()
    ok(sim.state.waves[1].yaw ~= sim.state.waves[11].yaw, "each pool has independent emission phase")
    for index = 2, 10 do
        near(sim.state.waves[index].yaw - sim.state.waves[index - 1].yaw,
            math.pi / 5, "radial spokes evenly spaced")
    end
    local original = sim.state.waves[1].yaw
    sim:_emit()
    ok(original ~= sim.state.waves[21].yaw, "each emission has new independent phase")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim.state.player.x, sim.state.player.y = 0, 0
    ok(sim:UseAbility("roll"), "roll available")
    sim:Advance(0.4, {})
    near(sim.state.player.x, 12, "roll travels twelve over short interval")
    ok(not sim:UseAbility("roll"), "roll cooldown")
    ok(sim:UseAbility("leap", 42, 0), "targeted leap available")
    sim:Advance(0.3, {})
    near(sim.state.player.x, 27, "targeted leap midpoint")
    ok(sim.state.player.z > 5, "targeted leap visible arc")
    sim:Advance(0.3, {})
    near(sim.state.player.x, 42, "targeted leap destination")
    near(sim.state.player.z, 0, "targeted leap lands")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim.state.pools[1] = { x = 0, y = 0, radius = 10, createdAt = -1 }
    sim.state.player.yaw = math.pi / 2
    sim:Advance(1 / 60, {})
    equal(sim.state.deaths, 1, "pool launch still counts death")
    for tick = 1, 120 do sim:Advance(1 / 60, { forward = -1, strafe = 1 }) end
    near(sim.state.player.x, 0, "center contact falls back to facing")
    near(sim.state.player.y, 25.2, "ballistic pool impulse carries corpse outside pool")
    near(sim.state.player.z, 0, "pool impulse lands")
    local x, y = sim.state.player.x, sim.state.player.y
    sim:Advance(0.5, { forward = 1 })
    near(sim.state.player.x, x, "landed dead player does not move x")
    near(sim.state.player.y, y, "landed dead player does not move y")
    ok(sim:Revive(), "corpse outside pool can revive")
    sim:Advance(1 / 60, {})
    ok(not sim.state.player.dead, "revive after knockback escapes original pool")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim.state.pools[1] = { x = 0, y = 0, radius = 10, createdAt = -1 }
    sim:Advance(1 / 60, {})
    sim:Advance(0.25, {})
    ok(sim.state.player.z > 0, "knockback is active before early revive")
    local x, y = sim.state.player.x, sim.state.player.y
    sim:Revive()
    sim.state.pools = {}
    sim:Advance(0.5, {})
    near(sim.state.player.x, x, "revive cancels horizontal impulse x")
    near(sim.state.player.y, y, "revive cancels horizontal impulse y")
    near(sim.state.player.z, 0, "revive cancels vertical impulse")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim.state.pools[1] = { x = 0, y = 0, radius = 10, createdAt = -1 }
    sim:UseAbility("immunity")
    sim:Advance(1 / 60, {})
    ok(sim.state.player.dead, "knockback immunity does not grant lava invulnerability")
    sim:Advance(0.5, {})
    near(sim.state.player.x, 0, "immunity suppresses horizontal knockback")
    near(sim.state.player.z, 0, "immunity suppresses vertical knockback")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    sim:Advance(1 / 60, { forward = 1, yaw = 0, jump = true })
    sim:Advance(0.4, { forward = -1, strafe = 1, yaw = math.pi / 2 })
    ok(sim.state.player.z > 0, "jump still airborne during steering check")
    near(sim.state.player.x, 7 * (0.4 + 1 / 60), "air input preserves launch speed")
    near(sim.state.player.y, 0, "air input and yaw cannot steer launch momentum")
    while sim.state.player.z > 0 do
        sim:Advance(1 / 60, { forward = -1, strafe = 1, yaw = math.pi / 2 })
    end
    local x = sim.state.player.x
    near(sim.state.player.y, 0, "launch momentum persists until landing")
    sim:Advance(1 / 60, { forward = 1, yaw = math.pi / 2 })
    near(sim.state.player.x, x, "ground movement uses new direction")
    near(sim.state.player.y, 7 / 60, "ground movement responds after landing")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    for frame = 1, 600 do sim:Advance(1 / 60, { forward = 1, walk = true }) end
    near(sim.state.player.x, 25, "walking ten seconds travels twenty-five")
    near(sim.state.player.y, 0, "walking follows facing")
    sim.state.player.x = 0
    for frame = 1, 600 do sim:Advance(1 / 60, { forward = -1, walk = true }) end
    near(sim.state.player.x, -25, "backward walking remains speed 2.5")
end

do
    local function airborneSignature(fps, pool)
        local sim = Simulation.New({})
        isolate(sim)
        -- Trigger at the same known time to isolate ballistic integration from
        -- collision-detection cadence (which now also runs on input frames).
        if pool then sim:_kill("Lava pool", sim:_poolImpulse({x=0,y=0})) end
        for frame = 1, fps * 2 do
            local input = frame / fps <= 0.25 and { forward = 1, jump = frame == 1 } or
                { forward = -1, strafe = 1, yaw = math.pi / 2 }
            sim:Advance(1 / fps, pool and {} or input)
        end
        return string.format("%.9f/%.9f/%.9f/%d/%.9f", sim.state.player.x,
            sim.state.player.y, sim.state.player.z, sim.state.deaths, sim.state.deadTime)
    end
    equal(airborneSignature(30, false), airborneSignature(60, false), "jump momentum identical at 30/60 FPS")
    equal(airborneSignature(144, false), airborneSignature(60, false), "jump momentum identical at 144/60 FPS")
    equal(airborneSignature(30, true), airborneSignature(60, true), "corpse ballistics identical at 30/60 FPS")
    equal(airborneSignature(144, true), airborneSignature(60, true), "corpse ballistics identical at 144/60 FPS")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    local player = sim.state.player
    player.previousYaw = -0.2
    player.displayYaw = 0.5
    player.previousDisplayYaw = 0.3
    local x, y, time = player.x, player.y, sim.state.time
    ok(sim:SetPlayerFacing(math.pi / 2), "render-sampled RMB facing is accepted while stationary")
    near(player.yaw, math.pi / 2, "render-sampled facing updates logical orientation immediately")
    near(player.previousYaw, math.pi / 2 - 0.2, "render-sampled facing rotates logical interpolation snapshot")
    near(player.displayYaw, math.pi / 2 + 0.5, "render-sampled facing carries current model offset")
    near(player.previousDisplayYaw, math.pi / 2 + 0.3, "render-sampled facing carries previous model offset")
    near(player.x, x, "render-sampled facing never advances stationary x")
    near(player.y, y, "render-sampled facing never advances stationary y")
    near(sim.state.time, time, "render-sampled facing never advances fixed simulation time")
    ok(player.cameraFacingLocked, "render-sampled facing marks the model camera-aligned")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    local player = sim.state.player
    sim:Advance(1 / 60, { forward = 1, jump = true })
    ok(player.z > 0, "airborne facing fixture takes off")
    local x, y = player.x, player.y
    ok(sim:SetPlayerFacing(math.pi / 2), "airborne RMB may update logical orientation")
    near(player.yaw, math.pi / 2, "airborne RMB orientation applies immediately")
    sim:Advance(1 / 60, { yaw = math.pi / 2 })
    ok(player.x > x, "airborne facing does not redirect stored launch velocity")
    near(player.y, y, "airborne facing preserves world-space launch direction")
end

do
    local forced = Simulation.New({})
    isolate(forced)
    ok(forced:UseAbility("roll"), "forced-facing fixture starts roll")
    local player = forced.state.player
    local yaw, previousYaw, displayYaw = player.yaw, player.previousYaw, player.displayYaw
    ok(not forced:SetPlayerFacing(1), "forced movement rejects RMB facing")
    near(player.yaw, yaw, "forced movement preserves logical orientation")
    near(player.previousYaw, previousYaw, "forced movement preserves orientation snapshot")
    near(player.displayYaw, displayYaw, "forced movement preserves model orientation")

    local dead = Simulation.New({})
    isolate(dead)
    dead:_kill("Test")
    yaw, previousYaw, displayYaw = dead.state.player.yaw, dead.state.player.previousYaw, dead.state.player.displayYaw
    ok(not dead:SetPlayerFacing(1), "dead player rejects RMB facing")
    near(dead.state.player.yaw, yaw, "dead player preserves logical orientation")
    near(dead.state.player.previousYaw, previousYaw, "dead player preserves orientation snapshot")
    near(dead.state.player.displayYaw, displayYaw, "dead player preserves model orientation")
end

do
    local sim = Simulation.New({})
    local player, boss = sim.state.player, sim.state.boss
    near(player.previousX, player.x, "fresh interpolation starts at spawn x")
    near(player.previousYaw, player.yaw, "fresh interpolation starts at spawn yaw")
    near(player.previousDisplayYaw, player.displayYaw, "fresh model interpolation starts at spawn facing")
    near(boss.previousY, boss.y, "fresh boss interpolation starts at spawn y")
    isolate(sim)
    sim:Advance(1 / 60, { forward = 1, turn = 1 })
    near(player.previousX, 0, "render player snapshot precedes fixed movement")
    near(player.previousYaw, 0, "render facing snapshot precedes fixed turn")
    near(sim:GetRenderAlpha(), 1, "exact boundary renders current pose")
    local time, x, yaw = sim.state.time, player.x, player.yaw
    sim:Advance(1 / 120, { forward = 1 })
    near(sim:GetRenderAlpha(), 1, "partial mechanics step renders current pose")
    near(sim.state.time, time + 1/120, "partial mechanics step consumes frame time")
    near(player.x, x + math.cos(yaw)*7/120, "partial mechanics step moves authoritative player")
    near(player.yaw, yaw, "interpolation does not change authoritative facing")
    sim:SetPaused(true)
    near(sim:GetRenderAlpha(), 1, "paused rendering settles at authoritative pose")
    sim:SetPaused(false)
    near(sim:GetRenderAlpha(), 1, "resume renders the current pose")
    sim:UseAbility("blink")
    near(player.previousX, player.x, "blink resets interpolation x")
    near(player.previousY, player.y, "blink resets interpolation y")
    sim:UseAbility("teleport_set")
    player.x = player.x + 4
    sim:UseAbility("teleport")
    near(player.previousX, player.x, "teleport resets interpolation x")
    sim:UseAbility("gateway_set", player.x + 30, player.y)
    sim:UseAbility("gateway")
    near(player.previousX, player.x, "gateway resets interpolation x")
    sim:_kill("Test")
    player.z = 8
    sim:Revive()
    near(player.previousZ, 0, "revive resets interpolation to ground")
    near(player.previousDisplayYaw, player.displayYaw, "revive resets model interpolation")
    near(player.displayYaw, player.yaw, "revive restores logical model heading")
    ok(not player.moving and not player.movingBackward, "revive clears movement animation flags")
    sim:Destroy()
    near(sim:GetRenderAlpha(), 1, "destroyed rendering settles at current pose")
end

do
    local sim = Simulation.New({})
    sim.state.player.x, sim.state.player.y = 500, 500
    advanceTo(sim, 6)
    local boss = sim.state.boss
    local x, y, z = boss.x, boss.y, boss.z
    sim:Advance(1 / 60, {})
    near(boss.previousX, x, "boss leap render snapshot x")
    near(boss.previousY, y, "boss leap render snapshot y")
    near(boss.previousZ, z, "boss leap render snapshot z")
    ok(boss.z > boss.previousZ, "boss snapshot allows leap interpolation")
end

do
    local directions = {
        { 1, 0, 0, "forward" }, { 0, 1, math.pi / 2, "left strafe" },
        { 0, -1, 3 * math.pi / 2, "right strafe" },
        { 1, 1, math.pi / 4, "forward left" }, { 1, -1, 7 * math.pi / 4, "forward right" },
        { -1, 0, 0, "backward" }, { -1, 1, 7 * math.pi / 4, "backward left" },
        { -1, -1, math.pi / 4, "backward right" },
    }
    for _, direction in ipairs(directions) do
        local sim = Simulation.New({})
        isolate(sim)
        sim:Advance(0.5, { forward = direction[1], strafe = direction[2] })
        local player = sim.state.player
        near(player.yaw, 0, direction[4] .. " preserves control heading")
        near(player.displayYaw, direction[3], direction[4] .. " displays appropriate model heading")
        equal(player.movingBackward, direction[1] < 0, direction[4] .. " selects backpedal state")
        ok(player.moving, direction[4] .. " selects moving state")
        local expected = direction[1] < 0 and 2.25 or 3.5
        near(math.sqrt(player.x^2 + player.y^2), expected, direction[4] .. " presentation preserves travel speed")
        local x, y = player.x, player.y
        ok(sim:UseAbility("blink"), direction[4] .. " allows blink")
        near(player.x, x + 20, direction[4] .. " blink follows logical heading")
        near(player.y, y, direction[4] .. " visual yaw cannot redirect blink")
        near(player.previousDisplayYaw, player.displayYaw, direction[4] .. " blink resets visual interpolation")
    end
end

do
    local sim = Simulation.New({})
    isolate(sim)
    local player = sim.state.player
    sim:Advance(1 / 60, { strafe = 1 })
    near(player.previousDisplayYaw, 0, "model snapshot precedes turn toward strafe")
    ok(player.displayYaw > 0 and player.displayYaw < math.pi / 2, "strafe model turns smoothly")
    sim:Advance(0.5, { strafe = 1, walk = true })
    ok(player.walking and player.moving, "walking has a distinct animation state")
    sim:Advance(0.5, {})
    near(player.displayYaw, player.yaw, "idle model returns to control heading")
    ok(not player.moving and not player.walking, "stopping clears movement and walk states")
    sim:Advance(1 / 60, { turn = 1 })
    ok(player.displayTurn > 0 and not player.moving, "stationary left turn selects shuffle direction")
    sim:Advance(1 / 60, { turn = -1 })
    ok(player.displayTurn < 0 and not player.moving, "stationary right turn selects shuffle direction")
    sim:Advance(1 / 60, { forward = 1, yaw = math.pi, lockFacing = true })
    near(player.displayYaw, player.yaw, "mouse-directed straight movement immediately faces camera")
end

do
    local sim = Simulation.New({})
    isolate(sim)
    local player = sim.state.player
    local peak, ticks = 0, 0
    repeat
        ticks = ticks + 1
        sim:Advance(1 / 60, { forward = 1, jump = ticks == 1 })
        peak = math.max(peak, player.z)
    until player.z <= 0
    -- The continuous curve lands at 49/60 exactly; a floating-point residue
    -- must not add a spurious extra step of airborne travel.
    equal(ticks, 49, "jump lands at the exact end of the existing arc")
    near(peak, 25 / 12, "jump reaches the expected two-yard arc at fixed tick resolution")
    near(player.x, 343 / 60, "jump horizontal travel stops at the exact landing time")
    near(player.jumpStartedAt, 1 / 60, "takeoff marker records animation start")
    near(player.landedAt, 49 / 60, "landing marker records the exact animation transition")
    sim:_kill("Test")
    ok(not player.moving and not player.movingBackward, "death clears locomotion animation state")
end

do
    -- Constant turn input follows a circular arc regardless of how render
    -- frames divide the mechanics grid.
    for _,fps in ipairs({30,60,144,240}) do
        local sim = Simulation.New({})
        isolate(sim)
        for frame=1,fps*2 do sim:Advance(1/fps,{forward=1,turn=1}) end
        near(sim.state.player.x,7/2.5*math.sin(5),"keyboard circle x is independent of frame subdivision")
        near(sim.state.player.y,7/2.5*(1-math.cos(5)),"keyboard circle y is independent of frame subdivision")
    end
end

local peakWaves = 0
do
    local sim = Simulation.New({ seed = 123456 })
    local boundedEvents = true
    while sim.state.status == "running" do
        sim:Advance(1 / 60, {})
        peakWaves = math.max(peakWaves, #sim.state.waves)
        boundedEvents = boundedEvents and #sim.state.events <= 40
    end
    ok(boundedEvents, "event journal remains bounded across every tick")
    equal(sim.state.emissionCount, 27, "complete tick-level pass preserves all emissions")
    ok(peakWaves >= 90 and peakWaves <= 270, "active wave population remains bounded")
end

do
    local function angle(value) return (value + math.pi) % (2 * math.pi) - math.pi end
    local axes = { {0,1,math.pi/2}, {0,-1,-math.pi/2}, {1,1,math.pi/4}, {1,-1,-math.pi/4}, {-1,1,-math.pi/4}, {-1,-1,math.pi/4} }
    for _, axis in ipairs(axes) do
        for _, speed in ipairs({-20,-4,4,20}) do
            local sim = Simulation.New({})
            isolate(sim)
            sim.state.player.displayYaw = 0
            for tick = 1, 30 do sim:Advance(1/60, {forward=axis[1],strafe=axis[2],yaw=0,lockFacing=true}) end
            for tick = 1, 60 do
                sim:Advance(1/60, {forward=axis[1],strafe=axis[2],yaw=tick*speed/60,lockFacing=true})
                local player = sim.state.player
                near(angle(player.displayYaw-player.yaw), axis[3], "mouse turn preserves movement-relative body facing")
            end
        end
    end
end

print("EncounterLab simulation: " .. passed .. " assertions passed")
print("Full reference run peak active waves (seed 123456): " .. peakWaves)
