-- Bounded, in-memory replay. Never drives the live simulation or saved scores.
local _,EL=...
local R={};R.__index=R;EL.Rehearsal=R
local function copy(source,out)
    out=out or {}
    for k in pairs(out) do if source[k]==nil then out[k]=nil end end
    for k,v in pairs(source) do
        out[k]=type(v)=="table" and copy(v,type(out[k])=="table" and out[k] or nil) or v
    end
    return setmetatable(out,getmetatable(source))
end
R.Copy=copy
function R.New(sim)
    local self=setmetatable({frames={},head=0,count=0,capacity=182,nextSample=0,failureSerial=sim.state.failureSerial or 0},R)
    self:Capture(sim)
    return self
end
function R:Capture(sim)
    local s=sim.state
    if self.checkpointIndex~=s.checkpoint and not s.player.dead then
        self.checkpoint=copy(sim);self.checkpointIndex=s.checkpoint
    end
    if self.frozen then return end
    local failure=s.failure and s.failure.serial~=(self.failureSerial or 0)
    if s.time<self.nextSample and not failure then return end
    self.head=self.head%self.capacity+1
    self.frames[self.head]=copy(s,self.frames[self.head])
    self.count=math.min(self.capacity,self.count+1)
    while self.count>1 and self:Frame(1).time<s.time-6 do self.count=self.count-1 end
    self.nextSample=s.time+1/30
    if failure then self.frozen=true;self.failureSerial=s.failure.serial;self.failure=copy(s.failure) end
end
function R:Frame(i) return self.frames[(self.head-self.count+i-1)%self.capacity+1] end
function R:Bounds()
    if self.count==0 then return 0,0 end
    return self:Frame(1).time,self:Frame(self.count).time
end
local function interpolatePose(out,a,b,t)
    for _,key in ipairs({"x","y","z","yaw","displayYaw"}) do
        if a[key] and b[key] then
            local delta=b[key]-a[key]
            if key=="yaw" or key=="displayYaw" then delta=(delta+math.pi)%(2*math.pi)-math.pi end
            out[key]=a[key]+delta*t
        end
    end
    out.previousX,out.previousY,out.previousZ=out.x,out.y,out.z
    out.previousYaw,out.previousDisplayYaw=out.yaw,out.displayYaw
end
function R:Sample(t)
    if self.count==0 then return nil end
    local a,b=self:Frame(1),self:Frame(self.count)
    for i=2,self.count do
        local nextFrame=self:Frame(i)
        if nextFrame.time>t then b=nextFrame;break end
        a=nextFrame
    end
    local f=b.time>a.time and math.max(0,math.min(1,(t-a.time)/(b.time-a.time))) or 0
    local out=copy(a,self.sample);self.sample=out
    interpolatePose(out.player,a.player,b.player,f)
    for i,h in ipairs(out.tornadoes or {}) do
        if h.active and b.tornadoes[i] and b.tornadoes[i].active then interpolatePose(h,a.tornadoes[i],b.tornadoes[i],f) end
    end
    out.time=a.time+(b.time-a.time)*f
    if out.scenario=="twinfangs" then
        out.beamYaw=EL.TwinFangs.BeamYaw(out,out.time)
        if out.flood then out.flood.yaw=out.beamYaw end
    end
    return out
end
function R:Retry()
    if not self.checkpoint then return nil end
    local sim=copy(self.checkpoint)
    sim.rewound,sim.state.assisted=true,true
    sim.state.failure=nil
    sim.state.status="running"
    sim._jumpHeld,sim._jumpQueued=false,false
    return sim
end
function R:ResetBuffer()
    self.head,self.count,self.nextSample=0,0,0
    self.frozen,self.failure=nil,nil
end
