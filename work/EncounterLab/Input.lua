local _, EL = ...
local L = EL.L
local Input = {}
EL.Input = Input
local defaults = { forward="W", backward="S", left="Q", right="E", turnLeft="A", turnRight="D", jump="SPACE", walk="NUMPADDIVIDE", revive="R", ability="F", pause="P" }
local order = { "forward", "backward", "left", "right", "turnLeft", "turnRight", "jump", "walk", "revive", "ability", "pause" }
local nativeActions = { forward="MOVEFORWARD", backward="MOVEBACKWARD", left="STRAFELEFT", right="STRAFERIGHT", turnLeft="TURNLEFT", turnRight="TURNRIGHT", jump="JUMP", walk="TOGGLERUN" }
local reserved = { ESCAPE=true, ENTER=true, SLASH=true, TAB=true, LALT=true, RALT=true, LCTRL=true, RCTRL=true, LSHIFT=true, RSHIFT=true, F11=true }
local mouseErrors={
    capture_busy=L["Another view is already using the mouse."],
    recovery_pending=L["The previous mouse settings could not be restored yet."],
    cursor_unavailable=L["The cursor position is unavailable."],
    settings_unavailable=L["Mouse settings are unavailable."],
}
Input.DEFAULT_BINDINGS = defaults

local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function applyMouseDelta(self, dx, dy)
    local camera = self.ui.camera
    local moved = dx ~= 0 or dy ~= 0
    -- Preserve the accepted cursor-speed/gain pairing. Native axis preferences
    -- and the optional user multiplier still apply.
    local gain = EL.MouseCapture.CAMERA_GAIN * ((self.ui.options.mouseSensitivity or .006) / .006)
    local yawSign = self.mouse.invertYaw and 1 or -1
    local pitchSign = self.mouse.invertPitch and 1 or -1
    if self.ui.options.invertY then pitchSign = -pitchSign end
    camera.yaw = (camera.yaw + dx * gain * self.mouse.yawScale * yawSign + math.pi) % (2 * math.pi) - math.pi
    camera.pitch = EL.Clamp(camera.pitch + dy * gain * self.mouse.pitchScale * pitchSign, 0, math.pi * .49)
    return moved
end

local function sampleMouseDelta(self)
    local dx, dy = self.mouse:Delta()
    return applyMouseDelta(self, dx, dy)
end

local function sampleMouseReleaseDelta(self)
    local dx, dy = self.mouse:ReleaseDelta()
    return applyMouseDelta(self, dx, dy)
end

local function supported(key)
    if type(key) ~= "string" or #key == 0 or #key > 40 then return false end
    local base = key:match("([^%-]+)$")
    -- Alt releases focus for OS switching. Mouse buttons belong to scene dragging.
    return base and not reserved[base] and not key:find("ALT%-") and
        not base:match("^BUTTON") and not base:match("^MOUSEWHEEL") and not base:match("^PAD")
end

local function chord(key)
    local prefix = ""
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end

local function freeKey(preferred, used)
    if supported(preferred) and not used[preferred] then return preferred end
    for index = 1, 12 do
        local key = "F" .. index
        if supported(key) and not used[key] then return key end
    end
end

