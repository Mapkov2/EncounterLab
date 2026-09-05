-- Client-owned 3D effects share the player's native scene, camera and depth buffer.
local _,EL=...
local T={};T.__index=T;EL.TempestRenderer=T
-- Native whirlwind and Sszorak's Tempest cast. No model files are bundled.
local TORNADO_MODEL,CAST_MODEL=2529592,7637242
local serial=0
local function line(parent)
    local l=parent:CreateLine(nil,"OVERLAY")
    l:SetColorTexture(.35,.95,.72,.85);l:SetThickness(2)
    if l.SetSnapToPixelGrid then l:SetSnapToPixelGrid(false) end
    if l.SetTexelSnappingBias then l:SetTexelSnappingBias(0) end
    l:Hide();return l
end
local function ring(parent,count)
    local r={sides=count,lines={}}
    for i=1,count do r.lines[i]=line(parent) end
    return r
end
local function hideRing(r) for _,l in ipairs(r.lines) do l:Hide() end end
local function actor(scene,name,fileID,scale)
    local a=scene:CreateActor(name,"ModelSceneActorTemplate")
    a:Hide();a:SetScale(scale)
    local ok,accepted=pcall(a.SetModelByFileID,a,fileID)
    return {actor=a,scale=scale,requested=ok and accepted~=false,nextCheck=0}
end
local function ready(slot,now)
    if slot.loaded then return true end
    if not slot.requested or now<slot.nextCheck then return false end
    slot.nextCheck=now+.5;slot.loaded=slot.actor:IsLoaded()==true
    return slot.loaded
end
local function animate(slot,animation,speed,offset,token,seeking)
    if seeking or slot.animation~=animation or slot.speed~=speed or slot.token~=token then
        slot.actor:SetAnimation(animation,0,speed,math.max(0,offset))
        slot.animation,slot.speed,slot.token=animation,speed,token
    end
end
function T.New(renderer)
    serial=serial+1
    local prefix="EncounterLabTempest"..serial.."_"
    local self=setmetatable({tornadoes={},trail={}},T)
    for i=1,EL.Sszorak.tornadoCapacity do
        local slot=actor(renderer.frame,prefix..i,TORNADO_MODEL,.65)
        slot.base=ring(renderer.ground,16)
        self.tornadoes[i]=slot
    end
    self.cast=actor(renderer.frame,prefix.."Cast",CAST_MODEL,1)
    for i=1,60 do self.trail[i]=line(renderer.ground) end
    self.failure=ring(renderer.ground,32)
    for _,l in ipairs(self.failure.lines) do l:SetColorTexture(1,.2,.1,.95) end
    return self
end
function T:Hide()
    for _,slot in ipairs(self.tornadoes) do slot.actor:Hide();hideRing(slot.base);slot.token=nil end
    self.cast.actor:Hide();self.cast.token=nil
    for _,l in ipairs(self.trail) do l:Hide() end
    hideRing(self.failure)
end
function T:Draw(renderer,s,rehearsal)
    local now=GetTime()
    local speed=s.status=="running" and (s.playbackSpeed or s.speed or 1) or 0
    local loaded=0
    for i,slot in ipairs(self.tornadoes) do
        local h=s.tornadoes[i]
        if ready(slot,now) then loaded=loaded+1 end
        if h and h.active then
            if renderer.hints or not slot.loaded then renderer:DrawRing(slot.base,h.x,h.y,h.radius) else hideRing(slot.base) end
            if slot.loaded then
                local age=s.time-h.birth
                slot.actor:SetPosition(h.x/slot.scale,h.y/slot.scale,0)
                local animation=age<1 and 0 or 158
                animate(slot,animation,speed,animation==158 and age-1 or age,h,rehearsal~=nil)
                slot.actor:Show()
            else slot.actor:Hide() end
        else slot.actor:Hide();hideRing(slot.base);slot.token=nil end
    end
    local b,cast=s.boss,self.cast
    if b.casting and ready(cast,now) then
        cast.actor:SetPosition(b.x,b.y,0)
        animate(cast,0,speed,s.time-b.castStarts,b.castStarts,rehearsal~=nil)
        cast.actor:Show()
    else cast.actor:Hide() end
    local used=0
    if rehearsal then
        local stride=math.max(1,math.ceil((rehearsal.count-1)/60))
        for i=1,rehearsal.count-stride,stride do
            local a,before=rehearsal:Frame(i),rehearsal:Frame(i+stride)
            if before.time<=s.time then
                used=used+1
                renderer:DrawWorldLine(self.trail[used],a.player.x,a.player.y,.12,before.player.x,before.player.y,.12)
            end
        end
        local f=rehearsal.failure
        if f then renderer:DrawRing(self.failure,f.x,f.y,2.8) else hideRing(self.failure) end
    else hideRing(self.failure) end
    for i=used+1,#self.trail do self.trail[i]:Hide() end
    renderer.diagnostics.nativeTornadoes=loaded
end
