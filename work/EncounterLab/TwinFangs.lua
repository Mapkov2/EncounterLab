-- Heroic intermission dodge practice. Timings and calibration notes: docs/twin-fangs.md.
-- Input and movement are supplied unchanged by the shared simulation.
local _,EL=...
local T={VERSION="twinfangs-1-intermission",castTime=4,channelTime=14,stormTime=18,
    poolTime=6,impactRadius=4,arenaRadius=42,warningTime=1.5,volleyInterval=1.5,
    volleys=12,perVolley=4,beamWidth=math.pi/15,sweep=math.pi*1.5,
    vexhulDisplayID=140993,ithrazDisplayID=141309}
EL.TwinFangs=T
local sin,cos,min,max,pi=math.sin,math.cos,math.min,math.max,math.pi
local PLAYER_RADIUS=.55
local EPS=1e-9
function T.Version() return T.VERSION end
function T.BeamYaw(s,t)
    return s.beamStart+s.direction*T.sweep*max(0,min(1,(t-T.castTime)/T.channelTime))
end
local function clip(lo,hi,a,b)
    if a<0 and b<0 then return nil end
    if a<0 then lo=max(lo,a/(a-b)) elseif b<0 then hi=min(hi,a/(a-b)) end
    if lo>hi then return nil end
    return lo,hi
end
-- A swept segment against the cone's two planes. Expand by the angular
-- movement during this substep, so a moving beam cannot slip between samples.
function T.BeamContact(ax,ay,bx,by,fromYaw,toYaw)
    local half=T.beamWidth/2+math.abs(toYaw-fromYaw)/2
    local yaw=(fromYaw+toYaw)/2
    local nx,ny=sin(yaw+half),-cos(yaw+half)
    local lo,hi=clip(0,1,nx*ax+ny*ay+PLAYER_RADIUS,nx*bx+ny*by+PLAYER_RADIUS)
    if not lo then return false end
    nx,ny=-sin(yaw-half),cos(yaw-half)
    return clip(lo,hi,nx*ax+ny*ay+PLAYER_RADIUS,nx*bx+ny*by+PLAYER_RADIUS)~=nil
end
local function circle(ax,ay,bx,by,x,y,radius)
    ax,ay,bx,by=ax-x,ay-y,bx-x,by-y
    local dx,dy=bx-ax,by-ay
    local length=dx*dx+dy*dy
    local f=length>0 and max(0,min(1,-(ax*dx+ay*dy)/length)) or 0
    return (ax+dx*f)^2+(ay+dy*f)^2<=(radius+PLAYER_RADIUS)^2
end
local function fail(self,reason,id)
    local s,p=self.state,self.state.player
    if p.dead then return end
    s.failureSerial=s.failureSerial+1
    s.failure={serial=s.failureSerial,reason=reason,time=s.time,x=p.x,y=p.y,entityID=id}
    self:_kill(reason)
end
local function mechanics(self,dt)
    local s,t=self.state,self.state.time
    self._fromTime=t-dt
    s.phase=t<T.castTime-EPS and "Vile Flood - prepare" or t<T.stormTime-EPS and "Vile Flood + Sanguine Storm" or "Congealed Gore - move clear"
    s.phaseEnds=t<T.castTime-EPS and T.castTime or t<T.stormTime-EPS and T.stormTime or self.duration
    s.beamYaw=T.BeamYaw(s,t)
    s.beamActive=t>=T.castTime-EPS and t<T.stormTime-EPS
    self._flood.yaw=s.beamYaw
    s.flood=t<T.stormTime-EPS and self._flood or nil
    s.boss.yaw=s.beamYaw
    for _,h in ipairs(s.impacts) do
        if not h.placed and t>=h.spawn-EPS then
            h.placed=true
            if h.targeted then h.x,h.y=s.player.x,s.player.y end
        end
        h.warning=h.placed and t<h.impact-EPS
        h.pool=t>=h.impact-EPS and t<h.expires-EPS
    end
end
local function point(ax,ay,p,from,now,t)
    local f=now>from and max(0,min(1,(t-from)/(now-from))) or 1
    return ax+(p.x-ax)*f,ay+(p.y-ay)*f
