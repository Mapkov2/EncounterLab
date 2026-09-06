local _, EL = ...
local L = EL.L
local modelStates = { loading = L["Loading"], ready = L["Ready"],
    ["not loaded"] = L["Not loaded"], unresolved = L["Unresolved"] }

-- EncounterLab's independent scene renderer. World coordinates are yards:
-- yaw zero faces +X, +Y is left, +Z is up. No real-world unit positions are read.
-- Camera/actor APIs: Blizzard FrameAPIModelSceneFrame[ActorBase]Documentation.
-- Projection units: Blizzard ModelSceneMixin:AddOrUpdateDropShadow.
local Renderer = {}
Renderer.__index = Renderer
EL.Renderer = Renderer

local sin, cos, sqrt, abs = math.sin, math.cos, math.sqrt, math.abs
local min, max, pi = math.min, math.max, math.pi
local WAVE_CAPACITY, WAVE_SIDES = 512, 16
local POOL_CAPACITY, POOL_SIDES = 32, 32
local TILE_COUNT, FLOOR_HALF_SIZE, TILE_SIZE = 20, 100, 10
local FRONTAL_VERTICES, FRONTAL_FLOOR_RADIUS = 64, 104
local MEDIA = "Interface\\AddOns\\EncounterLab\\Media\\"
local sequence = 0
local function clamp(v, lo, hi) return max(lo, min(hi, v)) end
local function finite(v) return type(v) == "number" and v == v and abs(v) < 1e10 end

local circle = {}
for sides = 16, 64, 16 do
    local points = {}
    for i = 0, sides do
        points[i * 2 + 1], points[i * 2 + 2] = cos(i * 2 * pi / sides), sin(i * 2 * pi / sides)
    end
    circle[sides] = points
end

local function newLine(parent, r, g, b, a, width)
    local line = parent:CreateLine(nil, "ARTWORK")
    if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
    if line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
    line:SetColorTexture(r, g, b, a)
    line:SetThickness(width or 1.5)
    line:Hide()
    return line
end

local function newRing(parent, sides, r, g, b, a, width)
    local ring = { sides = sides, active = false, lines = {} }
    for i = 1, sides do ring.lines[i] = newLine(parent, r, g, b, a, width) end
    return ring
end

local function hideRing(ring)
    if ring and ring.active then
        for i = 1, ring.sides do ring.lines[i]:Hide() end
        ring.active = false
    end
end

