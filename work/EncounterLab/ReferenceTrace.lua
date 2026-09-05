local _, EL = ...
local L = EL.L
local Trace = {}
EL.ReferenceTrace = Trace

-- Explicit, bounded comparison only. The optional reference addon remains the
-- sole owner of its input, settings and scene. We read its completed state;
-- never call its controller, replace scripts, hook methods or write its tables.
local function number(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge and value or false
end

local function values(fn, owner)
    if type(fn)~="function" then return false,false,false end
    local ok,a,b,c
    if owner then ok,a,b,c=pcall(fn,owner) else ok,a,b,c=pcall(fn) end
    if not ok then return false,false,false end
    return number(a),number(b),number(c)
end

local function cvar(name)
    local fn=C_CVar and C_CVar.GetCVar or GetCVar
    if type(fn)~="function" then return false end
    local ok,value=pcall(fn,name)
    return ok and number(tonumber(value)) or false
end

local function view()
    local reference=XPRACTICE
    local games=reference and reference.games
    local game=games and games[1]
    local env=game and not game.dead and game.environment_gameplay
    local camera=env and env.cameramanager and env.cameramanager.camera
    local focus=camera and camera.focus
    local scene=env and env.modelsceneframe
    if not (scene and focus and focus.position and camera.orientation) then return end
    if not scene:IsShown() then return end
    return game,camera,focus,scene
end

function Trace:Stop(reason)
    local record=self.record
    self.record,self.game,self.camera,self.lastGameTime=nil,nil,nil,nil
    if self.frame then
        self.frame:SetScript("OnUpdate",nil)
        self.frame:SetScript("OnEvent",nil)
        self.frame:UnregisterAllEvents()
        self.frame:Hide()
    end
    if not record then return end
    record.status,record.finishedAt=reason,GetTime()
    if reason=="complete" then
        EL.Print(L["Comparison saved. Use /reload, then report that the recording is ready."])
    else
        EL.Print(EL.F("Reference recording stopped: %s. Use /reload to save the available samples.",reason))
    end
end

function Trace:Sample(elapsed)
    local record=self.record
    if not record then return end
    local now=GetTime()
    if InCombatLockdown and InCombatLockdown() then self:Stop("combat"); return end
    if now-record.armedAt>=180 then self:Stop("timeout"); return end
    if EL.instance and EL.instance.frame:IsShown() then self:Stop("training_view_opened"); return end
    local game,camera,focus,scene=view()
    if not record.startedAt then
        local right=game and game.keys and game.keys.rmouse
        if not (game and right and right.current and number(camera.camerarotationprevmousex)) then return end
        record.startedAt,record.status=now,"recording"
        self.game,self.camera=game,camera
        local config=XPRACTICE.Config and XPRACTICE.Config.Camera
        local saved=XPRACTICE_SAVEDATA and XPRACTICE_SAVEDATA.Config
        local remembered=XPRACTICE.CVars and XPRACTICE.CVars.cvarvalues
        record.configuredCursorSpeed=config and number(config.MouseSpeed) or false
        record.configuredCameraSpeed=saved and saved.Camera and number(saved.Camera.CameraSpeed) or false
        record.configuredScreenMode=saved and type(saved.SCREEN_SIZE)=="string" and saved.SCREEN_SIZE or false
        record.rememberedYawSpeed=remembered and number(tonumber(remembered.cameraYawMoveSpeed)) or false
        record.rememberedMouseSpeed=remembered and number(tonumber(remembered.mouseSpeed)) or false
        record.rememberedMouseOverride=remembered and number(tonumber(remembered.enableMouseSpeed)) or false
        local meta=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        if type(meta)=="function" then
            local ok,version=pcall(meta,"XPractice","Version")
            record.referenceVersion=ok and type(version)=="string" and version or false
        end
        record.referenceVersion=record.referenceVersion or false
        EL.Print(L["Recording XPractice for 10 seconds. Keep the target in view while strafing with the right mouse button."])
    end
    if game~=self.game or camera~=self.camera then self:Stop("reference_view_changed"); return end
    -- Our observer may run before or after the reference OnUpdate. Retain its
    -- own time and applied cursor origin to align complete frames afterwards.
    -- Current cursor/native deltas are separate observational columns.
    local gameTime=number(game.currenttime)
    if gameTime~=self.lastGameTime then
        self.lastGameTime=gameTime
        local x,y=values(GetCursorPosition)
        local dx,dy=values(GetCursorDelta)
        local cx,cy,cz=values(scene.GetCameraPosition,scene)
        local fx,fy,fz=values(scene.GetCameraForward,scene)
        local fps=values(GetFramerate)
        local width=values(scene.GetWidth,scene)
        local height=values(scene.GetHeight,scene)
        local scale=values(scene.GetEffectiveScale,scene)
        local fov=values(scene.GetCameraFieldOfView,scene)
        local p,o=focus.position,camera.orientation
        local keys=game.keys or {}
        local buttons=(keys.lmouse and keys.lmouse.current and 1 or 0)+(keys.rmouse and keys.rmouse.current and 2 or 0)
        record.samples[#record.samples+1]={now,elapsed,gameTime,x,y,dx,dy,buttons,
            number(camera.camerarotationprevmousex),number(camera.camerarotationprevmousey),
            number(o.yaw),number(o.pitch),number(p.x),number(p.y),number(p.z),
            number(focus.orientation and focus.orientation.yaw),number(camera.cdist),
            cx,cy,cz,fx,fy,fz,fps,cvar("enableMouseSpeed"),cvar("mouseSpeed"),
            cvar("cameraYawMoveSpeed"),cvar("cameraPitchMoveSpeed"),cvar("mouseInvertYaw"),cvar("mouseInvertPitch"),
            width,height,scale,fov}
    end
    if now-record.startedAt>=record.duration or #record.samples>=record.limit then self:Stop("complete") end
end

function Trace:Arm()
    self:Stop("replaced")
    if InCombatLockdown and InCombatLockdown() then EL.Print(L["Please wait until combat ends."]); return false end
    if not XPRACTICE then
        EL.Print(L["Enable XPractice in the addon list and reload before starting the comparison."])
        return false
    end
    local record={schema=1,addonVersion=EL.VERSION,armedAt=GetTime(),status="armed",duration=10,limit=4096,
        columns={"time","elapsed","referenceTime","cursorX","cursorY","nativeDX","nativeDY","buttons",
            "appliedCursorX","appliedCursorY","yaw","pitch","playerX","playerY","playerZ","playerYaw","distance",
            "sceneX","sceneY","sceneZ","sceneForwardX","sceneForwardY","sceneForwardZ","fps",
            "enableMouseSpeed","mouseSpeed","cameraYawMoveSpeed","cameraPitchMoveSpeed","mouseInvertYaw","mouseInvertPitch",
            "width","height","scale","fov"},samples={}}
    self.record,EncounterLabReferenceTrace=record,record
    local frame=self.frame or CreateFrame("Frame")
    self.frame=frame
    frame:SetScript("OnUpdate",function(_,elapsed)
        local ok=pcall(self.Sample,self,elapsed)
        if not ok then self:Stop("reference_read_failed") end
    end)
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:RegisterEvent("PLAYER_LEAVING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent",function(_,event) self:Stop(event) end)
    frame:Show()
    EL.Print(L["Open XPractice with /xp, enter a practice scene, then strafe around a target while holding the right mouse button for 10 seconds."])
    return true
end

function Trace:BeginComparison(ui)
    if not XPRACTICE then
        EL.Print(L["Enable XPractice in the addon list and reload before starting the comparison."])
        return false
    end
    self:Stop("replaced")
    self.compareInput=nil
    ui:Show()
    ui.input:ArmTrace()
    self.compareInput=ui.input
    EL.Print(L["Comparison 1/2: start EncounterLab training and keep Rashok in view while strafing with the right mouse button for 10 seconds."])
    return true
end

function Trace:TrainingFinished(input,reason)
    if self.compareInput~=input then return end
    self.compareInput=nil
    if reason~="complete" then
        EL.Print(L["Comparison interrupted. Use /el mousecompare to start again."])
        return
    end
    input.ui:Hide()
    self:Arm()
end