function Input.New(ui)
    local self = setmetatable({ui=ui, keys={}, presses={}, buttons={}, sample={}, active=false}, {__index=Input})
    self.mouse = EL.MouseCapture.New()
    local capture = CreateFrame("Frame", nil, ui.viewport)
    capture:SetAllPoints()
    capture:SetFrameLevel(ui.viewport:GetFrameLevel() + 20)
    capture:EnableMouse(true)
    capture:EnableMouseWheel(true)
    capture:EnableKeyboard(false)
    capture:SetPropagateKeyboardInput(false)
    self.frame = capture
    capture:SetScript("OnKeyDown", function(_, key) self:KeyDown(key) end)
    capture:SetScript("OnKeyUp", function(_, key) self.keys[key], self.presses[key] = nil, nil end)
    capture:SetScript("OnMouseDown", function(_, button)
        if combat() then ui:Hide(L["Combat started"]) return end
        if ui.modal and ui.modal:IsShown() then return end
        if not self.active and not self:Acquire() then return end
        if not self:GameplayAllowed() then return end
        if ui.aiming and button == "LeftButton" then
            local x, y = ui.renderer:GetGroundPoint(GetCursorPosition())
            if x then ui:UseAbility(ui.aiming, x, y) end
            ui.aiming = nil
            return
        end
        if button == "MiddleButton" then ui:UseSelectedAbility() return end
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        if not self.buttons.LeftButton and not self.buttons.RightButton then
            self.pendingMouseFacingYaw = nil
            local started, reason = self.mouse:Begin()
            if not started then
                ui:Notice(EL.F("Mouse control could not start: %s",mouseErrors[reason] or L["Mouse settings are unavailable."]))
                return
            end
        end
        if button == "RightButton" then self.rightMouseAligned = nil end
        self.buttons[button] = true
    end)
    capture:SetScript("OnMouseUp", function(_, button) self:MouseUp(button) end)
    capture:SetScript("OnMouseWheel", function(_, delta)
        if not combat() and self:GameplayAllowed() then
            ui.camera.distance = EL.Clamp(ui.camera.distance - delta * 4, 5, 90)
        end
    end)
    capture:SetScript("OnHide", function()
        self.active, self.bindAction = false, nil
        self:Clear()
        for key in pairs(self.presses) do self.presses[key] = nil end
    end)
    capture:RegisterEvent("UPDATE_BINDINGS")
    capture:SetScript("OnEvent", function()
        self:Clear()
        self:RefreshBindings()
        if not combat() then
            if ui.UpdateControls then ui:UpdateControls() end
            if ui.modalPage == "settings" and ui.modal and ui.modal:IsShown() then ui:ShowSettings() end
        end
    end)
    self:RefreshBindings()
    return self
end

function Input:GameplayAllowed()
    local ui = self.ui
    if ui.modal and ui.modal:IsShown() then return false end
    return not ui.IsGameplayInputAllowed or ui:IsGameplayInputAllowed()
end

