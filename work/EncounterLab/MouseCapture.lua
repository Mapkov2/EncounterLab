local _, EL = ...
local Capture = {}
Capture.__index = Capture
EL.MouseCapture = Capture
local names = { "enableMouseSpeed", "mouseSpeed" }
local owner
-- Retain the accepted pre-0.6.2 physical response. A tenfold CVar increase
-- did not yield tenfold cursor travel on the user's client; that conversion
-- cannot be compensated by simply dividing the camera gain by ten.
Capture.CURSOR_SPEED = 0.1
Capture.CAMERA_GAIN = 0.054

local function number(value, name)
    if type(value) ~= "string" and type(value) ~= "number" then return nil end
    local result = tonumber(value)
    if not result or result ~= result then return nil end
    if name == "enableMouseSpeed" then
        if result ~= 0 and result ~= 1 then return nil end
    elseif result < 0 or result > 10 then return nil end
    return result
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function read(name)
    local fn = C_CVar and C_CVar.GetCVar or GetCVar
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, name)
    if ok and (type(value) == "string" or type(value) == "number") then return tostring(value) end
end

local function write(name, value)
    local fn = C_CVar and C_CVar.SetCVar or SetCVar
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, name, value)
    return ok and result ~= false
end

local function same(a, b, name)
    local first, second = number(a, name), number(b, name)
    return first ~= nil and second ~= nil and first == second
end

local function validated(record)
    if type(record) ~= "table" or record.version ~= 1 or
        type(record.original) ~= "table" or type(record.applied) ~= "table" then return nil end
    for key in pairs(record) do
        if key ~= "version" and key ~= "original" and key ~= "applied" then return nil end
    end
    for _, values in ipairs({ record.original, record.applied }) do
        for name, value in pairs(values) do
            if (name ~= names[1] and name ~= names[2]) or not number(value, name) then return nil end
        end
    end
    local clean = { version=1, original={}, applied={} }
    for _, name in ipairs(names) do
        if not number(record.original[name], name) then return nil end
        clean.original[name] = tostring(record.original[name])
        if record.applied[name] ~= nil then clean.applied[name] = tostring(record.applied[name]) end
    end
    return clean
end


-- Restore only settings still carrying our temporary value. A change made by
-- the player or another addon during the gesture belongs to its new owner.
function Capture.Recover(record)
    local clean = validated(record)
    if not clean then return nil end
    local pending = false
    for _, name in ipairs(names) do
        local applied = clean.applied[name]
        if applied ~= nil then
            local current = read(name)
            if current ~= nil and not same(current, applied, name) then
                clean.applied[name] = nil
            elseif current ~= nil then
                write(name, clean.original[name])
                local restored = read(name)
                if same(restored, clean.original[name], name) or
                    (restored ~= nil and not same(restored, applied, name)) then clean.applied[name] = nil end
            end
            if clean.applied[name] ~= nil then pending = true end
        end
    end
    return pending and clean or nil
end

local function persist(record)
    if type(EncounterLabDB) == "table" then EncounterLabDB.mouseRecovery = record end
end

local function cursor()
    if type(GetCursorPosition) ~= "function" then return nil end
    local ok, x, y = pcall(GetCursorPosition)
    if ok and finite(x) and finite(y) then return x, y end
end

function Capture.New()
    return setmetatable({ active=false, invertYaw=false, invertPitch=false, yawScale=1, pitchScale=0.5 }, Capture)
end

function Capture:Begin()
    if owner and owner ~= self then return false, "capture_busy" end
    if self.active then return true end
    local saved = self.record or (type(EncounterLabDB) == "table" and EncounterLabDB.mouseRecovery)
    self.record = Capture.Recover(saved)
    persist(self.record)
    if self.record then return false, "recovery_pending" end
    local x, y = cursor()
    if not x then return false, "cursor_unavailable" end
    local original = { enableMouseSpeed=read("enableMouseSpeed"), mouseSpeed=read("mouseSpeed") }
    for _, name in ipairs(names) do
        if not number(original[name], name) then return false, "settings_unavailable" end
    end
    local speed = tonumber(read("cameraYawMoveSpeed"))
    self.yawScale = finite(speed) and speed >= 0 and speed / 180 or 1
    local pitchSpeed = tonumber(read("cameraPitchMoveSpeed"))
    -- WoW's Mouse Look Speed slider sets pitch to half of yaw. Read both:
    -- players can also configure their vertical speed independently.
    self.pitchScale = finite(pitchSpeed) and pitchSpeed >= 0 and pitchSpeed / 180 or self.yawScale * 0.5
    self.invertYaw, self.invertPitch = tonumber(read("mouseInvertYaw")) == 1, tonumber(read("mouseInvertPitch")) == 1

    -- Keep the accepted cursor travel during a drag. This is a temporary lease,
    -- journaled before each write so closing/reloading can restore both values.
    -- Camera sensitivity itself comes from WoW's Mouse Look Speed setting.
    self.record = { version=1, original=original, applied={} }
    for _, name in ipairs(names) do
        local value = name == "enableMouseSpeed" and "1" or tostring(Capture.CURSOR_SPEED)
        if not same(original[name], value, name) then
            self.record.applied[name] = value
            persist(self.record)
            local changed = write(name, value)
            if not changed or not same(read(name), value, name) then
                self:End()
                return false, "settings_unavailable"
            end
        end
    end
    self.x, self.y, self.inputMode = x, y, "absolute"
    self.active, owner = true, self
    return true
end

function Capture:Delta()
    if not self.active then return 0, 0 end
    -- Use one coordinate space throughout the gesture, including mouse-up.
    -- Relative mouse counts cannot be integrated into an absolute cursor origin:
    -- sensitivity, acceleration and screen edges make those values diverge.
    local x, y = cursor()
    if not x then self.x, self.y = nil, nil; return 0, 0 end
    local dx, dy = self.x and x-self.x or 0, self.y and y-self.y or 0
    self.x, self.y = x, y
    return dx, dy, true
end

function Capture:ReleaseDelta()
    return self:Delta()
end


function Capture:End()
    self.active, self.x, self.y, self.inputMode = false, nil, nil, nil
    if owner == self then owner = nil end
    if not self.record then return true end
    self.record = Capture.Recover(self.record)
    persist(self.record)
    return self.record == nil
end
