local _,EL=...
local UI,L=EL.UI,EL.L
local function selected(self) return self.options.scenario=="twinfangs" end
local function active(self) return self.sim and self.sim.state.scenario=="twinfangs" end
local controls=UI.UpdateControls
function UI:UpdateControls()
    controls(self)
    if self.fangsLabel then self.fangsLabel:SetShown(selected(self)) end
    if not selected(self) or not self.encounterButton then return end
    self.encounterButton:SetText(L["The Twin Fangs"])
    self.encounterSubtitle:SetText(L["Heroic - Flood and Storm"])
    self.drillLabel:SetText(L["Intermission dodge practice"])
    for _,b in ipairs(self.loopButtons) do b:Hide() end
    if self.drillOptionsButton then self.drillOptionsButton:Show();self.highscoresButton:SetSize(105,26) end
end
local new=UI.New
function UI.New()
    local self=new()
    self.fangsLabel=self.side:CreateFontString(nil,"OVERLAY")
    EL.Theme.Font(self.fangsLabel,13,false)
    self.fangsLabel:SetPoint("TOPLEFT",12,-101);self.fangsLabel:SetWidth(216)
    self.fangsLabel:SetJustifyH("LEFT")
    self.fangsLabel:SetText(L["Read the sweep. Dodge the impacts."])
    self:UpdateControls()
    return self
end
local selectEncounter=UI.SelectEncounter
function UI:SelectEncounter(id)
    selectEncounter(self,id)
    if not selected(self) then return end
    local s,p=self.preview,self.preview.player
    s.arenaRadius=EL.TwinFangs.arenaRadius
    s.beamYaw,s.beamStart,s.direction=0,0,1
    s.ithraz={x=0,y=36,z=0,yaw=-math.pi/2}
    s.boss.x,s.boss.y,s.boss.z,s.boss.radius=0,0,0,4
    p.x,p.y,p.yaw,p.displayYaw=0,-24,math.pi/2,math.pi/2
    p.previousX,p.previousY,p.previousYaw,p.previousDisplayYaw=p.x,p.y,p.yaw,p.displayYaw
    self.camera.yaw,self.camera.pitch,self.camera.distance=p.yaw,math.pi*.075,60
    self.renderer:ResetMotion()
    self.fangsSeedPresented=self.seedBox:GetText()
end
local drill=UI.SelectDrill
function UI:SelectDrill(index) if not selected(self) then drill(self,index) end end
function UI:ShowTwinFangsHelp()
    self:Modal(L["Twin Fangs - Heroic"])
    self.modalBody:SetHeight(344)
    self.modalBody:SetText(L["Watch the green orbs around Vexhul: they show the sweep direction. The green sector warns where Vile Flood will start. It becomes dangerous after the 4-second cast and sweeps for 14 seconds. Move into the area the beam has already passed.\n\nRed circles warn before Sanguine Storm lands. Leave their 4-yard footprint before the inner ring disappears. The remaining blood pools stay dangerous for 6 seconds. Keep dodging while watching Vexhul.\n\nAny beam, impact or pool contact fails the clean dodge attempt. This is a strict practice rule: raid health, healing and Eternal Venom stacks are not simulated. Revive to continue or use Mistake replay and Retry checkpoint to review and repeat.\n\nNormal and Practice have separate local boards. Pausing, slowing down, reviving and checkpoint retries count as assistance."])
    self:ModalButton(L["Start training"],22,420,286,function() self:Start() end)
    self:ModalButton(L["About this drill"],320,420,286,function()
        self:Modal(L["About this drill"])
        self.modalBody:SetText(L["Heroic intermission practice with Vexhul and Ithraz's native boss models and the native Vile Flood effect. A client blood effect represents Congealed Gore.\n\nDocumented spell values: 4-second Flood cast, 14-second channel, 18-second Storm, 4-yard impacts and 6-second blood pools.\n\nThe 42-yard practice platform, 12-degree beam, 270-degree sweep, 1.5-second warnings, four impacts per volley, player baiting and randomized start/direction are training parameters awaiting live calibration. The room is an open stone approximation. Submerge, main-phase abilities and raid damage are outside this drill.\n\nThe same seed and movement reproduce the attempt. The last 6 seconds of a mistake can be replayed without affecting your live session."])
    end)
end
local help,training=UI.ShowHelp,UI.ShowTrainingTools
function UI:ShowHelp() if selected(self) then self:ShowTwinFangsHelp() else help(self) end end
function UI:ShowTrainingTools() if selected(self) then self:ShowTwinFangsHelp() else training(self) end end
local start=UI.Start
function UI:Start(repeatRun)
    if selected(self) and not repeatRun and not self.selectingEncounter and not InCombatLockdown() then
        if not self.fangsSeedPresented or self.seedBox:GetText()==self.fangsSeedPresented then
            self.fangsRandomSeed=((self.fangsRandomSeed or time()+math.floor(GetTime()*1000))*48271)%2147483647
            self.seedBox:SetText(tostring(math.max(1,self.fangsRandomSeed)))
        end
    end
    start(self,repeatRun)
    if active(self) then
        self.fangsSeedPresented=self.seedBox:GetText()
        self:Notice(L["Watch the orbiting green markers, then dodge the beam and red impacts."])
    end
end
local revive=UI.Revive
function UI:Revive()
    local wasDead=active(self) and self.sim.state.player.dead
    revive(self)
    if wasDead and not self.sim.state.player.dead then self:Notice(L["Revived behind the beam. This attempt is assisted."]) end
end
local update=UI.Update
function UI:Update(elapsed)
    update(self,elapsed)
    if not selected(self) or self.selectingEncounter or self.replay then return end
    self.fangsHudElapsed=(self.fangsHudElapsed or 0)+elapsed
    if self.fangsHudElapsed<.1 then return end
    self.fangsHudElapsed=0
    self.statusText:SetText(L["Twin Fangs - Heroic"])
    local s=self.sim and self.sim.state
    if not s then
        self.counterText:SetText("");self.centerText:SetText(L["Start training to rehearse the intermission"])
        return
    end
    self.counterText:SetText(EL.F("%s / %.1f s",L[s.phase],math.max(0,s.phaseEnds-s.time)))
    self.castFrame:Hide()
    if s.status=="running" and not self.loadingScene then
        if s.player.dead then self.centerText:SetText(EL.F("Dodge failed: %s\n[%s] Revive",L[s.lastHit],self.input:BindingLabel("revive")))
        elseif s.time<4 then self.centerText:SetText(L["Read the rotation - the green sector is a warning"])
        else self.centerText:SetText("") end
    end
end