local function newQuad(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
    t:SetColorTexture(r, g, b, a or 1)
    t:SetSize(1, 1)
    t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    t:Hide()
    t.drawn = false
    return t
end

local function hideQuad(t)
    if t.drawn then t:Hide(); t.drawn = false end
end

-- A solid-color quad has no texture-coordinate distortion. Each vertex is
-- independently projected, giving a true perspective planar floor.
local function setQuad(t, x1, y1, x2, y2, x3, y3, x4, y4)
    if not (x1 and x2 and x3 and x4) then hideQuad(t); return end
    t:SetVertexOffset(1, x1, y1 - 1)
    t:SetVertexOffset(2, x2, y2)
    t:SetVertexOffset(3, x3 - 1, y3 - 1)
    t:SetVertexOffset(4, x4 - 1, y4)
    if not t.drawn then t:Show(); t.drawn = true end
end

function Renderer.New(parent)
    sequence = sequence + 1
    local self = setmetatable({ hints = false, dead = false, diagnostics = {},
        waveRings = {}, poolRings = {}, waveFills = {}, poolFills = {}, floor = {}, grid = {}, near = 0.1,
        projectionValid = false, nextAssetCheck = 0, assetChecks = 0,
        renderPlayer = {}, sourcePlayer = {}, renderCamera = {}, renderBoss = {},
        viewMotion = EL.ViewMotion.New(), frontalFills = {}, frontalPolyA = {}, frontalPolyB = {} }, Renderer)
    self.parent = parent
    local floor = CreateFrame("Frame", nil, parent)
    floor:SetAllPoints(parent)
    floor:SetFrameLevel(parent:GetFrameLevel() + 1)
    floor:SetClipsChildren(true)
    floor:EnableMouse(false)
    self.floorFrame = floor
    self.backdrop = floor:CreateTexture(nil, "BACKGROUND")
    self.backdrop:SetAllPoints(floor)
    self.backdrop:SetColorTexture(0.018, 0.013, 0.019, 1)

    local frame = CreateFrame("ModelScene", nil, parent)
    frame:SetAllPoints(parent)
    frame:SetFrameLevel(parent:GetFrameLevel() + 2)
    frame:EnableMouse(false)
    frame:SetCameraNearClip(self.near)
    frame:SetCameraFarClip(400)
    frame:SetLightAmbientColor(0.8, 0.72, 0.64)
    frame:SetLightDiffuseColor(0.65, 0.52, 0.4)
    frame:SetLightDirection(-0.5, -0.4, -1)
    frame:SetLightVisible(true)
    frame:SetAllowOverlappedModels(true)
    self.frame = frame

    -- Keep all world geometry in one native scene: floor, actors and effects
    -- share its camera and depth buffer instead of composing two 3D views.
    -- The separate UI layer keeps telegraphs visible above the opaque floor.
    self.assets = EL.SceneAssets.New(frame, frame, WAVE_CAPACITY, POOL_CAPACITY)

    local ground = CreateFrame("Frame", nil, parent)
    ground:SetAllPoints(parent)
    ground:SetFrameLevel(parent:GetFrameLevel() + 3)
    ground:SetClipsChildren(true)
    ground:EnableMouse(false)
    self.ground = ground
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel(parent:GetFrameLevel() + 5)
    overlay:SetClipsChildren(true)
    overlay:EnableMouse(false)
    self.overlay = overlay

    for iy = 0, TILE_COUNT - 1 do
        for ix = 0, TILE_COUNT - 1 do
            local shade = ((ix + iy) % 2 == 0) and 0.085 or 0.108
            local t = newQuad(floor, shade * 1.25, shade, shade * 0.91)
            t:SetTexture(MEDIA.."Basalt.tga")
            t:SetVertexColor(shade*4.8,shade*4.8,shade*4.8,1)
            t.wx = -FLOOR_HALF_SIZE + ix * TILE_SIZE
            t.wy = -FLOOR_HALF_SIZE + iy * TILE_SIZE
            self.floor[#self.floor + 1] = t
        end
    end
    for i = 1, (TILE_COUNT + 1) * 2 do self.grid[i] = newLine(floor, 0.48, 0.31, 0.17, 0.2, 1) end
    self.border = newRing(ground, 64, 0.72, 0.39, 0.13, 0.9, 2)
    self.practiceBoundary = newRing(ground, 64, 0.9, 0.61, 0.16, 0.5, 1)
    self.bossRing = newRing(ground, 32, 1, 0.24, 0.13, 0.9, 2)
    self.playerRing = newRing(ground, 16, 0.12, 0.95, 0.83, 0.95, 2)
    self.slamRing = newRing(ground, 32, 1, 0.7, 0.12, 0.95, 3)
    self.slamInner = newRing(ground, 32, 1, 0.34, 0.1, 0.6, 2)
    self.frontalRing = newRing(ground, 32, 1, 0.22, 0.07, 0.95, 3)
    self.frontalEdges = {newLine(ground, 1, 0.4, 0.08, 1, 4), newLine(ground, 1, 0.4, 0.08, 1, 4)}
    for i = 1, FRONTAL_VERTICES+8 do
        self.frontalFills[i] = newQuad(ground, 1, 0.12, 0.025, 0.32, "ARTWORK")
    end
    -- Fixed region pools: no frame, actor, line or texture creation in Render.
    for i = 1, POOL_CAPACITY do
        self.poolFills[i] = newQuad(ground,1,1,1,1)
        self.poolFills[i]:SetTexture(MEDIA.."LavaPool.tga")
    end
    for i = 1, WAVE_CAPACITY do
        self.waveFills[i] = newQuad(ground,1,1,1,1)
        self.waveFills[i]:SetTexture(MEDIA.."LavaWave.tga")
    end
    self.heading = newLine(ground, 0.3, 1, 0.84, 0.95, 2)
    self.teleportRing=newRing(ground,16,.7,.35,1,.9,2)
    self.gatewayA=newRing(ground,16,.3,1,.45,.9,2)
    self.gatewayB=newRing(ground,16,.3,1,.45,.9,2)
    self.gatewayLine=newLine(ground,.3,1,.45,.4,1)
    self.bossLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.bossLabel:SetText(L["Rashok"])
    self.playerLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.playerLabel:SetText(L["YOU"])
    self.statusLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.statusLabel:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 10, 10)
    self.statusLabel:SetTextColor(1, 0.72, 0.33)
    self.statusLabel:SetJustifyH("LEFT")
    self.playerActor = frame:CreateActor("EncounterLabPlayer" .. sequence, "ModelSceneActorTemplate")
    self.bossActor = frame:CreateActor("EncounterLabBoss" .. sequence, "ModelSceneActorTemplate")
    self.playerActor:SetUseCenterForOrigin(true, true, false)
    self.bossActor:SetUseCenterForOrigin(true, true, false)
    self.playerActor:SetScale(1)
    self.bossScale = 2
    self.bossActor:SetScale(self.bossScale)
    self.playerActor:SetAnimation(0, 0, 1)
    self.bossActor:SetAnimation(0, 0, 1)
    local ok, accepted = pcall(self.playerActor.SetModelByUnit, self.playerActor, "player", true, true)
    self.diagnostics.playerRequest = ok and accepted ~= false
    self.diagnostics.playerModel = "loading"
    self.diagnostics.bossModel = "unresolved"
    self.playerActor:Show()
    self.bossActor:Hide()
    self:Resize()
    return self
end

-- Visible sample identity for an explicitly armed ten-second video capture.
-- The binary strip is sample-1, twelve bits, most significant bit at the left.
-- It lets a recorded video frame select its exact SavedVariables row.
function Renderer:PrepareTraceStamp()
    if self.traceStamp then return end
    local frame = CreateFrame("Frame", nil, self.overlay)
    frame:SetSize(204, 54)
    frame:SetPoint("TOPLEFT", self.overlay, "TOPLEFT", 12, -36)
    frame:SetFrameLevel(self.overlay:GetFrameLevel() + 1)
    frame:EnableMouse(false)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0, 0, 0, 1)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font = label:GetFont()
    label:SetFont(font, 20, "OUTLINE")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -5)
    label:SetTextColor(1, 1, 1)
    local bits = {}
    for i = 1, 12 do
        local bit = frame:CreateTexture(nil, "ARTWORK")
        bit:SetSize(13, 14)
        bit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8 + (i-1)*16, 6)
        bits[i] = bit
    end
    self.traceStamp = {frame=frame, label=label, bits=bits}
    frame:Hide()
