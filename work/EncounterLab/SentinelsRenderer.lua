-- Bounded native actors in the existing world scene; no second camera or mouse path.
local _,EL=...
local R={};R.__index=R;EL.SentinelsRenderer=R
local serial=0
local MASK="Interface\\CharacterFrame\\TempPortraitAlphaMask"
local colors={
    green={.56,1,.015},red={.82,.025,.065},shadow={.19,.15,.24},
}
-- Four fixed slots, clockwise from the top, as in the encounter reference.
-- Masked native regions are created once, not new text or actors each frame.
local positions={{0,.29},{.29,0},{0,-.29},{-.29,0}}
local function circle(parent,layer,sublevel,size,x,y)
    local texture=parent:CreateTexture(nil,layer,nil,sublevel)
    texture:SetPoint("CENTER",parent,"CENTER",x or 0,y or 0)
    texture:SetSize(size,size)
    local mask=parent:CreateMaskTexture()
    mask:SetTexture(MASK,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture);texture:AddMaskTexture(mask)
    return texture
end
local function marker(parent)
    local m=CreateFrame("Frame",nil,parent)
    m:SetSize(64,64);m:EnableMouse(false);m.orbs={}
    for i=1,4 do
        local orb=CreateFrame("Frame",nil,m)
        orb:SetSize(1,1);orb:EnableMouse(false)
        orb:SetPoint("CENTER",m,"CENTER",positions[i][1]*64,positions[i][2]*64)
        orb.halo=circle(orb,"BACKGROUND",0,25)
        orb.rim=circle(orb,"ARTWORK",0,19)
        orb.body=circle(orb,"ARTWORK",1,15.5,.25,.25)
        orb.shine=circle(orb,"ARTWORK",2,6,-3,3.5)
        m.orbs[i]=orb
    end
    m:Hide();return m
end
local function hideMarker(m)
    if m.shown then m:Hide();m.shown=false end
end
local function drawMarker(renderer,m,s,r,x,y,z)
    if not s.applied or r.dead or r.stacks<=0 then hideMarker(m);return end
    local sx,sy,depth=renderer:Project(x,y,z+4.2)
    if not sx or sx<0 or sy<0 or sx>renderer.width or sy>renderer.height then hideMarker(m);return end
    local count=EL.Sentinels.VisibleNumber(s,r) or 0
    if m.visibleStacks~=count then
        for i,orb in ipairs(m.orbs) do
            -- Concealment uses the exact same four dark orbs for every role.
            local c=count==0 and colors.shadow or i<=count and colors.green or colors.red
            orb.halo:SetColorTexture(c[1],c[2],c[3],count==0 and .12 or .22)
            orb.rim:SetColorTexture(c[1]*.28,c[2]*.28,c[3]*.28,.95)
            orb.body:SetColorTexture(c[1],c[2],c[3],.98)
            orb.shine:SetColorTexture(c[1]+(1-c[1])*.65,c[2]+(1-c[2])*.65,c[3]+(1-c[3])*.65,count==0 and .08 or .7)
        end
        m.visibleStacks=count
    end
    local scale=math.max(30,math.min(72,math.abs(renderer.ky or 680)*3.4/(depth or 40)))/64
    if m.scale~=scale then m:SetScale(scale);m.scale=scale;m.x,m.y=nil,nil end
    -- Anchor coordinates are in the scaled child's units, not overlay units.
    local px,py=sx/scale,sy/scale
    if m.x~=px or m.y~=py then
        m:ClearAllPoints();m:SetPoint("CENTER",renderer.overlay,"BOTTOMLEFT",px,py);m.x,m.y=px,py
    end
    if not m.shown then m:Show();m.shown=true end
end
local function text(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,"OUTLINE")
    f:SetJustifyH("CENTER");f:SetShadowColor(0,0,0,1);f:SetShadowOffset(1,-1)
    return f
end
local function actor(self,suffix)
    local a=self.renderer.frame:CreateActor(self.prefix..suffix,"ModelSceneActorTemplate")
    a:SetUseCenterForOrigin(true,true,false);a:Hide()
    return a
end
function R.New(renderer)
    serial=serial+1
    local self=setmetatable({renderer=renderer,prefix="EncounterLabSentinels"..serial.."_",raiders={},bosses={},nextCheck=0},R)
    for i=1,20 do
        -- The user's existing actor is reused; the spare slot is hidden.
        local slot={actor=actor(self,"Raider"..i),label=text(renderer.overlay,16),ping=text(renderer.overlay,15),marker=marker(renderer.overlay)}
        slot.actor:SetScale(1)
        pcall(slot.actor.SetModelByUnit,slot.actor,"player",true,true)
        self.raiders[i]=slot
    end
    for i=1,2 do
        local slot={actor=actor(self,"Boss"..i),label=text(renderer.overlay,14),scale=1}
        pcall(slot.actor.SetModelByCreatureDisplayID,slot.actor,EL.Sentinels.bossDisplays[i])
        self.bosses[i]=slot
    end
    self.center=text(renderer.overlay,14)
    return self
