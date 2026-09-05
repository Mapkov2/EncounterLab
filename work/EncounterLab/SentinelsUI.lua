local _,EL=...
local UI,L=EL.UI,EL.L
local function selected(self) return self.options.scenario=="sentinels" end
local function active(self) return self.sim and self.sim.state.scenario=="sentinels" end
local controls=UI.UpdateControls
function UI:UpdateControls()
    controls(self)
    for i=1,3 do self.loopButtons[i]:SetShown(not selected(self)) end
    if self.randomNumberLabel then self.randomNumberLabel:SetShown(selected(self)) end
    if self.sentinelsPingButton then self.sentinelsPingButton:SetShown(selected(self)) end
    if self.abilityButton then self.abilityButton:SetShown(not selected(self)) end
    if not selected(self) or not self.encounterButton then return end
    self.encounterButton:SetText(L["Entombed Sentinels"])
    self.encounterSubtitle:SetText(L["Mythic - Helical Toxins"])
    self.drillLabel:SetText(L["Your number is drawn each attempt"])
    if self.drillOptionsButton then self.drillOptionsButton:Show();self.highscoresButton:SetSize(105,26) end
    if self.abilityButton and self.input then self.abilityButton:SetText(EL.F("Ping yourself [%s]",self.input:BindingLabel("ability"))) end
end
local new=UI.New
function UI.New()
    local self=new()
    self.randomNumberLabel=self.side:CreateFontString(nil,"OVERLAY")
    self.randomNumberLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",14,"OUTLINE")
    self.randomNumberLabel:SetPoint("TOPLEFT",12,-101)
    self.randomNumberLabel:SetText(L["Random: 1, 2 or 3"])
    self.sentinelsPingButton=UI.CreateButton(self.bottom,L["PING YOURSELF"],172,26,function() self:PingSentinels() end)
    self.sentinelsPingButton:SetPoint("TOPLEFT",self.bottom,"TOPLEFT",346,-9)
    self:UpdateControls()
    return self
end
local selectEncounter=UI.SelectEncounter
function UI:SelectEncounter(id)
    selectEncounter(self,id)
    if selected(self) then self.sentinelsSeedPresented=self.seedBox:GetText() end
end
local drill=UI.SelectDrill
function UI:SelectDrill(index)
    if not selected(self) then drill(self,index) end
end
local tools,help=UI.ShowTrainingTools,UI.ShowHelp
local abilities=UI.ShowAbilities
function UI:ShowAbilities()
    if selected(self) then self:ShowSentinelsHelp() else abilities(self) end
end
function UI:ShowSentinelsHelp()
    self:Modal(L["Sentinels - Mythic intermission"])
    self.modalBody:SetText(L["Your number (1, 2 or 3) and starting camp are drawn each attempt. Both bosses run to the center when Helical Toxins appears. Count your green orbs when Helical Toxins appears. Each player has four orbs; the rest are red. Other players' orbs are shrouded shortly afterwards.\n\n3: go around the center to a pinging 1 from either camp and touch them. Keep the middle clear for the 2s.\n2: move to the center between the bosses and touch another 2.\n1: ping yourself and keep jumping. A 3 comes to you. You must manually ping and jump after the reveal, before contact. Missing either action fails the attempt.\n\nOnly 2+2, 3+1 and 1+3 clear both players. Every other active contact immediately wipes the raid. Unresolved toxins expire after 30 seconds.\n\nClick the dedicated PING YOURSELF button when you have 1. The practice-ability key does not ping. Pings and square speech bubbles are simulated inside the arena."])
    self:ModalButton(L["Start training"],22,390,286,function() self:Start() end)
    self:ModalButton(L["About this drill"],320,390,286,function()
        self:Modal(L["About this drill"])
        self.modalBody:SetText(L["Two camps of 10 start at separate bosses, with shuffled positions, number counts and reactions. The bosses move to the center during the reveal. All 2s meet there; 1s ping and jump and 3s seek them across both camps. Visible 1+3 pairs can clear after the 1 pings. A simulated 3 waits for your manual ping if you have 1.\n\nThe addition and concealment rules follow the encounter. The 10/10 split, shuffled numbers across both camps, spawn positions, bot reactions, contact size and the default 2-second reveal are training values awaiting live calibration. Room scenery is a native model approximation. The main phase, raid damage and healing are not simulated.\n\nNormal always uses a 2-second reveal. Practice can change it below. Successful full-raid clears are ranked by your matching time, on a separate random-role board for each reveal duration."])
        self:ModalButton(EL.F("Practice reveal: %d s",self.options.sentinelsReveal),22,390,286,function()
            self.options.sentinelsReveal=self.options.sentinelsReveal%5+1;self:SaveOptions();self:ShowSentinelsHelp()
        end)
    end)
end
function UI:ShowTrainingTools() if selected(self) then self:ShowSentinelsHelp() else tools(self) end end
function UI:ShowHelp() if selected(self) then self:ShowSentinelsHelp() else help(self) end end
local ability,use=UI.UseSelectedAbility,UI.UseAbility
function UI:PingSentinels()
    if active(self) and not self.sim:Ping() then self:Notice(L["Ping when your active number is 1."]) end
end
function UI:UseSelectedAbility()
    if active(self) then
        self:Notice(L["Click PING YOURSELF to announce your 1."])
    else ability(self) end
