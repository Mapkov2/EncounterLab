local _, EL = ...
local Assets = {}
Assets.__index = Assets
EL.SceneAssets = Assets

-- Independent adapter for client-owned models. All actors are created once;
-- effect identity follows hazard tables, never compacted simulation indices.
local sequence = 0
local empty = {}
local abs, max, min = math.abs, math.max, math.min
local function finite(n) return type(n) == "number" and n == n and abs(n) < 1e10 end
local function hide(slot)
    if slot.shown then slot.actor:Hide(); slot.shown = false end
end
local function show(slot)
    if not slot.shown then slot.actor:Show(); slot.shown = true end
end

local function newSlot(scene, name, scale)
    local actor = scene:CreateActor(name, "ModelSceneActorTemplate")
    actor:Hide()
    if scale then actor:SetScale(scale) end
    return { actor = actor, scale = scale or 1, shown = false, nextCheck = 0 }
end

local function request(slot, fileID, displayID)
    if slot.requested then return end
    slot.requested = true
    local method = displayID and slot.actor.SetModelByCreatureDisplayID or slot.actor.SetModelByFileID
    local ok, accepted = pcall(method, slot.actor, displayID or fileID)
    if not ok or accepted == false then slot.failed = true; hide(slot) end
end

local function ready(slot, now)
    if slot.failed then return false end
    if slot.loaded then return true end
    if not slot.requested or now < slot.nextCheck then return false end
    slot.nextCheck = now + 0.5
    slot.loaded = slot.actor:IsLoaded() == true
    return slot.loaded
end

local function vectorXYZ(vector)
    if type(vector) ~= "table" and type(vector) ~= "userdata" then return end
    local ok, x, y, z = pcall(function() return vector:GetXYZ() end)
    if ok then return x, y, z end
    ok, x, y, z = pcall(function() return vector.x, vector.y, vector.z end)
    if ok then return x, y, z end
end

local function readBounds(actor, method)
    -- Generated docs describe vector3 pairs; Blizzard call sites consume six
    -- scalar returns. Accept either representation and reject invisible bounds.
    local ok, bx, by, bz, tx, ty, tz = pcall(method, actor)
    if not ok then return end
    if type(bx) ~= "number" then
        local bottom, top = bx, by
        bx, by, bz = vectorXYZ(bottom)
        tx, ty, tz = vectorXYZ(top)
    end
    if not (finite(bx) and finite(by) and finite(bz) and finite(tx) and finite(ty) and finite(tz)) then return end
    if tx <= bx or ty <= by or tz <= bz then return end
    return bx, by, bz, tx, ty, tz
end

local function bounds(actor)
    local bx, by, bz, tx, ty, tz = readBounds(actor, actor.GetActiveBoundingBox)
    if bx then return bx, by, bz, tx, ty, tz end
    return readBounds(actor, actor.GetMaxBoundingBox)
end
Assets.ReadBounds=bounds

local function place(slot, x, y, z)
    if x ~= slot.x or y ~= slot.y or z ~= slot.z then
        -- Blizzard's scripted effect scene also compensates positions by scale.
        slot.actor:SetPosition(x / slot.scale, y / slot.scale, z / slot.scale)
        slot.x, slot.y, slot.z = x, y, z
    end
end

local function newGroup(scene, prefix, count, scale)
    local group = { slots = {}, free = {}, active = {}, map = {} }
    for index = 1, count do
        local slot = newSlot(scene, prefix .. index, scale)
        group.slots[index], group.free[index] = slot, slot
    end
    return group
end

