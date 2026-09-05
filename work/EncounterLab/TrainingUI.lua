local _,EL=...
local UI,L=EL.UI,EL.L
local names={tempest=L["Tempest"],wind=L["Wind"],combined=L["Combined"]}
local checkpoints={L["Preparation"],L["Wind 1"],L["Wind 2"],L["Wind 3"]}
local volleys={L["Start"],L["Middle"],L["Final"]}
local reasons={
    ["Tempest tornado"]=L["Tempest tornado"],
    ["Fell off the platform"]=L["Fell off the platform"],
}
function UI:SelectedDrillName()
    return EL.F("Sszorak / %s / %s",L["Tempest"],volleys[self.options.sszorakCheckpoint])
end
function UI:VersionName(version)
    local drill,index=version:match("^sszorak%-%d+%-(%a+)%-(%d+)$")
    if not drill then return L["Sszorak"] end
    local c=drill=="tempest" and volleys or checkpoints
    return EL.F("Sszorak / %s / %s",names[drill] or drill,c[tonumber(index)] or "")
end
function UI:SelectDrill(index)
    if self.options.scenario=="sszorak" then
        self.options.sszorakDrill="tempest";self.options.sszorakCheckpoint=index
    else self.options.loop=index end
    self:SaveOptions()
end
local updateControls=UI.UpdateControls
function UI:UpdateControls()
    updateControls(self)
    if not self.encounterButton then return end
    local wind=self.options.scenario=="sszorak"
    self.encounterButton:SetText(wind and L["Sszorak"] or L["Rashok"])
    self.encounterSubtitle:SetText(wind and L["Tempest - tornado dodging"] or L["Lava waves"])
    self.encounterSubtitle:SetWidth(216)
    self.drillLabel:SetText(wind and L["Starting point"] or L["Starting loop"])
    for i=1,3 do
        self.loopButtons[i]:SetText(wind and volleys[i] or EL.F("Loop %d",i))
        self.loopButtons[i]:Selected(wind and self.options.sszorakCheckpoint==i or not wind and self.options.loop==i)
    end
    if self.drillOptionsButton then
        self.drillOptionsButton:SetShown(wind)
        self.highscoresButton:SetSize(wind and 105 or 216,26)
    end
end
function UI:SelectEncounter(id)
    id=(id=="sszorak" or id=="sentinels") and id or "rashok"
    if self.sim and (self.sim.state.scenario or "rashok")~=id then
        self:RecordAbandoned();self.sim:Destroy();self.sim=nil;self.rehearsal=nil
        self.lastRunOptions=nil;self.recorded=false
    end
    self.options.scenario=id
    self.selectingEncounter=false
    self.menuVisible=true
    self:SaveOptions();self:CloseModal();self:ApplyLayout()
    self.renderer:SetEncounter(id)
    self.preview.scenario=id
    self.preview.arenaRadius=id=="sszorak" and 42 or nil
    self.preview.tornadoes={}
    self.preview.raiders=nil
    if id=="sentinels" then self.preview.arenaRadius=40 end
    local p=self.preview.player
    p.x,p.y,p.yaw=id=="sszorak" and 0 or 24.32,id=="sszorak" and -8 or 14.44,id=="sszorak" and math.pi/2 or -math.pi*5/6
    self.camera.yaw,self.camera.pitch,self.camera.distance=p.yaw,math.pi*.075,60
    self.renderer:ResetMotion()
    self.input:Acquire()
end
function UI:ShowEncounters()
    self:EndReplay()
    self.selectingEncounter=true
    self:ApplyLayout()
    self:Modal(L["Encounters"])
    self.modal:SetHeight(375);self.modalBody:SetHeight(120)
    self.modalBody:SetText(L["Choose an encounter. Its drills and settings appear in the training menu.\n\nRashok: lava waves and frontals.\nSszorak: dodge moving Tempest tornadoes.\nSentinels: Mythic toxin pairing."])
    self:ModalButton(L["Rashok"],22,200,586,function() self:SelectEncounter("rashok") end):Selected(self.options.scenario=="rashok")
    self:ModalButton(L["Sszorak"],22,242,586,function() self:SelectEncounter("sszorak") end):Selected(self.options.scenario=="sszorak")
    self:ModalButton(L["Entombed Sentinels - Mythic"],22,284,586,function() self:SelectEncounter("sentinels") end):Selected(self.options.scenario=="sentinels")