end
local function place(renderer,label,x,y,z,value)
    local sx,sy=renderer:Project(x,y,z)
    if value~="" and sx and sx>=0 and sy>=0 and sx<=renderer.width and sy<=renderer.height then
        if label.encounterText~=value then label:SetText(value);label.encounterText=value end
        label:ClearAllPoints();label:SetPoint("BOTTOM",renderer.overlay,"BOTTOMLEFT",sx,sy);label:Show()
    else label:Hide() end
end
local function animate(slot,id,speed)
    if slot.animation~=id or slot.speed~=speed then
        slot.actor:SetAnimation(id,0,speed);slot.animation,slot.speed=id,speed
    end
end
function R:Check(now)
    if now<self.nextCheck then return end
    self.nextCheck=now+.5
    for _,slot in ipairs(self.raiders) do slot.loaded=slot.actor:IsLoaded() end
    for _,slot in ipairs(self.bosses) do
        slot.loaded=slot.actor:IsLoaded()
        if slot.loaded and not slot.sized then
            local bx,by,bz,tx,ty,tz=EL.SceneAssets.ReadBounds(slot.actor)
            if bz and tz>bz then slot.scale=8/(tz-bz);slot.z=-bz;slot.actor:SetScale(slot.scale);slot.sized=true end
        end
    end
end
function R:Draw(renderer,s)
    self:Check(GetTime())
    local speed=s.status=="running" and (s.speed or 1) or 0
    for i,slot in ipairs(self.raiders) do
        local r=s.raiders and s.raiders[i]
        if r then
            local x,y,z=r.x,r.y,r.z or 0
            if r.isPlayer then local p=renderer.renderPlayer;x,y,z=p.x,p.y,p.z or 0 end
            if not r.isPlayer and slot.loaded then
                slot.actor:SetPosition(x,y,z);slot.actor:SetYaw(r.yaw)
                animate(slot,r.dead and 1 or (r.z or 0)>0 and 37 or r.moving and 5 or 0,speed);slot.actor:Show()
            else slot.actor:Hide() end
            drawMarker(renderer,slot.marker,s,r,x,y,z)
            local caption=""
            if r.clearedAt and s.time-r.clearedAt<1.5 then caption="|cff60ed97"..EL.L["Clear"].."|r" end
            place(renderer,slot.label,x,y,z+3.3,caption)
            local ping=r.pingUntil and r.pingUntil>s.time and r.stacks>0 and not r.dead
            place(renderer,slot.ping,x,y,z+5.2,ping and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:20|t ! |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:20|t\n|A:Ping_Marker_Icon_OnMyWay:24:24|a |cff7dc5ff"..EL.L["On my way"].."|r" or "")
        else slot.actor:Hide();slot.label:Hide();slot.ping:Hide();hideMarker(slot.marker) end
    end
    -- Encounter selection renders a sparse "ready" preview before Start has
    -- created raiders/groups. Do not assume a live simulation or assign a side.
    for i,slot in ipairs(self.bosses) do
        local x,y,moving=EL.Sentinels.BossPosition(s,i)
        if slot.loaded then
            slot.actor:SetPosition(x/slot.scale,y/slot.scale,slot.z or 0)
            slot.actor:SetYaw(i==1 and 0 or math.pi)
            animate(slot,moving and 5 or s.applied and 125 or 0,speed);slot.actor:Show()
        end
        place(renderer,slot.label,x,y,9,i==1 and "|cff8bed50"..EL.L["Breath of Ula'tek"].."|r" or "|cffff6878"..EL.L["Blood of Ula'tek"].."|r")
    end
    local own=s.raiders and s.playerIndex and s.raiders[s.playerIndex]
    if own then
        place(renderer,self.center,0,-3,.15,EL.L["Center - all 2s meet here"])
    else self.center:Hide() end
    renderer.playerLabel:Hide();renderer.bossLabel:Hide();renderer.bossActor:Hide()
    for _,line in ipairs(renderer.bossRing.lines) do line:Hide() end
end
function R:Hide()
    for _,s in ipairs(self.raiders) do s.actor:Hide();s.label:Hide();s.ping:Hide();hideMarker(s.marker) end
    for _,s in ipairs(self.bosses) do s.actor:Hide();s.label:Hide() end
    self.center:Hide()
end
function R:Destroy()
    self:Hide()
    for _,s in ipairs(self.raiders) do s.actor:ClearModel() end
    for _,s in ipairs(self.bosses) do s.actor:ClearModel() end
end