end

function Renderer:ShowTraceSample(index)
    local stamp = self.traceStamp
    if not stamp then return end
    stamp.label:SetText(string.format("EL TRACE %04d", index))
    local value = index - 1
    for i = 1, 12 do
        local on = math.floor(value / 2^(12-i)) % 2 == 1
        local shade = on and 1 or 0.15
        stamp.bits[i]:SetColorTexture(shade, shade, shade, 1)
    end
    stamp.frame:Show()
end

function Renderer:HideTraceStamp()
    if self.traceStamp then self.traceStamp.frame:Hide() end
end

function Renderer:SetEncounter(id)
    id=(id=="sszorak" or id=="sentinels" or id=="twinfangs") and id or "rashok"
    if not self.room then self.room=EL.ArenaRoom.New(self.frame) end
    self.room:SetEncounter(id)
    if id=="sentinels" and not self.sentinelsArena then self.sentinelsArena=EL.SentinelsArena.New(self.floorFrame) end
    if id~="sentinels" and self.sentinelsArena then self.sentinelsArena:Hide() end
    if self.encounter==id then return end
    self.encounter=id
    if id=="sszorak" or id=="sentinels" or id=="twinfangs" then
        self.frame:SetLightAmbientColor(.52,.59,.52)
        self.frame:SetLightDiffuseColor(.54,.65,.48)
        self.backdrop:SetColorTexture(.012,.024,.022,1)
    else
        self.frame:SetLightAmbientColor(.58,.54,.52)
        self.frame:SetLightDiffuseColor(.65,.50,.40)
        self.backdrop:SetColorTexture(.022,.015,.020,1)
    end
    self.bossActor:Hide();self.bossActor:ClearModel()
    self.bossRequested=nil;self.nextAssetCheck=0;self.assetChecks=0
    self.diagnostics.bossModel="unresolved"
    self.bossAnimation,self.bossAnimationSpeed=nil,nil
    self.diagnostics.bossDisplayID=nil
    self.bossLabel:SetText(id=="sszorak" and L["Sszorak"] or L["Rashok"])
    self.assets:SetArenaRadius(id=="sentinels" and 40 or (id=="sszorak" or id=="twinfangs") and 42 or 100)
    if id=="sszorak" and not self.tempestRenderer then self.tempestRenderer=EL.TempestRenderer.New(self) end
    if id~="sszorak" and self.tempestRenderer then self.tempestRenderer:Hide() end
    if id=="sentinels" and not self.sentinelsRenderer then self.sentinelsRenderer=EL.SentinelsRenderer.New(self) end
    if id~="sentinels" and self.sentinelsRenderer then self.sentinelsRenderer:Hide() end
    if id=="twinfangs" and not self.twinFangsRenderer then self.twinFangsRenderer=EL.TwinFangsRenderer.New(self) end
    if id~="twinfangs" and self.twinFangsRenderer then self.twinFangsRenderer:Hide() end
    for _,fill in ipairs(self.frontalFills) do
        if id=="twinfangs" then fill:SetColorTexture(.35,1,.06,.38)
        else fill:SetColorTexture(1,.12,.025,.32) end
    end
    for _,edge in ipairs(self.frontalEdges) do
        if id=="twinfangs" then edge:SetColorTexture(.5,1,.08,.95)
        else edge:SetColorTexture(1,.4,.08,1) end
    end
    self:ResetMotion()
end

function Renderer:Resize()
    self.width, self.height = self.frame:GetWidth(), self.frame:GetHeight()
    self.scale = self.frame:GetEffectiveScale()
    self.projectionValid = false
    self.calibration = nil
end

function Renderer:SetHints(enabled)
    self.hints = enabled == true
    -- Hit outlines are an optional training aid, prepared outside the render loop.
    if self.hints and not self.outlinesPrepared then
        for i = 1, POOL_CAPACITY do self.poolRings[i] = newRing(self.ground, POOL_SIDES, 1, 0.27, 0.05, 0.83, 2.5) end
        for i = 1, WAVE_CAPACITY do self.waveRings[i] = newRing(self.ground, WAVE_SIDES, 1, 0.66, 0.14, 0.94, 2.5) end
        self.outlinesPrepared = true
    end
    for _,rings in ipairs({self.waveRings,self.poolRings}) do
        for _,ring in ipairs(rings) do
            if not self.hints then hideRing(ring) end
        end
    end
end

function Renderer:DrawHazardFill(texture, x, y, radius, alpha)
    local x1,y1=self:Project(x-radius,y+radius,0)
    local x2,y2=self:Project(x-radius,y-radius,0)
    local x3,y3=self:Project(x+radius,y+radius,0)
    local x4,y4=self:Project(x+radius,y-radius,0)
    setQuad(texture,x1,y1,x2,y2,x3,y3,x4,y4)
    alpha = alpha or 1
    if texture.drawAlpha ~= alpha then texture:SetAlpha(alpha); texture.drawAlpha = alpha end
end

