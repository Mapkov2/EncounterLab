-- Lua 5.1 native-asset adapter tests; no real client assets are loaded here.
local base = (arg and arg[1]) or "EncounterLab/"
local EL = {}
assert(loadfile(base .. "SceneAssets.lua"))("EncounterLab", EL)
local checks, cases = 0, 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function near(a, b) return math.abs(a - b) < 1e-8 end
local function test(name, callback)
    callback()
    cases = cases + 1
    print("PASS " .. name)
end
local defaultBounds = { -10, -10, -20, 10, 10, 20 }
local function scene()
    local result = { actors = {} }
    function result:CreateActor(name, template)
        assert(template == "ModelSceneActorTemplate")
        local actor = { name = name, loaded = true, calls = {} }
        local function count(method) actor.calls[method] = (actor.calls[method] or 0) + 1 end
        function actor:Hide() count("Hide"); self.shown = false end
        function actor:Show() count("Show"); self.shown = true end
        function actor:SetUseCenterForOrigin(x, y, z) self.center = { x, y, z } end
        function actor:SetScale(value) count("SetScale"); self.scale = value end
        function actor:SetPosition(x, y, z) count("SetPosition"); self.x, self.y, self.z = x, y, z end
        function actor:SetYaw(yaw) count("SetYaw"); self.yaw = yaw end
        function actor:SetAnimation(...) count("SetAnimation"); self.animation = { ... } end
        function actor:SetAlpha(alpha) count("SetAlpha"); self.alpha = alpha end
        function actor:SetModelByFileID(id)
            count("SetModelByFileID"); self.file = id
            if self.requestError then error("model request failed") end
            return not self.requestRejected
        end
        function actor:SetModelByCreatureDisplayID(id)
            count("SetModelByCreatureDisplayID"); self.display = id
            if self.requestError then error("model request failed") end
            return not self.requestRejected
        end
        function actor:IsLoaded() count("IsLoaded"); return self.loaded end
        function actor:GetActiveBoundingBox()
            count("GetActiveBoundingBox")
            if self.activeError then error("bounds unavailable") end
            return unpack(self.activeBounds or defaultBounds)
        end
        function actor:GetMaxBoundingBox() count("GetMaxBoundingBox"); return unpack(self.maxBounds or {}) end
        function actor:ClearModel() count("ClearModel"); self.loaded = false end
        self.actors[#self.actors + 1] = actor
        return actor
    end
    return result
end
local function new(waves, pools)
    local actors, floor = scene(), scene()
    return EL.SceneAssets.New(actors, floor, waves or 2, pools or 1), actors, floor
end
local function hazard(id, x, y, createdAt)
    return { id = id, x = x or 0, y = y or 0, createdAt = createdAt or 0, dx = 1, dy = 0, alpha = 1 }
end
local function frame(assets, state, now)
    assets:UpdateFloor(now)
    assets:BeginFrame(state)
end

test("uniform floor scale places both cylinder caps at the requested heights", function()
    local assets, actors, floor = new(2, 1)
    check(#actors.actors == 3 and #floor.actors == 2, "all capacity is preallocated")
    check(not floor.actors[1].shown and not actors.actors[1].shown, "startup actors are hidden")
    check(assets:UpdateFloor(0), "valid scalar bounds load floor")
    local top, bottom = floor.actors[1], floor.actors[2]
    check(top.file == 3088346 and bottom.file == 3088259, "correct client cylinder IDs")
    check(near(top.scale, 10) and near(bottom.scale, 10.4), "100/104 radius derived from native bounds")
    check(near((top.z + 20) * top.scale, -0.04), "top cap world height includes scaled position")
    check(near((bottom.z + 20) * bottom.scale, -0.2), "base cap world height includes scaled position")
    check(top.center[1] and top.center[2] and not top.center[3], "center XY while retaining native Z origin")
    assets:UpdateFloor(10)
    check(top.calls.GetActiveBoundingBox == 1 and top.calls.SetScale == 1, "ready floor does not remeasure or rescale")
end)

test("vector bounds and maximum-bound fallback support invisible active bounds", function()
    local assets, _, floor = new()
    local vector = { GetXYZ = function(self) return self.x, self.y, self.z end }
    floor.actors[1].activeBounds = {
        setmetatable({ x = -10, y = -10, z = -20 }, { __index = vector }),
        setmetatable({ x = 10, y = 10, z = 20 }, { __index = vector }),
    }
    floor.actors[2].activeBounds = {}
    floor.actors[2].maxBounds = { { x = -10, y = -10, z = -20 }, { x = 10, y = 10, z = 20 } }
    check(assets:UpdateFloor(0), "method-vector and field-vector bounds accepted")
    check(floor.actors[2].calls.GetMaxBoundingBox == 1, "missing active bounds use maximum bounds")
    check(near(floor.actors[2].scale, 10.4), "fallback computes correct radius")
end)

test("invalid floor bounds remain hidden and retry only at the loading cadence", function()
    local assets, _, floor = new()
    floor.actors[1].activeBounds = { 0, 0, 0, 0, 0, 0 }
    floor.actors[1].maxBounds = { 0, 0, 0, 0, 0, 0 }
    check(not assets:UpdateFloor(0), "degenerate bounds use procedural fallback")
    check(not floor.actors[1].shown and not floor.actors[2].shown, "no incomplete native floor")
    assets:UpdateFloor(0.2)
    check(floor.actors[1].calls.GetActiveBoundingBox == 1, "bounds are not polled per frame")
    floor.actors[1].activeError = true
    floor.actors[1].maxBounds = defaultBounds
    check(assets:UpdateFloor(0.5), "maximum bounds recover from active-bound error")
end)

test("effect load checks use captured frame time and retain fallback until ready", function()
    local assets = new(1, 0)
    local h = hazard(1)
    local actor = assets.waves.free[1].actor
    actor.loaded = false
    frame(assets, { waves = { h } }, 0)
    check(not assets:Wave(1, h, 0, 0, 0), "loading model leaves procedural fallback")
    check(not actor.shown and actor.calls.SetModelByFileID == 1, "first use requests once and stays hidden")
    frame(assets, { waves = { h } }, 0.2)
    check(not assets:Wave(1, h, 0, 0, 0), "paused visual time can keep loading")
    check(actor.calls.IsLoaded == 1, "native readiness not queried before half a second")
    actor.loaded = true
    frame(assets, { waves = { h } }, 0.5)
    check(assets:Wave(1, h, 0, 0, 0), "real captured frame time advances readiness during pause")
    check(actor.calls.SetModelByFileID == 1 and actor.calls.IsLoaded == 2, "no repeated requests")
end)

test("rejected or throwing requests fail closed without repeated model calls", function()
    for _, failure in ipairs({ "requestError", "requestRejected" }) do
        local assets = new(1, 1)
        local h, p = hazard(1), hazard(2)
        local wave, pool = assets.waves.free[1].actor, assets.pools.free[1].actor
        wave[failure], pool[failure] = true, true
        frame(assets, { waves = { h }, pools = { p } }, 0)
        check(not assets:Wave(1, h, 0, 0, 0) and not assets:Pool(1, p, 0), failure .. " falls back")
        frame(assets, { waves = { h }, pools = { p } }, 2)
        assets:Wave(1, h, 0, 0, 2); assets:Pool(1, p, 2)
        check(wave.calls.SetModelByFileID == 1 and pool.calls.SetModelByCreatureDisplayID == 1, "failed requests not repeated")
        check(not wave.shown and not pool.shown, "bad actors remain hidden")
    end
end)

test("stable hazards retain actors and animation across array compaction", function()
    local assets, actors = new(2, 0)
    local a, b, c = hazard(1), hazard(2, 4, 5), hazard(3, 7, 8)
    frame(assets, { waves = { a, b } }, 0)
    assets:Wave(1, a, 0, 0, 0); assets:Wave(2, b, 4, 5, 0); assets:EndFrame()
    local actorB = assets.waves.map[b].actor
    frame(assets, { waves = { b, c } }, 0.1)
    check(assets:Wave(1, b, 4, 5, 0.1) and assets:Wave(2, c, 7, 8, 0.1), "freed capacity is reusable in the same frame")
    assets:EndFrame()
    check(assets.waves.map[b].actor == actorB and not assets.waves.map[a], "compaction preserves surviving identity")
    check(actorB.calls.SetAnimation == 1, "compaction never restarts a survivor")
    check(#actors.actors == 2 and assets.waves.map[c].actor.calls.SetModelByFileID == 1, "reuse creates no actor or model request")
end)

test("full-capacity restart uses new table identity even when IDs repeat", function()
    local assets, actors = new(2, 1)
    local first = { pools = { hazard(1) }, waves = { hazard(1), hazard(2) } }
    frame(assets, first, 0)
    assets:Pool(1, first.pools[1], 0)
    for i, h in ipairs(first.waves) do assets:Wave(i, h, h.x, h.y, 0) end
    assets:EndFrame()
    local second = { pools = { hazard(1) }, waves = { hazard(1), hazard(2) } }
    frame(assets, second, 0.1)
    check(assets:Pool(1, second.pools[1], 0), "pool slot reclaimed before restart visit")
    for i, h in ipairs(second.waves) do check(assets:Wave(i, h, 0, 0, 0), "full-capacity wave restart succeeds") end
    assets:EndFrame()
    check(not assets.pools.map[first.pools[1]] and not assets.waves.map[first.waves[1]], "old table identities released")
    check(#actors.actors == 3, "restart allocates no native actors")
    check(assets.waves.map[second.waves[1]].actor.calls.SetAnimation == 2, "new hazard restarts native animation once")
    frame(assets, second, 0.2)
    assets:EndFrame()
    check(#assets.pools.active == 0 and #assets.waves.active == 0, "unvisited effects released at end of frame")
end)

test("native effect transforms and animations change only when needed", function()
    local assets = new(1, 1)
    local p, w = hazard(1, 10, 20, -1), hazard(2, 3, 6)
    local state = { pools = { p }, waves = { w } }
    frame(assets, state, 0)
    assets:Pool(1, p, 0); assets:Wave(1, w, 3, 6, 0); assets:EndFrame()
    local pool, wave = assets.pools.map[p].actor, assets.waves.map[w].actor
    check(pool.display == 108784 and pool.scale == 2.5 and near(pool.x, 4) and near(pool.y, 8), "pool uses display and compensated world position")
    check(wave.file == 4662848 and wave.scale == 0.75 and near(wave.x, 4) and near(wave.y, 8), "wave has constant footprint and compensated position")
    check(pool.animation[1] == 158 and wave.animation[1] == 0, "preplaced pool is active; new wave starts born")
    frame(assets, state, 0.2)
    assets:Pool(1, p, 0.2); assets:Wave(1, w, 4, 6, 0.2); assets:EndFrame()
    check(pool.calls.SetPosition == 1 and wave.calls.SetPosition == 2, "only moving actors receive another position")
    check(pool.calls.SetAnimation == 1 and wave.calls.SetAnimation == 1, "unchanged animation not restarted")
    check(pool.calls.SetAlpha == 1 and wave.calls.SetAlpha == 1 and wave.calls.SetScale == 1, "unchanged opacity and scale not rewritten")
    w.alpha = 0.4
    frame(assets, state, 1)
    assets:Wave(1, w, 5, 6, 1)
    check(wave.animation[1] == 158 and wave.calls.SetAnimation == 2, "one transition to active animation")
    check(wave.alpha == 0.4 and wave.calls.SetAlpha == 2, "native opacity follows hazard fade")
    local extra = hazard(3)
    check(not assets:Wave(2, extra, 0, 0, 1), "capacity overflow returns fallback")
end)

test("diagnostics and destruction clear loaded actors and ownership", function()
    local assets, actors, floor = new(1, 1)
    local p, w = hazard(1), hazard(2)
    frame(assets, { pools = { p }, waves = { w } }, 0)
    assets:Pool(1, p, 0); assets:Wave(1, w, 0, 0, 0)
    local d = assets:Diagnostics()
    check(d.floorReady and d.poolLoaded == 1 and d.waveLoaded == 1 and d.actors == 4, "diagnostics report actual loaded slots")
    assets:Destroy(); assets:Destroy()
    for _, group in ipairs({ actors.actors, floor.actors }) do
        for _, actor in ipairs(group) do check(not actor.shown and actor.calls.ClearModel == 1, "idempotent cleanup hides and clears each actor") end
    end
    d = assets:Diagnostics()
    check(not d.floorReady and d.poolLoaded == 0 and d.waveLoaded == 0, "destroy resets readiness")
    check(not assets.waves.map[w] and #assets.waves.active == 0, "destroy releases hazard references")
    check(not assets:UpdateFloor(10) and not assets:Wave(1, w, 0, 0, 10), "destroyed adapter stays inactive")
end)

assert(loadfile(base .. "ArenaRoom.lua"))("EncounterLab", EL)
test("rooms reuse native actors across encounter switches without allocating in the frame loop",function()
    local native=scene();local room=EL.ArenaRoom.New(native)
    room:SetEncounter('rashok');check(#native.actors==14,'Rashok room count')
    check(room:Update(0),'native floor loads')
    local floor=room.active.floor
    check(floor.actor.file==4581082 and near((floor.actor.z+20)*floor.actor.scale,-.06),'floor is placed beneath the walking plane')
    room:SetEncounter('sszorak');check(#native.actors==27 and not floor.shown,'old room hidden')
    check(room:Update(1) and room.active.floor.actor.file==2438939,'Sszorak has its own floor')
    for i=1,240 do room:Update(1+i/240) end
    check(#native.actors==27 and room.active.floor.actor.calls.GetActiveBoundingBox==1,'steady room never rebuilds geometry or bounds')
    room:SetEncounter('rashok');check(room:Update(3) and #native.actors==27,'switch reuses the original set')
    room:Destroy();check(not room:Update(4),'destroyed room is inactive')
    for _,a in ipairs(native.actors) do check(not a.shown,'destroy leaves no visible scenery') end
end)
test("pending room models retry at a bounded cadence and preserve fallback terrain",function()
    local native=scene();local room=EL.ArenaRoom.New(native)
    room:SetEncounter('sszorak');local floor=room.active.floor.actor;floor.loaded=false
    check(not room:Update(0),'not-ready floor must not conceal fallback terrain')
    for i=1,20 do room:Update(i/100) end
    check(floor.calls.IsLoaded==1,'pending models only poll twice per second')
    floor.loaded=true;check(room:Update(.6),'late floor becomes ready')
    local assets,_,terrain=new();assets:UpdateFloor(.6,true)
    check(not terrain.actors[1].shown and not terrain.actors[2].shown,'fallback does not cover the decorated room')
    assets:UpdateFloor(1,false);check(terrain.actors[1].shown,'fallback can reappear')
end)
test("foreground scenery fades without modifying the scene camera",function()
    local native=scene();local room=EL.ArenaRoom.New(native);room:SetEncounter('sszorak')
    local prop=room.active[2]
    local camera={cx=prop.x-21,cy=prop.y,fx=1,fy=0}
    room:Update(0,camera);check(near(prop.actor.alpha,.5),'foreground alpha blends continuously')
    check(camera.cx==prop.x-21 and camera.fx==1,'scenery never moves the camera')
    camera.cx=prop.x;room:Update(.1,camera);check(not prop.shown,'scenery at the camera is hidden')
end)
test("Sentinels owns a rectangular hall and does not load the Sszorak elevator",function()
    local native=scene();local room=EL.ArenaRoom.New(native);room:SetEncounter('sentinels')
    check(#native.actors==14 and room.active.projectedFloor,'dedicated hall')
    check(not room:Update(0),'projected stonework owns the floor')
    for _,slot in ipairs(room.active) do
        check(slot.actor.file~=2438939 and slot.x*slot.x+slot.y*slot.y>40*40,'scenery stays beyond the accepted training area')
    end
    local first=room.active;room:SetEncounter('sszorak');room:Update(1)
    for _,slot in ipairs(first) do check(not slot.shown,'Sentinels scenery hidden on switch') end
    room:SetEncounter('sentinels');room:Update(2)
    check(room.active==first and #native.actors==27,'hall models are reused')
end)
print(string.format("SCENE ASSETS %d checks in %d cases passed. Mock API and geometry proof only; no live-client visual proof.", checks, cases))