end
function UI:UseAbility(name,x,y)
    if active(self) then self:UseSelectedAbility() else use(self,name,x,y) end
end
local revive=UI.Revive
function UI:Revive()
    if active(self) then self:Start() else revive(self) end
end
local start=UI.Start
function UI:Start(repeatRun)
    if selected(self) and not self.selectingEncounter and not InCombatLockdown() then
        self.options.sentinelsNumber=0
        if not repeatRun and (not self.sentinelsSeedPresented or self.seedBox:GetText()==self.sentinelsSeedPresented) then
            self.sentinelsRandomSeed=((self.sentinelsRandomSeed or time()+math.floor(GetTime()*1000))*48271)%2147483647
            self.seedBox:SetText(tostring(math.max(1,self.sentinelsRandomSeed)))
        end
    end
    start(self,repeatRun)
    if active(self) then
        if self.sentinelsPingButton then self.sentinelsPingButton:Selected(false) end
        self.sentinelsSeedPresented=self.seedBox:GetText()
        self:Notice(L["Both camps: 2s to the center, 1s ping and jump, 3s find a pinging 1."])
    end
end
local update=UI.Update
function UI:Update(elapsed)
    update(self,elapsed)
    if self.selectingEncounter or not selected(self) then return end
    self.sentinelsHudElapsed=(self.sentinelsHudElapsed or 0)+elapsed
    if self.sentinelsHudElapsed<.1 then return end
    self.sentinelsHudElapsed=0
    self.statusText:SetText(L["Sentinels - Mythic intermission"])
    self.reviveButton:SetText(EL.F("New attempt [%s]",self.input:BindingLabel("revive")))
    self.castFrame:Hide()
    local s=active(self) and self.sim.state
    if not s then
        self.counterText:SetText(L["20 players - combine to exactly 4"])
        self.centerText:SetText(L["Start training to draw your number"]);return
    end
    local r=s.raiders[s.playerIndex]
    self.sentinelsPingButton:Selected(s.applied and s.status=="running" and not r.dead and r.stacks==1)
    self.counterText:SetText(EL.F("%.1f s / %d of 20 clear",math.max(0,self.sim.duration-s.time),s.cleared))
    if self.loadingScene then return end
    if s.status=="paused" then return end
    if s.failure then
        self.centerText:SetText(EL.F(s.wipe and "RAID WIPE\n%s\n[%s] Retry" or "Attempt failed\n%s\n[%s] Retry",L[s.failure],self.input:BindingLabel("revive")))
    elseif s.status=="finished" then
        self.centerText:SetText(s.cleared==20 and EL.F("20 / 20 clear\nYour match: %.2f s\n[%s] Retry",s.matchTime or 0,self.input:BindingLabel("revive")) or L["Raid failed - retry the intermission"])
    elseif not s.applied then
        self.centerText:SetText(EL.F("Helical Toxins in %.1f",math.max(0,EL.Sentinels.preparation-s.time)))
    elseif r.stacks==0 then self.centerText:SetText(L["Toxins cleared"])
    else self.centerText:SetText("") end
    local hint=r.stacks==3 and L["3: go around the center to a pinging 1"] or r.stacks==2 and L["2: move to the center"] or r.stacks==1 and L["1: ping yourself and keep jumping"] or L["Toxins cleared"]
    self.footerText:SetText(s.applied and hint or L["Your number appears with Helical Toxins"])
end
local scores=UI.ShowScores
function UI:ShowScores(filter)
    if not selected(self) then scores(self,filter);return end
    self.boardFilter=filter or self.boardFilter or "reference"
    self:Modal(L["Sentinels highscores - Random roles"])
    self.modal:SetHeight(580);self.modalBody:SetHeight(400)
    self.modalBody:ClearAllPoints();self.modalBody:SetPoint("TOPLEFT",22,-112)
    local boardOptions={sentinelsNumber=0,sentinelsReveal=self.options.sentinelsReveal,mode=self.boardFilter=="practice" and "practice" or "reference"}
    local entries=EL.Store.GetBoard(self.boardFilter,1,self.boardSeedOnly and self.options.seed or nil,EL.Sentinels.Version(boardOptions))
    local lines={}
    for i,e in ipairs(entries) do lines[#lines+1]=EL.F("%d. %.2f s / Seed %d",i,e.matchTime or 0,e.seed) end
    if #entries==0 then lines[1]=L["No completed ranked runs yet."] end
    lines[#lines+1]="\n"..L["Fastest personal match wins. Only successful 20-player clears qualify. Paused and practice runs use separate boards."]
    self.modalBody:SetText(table.concat(lines,"\n\n"))
    for i,id in ipairs({"reference","practice","assisted"}) do
        local bucket=id;local names={reference=L["Normal"],practice=L["Practice"],assisted=L["Assisted"]}
        self:ModalButton(names[id],22+(i-1)*198,65,188,function() self:ShowScores(bucket) end):Selected(id==self.boardFilter)
    end
    self:ModalButton(L["Recent runs"],22,524,174,function() self:ShowHistory() end)
    self:ModalButton(self.boardSeedOnly and L["This seed"] or L["All seeds"],206,524,174,function() self.boardSeedOnly=not self.boardSeedOnly;self:ShowScores() end)
end