end
function UI:ShowTrainingTools()
    self:Modal(L["Sszorak - Tempest"])
    self.modalBody:SetText(L["Dodge the moving tornadoes while keeping Sszorak in view.\n\nChoose a starting point below. Each starting point has its own local leaderboard.\n\nA tornado hit ends the clean attempt. Revive to continue, review the mistake in replay or retry the latest checkpoint. Checkpoint retries are unranked."])
    for i,text in ipairs(volleys) do
        local index=i
        local b=self:ModalButton(text,22+(i-1)*198,260,188,function() self.options.sszorakCheckpoint=index;self:SaveOptions();self:ShowTrainingTools() end)
        b:Selected(i==self.options.sszorakCheckpoint)
    end
    self:ModalButton(L["Start training"],22,310,286,function() self.options.scenario="sszorak";self:SaveOptions();self:Start() end)
    self:ModalButton(L["Retry checkpoint"],320,310,286,function() self:RetryCheckpoint() end)
    self:ModalButton(L["Mistake replay"],22,350,286,function() self:BeginReplay() end)
    self:ModalButton(L["About this drill"],320,350,286,function()
        self:Modal(L["About this drill"])
        self.modalBody:SetText(L["Tempest-only solo practice with native WoW models.\n\nContact counts as a failed dodge; raid health, damage and stacking slows are not simulated.\n\nSszorak uses his actual boss model and Tempest cast effect. A native whirlwind represents each tornado. Paths and collision sizes are training values awaiting live calibration."])
    end)
end
local new=UI.New
function UI.New()
    local self=new()
    self.drillOptionsButton=UI.CreateButton(self.side,L["Drill options"],105,26,function() self:ShowTrainingTools() end)
    self.drillOptionsButton:SetPoint("TOPLEFT",self.side,"TOPLEFT",123,-424)
    self:UpdateControls()
    local function control(text,width,x,callback)
        local b=UI.CreateButton(self.bottom,text,width,26,callback)
        b:SetFrameLevel(self.bottom:GetFrameLevel()+1)
        b:SetPoint("BOTTOMLEFT",self.bottom,"TOPLEFT",x,6)
        return b
    end
    self.trainingButton=control(L["Encounters"],172,0,function() self:ShowEncounters() end)
    self.checkpointButton=control(L["Retry checkpoint"],172,178,function() self:RetryCheckpoint() end)
    self.replayButton=control(L["Mistake replay"],172,356,function() self:BeginReplay() end)
    self.replayBar=CreateFrame("Frame",nil,self.bottom)
    self.replayBar:SetSize(728,38);self.replayBar:SetPoint("BOTTOMLEFT",self.bottom,"TOPLEFT",0,6)
    self.replayBar:SetFrameLevel(self.bottom:GetFrameLevel()+5);EL.Theme.Panel(self.replayBar,EL.Theme.colors.shell)
    local function replayButton(text,x,w,callback)
        local b=UI.CreateButton(self.replayBar,text,w,26,callback);b:SetPoint("TOPLEFT",x,-6);return b
    end
    self.replayPlay=replayButton(L["Pause"],6,106,function() self.replayPlaying=not self.replayPlaying end)
    replayButton(L["-1 second"],118,90,function() self:SeekReplay(-1) end)
    replayButton(L["+1 second"],214,90,function() self:SeekReplay(1) end)
    self.replaySpeedButton=replayButton(L["Speed: 50%"],310,116,function()
        self.replaySpeed=self.replaySpeed==.5 and .25 or self.replaySpeed==.25 and 1 or .5
        self.replaySpeedButton:SetText(EL.F("Speed: %d%%",self.replaySpeed*100))
    end)
    replayButton(L["Return to training"],432,144,function() self:EndReplay() end)
    replayButton(L["Retry checkpoint"],582,140,function() self:RetryCheckpoint() end)
    self.replayBar:Hide();self.checkpointButton:Hide();self.replayButton:Hide()
    self.noticeText:ClearAllPoints()
    self.noticeText:SetPoint("BOTTOMLEFT",self.overlay,"BOTTOMLEFT",16,140)
    self.noticeText:SetPoint("BOTTOMRIGHT",self.overlay,"BOTTOMRIGHT",-16,140)
    return self
end
function UI:RetryCheckpoint()
    if InCombatLockdown() then self:Hide(L["Combat started"]);return end
    if not self.rehearsal then self:Notice(L["Start a Sszorak drill first."]);return end
    self:EndReplay();self:CloseModal()
    local nextSim=self.rehearsal:Retry()
    if not nextSim then return end
    self:RecordAbandoned();self.sim:Destroy();self.sim=nextSim;self.recorded=false
    self.rehearsal=EL.Rehearsal.New(nextSim)
    self.renderer:ResetMotion();self.input:Clear();self.menuResume=nil
    self:SetMenuVisible(false);self.input:Acquire()
    self:Notice(L["Checkpoint restored. This attempt is unranked."])
end
function UI:BeginReplay()
    if not self.rehearsal or not self.rehearsal.frozen then self:Notice(L["Replay becomes available after a mistake."]);return end
    if self.replay then return end
    self:CloseModal();self:SetMenuVisible(false)
    self.replayResume=self.sim.state.status=="running"
    if self.replayResume then self.sim:SetPaused(true) end
    self.savedReplayCamera=EL.Rehearsal.Copy(self.camera)
    self.replay=true;self.replayTime=self.rehearsal:Bounds();self.replaySpeed=.5;self.replayPlaying=true
    self.renderer.replayTrail=self.rehearsal;self.renderer:ResetMotion()
    self.aiming=nil;self.input:Clear();self.input:Acquire();self.replayBar:Show()
    self.replaySpeedButton:SetText(EL.F("Speed: %d%%",50))
