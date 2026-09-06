-- Reuses the single gameplay scene and its calibrated projection.
local _,EL=...
local R={};R.__index=R;EL.TwinFangsRenderer=R
local serial=0
local pi,cos,sin=math.pi,math.cos,math.sin
local function line(parent,r,g,b)
    local l=parent:CreateLine(nil,"OVERLAY")
    l:SetColorTexture(r,g,b,.95);l:SetThickness(2)
    l:SetSnapToPixelGrid(false);l:SetTexelSnappingBias(0);l:Hide()
    return l
end
local function ring(parent,r,g,b)
    local out={sides=32,lines={}}
    for i=1,32 do out.lines[i]=line(parent,r,g,b) end
    return out
end
local function hideRing(r) for _,l in ipairs(r.lines) do l:Hide() end;r.active=false end
local function actor(self,name,id,display)
    local a=self.renderer.frame:CreateActor(self.prefix..name,"ModelSceneActorTemplate")
    a:Hide();a:SetScale(1)
    if display then a:SetUseCenterForOrigin(true,true,false) end
    local ok,accepted=pcall(display and a.SetModelByCreatureDisplayID or a.SetModelByFileID,a,id)
    local slot={actor=a,requested=ok and accepted~=false,scale=1,z=0,display=display}
    self.actors[#self.actors+1]=slot
    return slot
end
local function label(parent,name)
    local f=parent:CreateFontString(nil,"OVERLAY")
    EL.Theme.Font(f,14,true);f:SetText(EL.L[name]);f:Hide();return f
end
local function placeLabel(renderer,f,x,y,z)
    local a,b=renderer:Project(x,y,z)
    if a and a>=0 and b>=0 and a<=renderer.width and b<=renderer.height then
        f:ClearAllPoints();f:SetPoint("BOTTOM",renderer.overlay,"BOTTOMLEFT",a,b);f:Show()
    else f:Hide() end
end
local function hide(slot)
    slot.actor:Hide();slot.token=nil
end
local function draw(slot,x,y,z,yaw,animation,speed,offset,token,seeking)
    if not slot.loaded then hide(slot);return end
    slot.actor:SetPosition(x/slot.scale,y/slot.scale,z/slot.scale+slot.z)
    slot.actor:SetYaw(yaw)
    if slot.animation~=animation or slot.speed~=speed or slot.token~=token or seeking then
        slot.actor:SetAnimation(animation,0,speed,math.max(0,offset))
        slot.animation,slot.speed,slot.token=animation,speed,token
    end
    slot.actor:Show()
end
function R.New(renderer)
    serial=serial+1
    local self=setmetatable({renderer=renderer,prefix="EncounterLabFangs"..serial.."_",actors={},impacts={},orbs={},nextCheck=0},R)
    self.vexhul=actor(self,"Vexhul",EL.TwinFangs.vexhulDisplayID,true)
    self.ithraz=actor(self,"Ithraz",EL.TwinFangs.ithrazDisplayID,true)
    self.beam=actor(self,"Flood",7948782)
    self.vexhul.label=label(renderer.overlay,"Vexhul")
    self.ithraz.label=label(renderer.overlay,"Ithraz")
    for i=1,EL.TwinFangs.volleys*EL.TwinFangs.perVolley do
        -- Client blood effect represents gore; mandatory rings retain the
        -- drill's calibrated footprint even when a native effect is unavailable.
        local h=actor(self,"Gore"..i,7752025)
        h.ring=ring(renderer.ground,1,.12,.18)
        h.timer=ring(renderer.ground,1,.64,.66)
        local fill=renderer.ground:CreateTexture(nil,"ARTWORK")
        fill:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        fill:SetVertexColor(.65,.02,.055,1);fill:SetSize(1,1)
        fill:SetPoint("BOTTOMLEFT",renderer.ground,"BOTTOMLEFT",0,0)
        fill:SetSnapToPixelGrid(false);fill:SetTexelSnappingBias(0);fill:Hide()
        h.fill=fill
        self.impacts[i]=h
    end
    for i=1,3 do self.orbs[i]=ring(renderer.ground,.45,1,.08) end
    self.directionLine=line(renderer.ground,.65,1,.1)
    return self
end
function R:Check(now)
    if self.dead or now<self.nextCheck then return end
    self.nextCheck=now+.5
    for _,slot in ipairs(self.actors) do
        if slot.requested and not slot.loaded and slot.actor:IsLoaded() then
            slot.loaded=true
            if slot.display then
                local _,_,bz,_,_,tz=EL.SceneAssets.ReadBounds(slot.actor)
                if bz and tz>bz then slot.scale=11/(tz-bz);slot.z=-bz;slot.actor:SetScale(slot.scale) end
            end
        end
    end
end
function R:Hide()
    for _,slot in ipairs(self.actors) do hide(slot) end
    for _,h in ipairs(self.impacts) do hideRing(h.ring);hideRing(h.timer);h.fill:Hide();h.fill.drawn=false end
    for _,r in ipairs(self.orbs) do hideRing(r) end
    self.directionLine:Hide();self.vexhul.label:Hide();self.ithraz.label:Hide()
end
function R:Draw(renderer,s,replay)
    if self.dead then return end
    self:Check(GetTime())
    renderer.bossActor:Hide();renderer.bossLabel:Hide()
    local t=s.time or 0
    local speed=s.status=="running" and (s.playbackSpeed or s.speed or 1) or 0
    local b=s.ithraz or {x=0,y=36,z=0,yaw=-pi/2}
    local yaw=s.beamYaw or 0
    local casting=s.status~="ready" and t<18
    draw(self.vexhul,0,0,0,yaw,casting and 125 or 0,speed,t,s,replay)
    draw(self.ithraz,b.x,b.y,0,b.yaw,casting and 125 or 0,speed,t,s,replay)
    placeLabel(renderer,self.vexhul.label,0,0,12)
    placeLabel(renderer,self.ithraz.label,b.x,b.y,12)
    if s.beamActive then draw(self.beam,0,0,2,yaw,0,speed,t-4,s,replay) else hide(self.beam) end
    local impacts=s.impacts
    for i,h in ipairs(self.impacts) do
        local live=impacts and impacts[i]
        if live and (live.warning or live.pool) then
            renderer:DrawRing(h.ring,live.x,live.y,live.radius)
            renderer:DrawHazardFill(h.fill,live.x,live.y,live.radius,live.warning and .22 or .5)
            if live.warning then
                renderer:DrawRing(h.timer,live.x,live.y,live.radius*math.max(0,(live.impact-t)/EL.TwinFangs.warningTime))
                hide(h)
            else
                hideRing(h.timer)
                draw(h,live.x,live.y,.03,0,0,speed,t-live.impact,live,replay)
            end
        else hide(h);hideRing(h.ring);hideRing(h.timer);h.fill:Hide();h.fill.drawn=false end
    end
    for i,r in ipairs(self.orbs) do
        if casting then
            local a=(s.beamStart or 0)+(s.direction or 1)*t*1.2+i*pi*2/3
            renderer:DrawRing(r,cos(a)*6,sin(a)*6,.6)
        else hideRing(r) end
    end
    if casting then
        local a=yaw+(s.direction or 1)*.5
        renderer:DrawWorldLine(self.directionLine,cos(yaw)*8,sin(yaw)*8,.15,cos(a)*8,sin(a)*8,.15)
    else self.directionLine:Hide() end
    renderer.diagnostics.twinFangsModels=(self.vexhul.loaded and 1 or 0)+(self.ithraz.loaded and 1 or 0)
end
function R:Destroy()
    self:Hide();self.dead=true
    for _,slot in ipairs(self.actors) do slot.actor:ClearModel() end
end
