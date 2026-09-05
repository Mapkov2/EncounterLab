local _, EL = ...
local UI = {}
EL.UI = UI
local L, Theme = EL.L, EL.Theme
local abilityNames = {blink=L["Blink"],roll=L["Roll"],sprint=L["Sprint"],leap=L["Targeted leap"],teleport=L["Teleport"],gateway=L["Gateway"],immunity=L["Immunity"]}
abilityNames.teleport_set=L["Teleport point placed"]
abilityNames.gateway_set=L["Gateway placed"]
local hitNames = {["Lava pool"]=L["Lava pool"],["Lava wave"]=L["Lava wave"],["Bonus wave"]=L["Bonus wave"],Frontal=L["Frontal"]}
local abilityErrors = {Unavailable=L["Player is dead or training is paused"],Cooldown=L["On cooldown"],["Set teleport first"]=L["Place a teleport point first"],["Set gateway first"]=L["Place a gateway first"],["Move within 5 of an endpoint"]=L["Move within 5 yards of a gateway endpoint"]}
local abilityOrder = {"blink","roll","sprint","leap","teleport","gateway","immunity"}
local bindingLabels = {forward=L["Forward"],backward=L["Backward"],left=L["Strafe left"],right=L["Strafe right"],turnLeft=L["Turn left"],turnRight=L["Turn right"],jump=L["Jump"],walk=L["Walk / run"],revive=L["Revive"],ability=L["Movement ability"],pause=L["Pause"]}
local bindingOrder = {"forward","backward","left","right","turnLeft","turnRight","jump","walk","revive","ability","pause"}

local function fill(frame, r, g, b, a)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r,g,b,a or 1)
    return texture
end

local function label(parent, text, size, r, g, b)
    local font = parent:CreateFontString(nil, "OVERLAY")
    Theme.Font(font,size or 13,(size or 13)>=15)
    if r then font:SetTextColor(r,g,b) end
    font:SetJustifyH("LEFT"); font:SetJustifyV("TOP")
    font:SetText(L[text or ""])
    return font
end

local function button(parent, text, width, height, callback, bright)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 180,height or 26)
    b.tint = Theme.Panel(b, bright and Theme.colors.selected or Theme.colors.raised)
    b.bright = bright
    b.caption = label(b,text,13)
    -- This custom control owns its caption. Do not hand it to the native
    -- button text/state layout, which can override the FontString's bounds.
    b.caption:ClearAllPoints()
    b.caption:SetPoint("CENTER",b,"CENTER",0,0)
    local function sizeCaption(self)
        self.caption:SetSize(math.max(1,self:GetWidth()-12),math.max(1,self:GetHeight()-4))
    end
    b:SetScript("OnSizeChanged",sizeCaption)
    sizeCaption(b)
    b.caption:SetJustifyH("CENTER"); b.caption:SetJustifyV("MIDDLE")
    b.caption:SetWordWrap(false)
    function b:SetText(value) self.caption:SetText(value or "");self.caption:Show() end
    function b:GetText() return self.caption:GetText() end
    b:SetText(L[text or ""])
    b:SetScript("OnClick",callback)
    b:SetScript("OnEnter",function() b.tint(Theme.colors.hover) end)
    b:SetScript("OnLeave",function() b:Selected(b.selected) end)
    function b:Selected(value)
        self.selected=value
        self.tint((value or self.bright) and Theme.colors.selected or Theme.colors.raised)
    end
    return b
end

local function edit(parent, width, text)
    local e = CreateFrame("EditBox",nil,parent)
    e:SetSize(width,26)
    Theme.Panel(e,Theme.colors.shell)
    Theme.Font(e,13)
    e:SetTextInsets(8,8,0,0)
    e:SetAutoFocus(false)
    e:SetMaxLetters(10)
    e:SetNumeric(true)
    e:SetText(text or "")
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    return e
end

local function at(item, parent, x, y)
    item:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    return item
end

UI.CreateButton=button