function Renderer:ConfigureCamera(camera, player)
    local yaw = camera.renderYaw or camera.yaw or 0
    local pitch = clamp(camera.pitch or pi * 0.075, 0, pi * 0.49)
    local d = clamp(camera.distance or 60, 5, 90)
    local tx, ty, tz = camera.targetX or player.x, camera.targetY or player.y, camera.targetZ or ((player.z or 0) + 1.2)
    local cy, sy, cp, sp = cos(yaw), sin(yaw), cos(pitch), sin(pitch)
    self.fx, self.fy, self.fz = cp * cy, cp * sy, -sp
    self.rx, self.ry, self.rz = sy, -cy, 0
    self.ux, self.uy, self.uz = sp * cy, sp * sy, cp
    self.cx, self.cy, self.cz = tx - self.fx * d, ty - self.fy * d, tz - self.fz * d
    local scene = self.frame
    scene:SetCameraPosition(self.cx, self.cy, self.cz)
    -- Use the same native orientation entry point as Blizzard's orbit camera.
    scene:SetCameraOrientationByYawPitchRoll(yaw,pitch,0)
    -- Three native samples calibrate focal scales and viewport center without
    -- assuming a FOV, UI scale, aspect ratio or undocumented projection matrix.
    self.scale = scene:GetEffectiveScale()
    self.width, self.height = scene:GetWidth(), scene:GetHeight()
    local fov = scene:GetCameraFieldOfView()
    local calibration = self.calibration
    if calibration and calibration.width == self.width and calibration.height == self.height
        and calibration.scale == self.scale and calibration.fov == fov then
        self.projectionValid = true
        return true
    end
    -- Intrinsics do not change with camera position or orbit. A wide sampling
    -- baseline limits rounding error; retaining them avoids ground shimmer.
    local span = d * 0.5
    local x0, y0 = scene:Project3DPointTo2D(tx, ty, tz)
    local xr = scene:Project3DPointTo2D(tx + self.rx*span, ty + self.ry*span, tz + self.rz*span)
    local _, yu = scene:Project3DPointTo2D(tx + self.ux*span, ty + self.uy*span, tz + self.uz*span)
    if not (finite(x0) and finite(y0) and finite(xr) and finite(yu)) then
        self.projectionValid = false
        self.diagnostics.projection = "native projection unavailable"
        return false
    end
    self.ox, self.oy = x0 / self.scale, y0 / self.scale
    self.kx, self.ky = (xr - x0) * d / (self.scale*span), (yu - y0) * d / (self.scale*span)
    self.projectionValid = abs(self.kx) > 0.01 and abs(self.ky) > 0.01
    if self.projectionValid then
        -- Input's positive strafe means left. Preserve that screen direction
        -- when the native scene projects our horizontal basis with the other sign.
        self.lateralInputSign = self.kx < 0 and -1 or 1
        self.calibration = {width=self.width,height=self.height,scale=self.scale,fov=fov}
    end
    self.diagnostics.projection = self.projectionValid and "calibrated" or "degenerate projection"
    return self.projectionValid
end

function Renderer:Project(x, y, z)
    if not self.projectionValid then return end
    local dx, dy, dz = x - self.cx, y - self.cy, (z or 0) - self.cz
    local depth = dx * self.fx + dy * self.fy + dz * self.fz
    if depth <= self.near then return end
    return self.ox + self.kx * (dx * self.rx + dy * self.ry + dz * self.rz) / depth,
        self.oy + self.ky * (dx * self.ux + dy * self.uy + dz * self.uz) / depth, depth
end

function Renderer:GetGroundPoint(cursorX, cursorY)
    if not self.projectionValid or not finite(cursorX) or not finite(cursorY) then return end
    local left, bottom = self.frame:GetLeft(), self.frame:GetBottom()
    if not left or not bottom then return end
    local x, y = cursorX / self.scale - left, cursorY / self.scale - bottom
    if x < 0 or y < 0 or x > self.width or y > self.height then return end
    local qx, qy = (x - self.ox) / self.kx, (y - self.oy) / self.ky
    local dx = self.fx + qx * self.rx + qy * self.ux
    local dy = self.fy + qx * self.ry + qy * self.uy
    local dz = self.fz + qx * self.rz + qy * self.uz
    if dz >= -0.00001 then return end
    local t = -self.cz / dz
    if t < 0 or t > 600 then return end
    return self.cx + dx * t, self.cy + dy * t
end

-- Clip a line to the camera near plane, then let the viewport clip its region.
function Renderer:DrawWorldLine(line, ax, ay, az, bx, by, bz)
    local da = (ax - self.cx) * self.fx + (ay - self.cy) * self.fy + (az - self.cz) * self.fz
    local db = (bx - self.cx) * self.fx + (by - self.cy) * self.fy + (bz - self.cz) * self.fz
    local near = self.near + 0.02
    if da <= near and db <= near then line:Hide(); return end
    if da < near then
        local t = (near - da) / (db - da)
        ax, ay, az = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t
    elseif db < near then
        local t = (near - db) / (da - db)
        bx, by, bz = bx + (ax - bx) * t, by + (ay - by) * t, bz + (az - bz) * t
    end
    local x1, y1 = self:Project(ax, ay, az)
    local x2, y2 = self:Project(bx, by, bz)
    if not (x1 and x2) or (x1 < 0 and x2 < 0) or (x1 > self.width and x2 > self.width)
        or (y1 < 0 and y2 < 0) or (y1 > self.height and y2 > self.height) then line:Hide(); return end
    -- Liang-Barsky clipping keeps region coordinates bounded even near the eye.
    local dx, dy, lo, hi = x2 - x1, y2 - y1, 0, 1
    for edge = 1, 4 do
        local p, q
        if edge == 1 then p, q = -dx, x1
        elseif edge == 2 then p, q = dx, self.width - x1
        elseif edge == 3 then p, q = -dy, y1
        else p, q = dy, self.height - y1 end
        if abs(p) < 1e-8 then if q < 0 then line:Hide(); return end
        else
            local t = q / p
            if p < 0 then lo = max(lo, t) else hi = min(hi, t) end
            if lo > hi then line:Hide(); return end
        end
    end
    line:SetStartPoint("BOTTOMLEFT", line:GetParent(), x1 + lo * dx, y1 + lo * dy)
    line:SetEndPoint("BOTTOMLEFT", line:GetParent(), x1 + hi * dx, y1 + hi * dy)
    line:Show()