end
function UI:EndReplay()
    if not self.replay then return end
    self.replay=nil;self.renderer.replayTrail=nil
    if self.savedReplayCamera then self.camera=EL.Rehearsal.Copy(self.savedReplayCamera,self.camera) end
    self.savedReplayCamera=nil
    if self.replayResume and self.sim and self.sim.state.status=="paused" then
        if self.modal and self.modal:IsShown() then self.modalResume=true
        elseif self.options.fullscreen and self.menuVisible then self.menuResume=true
        else self.sim:SetPaused(false) end
    end
    self.replayResume=nil;self.replayBar:Hide();self.renderer:ResetMotion();self.input:Clear()
end
function UI:SeekReplay(delta)
    if not self.replay then return end
    local lo,hi=self.rehearsal:Bounds()
    self.replayTime=EL.Clamp(self.replayTime+delta,lo,hi)
    self.renderer:ResetMotion()
end
local update=UI.Update
function UI:Update(elapsed)
    if self.selectingEncounter then
        if InCombatLockdown() then self:Hide(L["Combat started"]) end
        return
    end
    if self.replay then
        if InCombatLockdown() then self:Hide(L["Combat started"]);return end
        self.input:Sample()
        local lo,hi=self.rehearsal:Bounds()
        if self.replayPlaying and self:IsGameplayInputAllowed() and not (self.modal and self.modal:IsShown()) then
            self.replayTime=math.min(hi,self.replayTime+math.min(elapsed,.5)*self.replaySpeed)
            if self.replayTime>=hi then self.replayPlaying=false end
        end
        local s=self.rehearsal:Sample(self.replayTime)
        s.playbackSpeed=self.replayPlaying and self.replaySpeed or 0
        self.camera.targetX,self.camera.targetY,self.camera.targetZ=s.player.x,s.player.y,1
        self.camera.renderYaw,self.camera.playerFacingYaw=self.camera.yaw,nil
        self.renderer:Render(s,self.camera,1,elapsed)
        self.statusText:SetText(L["Mistake replay"])
        self.counterText:SetText(EL.F("Replay %.1f / %.1f s",self.replayTime-lo,hi-lo))
        self.centerText:SetText("");self.castFrame:Hide()
        self.footerText:SetText(reasons[self.rehearsal.failure.reason] or L["Mistake replay"])
        self.replayPlay:SetText(self.replayPlaying and L["Pause"] or L["Play"])
        return
    end
    update(self,elapsed)
    if self.rehearsal then self.rehearsal:Capture(self.sim) end
    local training=self.rehearsal~=nil
    if self.checkpointButton and self.trainingControlsShown~=training then
        self.trainingControlsShown=training
        self.checkpointButton:SetShown(self.rehearsal~=nil)
        self.replayButton:SetShown(self.rehearsal~=nil)
    end
    self.trainingHudElapsed=(self.trainingHudElapsed or 0)+elapsed
    if self.trainingHudElapsed<.1 then return end
    self.trainingHudElapsed=0
    local s=self.sim and self.sim.state
    if s and s.scenario=="sszorak" then
        self.statusText:SetText(EL.F("Sszorak / %s / %s",names[s.drill],L[s.phase]))
        local active=0
        for _,h in ipairs(s.tornadoes) do if h.active then active=active+1 end end
        self.counterText:SetText(EL.F("%s / %d tornadoes / %.1f s",EL.FormatTime(s.time),active,math.max(0,s.phaseEnds-s.time)))
        if s.player.dead and s.status=="running" then
            self.centerText:SetText(EL.F("Hit!\n[%s] Revive\n%s",self.input:BindingLabel("revive"),reasons[s.lastHit] or ""))
        elseif s.status=="running" and not self.loadingScene then
            self.centerText:SetText("")
        end
    end
end
local start,pause,revive,escape,hide,help=UI.Start,UI.TogglePause,UI.Revive,UI.HandleEscape,UI.OnHide,UI.ShowHelp
function UI:Start(repeatRun)
    self:EndReplay();start(self,repeatRun)
    if self.rehearsal then self:Notice(L["Use Drill options for checkpoints and instructions."]) end
end
function UI:TogglePause()
    if self.replay then self.replayPlaying=not self.replayPlaying else pause(self) end
end
function UI:Revive()
    if self.replay then return end
    local wasDead=self.sim and self.sim.state.player.dead
    revive(self)
    if self.rehearsal and wasDead and not self.sim.state.player.dead then
        self.rehearsal:ResetBuffer();self:Notice(L["Revived at the center. Watch the active mechanics."])
    end
end
function UI:HandleEscape() if self.replay and not (self.modal and self.modal:IsShown()) then self:EndReplay() else escape(self) end end
function UI:OnHide() self:EndReplay();hide(self) end
function UI:ShowHelp() if self.options.scenario=="sszorak" then self:ShowTrainingTools() else help(self) end end
local ability,selected=UI.UseAbility,UI.UseSelectedAbility
function UI:UseAbility(...) if not self.replay then return ability(self,...) end end
function UI:UseSelectedAbility(...) if not self.replay then return selected(self,...) end end