function UI.New()
    local self = setmetatable({}, {__index=UI})
    self.options = EL.Store.GetOptions()
    self.camera = {yaw=-math.pi*5/6,pitch=math.pi*.075,distance=60}
    self.menuVisible = true
    local f = CreateFrame("Frame","EncounterLabWindow",UIParent)
    self.frame = f
    f:Hide(); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:SetResizable(true)
    f:SetClampedToScreen(true); f:EnableMouse(true)
    f:SetResizeBounds(1040,720,math.max(1040,UIParent:GetWidth()),math.max(720,UIParent:GetHeight()))
    Theme.Panel(f,Theme.colors.shell)

    local viewport = CreateFrame("Frame",nil,f)
    self.viewport = viewport
    viewport:SetClipsChildren(true)
    fill(viewport,.008,.012,.020)
    self.renderer = EL.Renderer.New(viewport)
    self.input = EL.Input.New(self)

    -- Menus sit above the private mouse/keyboard capture frame. The arena never
    -- inherits a sidebar inset in fullscreen mode.
    local menu = CreateFrame("Frame",nil,f)
    self.menu = menu
    menu:SetFrameLevel(self.input.frame:GetFrameLevel()+20)
    menu:SetSize(256,610); menu:EnableMouse(true)
    Theme.Panel(menu,Theme.colors.shell)
    local top = CreateFrame("Frame",nil,menu)
    self.top = top
    top:SetPoint("TOPLEFT",12,-12); top:SetPoint("TOPRIGHT",-12,-12); top:SetHeight(42)
    top:EnableMouse(true); top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart",function() if not self.options.fullscreen and not InCombatLockdown() then f:StartMoving() end end)
    top:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    at(label(top,"EncounterLab",21),top,4,0)
    at(label(top,"Mechanics practice",11,.66,.71,.78),top,4,26)
    local close = button(top,"X",26,24,function() self:Hide() end)
    close:SetPoint("TOPRIGHT")

    local side = CreateFrame("Frame",nil,menu)
    self.side = side
    side:SetPoint("TOPLEFT",8,-66); side:SetPoint("BOTTOMRIGHT",-8,8)
    Theme.Panel(side,Theme.colors.rail)
    self.encounterButton=at(button(side,"Rashok",216,26,function() self:ShowEncounters() end),side,12,10)
    self.encounterSubtitle=at(label(side,"Lava waves",13,.66,.71,.78),side,12,42)
    self.drillLabel=at(label(side,"Starting loop",11,.66,.71,.78),side,12,75)
    self.loopButtons = {}
    for i=1,3 do
        local loop = i
        self.loopButtons[i] = at(button(side,EL.F("Loop %d",i),68,26,function() self:SelectDrill(loop) end),side,12+(i-1)*74,96)
    end
    self.normalButton = at(button(side,"Normal",105,26,function()
        self.options.mode,self.options.speed,self.options.hints="reference",1,false; self:SaveOptions()
    end),side,12,134)
    self.practiceButton = at(button(side,"Practice",105,26,function() self.options.mode="practice"; self:SaveOptions() end),side,123,134)
    self.speedButton = at(button(side,"",216,26,function()
        local speed = self.options.speed
        self.options.speed = speed == 1 and .75 or (speed == .75 and .5 or 1)
        if self.options.speed ~= 1 then self.options.mode="practice" end
        self:SaveOptions()
    end),side,12,169)
    self.hintsButton = at(button(side,"",216,26,function()
        self.options.hints=not self.options.hints
        if self.options.hints then self.options.mode="practice" end
        self:SaveOptions()
    end),side,12,201)
    at(label(side,"Run seed",11,.66,.71,.78),side,12,244)
    self.seedBox = at(edit(side,216,tostring(self.options.seed or EL.Store.GetDailySeed(date("%Y-%m-%d")))),side,12,264)
    self.seedBox:SetScript("OnEditFocusGained",function() self:PauseForFocus(L["Editing run seed"]) end)
    self.seedBox:SetScript("OnEditFocusLost",function() if self.frame:IsShown() then self.input:Acquire() end end)
    at(button(side,"Daily seed",105,26,function()
        self.seedBox:ClearFocus(); self.seedBox:SetText(tostring(EL.Store.GetDailySeed(date("%Y-%m-%d"))))
        self:Notice(L["The daily seed gives everyone the same sequence."])
    end),side,12,298)
    at(button(side,"Random seed",105,26,function()
        self.seedBox:ClearFocus(); self.seedBox:SetText(tostring((time() + math.floor(GetTime()*1000)) % 2147483646 + 1))
    end),side,123,298)
    self.startButton = at(button(side,"Start training",216,32,function() self:Start() end,true),side,12,346)
    self.retryButton = at(button(side,"Restart same run",216,26,function() self:Start(true) end),side,12,384)
    self.highscoresButton = at(button(side,"Highscores",216,26,function() self:ShowScores() end),side,12,424)
    at(button(side,"Controls",105,26,function() self:ShowSettings() end),side,12,458)
    at(button(side,"Help",105,26,function() self:ShowHelp() end),side,123,458)
    self.fullscreenButton = at(button(side,"",216,26,function() self:ToggleFullscreen() end),side,12,492)

    local overlay = CreateFrame("Frame",nil,viewport)
    self.overlay = overlay
    overlay:SetAllPoints(); overlay:SetFrameLevel(self.input.frame:GetFrameLevel()+1); overlay:EnableMouse(false)
    self.statusText = label(overlay,"Ready",15)
    self.statusText:SetPoint("TOP",0,-18); self.statusText:SetJustifyH("CENTER")
    self.counterText = label(overlay,"",11,.66,.71,.78)
    self.counterText:SetPoint("TOP",0,-40); self.counterText:SetJustifyH("CENTER")
    self.castFrame = CreateFrame("Frame",nil,overlay)
    self.castFrame:SetPoint("TOP",0,-61); self.castFrame:SetSize(340,22); self.castFrame:EnableMouse(false)
    Theme.Panel(self.castFrame,Theme.colors.shell)
    self.castFill=self.castFrame:CreateTexture(nil,"ARTWORK")
    self.castFill:SetPoint("TOPLEFT",2,-2); self.castFill:SetPoint("BOTTOMLEFT",2,2); self.castFill:SetWidth(1)
    self.castFill:SetColorTexture(.85,.34,.08,.85)
    self.castText=label(self.castFrame,"",12); self.castText:SetPoint("CENTER"); self.castFrame:Hide()
    self.centerText = label(overlay,"",21)
    self.centerText:SetPoint("CENTER",0,24); self.centerText:SetJustifyH("CENTER"); self.centerText:SetWidth(440)
    self.noticeText = label(overlay,"",12)
    self.noticeText:SetPoint("BOTTOMLEFT",16,100); self.noticeText:SetPoint("BOTTOMRIGHT",-16,100); self.noticeText:SetJustifyH("CENTER")

    local bottom = CreateFrame("Frame",nil,f)
    self.bottom = bottom
    bottom:SetFrameLevel(menu:GetFrameLevel()); bottom:SetSize(728,74); bottom:EnableMouse(true)
    Theme.Panel(bottom,Theme.colors.shell)
    self.menuButton = at(button(bottom,"Menu",70,26,function() self:SetMenuVisible(not self.menuVisible) end),bottom,10,9)
    self.pauseButton = at(button(bottom,"",124,26,function() self:TogglePause() end),bottom,86,9)
    self.reviveButton = at(button(bottom,"",124,26,function() self:Revive() end),bottom,216,9)
    self.abilityButton = at(button(bottom,"",172,26,function() self:UseSelectedAbility() end),bottom,346,9)
    at(button(bottom,"Abilities",96,26,function() self:ShowAbilities() end),bottom,524,9)
    self.helpButton = at(button(bottom,"Help",92,26,function() self:ShowHelp() end),bottom,626,9)
    self.footerText = at(label(bottom,"",11,.66,.71,.78),bottom,12,46)
    self.footerText:SetPoint("TOPRIGHT",bottom,"TOPRIGHT",-12,-46)
    self.footerText:SetJustifyH("CENTER")
    local grip = button(f,"+",18,18,function() end)
    self.grip=grip
    grip:SetFrameLevel(menu:GetFrameLevel()); grip:SetPoint("BOTTOMRIGHT")
    grip:SetScript("OnMouseDown",function() if not self.options.fullscreen and not InCombatLockdown() then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp",function()
        f:StopMovingOrSizing()
        if not self.options.fullscreen then self.options.windowWidth,self.options.windowHeight=f:GetSize(); EL.Store.SaveOptions(self.options) end
        self.renderer:Resize()
    end)
    f:SetScript("OnSizeChanged",function() if self.renderer then self.renderer:Resize() end end)
    f:SetScript("OnHide",function() self:OnHide() end)
    f:RegisterEvent("DISPLAY_SIZE_CHANGED"); f:RegisterEvent("UI_SCALE_CHANGED")
    f:SetScript("OnEvent",function() self:ApplyLayout() end)
    self.preview = {player={x=24.32,y=14.44,z=0,yaw=-math.pi*5/6,dead=false},boss={x=0,y=0,z=0,yaw=math.pi/6},pools={},waves={},time=0,status="ready"}
    self:ApplyLayout(); self:UpdateControls()
    return self