end

function Renderer:DrawRing(ring, x, y, radius, alpha, yaw, arc)
    if not ring then return end
    ring.active = true
    local sides = ring.sides
    local points = circle[sides]
    if alpha and alpha ~= ring.alpha then
        for i = 1, sides do ring.lines[i]:SetAlpha(alpha) end
        ring.alpha = alpha
    end
    for i = 1, sides do
        local ax, ay, bx, by
        if arc then
            local a, b = yaw - arc / 2 + (i - 1) * arc / sides, yaw - arc / 2 + i * arc / sides
            ax, ay, bx, by = cos(a), sin(a), cos(b), sin(b)
        else
            ax, ay, bx, by = points[(i - 1) * 2 + 1], points[(i - 1) * 2 + 2], points[i * 2 + 1], points[i * 2 + 2]
        end
        local line = ring.lines[i]
        self:DrawWorldLine(line, x + ax * radius, y + ay * radius, 0,
            x + bx * radius, y + by * radius, 0)
    end
end

function Renderer:DrawFloor()
    for i = 1, #self.floor do
        local t = self.floor[i]
        local x, y = t.wx, t.wy
        local x1, y1 = self:Project(x, y + TILE_SIZE, 0)
        local x2, y2 = self:Project(x, y, 0)
        local x3, y3 = self:Project(x + TILE_SIZE, y + TILE_SIZE, 0)
        local x4, y4 = self:Project(x + TILE_SIZE, y, 0)
        -- Fully behind/near tiles are omitted; grid lines are near-plane clipped.
        setQuad(t, x1, y1, x2, y2, x3, y3, x4, y4)
    end
    for i = 0, TILE_COUNT do
        local v = -FLOOR_HALF_SIZE + i * TILE_SIZE
        self:DrawWorldLine(self.grid[i + 1], -FLOOR_HALF_SIZE, v, 0, FLOOR_HALF_SIZE, v, 0)
        self:DrawWorldLine(self.grid[i + TILE_COUNT + 2], v, -FLOOR_HALF_SIZE, 0, v, FLOOR_HALF_SIZE, 0)
    end
end

-- Clip a convex polygon against a*x+b*y+c >= 0, reusing packed XY buffers.
local function clipPolygon(source, count, target, a, b, c)
    if count == 0 then return 0 end
    local written = 0
    local px, py = source[count*2-1], source[count*2]
    local previous = a*px+b*py+c
    for i = 1, count do
        local x, y = source[i*2-1], source[i*2]
        local distance = a*x+b*y+c
        if (previous >= 0) ~= (distance >= 0) then
            local t = previous/(previous-distance)
            written = written+1
            target[written*2-1], target[written*2] = px+(x-px)*t, py+(y-py)*t
        end
        if distance >= 0 then
            written = written+1
            target[written*2-1], target[written*2] = x, y
        end
        px, py, previous = x, y, distance
    end
    return written
end
Renderer.ClipPolygon=clipPolygon

function Renderer:DrawFrontal(frontal)
    local drawn = 0
    if frontal then
        local a, b = self.frontalPolyA, self.frontalPolyB
        local points = circle[FRONTAL_VERTICES]
        for i = 1, FRONTAL_VERTICES*2 do a[i] = points[i]*(frontal.floorRadius or FRONTAL_FLOOR_RADIUS) end
        local half = (frontal.width or pi/2)/2
        local yaw = frontal.yaw or 0
        local lx, ly = cos(yaw+half), sin(yaw+half)
        local rx, ry = cos(yaw-half), sin(yaw-half)
        -- The actual attack has no range limit: intersect its two angle planes
        -- with the visible floor, rather than inventing a shorter safe range.
        local count = clipPolygon(a,FRONTAL_VERTICES,b,ly,-lx,lx*frontal.y-ly*frontal.x)
        count = clipPolygon(b,count,a,-ry,rx,ry*frontal.x-rx*frontal.y)
        -- Clip before projection, including when the boss is behind the camera.
        count = clipPolygon(a,count,b,self.fx,self.fy,-self.cx*self.fx-self.cy*self.fy-self.cz*self.fz-self.near-0.02)
        for i = 1, count do a[i*2-1],a[i*2] = self:Project(b[i*2-1],b[i*2],0) end
        count = clipPolygon(a,count,b,1,0,0)
        count = clipPolygon(b,count,a,-1,0,self.width)
        count = clipPolygon(a,count,b,0,1,0)
        count = clipPolygon(b,count,a,0,-1,self.height)
        for i = 2, count-1 do
            local x1,y1,x2,y2,x3,y3 = a[1],a[2],a[i*2-1],a[i*2],a[i*2+1],a[i*2+2]
            if abs((x2-x1)*(y3-y1)-(y2-y1)*(x3-x1)) > 0.001 then
                drawn = drawn+1
                -- A duplicate fourth vertex makes one triangle of the fan.
                if (x2-x1)*(y3-y1)-(y2-y1)*(x3-x1) < 0 then x2,y2,x3,y3 = x3,y3,x2,y2 end
                setQuad(self.frontalFills[drawn],x1,y1,x2,y2,x3,y3,x3,y3)
            end
        end
    end
    for i = drawn+1, self.drawnFrontalFills or 0 do hideQuad(self.frontalFills[i]) end
    self.drawnFrontalFills = drawn