end
local function hazards(self)
    local s,p=self.state,self.state.player
    if p.dead then return end
    if p.x*p.x+p.y*p.y>(s.arenaRadius-PLAYER_RADIUS)^2 then
        s.arenaExit=true;fail(self,"Fell off the platform");return
    end
    local from=self._fromTime or s.time
    local ax,ay=self._previousX or p.x,self._previousY or p.y
    if s.time>=T.castTime-EPS and from<T.stormTime-EPS then
        local a,b=max(from,T.castTime),min(s.time,T.stormTime)
        local x,y=point(ax,ay,p,from,s.time,a);local u,v=point(ax,ay,p,from,s.time,b)
        if T.BeamContact(x,y,u,v,T.BeamYaw(s,a),T.BeamYaw(s,b)) then fail(self,"Vile Flood");return end
    end
    for _,h in ipairs(s.impacts) do
        if h.placed and s.time>=h.impact-EPS and from<h.expires-EPS then
            local x,y=point(ax,ay,p,from,s.time,max(from,h.impact))
            local u,v=point(ax,ay,p,from,s.time,min(s.time,h.expires))
            if circle(x,y,u,v,h.x,h.y,h.radius) then
                fail(self,from<h.impact-EPS and "Sanguine Storm" or "Congealed Gore",h.id);return
            end
        end
    end
end
local function step(self,input,dt)
    dt=min(dt,max(0,self.duration-self.state.time))
    self._baseStep(self,input,dt,self.state.elapsed+dt)
    if self.state.time>=self.duration-1e-9 then self.state.status="finished" end
end
local function result(self)
    local r=self._baseResult(self)
    if r then r.version=self.version;r.highscoreEligible=r.highscoreEligible and not self.rewound end
    return r
end
local function revive(self)
    if not self._baseRevive(self) then return false end
    -- Revive behind the current beam, choosing a point clear of existing pools.
    local s,p=self.state,self.state.player
    for i=0,15 do
        local a=s.beamYaw+pi+(i%2==0 and 1 or -1)*math.ceil(i/2)*pi/16
        local x,y=cos(a)*24,sin(a)*24
        local safe=true
        for _,h in ipairs(s.impacts) do
            if (h.pool or h.warning) and circle(x,y,x,y,h.x,h.y,h.radius) then safe=false;break end
        end
        if safe or i==15 then p.x,p.y=x,y;break end
    end
    p.z=0;p.previousX,p.previousY,p.previousZ=p.x,p.y,0
    s.assisted=true
    return true
end
function T.New(options)
    options=options or {}
    local self=EL.Simulation.New({loop=1,seed=options.seed,mode=options.mode,timeScale=options.timeScale,assist=options.assist})
    self.version=T.VERSION
    self._baseStep,self._baseResult,self._baseRevive=self._step,self.GetResult,self.Revive
    self._step,self.GetResult,self.Revive=step,result,revive
    self._moveWaves,self._checkHazards=mechanics,hazards
    self._queue,self._queueIndex={},1
    self._startTime,self.duration=0,T.stormTime+T.poolTime
    local s,p=self.state,self.state.player
    s.scenario,s.time,s.arenaRadius="twinfangs",0,T.arenaRadius
    s.speed=self.options.timeScale;s.pools,s.waves,s.tornadoes,s.impacts={},{},{},{}
    s.failureSerial,s.checkpoint=0,1
    s.direction=self:_random()<.5 and -1 or 1
    s.beamStart=self:_random()*pi*2
    local angle=s.beamStart+s.direction*(pi*.5+self:_random()*pi*.25)
    p.x,p.y,p.yaw,p.displayYaw=cos(angle)*24,sin(angle)*24,angle+pi,angle+pi
    p.previousX,p.previousY,p.previousYaw,p.previousDisplayYaw=p.x,p.y,p.yaw,p.displayYaw
    s.boss.x,s.boss.y,s.boss.z,s.boss.radius=0,0,0,4
    s.ithraz={x=0,y=36,z=0,yaw=-pi/2}
    for volley=0,T.volleys-1 do
        for j=1,T.perVolley do
            local a,r=self:_random()*pi*2,math.sqrt(self:_random())*36
            local spawn=volley*T.volleyInterval
            s.impacts[#s.impacts+1]={id=#s.impacts+1,x=cos(a)*r,y=sin(a)*r,
                targeted=j==1,spawn=spawn,impact=spawn+T.warningTime,
                expires=spawn+T.warningTime+T.poolTime,radius=T.impactRadius}
        end
    end
    self._flood={x=0,y=0,width=T.beamWidth,radius=T.arenaRadius,floorRadius=T.arenaRadius}
    mechanics(self,0)
    return self
end