end

function UI:ApplyLayout()
    local f = self.frame
    f:StopMovingOrSizing(); f:ClearAllPoints(); self.viewport:ClearAllPoints(); self.menu:ClearAllPoints(); self.bottom:ClearAllPoints()
    if self.options.fullscreen then
        f:SetScale(1); f:SetAllPoints(UIParent)
        self.viewport:SetAllPoints(f)
        self.menu:SetPoint("TOPLEFT",16,-16)
        self.bottom:SetPoint("BOTTOM",0,16)
        self.grip:Hide()
    else
        local fit=math.min(1,(UIParent:GetWidth()-24)/1040,(UIParent:GetHeight()-24)/720)
        f:SetScale(fit)
        f:SetSize(math.min(math.max(1040,self.options.windowWidth),UIParent:GetWidth()/fit-24),math.min(math.max(720,self.options.windowHeight),UIParent:GetHeight()/fit-24))
        f:SetPoint("CENTER")
        self.menu:SetPoint("TOPLEFT",12,-12)
        self.viewport:SetPoint("TOPLEFT",f,"TOPLEFT",280,-12); self.viewport:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-12,98)
        self.bottom:SetPoint("BOTTOM",0,12); self.grip:Show()
    end
    -- Menus stay readable at small UI scales, independently of the full arena.
    self.menu:SetScale(self.options.fullscreen and math.min(1,(UIParent:GetHeight()-120)/610) or 1)
    self.bottom:SetScale(self.options.fullscreen and math.min(1,(UIParent:GetWidth()-24)/728) or 1)
    self.menu:SetShown(not self.selectingEncounter and (self.menuVisible or not self.options.fullscreen))
    self.viewport:SetShown(not self.selectingEncounter)
    self.bottom:SetShown(not self.selectingEncounter)
    self.grip:SetShown(not self.selectingEncounter and not self.options.fullscreen)
    if self.modal then self.modal:SetScale(math.min(1,(UIParent:GetHeight()/f:GetEffectiveScale()-32)/570)) end
    self.renderer:Resize()
end

function UI:SetFullscreen(value)
    value=value==true
    if self.options.fullscreen==value then return end
    if not self.options.fullscreen then self.options.windowWidth,self.options.windowHeight=self.frame:GetSize() end
    self.options.fullscreen=value
    self.input:Clear()
    if not value then
        if self.menuResume and self.sim and self.sim.state.status=="paused" then
            if self.modal and self.modal:IsShown() then self.modalResume=true
            else self.sim:SetPaused(false) end
        end
        self.menuResume=nil; self.menuVisible=true
    else
        self.menuVisible=not self.sim or self.sim.state.status~="running"
    end
    self:SaveOptions(); self:ApplyLayout()
end

function UI:ToggleFullscreen() self:SetFullscreen(not self.options.fullscreen) end

function UI:IsGameplayInputAllowed()
    return not self.selectingEncounter and not (self.options.fullscreen and self.menuVisible)
end

function UI:SetMenuVisible(visible)
    visible=visible==true
    if self.selectingEncounter then return end
    if not self.options.fullscreen then self.menuVisible=true; self.menu:Show(); return end
    if visible==self.menuVisible then return end
    if visible then
        self.menuResume=self.sim and self.sim.state.status=="running" or false
        if self.menuResume then self.sim:SetPaused(true) end
        self.aiming=nil
    elseif self.menuResume and self.sim and self.sim.state.status=="paused" then
        if self.modal and self.modal:IsShown() then self.modalResume=true
        else self.sim:SetPaused(false) end
    end
    if not visible then self.menuResume=nil end
    self.menuVisible=visible; self.menu:SetShown(visible)
    self.input:Acquire(); self:UpdateControls()