end

function Renderer:CheckAssets(now)
    if now < self.nextAssetCheck then return end
    self.nextAssetCheck = now + 0.5
    self.assetChecks = self.assetChecks + 1
    if self.playerActor:IsLoaded() then
        self.diagnostics.playerModel = "ready"
    elseif self.assetChecks > 20 then self.diagnostics.playerModel = "not loaded" end
    if self.encounter=="twinfangs" then
        self.twinFangsRenderer:Check(now)
        self.diagnostics.bossModel=self.twinFangsRenderer.vexhul.loaded and self.twinFangsRenderer.ithraz.loaded and "ready" or "loading"
        self.statusLabel:SetText(self.diagnostics.bossModel=="ready" and "" or L["Boss models loading - ground markers remain active"])
        return
    end
    if self.encounter=="sentinels" then
        self.sentinelsRenderer:Check(now)
        -- Boss decorations never block movement practice; raiders have label fallbacks.
        self.diagnostics.sentinelModels=(self.sentinelsRenderer.bosses[1].loaded and 1 or 0)+(self.sentinelsRenderer.bosses[2].loaded and 1 or 0)
        self.diagnostics.bossModel=self.diagnostics.sentinelModels==2 and "ready" or "loading"
        self.statusLabel:SetText("");return
    end
    if self.encounter=="sszorak" then
        if not self.bossRequested then
            self.bossRequested=true
            local ok,accepted=pcall(self.bossActor.SetModelByCreatureDisplayID,self.bossActor,EL.Sszorak.bossDisplayID)
            self.diagnostics.bossRequest=ok and accepted~=false
            self.diagnostics.bossDisplayID=EL.Sszorak.bossDisplayID
        end
        if self.diagnostics.bossRequest and self.bossActor:IsLoaded() then
            self.diagnostics.bossModel="ready";self.bossActor:Show()
        else
            self.diagnostics.bossModel=self.assetChecks>20 and "not loaded" or "loading"
            self.bossActor:Hide()
        end
        self.statusLabel:SetText(self.diagnostics.bossModel=="ready" and "" or L["Loading Sszorak model"])
        return
    end
    if not self.bossRequested and EJ_GetCreatureInfo then
        local ok, _, name, _, displayID = pcall(EJ_GetCreatureInfo, 1, EL.RASHOK_JOURNAL_ENCOUNTER_ID or 2525)
        if ok and type(displayID) == "number" and displayID > 0 then
            self.bossRequested = true
            self.bossLabel:SetText(L["Rashok"])
            local loaded, accepted = pcall(self.bossActor.SetModelByCreatureDisplayID, self.bossActor, displayID)
            self.diagnostics.bossRequest = loaded and accepted ~= false
            self.diagnostics.bossDisplayID = displayID
            self.diagnostics.bossModel = "loading"
            self.bossActor:Show()
        end
    end
    if self.bossActor:IsLoaded() then self.diagnostics.bossModel = "ready"
    elseif self.assetChecks > 20 then self.diagnostics.bossModel = "not loaded" end
    if self.diagnostics.playerModel ~= "ready" or self.diagnostics.bossModel ~= "ready" then
        self.statusLabel:SetText(EL.F("Models: player %s / Rashok %s",
            modelStates[self.diagnostics.playerModel] or L["Unknown"],
            modelStates[self.diagnostics.bossModel] or L["Unknown"]))
    else self.statusLabel:SetText("") end
end

local function positionLabel(self, label, x, y, z, show)
    local sx, sy = self:Project(x, y, z)
    if show and sx and sx >= 0 and sy >= 0 and sx <= self.width and sy <= self.height then
        label:ClearAllPoints()
        label:SetPoint("BOTTOM", self.overlay, "BOTTOMLEFT", sx, sy + TILE_SIZE)
        label:Show()
    else label:Hide() end
end

local function renderPose(out, source, alpha)
    local px, py, pz = source.previousX or source.x, source.previousY or source.y, source.previousZ or source.z or 0
    out.x = px + (source.x - px) * alpha
    out.y = py + (source.y - py) * alpha
    out.z = pz + ((source.z or 0) - pz) * alpha
    local yaw = source.yaw or 0
    local previousYaw = source.previousYaw or yaw
    local delta = (yaw - previousYaw + pi) % (2*pi) - pi
    out.yaw = alpha == 1 and yaw or (previousYaw + delta * alpha)
    local displayed=source.displayYaw or yaw
    local previousDisplay=source.previousDisplayYaw or (source.displayYaw==nil and previousYaw) or displayed
    local displayDelta=(displayed-previousDisplay+pi)%(2*pi)-pi
    out.displayYaw=alpha==1 and displayed or (previousDisplay+displayDelta*alpha)
    out.dead, out.radius = source.dead, source.radius
    return out
end

function Renderer:ResetMotion()
    self.viewMotion:Reset()
end

