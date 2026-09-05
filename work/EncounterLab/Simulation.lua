-- EncounterLab: independently authored encounter simulation with frame-time movement.
-- No WoW APIs and no upstream addon code are used in this module.
-- Behavior-derived geometry; visual/mobility calibration pending.
local _, EL = ...
EL = EL or {}

local Simulation = {}
EL.Simulation = Simulation
local Sim = {}
Sim.__index = Sim

local PI, TAU = math.pi, 2 * math.pi
local STEP = 1 / 60
local POOL_RADIUS, WAVE_RADIUS, WAVE_SPEED = 10, 3.875, 14
local BOSS_SPEED, LANDING_GAP = 14, 10
local VERSION = EL.SCENARIO_VERSION or "rashok-lava-3"
local COS45 = math.cos(PI / 4)

Simulation.VERSION = VERSION
Simulation.Constants = {
    tickRate = 60, poolRadius = POOL_RADIUS, waveHitRadius = WAVE_RADIUS,
    waveSpeed = WAVE_SPEED, maximumAdvance = 0.5,
}

-- Local yard positions relative to world (-2253.34, 2896.98), represented from
-- observed scenario behavior. These stationary pool origins also drive announcements.
local POOL_ORIGINS = {
    { -44.43, -23.36 }, { -57.85, 0.67 }, { -38.26, -4.57 },
    { -29.36, 14.93 }, { -10.22, 56.44 }, { -34.73, 34.97 },
    { -6.39, 26.75 }, { 55.21, 6.95 }, { 30.95, 16.67 },
}
local TACTICAL_POINTS = {
    { -21.10, -0.42 }, { -20.14, 9.35 }, { -4.51, 4.37 },
    { -8.64, 21.97 }, { -3.16, 26.48 }, { -0.33, 9.57 },
    { 19.40, 7.07 }, { 32.94, -2.39 }, { 32.17, -1.79 },
}
local function pointFor(index)
    return POOL_ORIGINS[index][1], POOL_ORIGINS[index][2]
end

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and PI or -PI) end
    if y > 0 then return PI / 2 end
    if y < 0 then return -PI / 2 end
    return 0
end

local function clamp(n, low, high)
    return math.max(low, math.min(high, n))
end

local function axis(n)
    return finite(n) and clamp(n, -1, 1) or 0
end

local function snapshotPose(pose)
    pose.previousX, pose.previousY, pose.previousZ = pose.x, pose.y, pose.z
    pose.previousYaw = pose.yaw
    pose.previousDisplayYaw = pose.displayYaw
end

local function normalizeSeed(value)
    local seed = finite(value) and math.floor(value) or 1
    seed = seed % 2147483647
    if seed == 0 then seed = 1 end
    return seed
end