end

function UI:HandleEscape()
    if self.aiming then self.aiming=nil
    elseif self.modal and self.modal:IsShown() then self:CloseModal()
    elseif self.options.fullscreen and self.sim then self:SetMenuVisible(not self.menuVisible)
    else self:Hide() end
end

function UI:SaveOptions()
    self.options = EL.Store.SaveOptions(self.options)
    self:UpdateControls()
end

function UI:UpdateControls()
    for i=1,3 do self.loopButtons[i]:Selected(self.options.loop==i) end
    self.normalButton:SetText(L["Normal"])
    self.practiceButton:SetText(L["Practice"])
    self.normalButton:Selected(self.options.mode=="reference")
    self.practiceButton:Selected(self.options.mode=="practice")
    self.speedButton:SetText(EL.F("Speed: %d%%",math.floor(self.options.speed*100)))
    self.hintsButton:SetText(self.options.hints and L["Hit outlines: on"] or L["Hit outlines: off"])
    self.fullscreenButton:SetText(self.options.fullscreen and L["Windowed mode [F11]"] or L["Fullscreen [F11]"])
    self.menuButton:SetText(self.options.fullscreen and self.menuVisible and L["Resume"] or L["Menu"])
    if self.input then
        self.abilityButton:SetText(EL.F("%s: %s",self.input:BindingLabel("ability"),abilityNames[self.options.selectedAbility] or L["Blink"]))
        self.pauseButton:SetText(EL.F("Pause [%s]",self.input:BindingLabel("pause")))
        self.reviveButton:SetText(EL.F("Revive [%s]",self.input:BindingLabel("revive")))
    end
end

function UI:Notice(text)
    self.noticeText:SetText(text)
    self.noticeUntil=GetTime()+7
end

function UI:Show()
    if InCombatLockdown() then EL.Print(L["Training is available after combat."]); return end
    local opening=not self.frame:IsShown()
    if opening then self.selectingEncounter=true end
    self:ApplyLayout()
    self.renderer:ResetMotion()
    self.frame:Show()
    if opening then self:ShowEncounters() end
    self.frame:SetScript("OnUpdate",function(_,elapsed)
        local ok,err=pcall(self.Update,self,elapsed)
        if not ok then
            self:Hide(L["Rendering error; input released"])
            EL.Print(tostring(err))
        end
    end)
    self.input:Acquire(); self:UpdateControls(); self.renderer:Resize()
end

function UI:Hide(reason)
    if reason then EL.Print(EL.F("Training closed: %s",reason)) end
    self.frame:Hide()
end

function UI:OnHide()
    self.frame:SetScript("OnUpdate",nil)
    self.input:Release(); self.input.frame:Hide()
    self.aiming,self.modalResume,self.menuResume=nil,nil,nil
    if self.modal then self.modal:Hide() end
    if self.modalBlocker then self.modalBlocker:Hide() end
    if self.sim and self.sim.state.status~="finished" then
        self.sim.state.interrupted=true; self.sim.state.assisted=true; self.sim:SetPaused(true)
    end
end

function UI:PauseForFocus(reason)
    if self.sim and self.sim.state.status=="running" then self.sim:SetPaused(true) end
    -- A focus interruption must never be auto-resumed by closing a menu.
    self.menuResume,self.modalResume=nil,nil
    if self.input then self.input:Release() end
    self:Notice(reason)
end

function UI:Start(repeatRun)
    if InCombatLockdown() then self:Hide(L["Combat started"]); return end
    if self.selectingEncounter then self:ShowEncounters();return end
    self:CloseModal()
    self.seedBox:ClearFocus()
    local loop, seed = self.options.loop, tonumber(self.seedBox:GetText())
    if repeatRun and self.lastRunOptions then loop, seed=self.lastRunOptions.loop,self.lastRunOptions.seed end
    seed=math.floor(EL.Clamp(seed or 1,1,2147483646))
    local options = {loop=loop,seed=seed,mode=self.options.mode,timeScale=self.options.mode=="reference" and 1 or self.options.speed,assist=self.options.mode=="practice" and self.options.hints}
    if repeatRun and self.lastRunOptions then
        options.mode,options.timeScale,options.assist=self.lastRunOptions.mode,self.lastRunOptions.timeScale,self.lastRunOptions.assist
    end
    options.scenario=repeatRun and self.lastRunOptions and self.lastRunOptions.scenario or self.options.scenario
    options.sszorakDrill=repeatRun and self.lastRunOptions and self.lastRunOptions.sszorakDrill or self.options.sszorakDrill
    options.sszorakCheckpoint=repeatRun and self.lastRunOptions and self.lastRunOptions.sszorakCheckpoint or self.options.sszorakCheckpoint
    options.sentinelsNumber=repeatRun and self.lastRunOptions and self.lastRunOptions.sentinelsNumber or self.options.sentinelsNumber
    options.sentinelsReveal=repeatRun and self.lastRunOptions and self.lastRunOptions.sentinelsReveal or self.options.sentinelsReveal
    if options.scenario=="sszorak" or options.scenario=="sentinels" then options.loop=1 end
    self.lastRunOptions=options
    self.options.seed=seed
    EL.Store.SaveOptions(self.options)
    self.seedBox:SetText(tostring(seed))
    if self.sim then self:RecordAbandoned(); self.sim:Destroy() end
    self.sim=options.scenario=="sentinels" and EL.Sentinels.New(options) or options.scenario=="sszorak" and EL.Sszorak.New(options) or EL.Simulation.New(options)
    self.renderer:SetEncounter(options.scenario)
    self.rehearsal=options.scenario=="sszorak" and EL.Rehearsal.New(self.sim) or nil
    self.recorded=false
    self.aiming=nil
    self.camera.yaw,self.camera.pitch,self.camera.distance=self.sim.state.player.yaw,math.pi*.075,60
    self.renderer:ResetMotion()
    self.renderer:SetHints(options.assist)
    self.renderFailure=nil
    self.menuResume=nil
    if self.options.fullscreen then self:SetMenuVisible(false) end
    self.input:Acquire()
    self:Notice(EL.F("Loop %d Â· Seed %d Â· Stay inside the gold 75-yard boundary for a ranked score.",loop,seed))