function Input:RefreshBindings()
    local options, effective, used = self.ui.options, {}, {}
    local configured = options.bindings or defaults
    local useNative = options.bindingPreset ~= "custom" and GetBindingKey
    for _, action in ipairs(order) do
        local keys = {}
        if useNative and nativeActions[action] then
            -- Read only: native commands are never executed or rebound.
            local first, second = GetBindingKey(nativeActions[action])
            if supported(first) then keys[#keys + 1] = first; used[first] = true end
            if supported(second) and second ~= first then keys[#keys + 1] = second; used[second] = true end
        else
            local key = freeKey(configured[action] or defaults[action], used)
            if key then keys[1], used[key] = key, true end
        end
        effective[action] = keys
    end
    self.effectiveBindings = effective
    self.bindingOptions, self.bindingConfig, self.bindingPreset = options, options.bindings, options.bindingPreset
end

function Input:Bindings()
    local options = self.ui.options
    if not self.effectiveBindings or self.bindingOptions ~= options or self.bindingConfig ~= options.bindings or self.bindingPreset ~= options.bindingPreset then
        self:RefreshBindings()
    end
    return self.effectiveBindings
end

function Input:Binding(action)
    local keys = self:Bindings()[action]
    return keys and keys[1] or ""
end

function Input:BindingLabel(action)
    local keys = self:Bindings()[action]
    return keys and #keys > 0 and table.concat(keys, " / ") or L["Unbound"]
end

function Input:Matches(action, key)
    for _, assigned in ipairs(self:Bindings()[action] or {}) do
        if assigned == key then return true end
    end
    return false
end

function Input:Held(action)
    for _, assigned in ipairs(self:Bindings()[action] or {}) do
        local base = assigned:match("([^%-]+)$")
        if self.keys[base] and chord(base) == assigned then return 1 end
    end
    return 0
end

function Input:Clear()
    self.rightMouseAligned, self.pendingMouseFacingYaw = nil, nil
    self.mouse:End()
    for key in pairs(self.keys) do self.keys[key] = nil end
    for button in pairs(self.buttons) do self.buttons[button] = nil end
    self.jumpQueued = false
end

function Input:MouseUp(button)
    if (button ~= "LeftButton" and button ~= "RightButton") or not self.buttons[button] then return end
    -- The same cursor baseline handles render samples and button transitions.
    -- Preserve a final RMB turn for the next render, even between fixed ticks.
    local moved = self.mouse.active and sampleMouseReleaseDelta(self)
    if self.buttons.RightButton and moved then
        self.rightMouseAligned = true
        self.pendingMouseFacingYaw = self.ui.camera.yaw
    end
    self.buttons[button] = nil
    if button == "RightButton" then self.rightMouseAligned = nil end
    if not self.buttons.LeftButton and not self.buttons.RightButton then self.mouse:End() end
end

function Input:Acquire()
    if combat() then return false end
    self:Clear()
    for key in pairs(self.presses) do self.presses[key] = nil end
    self:RefreshBindings()
    self.frame:Show()
    self.frame:SetPropagateKeyboardInput(false)
    self.frame:EnableKeyboard(true)
    self.active = true
    return true
end

function Input:Release()
    if self.trace and (self.trace.startedAt or (EL.ReferenceTrace and EL.ReferenceTrace.compareInput==self)) then
        self:StopTrace("input_released")
    end
    self:Clear()
    for key in pairs(self.presses) do self.presses[key] = nil end
    self.active, self.bindAction = false, nil
    -- Hiding our private frame also releases keyboard capture in lockdown.
    -- Never reconfigure protected keyboard methods after combat has started.
    if combat() then self.frame:Hide() else self.frame:EnableKeyboard(false) end
end

-- Explicitly armed input diagnostics only. No sampling runs in normal play.
-- Keep native deltas observational: they never enter the camera calculation.
function Input:ArmTrace()
    if self.trace then self:StopTrace("replaced") end
    local trace = {schema=3, addonVersion=EL.VERSION, status="armed", duration=10, limit=4096,
        videoStamp="sample-minus-one-12bit-msb",
        fullscreen=self.ui.options.fullscreen, sensitivity=self.ui.options.mouseSensitivity,
        columns={"time","elapsed","cursorX","cursorY","nativeDX","nativeDY","buttons",
            "yaw","pitch","playerX","playerY","playerZ","playerYaw","simulationTime",
            "forward","strafe","fps","enableMouseSpeed","mouseSpeed","cameraYawMoveSpeed","cameraPitchMoveSpeed",
            "sceneX","sceneY","sceneZ","sceneForwardX","sceneForwardY","sceneForwardZ","width","height","scale","fov",
            "sample","bossX","bossY","bossZ","nativeBossX","nativeBossY","overlayBossX","overlayBossY","viewportLeft","viewportBottom"}, samples={}}
    self.trace, EncounterLabMouseTrace = trace, trace
    self.ui.renderer:PrepareTraceStamp()
    self.ui:Notice(L["Mouse trace armed. Start training and hold a mouse button for 10 seconds."])
end

function Input:StopTrace(reason)
    local trace = self.trace
    if not trace then return end
    trace.status, trace.finishedAt = reason, GetTime()
    self.trace = nil
    self.ui.renderer:HideTraceStamp()
    self.ui:Notice(L["Mouse trace saved. Use /reload to write the local recording."])
    if EL.ReferenceTrace then EL.ReferenceTrace:TrainingFinished(self,reason) end
end

function Input:TraceFrame(elapsed, state)
    local trace = self.trace
    if not trace then return end
    local now = GetTime()
    if not trace.startedAt then
        if not self.mouse.active or state.status ~= "running" then return end
        trace.startedAt, trace.status = now, "recording"
        trace.fullscreen = self.ui.options.fullscreen
        trace.captureMode, trace.cameraGain = self.mouse.inputMode, EL.MouseCapture.CAMERA_GAIN
        trace.yawScale, trace.pitchScale = self.mouse.yawScale, self.mouse.pitchScale
        trace.invertYaw, trace.invertPitch = self.mouse.invertYaw, self.mouse.invertPitch
        local record = self.mouse.record
        if record then
            trace.originalMouseSpeed, trace.originalEnableMouseSpeed = record.original.mouseSpeed, record.original.enableMouseSpeed
            trace.captureMouseSpeed = record.applied.mouseSpeed or record.original.mouseSpeed
        end
        local scene = self.ui.renderer.frame
        trace.viewportWidth, trace.viewportHeight, trace.uiScale = scene:GetWidth(), scene:GetHeight(), scene:GetEffectiveScale()
    end
    if state.status ~= "running" then self:StopTrace("training_stopped"); return end
    local dx, dy, fps = false, false, false
    if type(GetCursorDelta) == "function" then
        local ok, x, y = pcall(GetCursorDelta)
        if ok and type(x)=="number" and type(y)=="number" and x==x and y==y
            and math.abs(x)<math.huge and math.abs(y)<math.huge then dx, dy = x, y end
    end
    if type(GetFramerate) == "function" then
        local ok, value = pcall(GetFramerate)
        if ok and type(value)=="number" and value==value and math.abs(value)<math.huge then fps=value end
    end
    local camera, player, input = self.ui.camera, state.player, self.sample
    local function numbers(fn,owner,...)
        if type(fn)~="function" then return false,false,false end
        local ok,a,b,c=pcall(fn,owner,...)
        local function value(v) return ok and type(v)=="number" and v==v and math.abs(v)<math.huge and v or false end
        return value(a),value(b),value(c)
    end
    local function setting(name)
        local fn=C_CVar and C_CVar.GetCVar or GetCVar
        if type(fn)~="function" then return false end
        local ok,value=pcall(fn,name)
        value=ok and tonumber(value)
        return value and value==value and math.abs(value)<math.huge and value or false
    end
    local scene=self.ui.renderer.frame
    local cx,cy,cz=numbers(scene.GetCameraPosition,scene)
    local fx,fy,fz=numbers(scene.GetCameraForward,scene)
    local width=numbers(scene.GetWidth,scene)
    local height=numbers(scene.GetHeight,scene)
    local scale=numbers(scene.GetEffectiveScale,scene)
    local fov=numbers(scene.GetCameraFieldOfView,scene)
    local index = #trace.samples + 1
    local boss = state.boss
    local bx,by,bz,nx,ny,ox,oy = false,false,false,false,false,false,false
    if boss then
        bx,by,bz = boss.x,boss.y,boss.z or 0
        nx,ny = numbers(scene.Project3DPointTo2D,scene,bx,by,bz)
        ox,oy = numbers(self.ui.renderer.Project,self.ui.renderer,bx,by,bz)
    end
    local left = numbers(scene.GetLeft,scene)
    local bottom = numbers(scene.GetBottom,scene)
    trace.samples[index] = {now, elapsed, self.mouse.x or false, self.mouse.y or false, dx, dy,
        (self.buttons.LeftButton and 1 or 0)+(self.buttons.RightButton and 2 or 0),
        camera.yaw, camera.pitch, player.x, player.y, player.z, player.yaw, state.time,
        input.forward, input.strafe, fps,setting("enableMouseSpeed"),setting("mouseSpeed"),
        setting("cameraYawMoveSpeed"),setting("cameraPitchMoveSpeed"),cx,cy,cz,fx,fy,fz,width,height,scale,fov,
        index,bx,by,bz,nx,ny,ox,oy,left,bottom}
    self.ui.renderer:ShowTraceSample(index)
    if now-trace.startedAt >= trace.duration or #trace.samples >= trace.limit then self:StopTrace("complete") end
end

function Input:KeyDown(key)
    if combat() then self.ui:Hide(L["Combat started"]) return end
    if not self.active then return end
    if self.presses[key] then return end
    self.presses[key] = true
    local ui = self.ui
    if key == "LALT" or key == "RALT" then
        ui:PauseForFocus(L["Focus changed: click the arena, then press Pause to resume"])
        return
    end
    if self.bindAction then
        if key == "ESCAPE" then
            self.bindAction = nil
            ui:ShowSettings()
            self.presses[key] = true
            return
        end
        local assigned = chord(key)
        if not supported(assigned) then return end
        local bindings = {}
        for action, default in pairs(defaults) do bindings[action] = self:Binding(action) ~= "" and self:Binding(action) or default end
        for action, existing in pairs(bindings) do
            if existing == assigned and action ~= self.bindAction then
                ui:Notice(EL.F("Key is already assigned: %s", assigned))
                return
            end
        end
        bindings[self.bindAction] = assigned
        ui.options.bindings = bindings
        EL.Store.SaveOptions(ui.options)
        self:RefreshBindings()
        self.bindAction = nil
        ui:ShowSettings()
        return
    end
    if key == "ESCAPE" then
        if ui.HandleEscape then ui:HandleEscape()
        elseif ui.aiming then ui.aiming = nil
        elseif ui.modal and ui.modal:IsShown() then ui:CloseModal()
        else ui:Hide() end
        self.presses[key] = true
        return
    end
    if key == "F11" and ui.ToggleFullscreen then
        ui:ToggleFullscreen()
        self.presses[key] = true
        return
    end
    if key == "ENTER" or key == "SLASH" then
        ui:PauseForFocus(L["Chat opened: click the arena, then press Pause to resume"])
        if ChatFrame_OpenChat then ChatFrame_OpenChat(key == "SLASH" and "/" or "") end
        return
    end
    local assigned = chord(key)
    if not self:GameplayAllowed() then
        -- Setup may pause the run, but its Pause shortcut must still resume it.
        -- A modal owns input until explicitly closed.
        if not (ui.modal and ui.modal:IsShown()) and self:Matches("pause", assigned) then
            ui:TogglePause()
            self.presses[key] = true
        end
        return
    end
    self.keys[key] = true
    if self:Matches("jump", assigned) then self.jumpQueued = true
    elseif self:Matches("revive", assigned) then ui:Revive()
    elseif self:Matches("ability", assigned) then ui:UseSelectedAbility()
    elseif self:Matches("pause", assigned) then ui:TogglePause()
    elseif self:Matches("walk", assigned) then self.walking = not self.walking end
    -- Action handlers can clear movement; latch the press to reject OS key repeat.
    self.presses[key] = true
end

function Input:BeginBinding(action)
    if not defaults[action] or not self:Acquire() then return end
    if self.ui.options.bindingPreset ~= "custom" then
        local bindings, used = {}, {}
        for _, name in ipairs(order) do
            local key = freeKey(self:Binding(name), used)
            bindings[name] = key
            if key then used[key] = true end
        end
        self.ui.options.bindings, self.ui.options.bindingPreset = bindings, "custom"
        EL.Store.SaveOptions(self.ui.options)
        self:RefreshBindings()
    end
    self.bindAction = action
    self.ui:Notice(L["Press a new key; Escape cancels."])
end

function Input:Sample()
    local out = self.sample
    out.forward, out.strafe, out.turn, out.yaw, out.jump = 0, 0, 0, nil, false
    out.lockFacing=false
    out.walk = self.walking or false
    if not self.active then return out end
    if combat() then self.ui:Hide(L["Combat started"]) return out end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus then
        self.ui:PauseForFocus(L["Text input: click the arena, then press Pause to resume"])
        return out
    end
    -- Only reconcile presses first received by this frame, using physical key state.
    if IsKeyDown then
        for key in pairs(self.keys) do
            if not IsKeyDown(key, true) then self.keys[key] = nil end
        end
        for key in pairs(self.presses) do
            if not IsKeyDown(key, true) then self.presses[key] = nil end
        end
    end
    if not self:GameplayAllowed() then self:Clear(); return out end
    if IsMouseButtonDown then
        if self.buttons.LeftButton and not IsMouseButtonDown("LeftButton") then self:MouseUp("LeftButton") end
        if self.buttons.RightButton and not IsMouseButtonDown("RightButton") then self:MouseUp("RightButton") end
    end
    local leftMouse, rightMouse = self.buttons.LeftButton, self.buttons.RightButton
    local mouseMoved=false
    if leftMouse or rightMouse then
        mouseMoved = sampleMouseDelta(self)
    else
        if self.mouse.active then self.mouse:End() end
    end
    -- Each side is a boolean action. Two keys for the same action do not make
    -- it stronger than an opposing action, and backpedal cancels mouse-forward.
    local forward=self:Held("forward")==1 or (leftMouse and rightMouse)
    out.forward=(forward and 1 or 0)-self:Held("backward")
    local left=self:Held("left")==1 or (rightMouse and self:Held("turnLeft")==1)
    local right=self:Held("right")==1 or (rightMouse and self:Held("turnRight")==1)
    out.strafe=(left and 1 or 0)-(right and 1 or 0)
    if rightMouse then
        -- Render frames can outnumber simulation ticks. Retain alignment after
        -- the first drag so a quiet cursor frame cannot discard its facing.
        if mouseMoved or leftMouse then self.rightMouseAligned = true end
        if self.rightMouseAligned then out.yaw=self.ui.camera.yaw; out.lockFacing=true end
    elseif self.pendingMouseFacingYaw ~= nil then
        out.yaw, out.lockFacing = self.pendingMouseFacingYaw, true
    else
        out.turn = self:Held("turnLeft") - self:Held("turnRight")
    end
    if out.lockFacing then self.pendingMouseFacingYaw = nil end
    out.jump = self.jumpQueued or false
    self.jumpQueued = false
    return out
end

function Input:Destroy()
    self:Release()
    self.frame:Hide()
    self.frame:UnregisterEvent("UPDATE_BINDINGS")
    self.frame:SetScript("OnEvent", nil)
    self.frame:SetScript("OnKeyDown", nil)
    self.frame:SetScript("OnKeyUp", nil)
    self.frame:SetScript("OnMouseDown", nil)
    self.frame:SetScript("OnMouseUp", nil)
    self.frame:SetScript("OnMouseWheel", nil)
    self.frame:SetScript("OnHide", nil)
end