function Renderer:Render(state, camera, alpha, elapsed)
    if self.dead or not state or not state.player then return end
    alpha = clamp(alpha or 1, 0, 1)
    local sourcePlayer = renderPose(self.sourcePlayer,state.player,alpha)
    self.viewMotion:Update(sourcePlayer,camera or {},elapsed,self.renderPlayer,self.renderCamera)
    local p = self.renderPlayer
    camera = self.renderCamera
    local boss = state.boss and renderPose(self.renderBoss,state.boss,alpha)
    if not self:ConfigureCamera(camera or {}, p) then
        self.floorFrame:Hide(); self.ground:Hide(); self.overlay:Hide()
        return
    end
    self.floorFrame:Show(); self.ground:Show(); self.overlay:Show()
    local now = GetTime()
    local roomFloor=self.room and self.room:Update(now,self) or false
    local sentinelFloor=self.encounter=="sentinels" and self.sentinelsArena
    local nativeFloor = self.assets:UpdateFloor(now,roomFloor or not not sentinelFloor) or roomFloor or not not sentinelFloor
    if nativeFloor then
        if not self.nativeFloor then
            for i=1,#self.floor do hideQuad(self.floor[i]) end
            for i=1,#self.grid do self.grid[i]:Hide() end
        end
    else self:DrawFloor() end
    self.nativeFloor = nativeFloor
    if sentinelFloor then sentinelFloor:Render(self) end
    self:DrawRing(self.border, 0, 0, state.arenaRadius or 70)
    self:DrawRing(self.practiceBoundary, 0, 0, state.arenaRadius or 75)
    for i = 2, self.practiceBoundary.sides, 2 do self.practiceBoundary.lines[i]:Hide() end
    self.playerActor:SetPosition(p.x, p.y, p.z or 0)
    self.playerActor:SetYaw(camera and camera.playerFacingYaw or p.displayYaw or p.yaw or 0)
    self.playerActor:SetAlpha(p.dead and 0.45 or 1)
    local moved = self.prevPX and ((p.x - self.prevPX)^2 + (p.y - self.prevPY)^2) > 0.000001
    local source=state.player
    local moving=source.moving
    if moving==nil then moving=moved end
    if self.landingAt~=source.landedAt then
        self.landingAt=source.landedAt
        self.landingRun=moving and not source.movingBackward
    end
    local anim=0
    if p.dead then anim=1
    elseif state.status=="paused" then anim=0
    elseif (source.z or 0)>0 then
        anim=source.jumpStartedAt and state.time-source.jumpStartedAt<5/6 and 37 or 38
    elseif self.landingAt and self.landingRun and state.time-self.landingAt<1/3 then anim=187
    elseif moving then
        anim=source.movingBackward and 13 or (source.walking and 4 or 5)
    elseif self.landingAt and state.time-self.landingAt<1.134 then anim=39
    elseif (source.displayTurn or 0)>.0001 then anim=11
    elseif (source.displayTurn or 0)<-.0001 then anim=12 end
    if anim ~= self.playerAnimation then self.playerActor:SetAnimation(anim, 0, 1); self.playerAnimation = anim end
    self.prevPX, self.prevPY = p.x, p.y
    self:DrawRing(self.playerRing, p.x, p.y, 0.6)
    self:DrawWorldLine(self.heading, p.x, p.y, 0, p.x + cos(p.yaw or 0) * 2, p.y + sin(p.yaw or 0) * 2, 0)
    local abilities=state.abilities
    if abilities and abilities.teleport then
        self:DrawRing(self.teleportRing,abilities.teleport.x,abilities.teleport.y,1.5)
    else hideRing(self.teleportRing) end
    if abilities and abilities.gateway then
        local a,b=abilities.gateway.a,abilities.gateway.b
        self:DrawRing(self.gatewayA,a.x,a.y,2)
        self:DrawRing(self.gatewayB,b.x,b.y,2)
        self:DrawWorldLine(self.gatewayLine,a.x,a.y,0,b.x,b.y,0)
    else hideRing(self.gatewayA);hideRing(self.gatewayB);self.gatewayLine:Hide() end
    positionLabel(self, self.playerLabel, p.x, p.y, (p.z or 0) + 2.2, self.hints)
    if boss then
        self.bossActor:SetPosition(boss.x / self.bossScale, boss.y / self.bossScale, (boss.z or 0) / self.bossScale)
        self.bossActor:SetYaw(boss.yaw or 0)
        local bossMoved=self.prevBX and ((boss.x-self.prevBX)^2+(boss.y-self.prevBY)^2)>0.000001
        local bossAnim=bossMoved and 5 or 0
        local cast=state.frontal or state.slam
        if cast then
            local castEnd=cast.announceEnds or cast.ends
            bossAnim=state.time<castEnd-5/6 and 125 or 216
        end
        if state.scenario=="sszorak" then
            bossAnim=state.boss.casting and 125 or 0
            local speed=state.status=="running" and (state.playbackSpeed or state.speed or 1) or 0
            if bossAnim~=self.bossAnimation or speed~=self.bossAnimationSpeed or self.replayTrail then
                self.bossActor:SetAnimation(bossAnim,0,speed,state.boss.casting and state.time-state.boss.castStarts or 0)
                self.bossAnimation,self.bossAnimationSpeed=bossAnim,speed
            end
        elseif bossAnim~=self.bossAnimation then self.bossActor:SetAnimation(bossAnim,0,1);self.bossAnimation=bossAnim end
        self.prevBX,self.prevBY=boss.x,boss.y
        self:DrawRing(self.bossRing, boss.x, boss.y, boss.radius or 5)
        positionLabel(self, self.bossLabel, boss.x, boss.y, 8, self.hints or state.scenario=="sszorak")
    else hideRing(self.bossRing); self.bossLabel:Hide() end
    local pools, waves = state.pools or {}, state.waves or {}
    local visualTime = state.time - (state.status == "running" and (1-alpha)/60 or 0)
    self.assets:BeginFrame(state)
    for i = 1, min(#pools, POOL_CAPACITY) do
        local h = pools[i]
        if self.assets:Pool(i,h,visualTime) then hideQuad(self.poolFills[i])
        else self:DrawHazardFill(self.poolFills[i],h.x,h.y,h.radius or 10,h.alpha or 1) end
        if self.hints then self:DrawRing(self.poolRings[i], h.x, h.y, h.radius or 10, h.alpha or 1) end
    end
    for i = #pools + 1, self.renderedPoolCount or 0 do hideRing(self.poolRings[i]); hideQuad(self.poolFills[i]) end
    self.renderedPoolCount=min(#pools,POOL_CAPACITY)
    for i = 1, min(#waves, WAVE_CAPACITY) do
        local h = waves[i]
        local x=(h.previousX or h.x)+(h.x-(h.previousX or h.x))*alpha
        local y=(h.previousY or h.y)+(h.y-(h.previousY or h.y))*alpha
        if self.assets:Wave(i,h,x,y,visualTime) then hideQuad(self.waveFills[i])
        else self:DrawHazardFill(self.waveFills[i],x,y,h.radius or 3.875,h.alpha or 1) end
        if self.hints then self:DrawRing(self.waveRings[i], x, y, h.radius or 3.875, h.alpha or 1) end
    end
    for i = #waves + 1, self.renderedWaveCount or 0 do hideRing(self.waveRings[i]); hideQuad(self.waveFills[i]) end
    self.renderedWaveCount=min(#waves,WAVE_CAPACITY)
    self.assets:EndFrame()
    self.diagnostics.waves = #waves
    self.diagnostics.waveCapacity = WAVE_CAPACITY
    self.diagnostics.overflow = max(0, #waves - WAVE_CAPACITY) + max(0, #pools - POOL_CAPACITY)
    local slam = state.slam
    if slam then
        local radius = slam.radius or 10
        self:DrawRing(self.slamRing, slam.x, slam.y, radius)
        self:DrawRing(self.slamInner, slam.x, slam.y, radius * clamp(((slam.ends or state.time) - state.time) / 2.5, 0, 1))
    else hideRing(self.slamRing); hideRing(self.slamInner) end
    local frontal = state.scenario=="twinfangs" and state.flood or state.frontal
    self:DrawFrontal(frontal)
    if frontal then
        local yaw, arc, radius = frontal.yaw or 0, frontal.width or pi / 2, frontal.radius or 220
        self:DrawRing(self.frontalRing, frontal.x, frontal.y, radius, 1, yaw, arc)
        for i = 1, 2 do
            local angle = yaw + (i == 1 and -1 or 1) * arc / 2
            self:DrawWorldLine(self.frontalEdges[i], frontal.x, frontal.y, 0,
                frontal.x + cos(angle) * radius, frontal.y + sin(angle) * radius, 0)
        end
    else
        hideRing(self.frontalRing)
        self.frontalEdges[1]:Hide(); self.frontalEdges[2]:Hide()
    end
    if self.tempestRenderer and state.scenario=="sszorak" then self.tempestRenderer:Draw(self,state,self.replayTrail) end
    if self.sentinelsRenderer and state.scenario=="sentinels" then self.sentinelsRenderer:Draw(self,state) end
    if self.twinFangsRenderer and state.scenario=="twinfangs" then self.twinFangsRenderer:Draw(self,state,self.replayTrail) end
    self:CheckAssets(now)
end

function Renderer:GetDiagnostics()
    local result = {}
    for k, v in pairs(self.diagnostics) do result[k] = v end
    result.modelScene = self.frame ~= nil
    result.worldScenes = self.frame and 1 or 0
    local assets = self.assets:Diagnostics()
    result.nativeActors = 2 + assets.actors + (self.room and #self.room.actors or 0) + (self.tempestRenderer and #self.tempestRenderer.tornadoes+1 or 0)
    result.nativeActors=result.nativeActors+(self.sentinelsRenderer and 22 or 0)
    result.nativeActors=result.nativeActors+(self.twinFangsRenderer and #self.twinFangsRenderer.actors or 0)
    result.roomModels = self.room and self.room.loaded or 0
    result.nativeFloor = self.encounter~="sentinels" and assets.floorReady
    result.nativePools, result.nativeWaves = assets.poolLoaded, assets.waveLoaded
    result.projectedGround = self.encounter=="sentinels" or not self.nativeFloor
    result.hints = self.hints
    result.destroyed = self.dead
    return result
end

function Renderer:Destroy()
    if self.dead then return end
    self.dead = true
    self.playerActor:Hide(); self.playerActor:ClearModel()
    self.bossActor:Hide(); self.bossActor:ClearModel()
    self.assets:Destroy()
    if self.sentinelsRenderer then self.sentinelsRenderer:Destroy() end
    if self.twinFangsRenderer then self.twinFangsRenderer:Destroy() end
    if self.room then self.room:Destroy() end
    if self.sentinelsArena then self.sentinelsArena:Hide() end
    self.frame:Hide(); self.floorFrame:Hide(); self.ground:Hide(); self.overlay:Hide()
end