end

function UI:TogglePause()
    if not self.sim or self.sim.state.status=="finished" then return end
    if self.options.fullscreen and self.menuVisible then
        self:SetMenuVisible(false)
        if self.sim.state.status=="running" then return end
    end
    self.sim:SetPaused(self.sim.state.status~="paused")
    self.input:Clear()
    if self.sim.state.status=="running" then self.input:Acquire()
    else self:Notice(L["Pausing counts as assistance. This run uses the Assisted leaderboard."]) end
end

function UI:Revive()
    if not self.sim then return end
    self.input:Clear()
    local wasDead=self.sim.state.player.dead
    self.sim:Revive()
    if wasDead then self.renderer:ResetMotion() end
    if wasDead then self:Notice(L["Revived. Time keeps running and lava is still dangerous."]) end
end

function UI:UseAbility(name,x,y)
    if not self.sim or self.sim.state.status~="running" then self:Notice(L["Start or resume a run first."]); return end
    local success,reason=self.sim:UseAbility(name,x,y)
    if success and (name=="blink" or name=="teleport" or name=="gateway") then self.renderer:ResetMotion() end
    if not success then self:Notice(EL.F("Ability unavailable: %s",abilityErrors[reason] or L["Check your player's state"]))
    else self:Notice(EL.F("%s Â· Practice ability",abilityNames[name] or name)) end
end

function UI:UseSelectedAbility()
    if not self.sim or self.sim.state.status~="running" or self.sim.state.player.dead then
        self:Notice(L["Abilities require a running session and a living player."]); return
    end
    local name=self.options.selectedAbility
    if name=="leap" then
        self.aiming=name; self:Notice(L["Left-click a landing point; Escape cancels."])
    else self:UseAbility(name) end
end

