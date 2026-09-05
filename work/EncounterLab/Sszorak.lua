-- Independently authored Tempest-only solo drill. Shared WoW movement stays in Simulation.
local _,EL=...
local S={drills={"tempest"},bossDisplayID=142788,tornadoCapacity=36,volleyInterval=6,volleyCount=9,spokes=4,pathSpeed=1.35}
EL.Sszorak=S
local pi,sin,cos,min,max=math.pi,math.sin,math.cos,math.min,math.max
local starts={0,16,34}
function S.Checkpoints() return starts end
local function checkpoint(options)
    local value=tonumber(options and options.sszorakCheckpoint)
    if not value or value~=value then return 1 end
    return max(1,min(3,math.floor(value)))
end
function S.Version(options) return "sszorak-3-tempest-"..checkpoint(options) end
local function swept(ax,ay,bx,by)
    local dx,dy=bx-ax,by-ay
    local length=dx*dx+dy*dy
    local f=length>0 and max(0,min(1,-(ax*dx+ay*dy)/length)) or 0
    return (ax+dx*f)^2+(ay+dy*f)^2
end
local function fail(self,reason,id)
    local s,p=self.state,self.state.player
    if p.dead then return end
    s.failureSerial=s.failureSerial+1
    s.failure={serial=s.failureSerial,reason=reason,time=s.time,x=p.x,y=p.y,entityID=id}
    self:_kill(reason)
end
local function position(h,t)
    local age=max(0,t-h.birth)*S.pathSpeed
    local radius=3+31*(1-cos(age*.24))*.5
    local angle=h.phase+h.direction*age*.36
    return cos(angle)*radius,sin(angle)*radius
end
local function mechanics(self,dt)
    local s,t=self.state,self.state.time
    s.checkpoint=t>=34 and 3 or t>=16 and 2 or 1
    s.phase,s.phaseEnds="Tempest",self.duration
    local volley=math.floor(t/S.volleyInterval)
    s.boss.castStarts=volley*S.volleyInterval
    s.boss.casting=volley<S.volleyCount and t-s.boss.castStarts<1.4
    for _,h in ipairs(s.tornadoes) do
        h.active=t>=h.birth and t<h.birth+55
        if h.active then
            h.previousX,h.previousY=position(h,max(t-dt,h.birth))
            h.x,h.y=position(h,t)
        end
    end
end
local function hazards(self)
    local s,p=self.state,self.state.player
    if p.dead then return end
    if p.x*p.x+p.y*p.y>(s.arenaRadius-.4)^2 then
        s.arenaExit=true;fail(self,"Fell off the platform");return
    end
    for _,h in ipairs(s.tornadoes) do
        if h.active and swept((self._previousX or p.x)-h.previousX,(self._previousY or p.y)-h.previousY,p.x-h.x,p.y-h.y)<(h.radius+.55)^2 then
            fail(self,"Tempest tornado",h.id);return
        end
    end
end
local function step(self,input,dt)
    local clipped=min(dt,max(0,self.duration-self.state.time))
    self._baseStep(self,input,clipped,self.state.elapsed+clipped)
    if self.state.time>=self.duration-1e-9 then self.state.status="finished" end
end
local function result(self)
    local r=self._baseResult(self)
    if r then r.version=self.version;r.highscoreEligible=r.highscoreEligible and not self.rewound end
    return r
end
local function revive(self)
    if not self._baseRevive(self) then return false end
    local p=self.state.player
    p.x,p.y,p.z=0,-8,0
    p.previousX,p.previousY,p.previousZ=p.x,p.y,p.z
    return true
end
function S.New(options)
    options=options or {}
    local self=EL.Simulation.New({loop=1,seed=options.seed,mode=options.mode,timeScale=options.timeScale,assist=options.assist})
    self.drill,self.version="tempest",S.Version(options)
    self._baseStep,self._baseResult,self._baseRevive=self._step,self.GetResult,self.Revive
    self._step,self.GetResult,self.Revive=step,result,revive
    self._moveWaves,self._checkHazards=mechanics,hazards
    self._queue,self._queueIndex={},1
    self._startTime,self.duration=starts[checkpoint(options)],55
    local s=self.state
    s.scenario,s.drill,s.time,s.arenaRadius="sszorak","tempest",self._startTime,42
    s.speed=self.options.timeScale
    s.pools,s.waves,s.tornadoes={},{},{}
    s.failureSerial=0
    s.player.x,s.player.y,s.player.yaw,s.player.displayYaw=0,-8,pi/2,pi/2
    s.player.previousX,s.player.previousY,s.player.previousYaw,s.player.previousDisplayYaw=0,-8,pi/2,pi/2
    s.boss.radius=4
    for volley=0,S.volleyCount-1 do
        local phase=self:_random()*2*pi
        for spoke=0,S.spokes-1 do
            s.tornadoes[#s.tornadoes+1]={id=#s.tornadoes+1,birth=volley*S.volleyInterval,phase=phase+spoke*2*pi/S.spokes,
                direction=volley%2==0 and 1 or -1,radius=2.2,x=0,y=0}
        end
    end
    mechanics(self,0)
    return self
end