local function release(group, slot)
    if not slot or not slot.hazard then return end
    hide(slot)
    group.map[slot.hazard] = nil
    local index, last = slot.activeIndex, group.active[#group.active]
    group.active[index] = last
    last.activeIndex = index
    group.active[#group.active] = nil
    slot.hazard, slot.activeIndex, slot.animation = nil, nil, nil
    group.free[#group.free + 1] = slot
end

local function assign(group, hazard)
    local slot = group.map[hazard]
    if slot then return slot end
    local count = #group.free
    if count == 0 then return end
    slot = group.free[count]
    group.free[count] = nil
    slot.hazard, slot.animation = hazard, nil
    slot.hazardID, slot.createdAt = hazard.id, hazard.createdAt
    slot.activeIndex = #group.active + 1
    group.active[slot.activeIndex], group.map[hazard] = slot, slot
    return slot
end

function Assets.New(scene, floorScene, waveCapacity, poolCapacity)
    sequence = sequence + 1
    local prefix = "EncounterLabNative" .. sequence .. "_"
    local self = setmetatable({ floorReady = false, epoch = 0, needed = {}, now = 0 }, Assets)
    self.pools = newGroup(scene, prefix .. "Pool", poolCapacity, 2.5)
    self.waves = newGroup(scene, prefix .. "Wave", waveCapacity, 0.75)
    self.floor = {
        newSlot(floorScene, prefix .. "FloorTop"),
        newSlot(floorScene, prefix .. "FloorBase"),
    }
    self.groups = { self.pools, self.waves }
    self.actorCount = waveCapacity + poolCapacity + 2
    for index, slot in ipairs(self.floor) do
        slot.actor:SetUseCenterForOrigin(true, true, false)
        slot.radius, slot.top = index == 1 and 100 or 104, index == 1 and -0.04 or -0.2
        request(slot, index == 1 and 3088346 or 3088259)
    end
    return self
end

function Assets:SetArenaRadius(radius)
    radius=radius or 100
    for i,slot in ipairs(self.floor) do
        local value=i==1 and radius or radius*1.04
        if slot.radius~=value then
            slot.radius,slot.floorReady,slot.nextBoundsCheck=value,false,0
        end
    end
end

function Assets:UpdateFloor(now, covered)
    if self.dead then return false end
    self.now = finite(now) and now or self.now
    local complete = true
    for _, slot in ipairs(self.floor) do
        if not slot.floorReady and self.now >= (slot.nextBoundsCheck or 0) then
            slot.nextBoundsCheck = self.now + 0.5
            if ready(slot, self.now) then
                local bx, by, bz, tx, ty, tz = bounds(slot.actor)
                if bx then
                    local radius = max(tx - bx, ty - by) * 0.5
                    local scale = slot.radius / radius
                    if finite(scale) and scale > 0 then
                        slot.scale = scale
                        slot.actor:SetScale(scale)
                        -- Uniform cylinders are buried; their upper caps form
                        -- the two platforms without an unsupported XYZ scale.
                        place(slot, 0, 0, slot.top - tz * scale)
                        slot.floorReady = true
                    end
                end
            end
        end
        if not slot.floorReady then complete = false end
    end
    self.floorReady = complete
    for _, slot in ipairs(self.floor) do if complete and not covered then show(slot) else hide(slot) end end
    return complete
end

function Assets:BeginFrame(state)
    if self.dead then return end
    self.epoch = self.epoch + 1
    if not state then return end
    local needed = self.needed
    for hazard in pairs(needed) do needed[hazard] = nil end
    for _, hazard in ipairs(state.pools or empty) do needed[hazard] = true end
    for _, hazard in ipairs(state.waves or empty) do needed[hazard] = true end
    -- Reclaim absent hazards before assigning new ones, including a full-capacity
    -- restart. Iterate assigned actors only, never all unused capacity.
    for _, group in ipairs(self.groups) do
        for index = #group.active, 1, -1 do
            local slot = group.active[index]
            if not needed[slot.hazard] then release(group, slot) end
        end
    end
end

local function effect(self, group, hazard, x, y, visualTime, fileID, displayID, yaw)
    if self.dead or type(hazard) ~= "table" or not finite(x) or not finite(y) then return false end
    local slot = assign(group, hazard)
    if not slot then return false end
    slot.epoch = self.epoch
    request(slot, fileID, displayID)
    if not ready(slot, self.now) then hide(slot); return false end
    place(slot, x, y, 0)
    if yaw ~= slot.yaw then slot.actor:SetYaw(yaw); slot.yaw = yaw end
    local age = max(0, (visualTime or 0) - (hazard.createdAt or visualTime or 0))
    local animation = age >= 1 and 158 or 0
    if animation ~= slot.animation then
        slot.actor:SetAnimation(animation, 0, 1, animation == 158 and age - 1 or age)
        slot.animation = animation
    end
    local alpha = finite(hazard.alpha) and min(1, max(0, hazard.alpha)) or 1
    if alpha ~= slot.alpha then slot.actor:SetAlpha(alpha); slot.alpha = alpha end
    if alpha <= 0 then hide(slot); return false end
    show(slot)
    return true
end

function Assets:Pool(index, hazard, visualTime)
    if type(hazard) ~= "table" then return false end
    return effect(self, self.pools, hazard, hazard.x, hazard.y, visualTime, nil, 108784, 0)
end

function Assets:Wave(index, hazard, x, y, visualTime)
    if type(hazard) ~= "table" then return false end
    local yaw = hazard.yaw
    if not finite(yaw) then yaw = math.atan2(hazard.dy or 0, hazard.dx or 1) end
    return effect(self, self.waves, hazard, x, y, visualTime, 4662848, nil, yaw)
end

function Assets:EndFrame()
    if self.dead then return end
    for _, group in ipairs(self.groups) do
        for index = #group.active, 1, -1 do
            local slot = group.active[index]
            if slot.epoch ~= self.epoch then release(group, slot) end
        end
    end
end

-- Legacy helpers address physical slots, not compacted simulation-array indices.
-- New rendering code uses BeginFrame(state)/EndFrame for hazard ownership.
function Assets:HidePool(index) release(self.pools, self.pools.slots[index]) end
function Assets:HideWave(index) release(self.waves, self.waves.slots[index]) end

function Assets:Diagnostics()
    local result = { floorReady = self.floorReady, poolLoaded = 0, waveLoaded = 0, actors = self.actorCount }
    for _, slot in ipairs(self.pools.slots) do if slot.loaded then result.poolLoaded = result.poolLoaded + 1 end end
    for _, slot in ipairs(self.waves.slots) do if slot.loaded then result.waveLoaded = result.waveLoaded + 1 end end
    return result
end

function Assets:Destroy()
    if self.dead then return end
    self.dead, self.floorReady = true, false
    for _, group in ipairs(self.groups) do
        for _, slot in ipairs(group.slots) do
            hide(slot); slot.actor:ClearModel(); slot.loaded = false
            slot.hazard, slot.activeIndex = nil, nil
        end
        for hazard in pairs(group.map) do group.map[hazard] = nil end
        for index = #group.active, 1, -1 do group.active[index] = nil end
    end
    for _, slot in ipairs(self.floor) do hide(slot); slot.actor:ClearModel(); slot.loaded = false end
    for hazard in pairs(self.needed) do self.needed[hazard] = nil end
end