local function segmentDistanceSquared(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local length = dx * dx + dy * dy
    local t = length > 0 and clamp(-(ax * dx + ay * dy) / length, 0, 1) or 0
    local x, y = ax + t * dx, ay + t * dy
    return x * x + y * y
end

function Sim:_random()
    -- Park-Miller arithmetic remains exact in Lua 5.1's double number range.
    self._rng = (self._rng * 16807) % 2147483647
    return (self._rng - 1) / 2147483646
end

function Sim:_event(kind, detail)
    local events = self.state.events
    events[#events + 1] = { time = self.state.time, kind = kind, detail = detail }
    if #events > 40 then table.remove(events, 1) end
end

function Sim:_addPool(index, preplaced)
    local x, y = pointFor(index)
    local pool = { id = index, x = x, y = y, radius = POOL_RADIUS,
        createdAt = preplaced and -1 or self.state.time }
    self.state.pools[#self.state.pools + 1] = pool
    return pool
end

function Sim:_addWave(x, y, yaw, bonus)
    self._nextWave = self._nextWave + 1
    self.state.waves[#self.state.waves + 1] = {
        id = self._nextWave, x = x, y = y, previousX = x, previousY = y,
        dx = math.cos(yaw) * WAVE_SPEED, dy = math.sin(yaw) * WAVE_SPEED,
        yaw = yaw, radius = WAVE_RADIUS, alpha = 1, createdAt = self.state.time,
        bonus = bonus or false,
    }
end

function Sim:_emit()
    local state = self.state
    state.emissionCount = state.emissionCount + 1
    state.lastEmissionWaveCount = #state.pools * 10
    for _, pool in ipairs(state.pools) do
        local phase = self:_random() * TAU
        for spoke = 0, 9 do self:_addWave(pool.x, pool.y, phase + spoke * TAU / 10) end
    end
    self:_event("emission", state.lastEmissionWaveCount)
end

function Sim:_bonusWaves()
    local rotation = self:_random() * TAU
    self.state.bonusWaveCount = 168
    self.state.bonusRotation = rotation
    -- Eight incoming walls around the center. Each has 21 equally spaced waves.
    -- Each wall begins 80 yards behind its travel direction with a 6-yard
    -- tangent offset. Remote ends fade by the normal arena rule.
    for line = 0, 7 do
        local yaw = rotation + line * TAU / 8
        local dx, dy = math.cos(yaw), math.sin(yaw)
        for point = -10, 10 do
            local tangent = point * 24 + 6
            self:_addWave(-80 * dx - tangent * dy,
                -80 * dy + tangent * dx, yaw, true)
        end
    end
    self:_event("bonus_waves", 168)
end

function Sim:_kill(reason, impulse)
    local state = self.state
    if state.player.dead then return end
    local height = state.player.z
    state.player.dead = true
    state.player.cameraFacingLocked = false
    state.player.moving, state.player.movingBackward, state.player.displayTurn = false, false, 0
    state.deaths = state.deaths + 1
    state.lastHit = reason
    state.player.z = impulse and math.max(0, height) or 0
    self._verticalVelocity = 0
    self._planarVX, self._planarVY = 0, 0
    self._forcedMovement = nil
    self._deathImpulse = impulse
    self:_event("death", reason)
end

function Sim:_poolImpulse(pool)
    if self.state.time < self.state.abilities.immunityUntil then return nil end
    local player = self.state.player
    local dx, dy = player.x - pool.x, player.y - pool.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > 1e-10 then
        dx, dy = dx / distance, dy / distance
    else
        dx, dy = math.cos(player.yaw), math.sin(player.yaw)
    end
    -- Original depth-sensitive tuning, not a copied knockback formula.
    -- Horizontal speed 14 units/s; deeper contact launches higher. Calibration is pending.
    return { vx = dx * 14, vy = dy * 14, vz = 8 + 10 * (1 - clamp(distance / POOL_RADIUS, 0, 1)) }
end

function Sim:_moveDeadPlayer(dt)
    local impulse = self._deathImpulse
    if not impulse then return end
    local player = self.state.player
    local duration = dt
    local nextZ = player.z + impulse.vz * dt - 10 * dt * dt
    if nextZ <= 0 and impulse.vz < 0 then
        -- Stop at the exact landing time within this tick, avoiding ground sliding.
        duration = clamp((impulse.vz + math.sqrt(impulse.vz^2 + 40 * player.z)) / 20, 0, dt)
        player.z, self._deathImpulse = 0, nil
    else
        player.z = math.max(0, nextZ)
        impulse.vz = impulse.vz - 20 * dt
    end
    player.x = player.x + impulse.vx * duration
    player.y = player.y + impulse.vy * duration
end

function Sim:_frontalHit(frontal)
    local player = self.state.player
    local dx, dy = player.x - frontal.x, player.y - frontal.y
    local length = math.sqrt(dx * dx + dy * dy)
    -- No distance cap. At the origin, the player is inside the attack.
    return length == 0 or
        (dx * math.cos(frontal.yaw) + dy * math.sin(frontal.yaw)) >= length * COS45 - 1e-10
end

function Sim:_schedule()
    local queue, order = {}, 0
    local function add(time, kind, index)
        if time <= self._startTime then return end
        order = order + 1
        queue[#queue + 1] = { time = time, kind = kind, index = index, order = order }
    end
    for index = 1, 9 do
        local start = 1 + 19.75 * (index - 1)
        add(start, "slam", index)
        add(start + 5, "leap", index)
        add(start + 5.75, "land", index)
        add(start + (index % 3 == 0 and 13.75 or 7.75), "reposition", index)
        add(start + 13.75, "emit", index)
        add(start + 19.75, "emit", index)
    end
    for loop = 1, 3 do
        local start = 48.25 + (loop - 1) * 59.25
        add(start, "frontal")
        add(start + 5, "frontal_hit")
    end
    add(183.75, "qualify")
    add(185.75, "bonus")
    add(189.75, "regular_finish")
    add(194.75, "bonus_frontal_hit")
    add(196.75, "bonus_finish")
    table.sort(queue, function(a, b)
        if a.time == b.time then return a.order < b.order end
        return a.time < b.time
    end)
    self._queue, self._queueIndex = queue, 1
end

function Sim:_startFrontal()
    local state = self.state
    local boss, player = state.boss, state.player
    self._bossMove, self._bossLeap = nil, nil
    boss.z = 0
    local yaw = atan2(player.y - boss.y, player.x - boss.x)
    boss.yaw = yaw
    state.frontal = { x = boss.x, y = boss.y, yaw = yaw,
        starts = state.time, ends = state.time + 5, width = PI / 2 }
    self:_event("frontal")
end

function Sim:_finish()
    self.state.status = "finished"
    self:_event("finished")
end

function Sim:_processEvent(event)
    local state, kind = self.state, event.kind
    if kind == "slam" then
        local x, y = pointFor(event.index)
        self._bossMove, self._bossLeap = nil, nil
        state.boss.yaw = atan2(y - state.boss.y, x - state.boss.x)
        state.slam = { x = x, y = y, id = event.index,
            starts = event.time, announceEnds = event.time + 5, ends = event.time + 5.75 }
        self:_event("slam", event.index)
    elseif kind == "leap" then
        local x, y = pointFor(event.index)
        local dx, dy = x - state.boss.x, y - state.boss.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance > LANDING_GAP then
            x, y = x - dx / distance * LANDING_GAP, y - dy / distance * LANDING_GAP
        end
        self._bossLeap = { x = state.boss.x, y = state.boss.y,
            toX = x, toY = y, starts = event.time, ends = event.time + 0.75 }
    elseif kind == "land" then
        self:_addPool(event.index)
        local leap = self._bossLeap
        state.boss.x, state.boss.y, state.boss.z = leap.toX, leap.toY, 0
        state.slam, self._bossLeap = nil, nil
        self:_event("land", event.index)
        self:_emit()
    elseif kind == "reposition" then
        local boss, target = state.boss, TACTICAL_POINTS[event.index]
        local dx, dy = target[1] - boss.x, target[2] - boss.y
        local distance = math.sqrt(dx * dx + dy * dy)
        self._bossMove = { x = boss.x, y = boss.y, toX = target[1], toY = target[2],
            starts = event.time, duration = distance / BOSS_SPEED }
        if distance > 0 then boss.yaw = atan2(dy, dx) end
    elseif kind == "emit" then
        self:_emit()
    elseif kind == "frontal" then
        self:_startFrontal()
    elseif kind == "frontal_hit" or kind == "bonus_frontal_hit" then
        if state.frontal and self:_frontalHit(state.frontal) then self:_kill("Frontal") end
        state.frontal = nil
    elseif kind == "qualify" then
        self._qualifyPending = true
    elseif kind == "bonus" then
        if state.bonus then self:_bonusWaves() end
    elseif kind == "regular_finish" then
        if state.bonus then self:_startFrontal() else self:_finish() end
    elseif kind == "bonus_finish" then
        if state.bonus then self:_finish() end
    end
end

function Sim:_updatePlayerPresentation(input, forced, dt)
    local player = self.state.player
    local forward, strafe = axis(input.forward), axis(input.strafe)
    local oldDisplay = player.displayYaw or player.yaw
    local target = oldDisplay
    local dx, dy = player.x - self._previousX, player.y - self._previousY
    player.moving = dx * dx + dy * dy > 1e-12
    player.walking = input.walk == true
    player.movingBackward = not forced and forward < 0
    -- Presentation may follow the current mouse camera without changing fixed-step facing.
    player.cameraFacingLocked = input.lockFacing == true and not forced
    if player.cameraFacingLocked then
        -- Carry mouse rotation first; the turn limit smooths only the body's
        -- movement offset, so fast camera turns cannot outrun or reverse it.
        local yawDelta = (player.yaw - (player.previousYaw or player.yaw) + PI) % TAU - PI
        oldDisplay = oldDisplay + yawDelta
    end

    -- Rendering follows travel without changing the heading used for controls,
    -- blink and other abilities. Backpedaling keeps the model facing away from travel.
    if forced and player.moving then
        target = atan2(dy, dx)
    elseif forward ~= 0 or strafe ~= 0 then
        target = player.yaw + atan2(strafe, forward)
        if player.movingBackward then target = target + PI end
    elseif player.z <= 0 or finite(input.yaw) or axis(input.turn) ~= 0 then
        target = player.yaw
    end

    local difference = (target - oldDisplay + PI) % TAU - PI
    local maximumTurn = ((player.moving or player.z > 0) and 10 or 5) * dt
    if input.lockFacing and strafe == 0 and forward ~= 0 and not forced then
        maximumTurn = PI
    end
    player.displayTurn = clamp(difference, -maximumTurn, maximumTurn)
    player.displayYaw = (oldDisplay + player.displayTurn) % TAU
end

function Sim:_movePlayer(input, dt)
    local player, state = self.state.player, self.state
    self._previousX, self._previousY = player.x, player.y
    if player.dead then self:_moveDeadPlayer(dt); return end
    if self._haltMovement then
        -- Revive consumes the next tick's movement, so held controls cannot move immediately.
        self._haltMovement = false
        return
    end
    local forced = self._forcedMovement
    local turnAngle = 0
    if not forced then
        if finite(input.yaw) then
            player.yaw = input.yaw % TAU
        else
            turnAngle = axis(input.turn) * 2.5 * dt
            player.yaw = (player.yaw + turnAngle) % TAU
        end
    end
    if forced then
        local fraction = clamp((state.time - forced.starts) / forced.duration, 0, 1)
        player.x = forced.x + forced.dx * fraction
        player.y = forced.y + forced.dy * fraction
        if forced.leap then player.z = math.sin(fraction * PI) * 6 end
        if fraction >= 1 then
            self._forcedMovement = nil
            player.z, self._verticalVelocity = 0, 0
            self._planarVX, self._planarVY = 0, 0
        end
    else
        local grounded = player.z <= 1e-9
        if grounded then
            local forward, strafe = axis(input.forward), axis(input.strafe)
            local length = math.sqrt(forward * forward + strafe * strafe)
            self._planarVX, self._planarVY = 0, 0
            if length > 0 then
                forward, strafe = forward / math.max(1, length), strafe / math.max(1, length)
                local walking = input.walk == true
                local speed = walking and 2.5 or (forward < 0 and 4.5 or 7)
                if not walking and state.time < state.abilities.sprintUntil then speed = speed * 1.6 end
                local c, s = math.cos(player.yaw), math.sin(player.yaw)
                self._planarVX = (c * forward - s * strafe) * speed
                self._planarVY = (s * forward + c * strafe) * speed
            end
        end
        -- Keep the world-space launch velocity while airborne, even if facing changes.
        local vx, vy = self._planarVX, self._planarVY
        if grounded and math.abs(turnAngle) > 1e-10 then
            -- Exact displacement along a constant keyboard-turn arc. Splitting
            -- one input frame at a mechanics boundary must not alter travel.
            local half = turnAngle * 0.5
            local c, s, fraction = math.cos(half), math.sin(half), math.sin(half) / half
            vx, vy = (vx * c + vy * s) * fraction, (-vx * s + vy * c) * fraction
        end
        player.x = player.x + vx * dt
        player.y = player.y + vy * dt
        if self._jumpQueued and player.z <= 0 then
            self._verticalVelocity = 10
            player.jumpStartedAt = state.time
        end
        self._jumpQueued = false
        if self._verticalVelocity ~= 0 or player.z > 0 then
            -- Continuous extension of the existing 60 Hz jump curve: at a full
            -- mechanics step this equals the original velocity-first update.
            player.z = player.z + self._verticalVelocity * dt + 12.5 * dt * (STEP - dt)
            self._verticalVelocity = self._verticalVelocity - 25 * dt
            if player.z <= 1e-9 then
                player.z, self._verticalVelocity = 0, 0
                player.landedAt = state.time
            end
        end
    end
    self:_updatePlayerPresentation(input, forced ~= nil, dt)
end

function Sim:_moveWaves(dt)
    local waves, time = self.state.waves, self.state.time
    local keep = 1
    for index = 1, #waves do
        local wave = waves[index]
        wave.previousX, wave.previousY = wave.x, wave.y
        wave.x, wave.y = wave.x + wave.dx * dt, wave.y + wave.dy * dt
        if not wave.fadeStartedAt and (math.abs(wave.x) > 90 or math.abs(wave.y) > 90) then
            wave.fadeStartedAt = time
        end
        if wave.fadeStartedAt then wave.alpha = math.max(0, 1 - (time - wave.fadeStartedAt)) end
        if wave.alpha > 1e-10 then waves[keep] = wave; keep = keep + 1 end
    end
    for index = #waves, keep, -1 do waves[index] = nil end
end

function Sim:_checkHazards()
    local player, state = self.state.player, self.state
    if player.dead then return end
    for _, pool in ipairs(state.pools) do
        local px, py = self._previousX, self._previousY
        if pool.createdAt == state.time then px, py = player.x, player.y end
        if segmentDistanceSquared(px - pool.x, py - pool.y,
            player.x - pool.x, player.y - pool.y) <= POOL_RADIUS * POOL_RADIUS + 1e-10 then
            self:_kill("Lava pool", self:_poolImpulse(pool))
            return
        end
    end
    for _, wave in ipairs(state.waves) do
        local px, py = self._previousX, self._previousY
        if wave.createdAt == state.time then px, py = player.x, player.y end
        if segmentDistanceSquared(px - wave.previousX, py - wave.previousY,
            player.x - wave.x, player.y - wave.y) <= WAVE_RADIUS * WAVE_RADIUS + 1e-10 then
            self:_kill(wave.bonus and "Bonus wave" or "Lava wave")
            return
        end
    end
end

function Sim:_moveBoss()
    local boss, time = self.state.boss, self.state.time
    local leap, move = self._bossLeap, self._bossMove
    if leap then
        local fraction = clamp((time - leap.starts) / (leap.ends - leap.starts), 0, 1)
        boss.x = leap.x + (leap.toX - leap.x) * fraction
        boss.y = leap.y + (leap.toY - leap.y) * fraction
        boss.z = math.sin(fraction * PI) * 8
    elseif move then
        local fraction = move.duration > 0 and clamp((time - move.starts) / move.duration, 0, 1) or 1
        boss.x = move.x + (move.toX - move.x) * fraction
        boss.y = move.y + (move.toY - move.y) * fraction
        if fraction >= 1 then self._bossMove = nil end
    end
end

function Sim:_step(input, dt, elapsed)
    local state = self.state
    -- Render snapshots are observational only; collision keeps its own sweep points.
    snapshotPose(state.player)
    snapshotPose(state.boss)
    state.time = self._startTime + elapsed
    state.elapsed = elapsed
    self:_movePlayer(input, dt)
    if state.player.x * state.player.x + state.player.y * state.player.y > 75 * 75 then
        state.arenaExit = true
    end
    self:_moveWaves(dt)
    -- Bring movement up to the event timestamp before a cast locks position/yaw.
    self:_moveBoss()
    local queue = self._queue
    while queue[self._queueIndex] and queue[self._queueIndex].time <= state.time + 1e-9 do
        self:_processEvent(queue[self._queueIndex])
        self._queueIndex = self._queueIndex + 1
        if state.status == "finished" then break end
    end
    self:_checkHazards()
    if state.player.dead then state.deadTime = state.deadTime + dt
    else state.aliveTime = state.aliveTime + dt end
    if self._qualifyPending then
        state.bonus = self.options.loop == 1 and state.deaths == 0 and state.deadTime == 0
        self._qualifyPending = nil
        self:_event("bonus_qualification", state.bonus)
    end
    state.abilities.immunityActive = state.time < state.abilities.immunityUntil
end

function Simulation.New(options)
    options = options or {}
    local loop = options.loop == 2 and 2 or options.loop == 3 and 3 or 1
    local mode = options.mode == "practice" and "practice" or "reference"
    local scale = options.timeScale == 0.5 and 0.5 or options.timeScale == 0.75 and 0.75 or 1
    -- A caller requesting slowdown gets an assisted run, including in reference mode.
    local assisted = mode == "practice" or options.assist == true or scale ~= 1
    local self = setmetatable({
        options = { loop = loop, seed = normalizeSeed(options.seed), mode = mode,
            timeScale = scale, assist = options.assist == true },
        _startTime = (loop - 1) * 59.25, _ticks = 0,
        _nextWave = 0,
        _verticalVelocity = 0, _jumpQueued = false, _jumpHeld = false,
        _planarVX = 0, _planarVY = 0,
    }, Sim)
    self._rng = self.options.seed
    self.state = {
        player = { x = 24.32, y = 14.44, z = 0, yaw = -5 * PI / 6,
            displayYaw = -5 * PI / 6, displayTurn = 0, moving = false,
            movingBackward = false, walking = false, cameraFacingLocked = false, dead = false },
        boss = { x = 0, y = 0, z = 0, yaw = PI / 6 },
        pools = {}, waves = {}, time = self._startTime, elapsed = 0,
        status = "running", deaths = 0, aliveTime = 0, deadTime = 0,
        bonus = false, lastHit = nil, events = {}, emissionCount = 0,
        lastEmissionWaveCount = 0, bonusWaveCount = 0,
        assisted = assisted, interrupted = false, arenaExit = false, layoutCalibrationPending = true,
        abilities = { cooldowns = {}, sprintUntil = 0, immunityUntil = 0, immunityActive = false },
    }
    snapshotPose(self.state.player)
    snapshotPose(self.state.boss)
    for index = 1, (loop - 1) * 3 do self:_addPool(index, true) end
    self:_schedule()
    return self
end

-- Mouse-facing is an orientation input, so apply it on the rendered input
-- sample instead of waiting for the next fixed movement tick. Rotate both pose
-- snapshots by the same delta to preserve interpolation and strafe offsets.
function Sim:SetPlayerFacing(yaw)
    local player = self.state.player
    if self._destroyed or self.state.status ~= "running" or player.dead or
        self._forcedMovement or not finite(yaw) then return false end
    yaw = yaw % TAU
    local old = player.yaw or yaw
    local delta = (yaw - old + PI) % TAU - PI
    local previousYaw = player.previousYaw or old
    local displayYaw = player.displayYaw or old
    local previousDisplayYaw = player.previousDisplayYaw or displayYaw
    player.yaw = yaw
    player.previousYaw = (previousYaw + delta) % TAU
    player.displayYaw = (displayYaw + delta) % TAU
    player.previousDisplayYaw = (previousDisplayYaw + delta) % TAU
    player.cameraFacingLocked = true
    return true
end

function Sim:Advance(realElapsed, input)
    if self._destroyed or self.state.status ~= "running" then return self.state end
    if not finite(realElapsed) or realElapsed < 0 or realElapsed > 0.5 then
        self.state.interrupted, self.state.assisted = true, true
        self.state.status = "paused"
        self:_event("interrupted", "Frame gap; resume explicitly")
        return self.state
    end
    input = input or {}
    local jump = input.jump == true
    if jump and not self._jumpHeld then self._jumpQueued = true end
    self._jumpHeld = jump
    -- Consume every input frame now. The 60 Hz grid bounds collision sweeps
    -- and encounter updates; it must never defer character translation while
    -- mouse-facing and the camera already use the current input sample.
    local target = self.state.elapsed + realElapsed * self.options.timeScale
    while self.state.elapsed < target - 1e-10 and self.state.status == "running" do
        local boundary = (self._ticks + 1) * STEP
        local finish = math.min(target, boundary)
        local player = self.state.player
        if not player.dead and not self._forcedMovement and (player.z > 0 or self._verticalVelocity > 0) then
            local velocity = self._verticalVelocity + 12.5 * STEP
            local landing = (velocity + math.sqrt(velocity * velocity + 50 * player.z)) / 25
            if landing > 1e-10 then finish = math.min(finish, self.state.elapsed + landing) end
        end
        self:_step(input, finish - self.state.elapsed, finish)
        if finish >= boundary - 1e-10 then self._ticks = self._ticks + 1 end
    end
    return self.state
end

function Sim:SetPaused(paused)
    if self._destroyed or self.state.status == "finished" then return false end
    if paused then
        if self.state.status ~= "paused" then self:_event("paused") end
        self.state.status, self.state.assisted = "paused", true
    else
        if self.state.status == "paused" then self:_event("resumed") end
        self.state.status = "running"
        self._jumpQueued, self._jumpHeld = false, false
    end
    return true
end

function Sim:GetRenderAlpha()
    -- All poses already represent the current input frame. Interpolating the
    -- preceding mechanics step here would put translation behind mouse-look.
    return 1
end

function Sim:Revive()
    if self._destroyed or self.state.status == "finished" or not self.state.player.dead then return false end
    local player = self.state.player
    player.dead, player.z = false, 0
    player.cameraFacingLocked = false
    player.displayYaw, player.displayTurn = player.yaw, 0
    player.moving, player.movingBackward = false, false
    player.jumpStartedAt, player.landedAt = nil, nil
    snapshotPose(player)
    self._verticalVelocity, self._forcedMovement = 0, nil
    self._planarVX, self._planarVY, self._deathImpulse = 0, 0, nil
    self._jumpQueued, self._jumpHeld, self._haltMovement = false, false, true
    self:_event("revive")
    -- Same position, no invulnerability: a lethal pool can kill on the next tick.
    return true
end

local function targetPosition(player, x, y, range)
    if not finite(x) or not finite(y) then
        return player.x + math.cos(player.yaw) * range, player.y + math.sin(player.yaw) * range
    end
    local dx, dy = x - player.x, y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > range then dx, dy = dx * range / distance, dy * range / distance end
    return player.x + dx, player.y + dy
end

function Sim:UseAbility(name, targetX, targetY)
    if self._destroyed or self.state.status ~= "running" or self.state.player.dead then return false, "Unavailable" end
    local state, player = self.state, self.state.player
    local abilities, time = state.abilities, state.time
    if type(name) ~= "string" then return false, "Unknown ability" end
    name = name:lower()
    local cooldown = abilities.cooldowns[name] or 0
    if cooldown > time + 1e-9 then return false, "Cooldown" end
    local duration
    if name == "blink" then
        self._forcedMovement = nil
        player.x = player.x + math.cos(player.yaw) * 20
        player.y = player.y + math.sin(player.yaw) * 20
        duration = 15
    elseif name == "roll" then
        player.cameraFacingLocked = false
        self._forcedMovement = { x = player.x, y = player.y, dx = math.cos(player.yaw) * 12,
            dy = math.sin(player.yaw) * 12, starts = time, duration = 0.4 }
        duration = 20
    elseif name == "sprint" then
        abilities.sprintUntil, duration = time + 6, 45
    elseif name == "leap" then
        player.cameraFacingLocked = false
        local x, y = targetPosition(player, targetX, targetY, 30)
        self._forcedMovement = { x = player.x, y = player.y, dx = x - player.x,
            dy = y - player.y, starts = time, duration = 0.6, leap = true }
        duration = 30
    elseif name == "teleport_set" then
        abilities.teleport = { x = player.x, y = player.y }
        duration = 0
    elseif name == "teleport" then
        if not abilities.teleport then return false, "Set teleport first" end
        self._forcedMovement = nil
        player.x, player.y = abilities.teleport.x, abilities.teleport.y
        duration = 30
    elseif name == "gateway_set" then
        local x, y = targetPosition(player, targetX, targetY, 40)
        abilities.gateway = { a = { x = player.x, y = player.y }, b = { x = x, y = y } }
        duration = 0
    elseif name == "gateway" then
        local gateway = abilities.gateway
        if not gateway then return false, "Set gateway first" end
        local da = (player.x - gateway.a.x)^2 + (player.y - gateway.a.y)^2
        local db = (player.x - gateway.b.x)^2 + (player.y - gateway.b.y)^2
        if math.min(da, db) > 25 then return false, "Move within 5 of an endpoint" end
        self._forcedMovement = nil
        local target = da <= db and gateway.b or gateway.a
        player.x, player.y, duration = target.x, target.y, 45
    elseif name == "immunity" then
        abilities.immunityUntil, abilities.immunityActive, duration = time + 5, true, 60
        -- Reserved for knockback only. Lava, waves and frontal still kill.
    else
        return false, "Unknown ability"
    end
    if name == "blink" or name == "teleport" or name == "gateway" then snapshotPose(player) end
    abilities.cooldowns[name] = time + duration
    if player.x * player.x + player.y * player.y > 75 * 75 then state.arenaExit = true end
    state.assisted = true
    self:_event("ability", name)
    return true
end

function Sim:GetResult()
    local state = self.state
    if state.status ~= "finished" then return nil end
    local score = state.elapsed > 0 and math.floor(state.aliveTime / state.elapsed * 100 + 1e-9) or 0
    return {
        completed = true, mode = self.options.mode, seed = self.options.seed, loop = self.options.loop,
        speed = self.options.timeScale, hints = self.options.assist,
        elapsed = state.elapsed, aliveTime = state.aliveTime, deadTime = state.deadTime,
        deaths = state.deaths, bonus = state.bonus, perfect = state.deaths == 0 and state.deadTime == 0,
        assisted = state.assisted, score = score, version = VERSION,
        interrupted = state.interrupted, arenaExit = state.arenaExit,
        highscoreEligible = not state.interrupted and not state.arenaExit,
        layoutCalibrationPending = true,
    }
end

function Sim:Destroy()
    self._destroyed = true
    self.state.destroyed = true
    if self.state.status ~= "finished" then self.state.status = "paused" end
    self._queue, self._forcedMovement, self._bossLeap, self._bossMove = {}, nil, nil, nil
    self._deathImpulse = nil
    self.state.waves = {}
end

return Simulation