function UI:Update(elapsed)
    if InCombatLockdown() then self:Hide(L["Combat started"]); return end
    if self.selectingEncounter then return end
    local controls=self.input:Sample()
    local mouseFacingApplied=self.sim and controls.lockFacing and self.sim:SetPlayerFacing(controls.yaw) or false
    local state=self.sim and self.sim.state or self.preview
    if self.sim then
        local previousYaw=state.player.yaw
        local diagnostics=self.renderer.diagnostics
        self.loadingScene=not self.renderer.projectionValid or diagnostics.playerModel~="ready" or (state.scenario~="sentinels" and diagnostics.bossModel~="ready")
        if not self.loadingScene then
            controls.strafe=controls.strafe*(self.renderer.lateralInputSign or 1)
            self.sim:Advance(elapsed,controls)
        elseif state.elapsed>0 and state.status=="running" then
            state.interrupted=true
            self.sim:SetPaused(true)
            self.input:Clear()
        end
        if not self.input.buttons.LeftButton and not self.input.buttons.RightButton then
            self.camera.yaw=self.camera.yaw+(state.player.yaw-previousYaw)
        end
    end
    local alpha=1
    local player=state.player
    self.camera.targetX,self.camera.targetY=player.x,player.y
    self.camera.targetZ=1
    self.camera.renderYaw=self.camera.yaw
    self.camera.playerFacingYaw=nil
    if state.status=="running" and not player.dead and mouseFacingApplied then
        local offset=0
        if controls.strafe~=0 then
            offset=((player.displayYaw or player.yaw)-player.yaw+math.pi)%(2*math.pi)-math.pi
        end
        -- Use this frame's movement offset around the sampled RMB facing.
        -- After RMB release, remaining LMB orbit stays camera-only.
        self.camera.playerFacingYaw=controls.yaw+offset
    end
    self.renderer:Render(state,self.camera,alpha,elapsed)
    if self.input.trace then self.input:TraceFrame(elapsed,state) end
    if self.sim and (self.renderer.diagnostics.overflow or 0)>0 and not self.renderFailure then
        self.renderFailure=true
        state.interrupted=true
        self.sim:SetPaused(true)
        self.input:Clear()
        self:Notice(L["Rendering limit reached. Run paused and unranked; please report the diagnostics."])
    end
    self.hudElapsed=(self.hudElapsed or 0)+elapsed
    if self.hudElapsed<.1 then return end
    self.hudElapsed=0
    self.counterText:SetText(EL.F("%s Â· %d pools Â· %d waves",EL.FormatTime(state.time),#state.pools,#state.waves))
    local cast=state.frontal or state.slam
    if cast then
        local remaining=math.max(0,cast.ends-state.time)
        local duration=math.max(.01,cast.ends-cast.starts)
        self.castFill:SetWidth(math.max(1,(self.castFrame:GetWidth()-4)*EL.Clamp(remaining/duration,0,1)))
        self.castFill:SetColorTexture(state.frontal and .95 or .85,state.frontal and .13 or .34,.08,.85)
        self.castText:SetText(EL.F("%s Â· %.1f s",state.frontal and L["Frontal"] or L["Slam"],remaining))
        self.castFrame:Show()
    else self.castFrame:Hide() end
    if self.sim then
        local mode=(state.assisted or self.lastRunOptions.mode=="practice") and L["Practice / Assisted"] or L["Normal"]
        self.statusText:SetText(state.bonus and EL.F("Loop %d Â· %s Â· Bonus",self.lastRunOptions.loop,mode) or EL.F("Loop %d Â· %s",self.lastRunOptions.loop,mode))
        if self.loadingScene then
            self.centerText:SetText(L["Preparing 3D scene\nOpen Diagnostics if models do not appear"])
        elseif state.status=="finished" then
            if not self.recorded then self:Finish() end
        elseif state.status=="paused" then
            self.centerText:SetText(L["Paused\nPress Pause or close the menu to continue"])
        elseif state.player.dead then
            self.centerText:SetText(EL.F("Hit!\n[%s] Revive\n%s",self.input:BindingLabel("revive"),hitNames[state.lastHit] or ""))
        elseif state.frontal then
            self.centerText:SetText(L["Frontal - move out of its path"])
        else self.centerText:SetText("") end
        local readyAt=state.abilities.cooldowns[self.options.selectedAbility] or 0
        local cooldown=math.max(0,readyAt-state.time)
        local name=abilityNames[self.options.selectedAbility] or L["Blink"]
        self.abilityButton:SetText(cooldown>0 and EL.F("%s: %s (%ds)",self.input:BindingLabel("ability"),name,math.ceil(cooldown)) or EL.F("%s: %s",self.input:BindingLabel("ability"),name))
        if cast and state.status=="running" then
            self.statusText:SetText(state.frontal and L["Frontal - move out of its path"] or L["Slam - a lava pool is forming"])
        end
        if state.arenaExit then self.footerText:SetText(L["Outside the arena: this run is unranked. Restart for a ranked attempt."])
        else self.footerText:SetText(EL.F("Alive: %.1f%% Â· Hits: %d Â· Seed %d",state.elapsed>0 and state.aliveTime/state.elapsed*100 or 100,state.deaths or 0,self.lastRunOptions.seed)) end
    else
        self.statusText:SetText(self.options.scenario=="sszorak" and L["Sszorak - Tempest"] or L["Rashok Â· Lava waves"])
        self.centerText:SetText(L["Choose a loop and start training"])
        self.footerText:SetText(L["WoW movement bindings Â· Drag to look Â· Mouse wheel to zoom"])
    end
    if self.noticeUntil and GetTime()>self.noticeUntil then self.noticeText:SetText(""); self.noticeUntil=nil end
end


function UI:Finish()
    self.recorded=true; self.input:Clear()
    local result=self.sim:GetResult()
    result.version=self.sim.version or EL.SCENARIO_VERSION
    local record=EL.Store.RecordResult(result)
    self.lastRecord=record
    local percent=result.elapsed>0 and result.aliveTime/result.elapsed*100 or 0
    self.centerText:SetText(result.perfect and EL.F("%.1f%% survived\n%d hits Â· Perfect!",percent,result.deaths or 0) or EL.F("%.1f%% survived\n%d hits",percent,result.deaths or 0))
    local suffix=L["Saved to history; no leaderboard rank."]
    if record.rank then suffix=record.newBest and EL.F("Rank %d - Personal best!",record.rank) or EL.F("Rank %d",record.rank) end
    self:Notice(suffix)
end

function UI:RecordAbandoned()
    if not self.sim or self.recorded then return end
    local state=self.sim.state
    if state.status=="finished" then self:Finish(); return end
    if state.elapsed<=0 then return end
    local run=self.lastRunOptions
    EL.Store.RecordResult({completed=false,mode=run.mode,seed=run.seed,loop=run.loop,
        elapsed=state.elapsed,aliveTime=state.aliveTime,deadTime=state.deadTime,
        deaths=state.deaths,bonus=state.bonus,perfect=false,assisted=state.assisted,
        version=self.sim.version or EL.SCENARIO_VERSION,highscoreEligible=false,interrupted=true,
        arenaExit=state.arenaExit,speed=run.timeScale,hints=run.assist})
    self.recorded=true
end

function UI:Modal(title)
    if not self.modal or not self.modal:IsShown() then
        self.modalResume=self.sim and self.sim.state.status=="running" or false
    end
    if self.sim and self.sim.state.status=="running" then self.sim:SetPaused(true) end
    self.input:Clear()
    if not self.modal then
        self.modalBlocker=CreateFrame("Frame",nil,self.frame)
        self.modalBlocker:SetAllPoints(self.frame)
        self.modalBlocker:SetFrameLevel(self.input.frame:GetFrameLevel()+70)
        self.modalBlocker:EnableMouse(true)
        fill(self.modalBlocker,0,0,0,.45)
        self.modal=CreateFrame("Frame",nil,self.frame)
        self.modal:SetFrameLevel(self.input.frame:GetFrameLevel()+80)
        self.modal:EnableMouse(true)
        self.modal:SetSize(630,570)
        self.modal:SetScale(math.min(1,(UIParent:GetHeight()/self.frame:GetEffectiveScale()-32)/570))
        self.modal:SetPoint("CENTER")
        Theme.Panel(self.modal,Theme.colors.shell)
        self.modalTitle=at(label(self.modal,"",21),self.modal,22,18)
        self.modalClose=button(self.modal,"Close",100,26,function() self:CloseModal() end)
        self.modalClose:SetPoint("BOTTOMRIGHT",-18,16)
        self.modalBody=at(label(self.modal,"",12),self.modal,22,58)
        self.modalBody:SetWidth(586)
        self.modalBody:SetHeight(438)
        self.modalWidgets={}
    end
    for _,widget in ipairs(self.modalWidgets) do widget:Hide() end
    self.modalWidgets={}
    self.modal:SetSize(630,570)
    self.modalTitle:SetText(title)
    self.modalPage=nil
    self.modalBody:ClearAllPoints()
    self.modalBody:SetPoint("TOPLEFT",22,-58)
    self.modalBody:SetHeight(438)
    self.modalBody:SetText("")
    self.modalBody:Show()
    self.modalBlocker:Show()
    self.modal:Show()
    self.input:Acquire()
    return self.modal
end

function UI:ModalButton(text,x,y,width,callback)
    -- Modal controls are created only when opening menus, never in the frame loop.
    -- Reuse a small pool across all modal pages.
    self.modalPool=self.modalPool or {}
    local index=#self.modalWidgets+1
    local b=self.modalPool[index]
    if not b then b=button(self.modal,"",width,28,callback); self.modalPool[index]=b end
    b:ClearAllPoints(); b:SetSize(width,28)
    b:SetText(text); b:Selected(false); b:SetScript("OnClick",callback); at(b,self.modal,x,y); b:Show()
    self.modalWidgets[index]=b
    return b
end

function UI:CloseModal()
    if self.selectingEncounter then self:Hide();return end
    if self.modal then self.modal:Hide() end
    if self.modalBlocker then self.modalBlocker:Hide() end
    self.input.bindAction=nil
    self.input:Clear()
    if self.modalResume and self.sim and self.sim.state.status=="paused" and not InCombatLockdown() then
        if self:IsGameplayInputAllowed() then
            self.sim:SetPaused(false)
            self.input:Acquire()
        else
            self.menuResume=true
        end
    end
    self.modalResume=nil
end

function UI:ShowHelp()
    self:Modal(L["How to practice"])
    self.modalBody:SetText(L["Movement uses your WoW keyboard bindings by default. Standard keys: W/S forward/back, A/D turn, Q/E strafe, Space jump. Right mouse turns your character and changes turn keys to strafe. Left mouse rotates only the camera; both mouse buttons run forward. Scroll to zoom."].."\n\n"..
        L["Escape opens or closes the training menu. F11 switches between fullscreen and windowed mode. Change bindings in Controls; your WoW bindings are never modified."].."\n\n"..
        L["A hit kills the practice player. Time keeps running; Revive lets you continue the same sequence. Jumping does not avoid horizontal lava collisions."].."\n\n"..
        L["Normal runs at 100% speed. Practice settings, pauses and movement abilities have separate leaderboards. Stay inside the gold 75-yard boundary to rank."].."\n\n"..
        L["Scores stay on this WoW account. A daily seed gives a repeatable sequence. Combat and zone changes close training."])
end

function UI:ShowAbilities()
    self:Modal(L["Movement abilities"])
    self.modalBody:SetText(EL.F("Choose an ability for [%s] or the middle mouse button. These practice abilities use separate scores.",self.input:BindingLabel("ability")))
    self.modalBody:SetHeight(60)
    for i,name in ipairs(abilityOrder) do
        local id=name
        local b=self:ModalButton(abilityNames[name],22+((i-1)%3)*198,123+math.floor((i-1)/3)*37,188,function()
            self.options.selectedAbility=id; self:SaveOptions(); self:ShowAbilities()
        end)
        b:Selected(self.options.selectedAbility==name)
    end
    self:ModalButton(L["Place teleport point"],22,260,286,function() self:CloseModal(); self:SetMenuVisible(false); self:UseAbility("teleport_set") end)
    self:ModalButton(L["Place gateway"],320,260,288,function() self:CloseModal(); self:SetMenuVisible(false); self:UseAbility("gateway_set") end)
    self:ModalButton(L["Return to arena"],22,307,586,function() self:CloseModal(); self:SetMenuVisible(false) end)
end

function UI:ShowSettings()
    self:Modal(L["Controls"])
    self.modalPage="settings"
    self.modalBody:SetText(L["Use your WoW movement keys, or choose custom bindings. Click a binding to change it. Escape and F11 are reserved."])
    self.modalBody:SetHeight(45)
    local native=self:ModalButton(L["WoW bindings"],22,110,286,function()
        self.options.bindingPreset="wow"; self:SaveOptions(); self.input:RefreshBindings(); self:ShowSettings()
    end)
    local custom=self:ModalButton(L["Custom bindings"],320,110,288,function()
        self.options.bindingPreset="custom"; self:SaveOptions(); self.input:RefreshBindings(); self:ShowSettings()
    end)
    native:Selected(self.options.bindingPreset=="wow"); custom:Selected(self.options.bindingPreset=="custom")
    for i,action in ipairs(bindingOrder) do
        local bind=action
        self:ModalButton(EL.F("%s: %s",bindingLabels[action],self.input:BindingLabel(action)),22+((i-1)%2)*298,154+math.floor((i-1)/2)*34,286,function() self.input:BeginBinding(bind) end)
    end
    self:ModalButton(EL.F("WoW camera speed: %.0f%%",self.options.mouseSensitivity/.006*100),22,374,286,function()
        local levels={.003,.0045,.006,.0075,.009}
        local nextLevel=levels[1]
        for _,v in ipairs(levels) do if v>self.options.mouseSensitivity+.0001 then nextLevel=v; break end end
        self.options.mouseSensitivity=nextLevel; self:SaveOptions(); self:ShowSettings()
    end)
    self:ModalButton(self.options.invertY and L["Invert Y: on"] or L["Invert Y: off"],320,374,288,function() self.options.invertY=not self.options.invertY; self:SaveOptions(); self:ShowSettings() end)
    self:ModalButton(L["Reset custom bindings"],22,417,286,function() self.options.bindings=EL.Input.DEFAULT_BINDINGS; self.options.bindingPreset="custom"; self:SaveOptions(); self:ShowSettings() end)
    self:ModalButton(L["Diagnostics"],320,417,288,function() self:ShowDiagnostics() end)
    self:ModalButton(self.options.fullscreen and L["Windowed mode [F11]"] or L["Fullscreen [F11]"],22,459,586,function() self:ToggleFullscreen(); self:ShowSettings() end)
end

function UI:ShowScores(filter)
    self.boardFilter=filter or self.boardFilter or "reference"
    self:Modal(self.options.scenario=="sszorak" and EL.F("Highscores: %s",self:SelectedDrillName()) or EL.F("Highscores Â· Loop %d",self.options.loop))
    self.modalBody:ClearAllPoints(); self.modalBody:SetPoint("TOPLEFT",22,-118); self.modalBody:SetHeight(370)
    local seedFilter=self.boardSeedOnly and tonumber(self.seedBox:GetText()) or nil
    local entries=EL.Store.GetBoard(self.boardFilter,self.options.scenario=="sszorak" and 1 or self.options.loop,seedFilter,self.options.scenario=="sszorak" and EL.Sszorak.Version(self.options) or EL.SCENARIO_VERSION)
    local lines={}
    for i,entry in ipairs(entries) do
        lines[#lines+1]=EL.F("%d.  %.2f%% alive Â· %d hits Â· %d points Â· Seed %d",i,entry.survivalPercent or 0,entry.deaths or 0,entry.score or 0,entry.seed or 0)
    end
    if #entries==0 then lines[1]=L["No completed ranked runs yet."] end
    lines[#lines+1]="\n"..L["Ranked by survival, perfect bonus, then dead time and hits. Interrupted runs and arena exits appear in history only."]
    self.modalBody:SetText(table.concat(lines,"\n\n"))
    local filters={{"reference",L["Normal"]},{"practice",L["Practice"]},{"assisted",L["Assisted"]}}
    for i,pair in ipairs(filters) do
        local id=pair[1]
        local b=self:ModalButton(pair[2],22+(i-1)*198,65,188,function() self:ShowScores(id) end)
        b:Selected(id==self.boardFilter)
    end
    self:ModalButton(L["Recent runs"],22,524,174,function() self:ShowHistory() end)
    self:ModalButton(self.boardSeedOnly and L["This seed"] or L["All seeds"],206,524,174,function() self.boardSeedOnly=not self.boardSeedOnly; self:ShowScores() end)
end

function UI:ShowHistory()
    self:Modal(L["Recent runs"])
    local history=EL.Store.GetHistory()
    local stats=EL.Store.GetStats()
    local lines={EL.F("%d attempts Â· %d completed Â· %d perfect",stats.attempts,stats.completed,stats.perfect)}
    local modeNames={reference=L["Normal"],practice=L["Practice"],assisted=L["Assisted"]}
    for i=1,math.min(10,#history) do
        local e=history[i]
        local text=EL.F("Loop %d Â· %.1f%% Â· %d hits Â· Seed %d Â· %s",e.loop,e.survivalPercent or 0,e.deaths,e.seed,modeNames[e.mode] or "")
        if e.version and e.version:match("^sentinels%-") then text=EL.F("Sentinels / %.2f s / Seed %d",e.matchTime or 0,e.seed) end
        if e.version and e.version:match("^sszorak%-") then text=EL.F("%s: %s",self:VersionName(e.version),text)
        else text=EL.F("%s: %s",L["Rashok"],text) end
        lines[#lines+1]=e.interrupted and EL.F("%s Â· Interrupted",text) or text
    end
    if #history==0 then lines[#lines+1]=L["No runs saved yet."] end
    self.modalBody:SetText(table.concat(lines,"\n\n"))
end

function UI:ShowDiagnostics()
    self:Modal(EL.F("Diagnostics Â· %s",EL.VERSION))
    local d=self.renderer:GetDiagnostics()
    local lines={L["Target: WoW 12.1 / Interface 120100"],EL.F("Scenario: %s",EL.SCENARIO_VERSION)}
    local names={playerModel=L["Player model"],bossModel=L["Boss model"],bossDisplayID=L["Boss display ID"],projection=L["Projection"],waves=L["Active waves"],waveCapacity=L["Wave capacity"],overflow=L["Overflow"],nativeActors=L["Native actors"],nativeFloor=L["Native terrain"],nativePools=L["Loaded pool models"],nativeWaves=L["Loaded wave models"]}
    local states={["ready"]=L["Ready"],["loading"]=L["Loading"],["not loaded"]=L["Not loaded"],["unresolved"]=L["Unresolved"],["calibrated"]=L["Calibrated"],["native projection unavailable"]=L["Native projection unavailable"],["degenerate projection"]=L["Invalid projection"]}
    local order={"playerModel","bossModel","bossDisplayID","projection","nativeFloor","nativePools","nativeWaves","waves","waveCapacity","overflow","nativeActors"}
    for _,key in ipairs(order) do
        local value=d[key]
        if key=="nativeFloor" then value=value and L["Ready"] or L["Fallback"] end
        if value~=nil then lines[#lines+1]=EL.F("%s: %s",names[key],states[value] or tostring(value)) end
    end
    lines[#lines+1]="\n"..L["Models come from the installed WoW client. Camera, hit areas and mouse behavior still need to be checked in game."]
    self.modalBody:SetText(table.concat(lines,"\n"))
end
