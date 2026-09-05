-- Independently authored Helical Toxins intermission. No live raid unit data.
local _,EL=...
local S={duration=30,preparation=3,contactRadius=1.4,centerRadius=8,bossTravel=2,bossDisplays={143437,143436}}
-- Read-only layout for the pre-Start preview. Live runs own separate copies.
S.bossPositions={{x=-23,y=0},{x=23,y=0}}
EL.Sentinels=S
local pi,cos,sin,sqrt,min,max=math.pi,math.cos,math.sin,math.sqrt,math.min,math.max
local function bounded(n,default,hi)
    n=tonumber(n);if not n or n~=n then return default end
    return math.floor(max(1,min(hi,n)))
end
function S.Number(options)
    local n=options and options.sentinelsNumber
    return (n==1 or n==2 or n==3) and n or 0
end
function S.Reveal(options)
    return options and options.mode=="practice" and bounded(options.sentinelsReveal,2,5) or 2
end
function S.Version(options) return "sentinels-9-"..S.Number(options).."-"..S.Reveal(options) end
function S.VisibleNumber(state,raider)
    if not state.applied or raider.dead or raider.stacks==0 then return nil end
    if raider.isPlayer or state.time<state.revealEnds then return raider.stacks end
end
-- Boss movement starts with the reveal; both arrive at the shared center.
-- Camps remain spawn metadata and never constrain targets or collision.
function S.BossPosition(state,index)
    local origin=S.bossPositions[index]
    local progress=state.status=="ready" and 0 or max(0,min(1,((state.time or 0)-S.preparation)/S.bossTravel))
    local destination=index==1 and -3 or 3
    return origin.x+(destination-origin.x)*progress,0,progress>0 and progress<1
end
local function mark(s,r)
    r.pingAt=s.time;r.pingUntil=s.time+4;r.nextPing=s.time+5
    r.pingX,r.pingY=r.x,r.y
end
local function ping(self)
    local s=self.state;local r=s.raiders[s.playerIndex]
    if s.status~="running" or not s.applied or r.dead or r.stacks~=1 then return false end
    if r.pingAt and s.time-r.pingAt<.5 then return false end
    mark(s,r);return true
end
local function kill(self,r,reason)
    if r.dead then return end
    r.dead=true;r.pingUntil=0
    if r.isPlayer then
        self:_kill(reason);self.state.failure=reason
    end
end
local function wipe(self,reason)
    local s=self.state
    if s.wipe then return end
    s.wipe=true;s.failure=reason
    for _,r in ipairs(s.raiders) do kill(self,r,reason) end
    s.cleared,s.raidDeaths,s.status=0,20,"finished"
end
local function oneFailure(r)
    if not r or not r.isPlayer or r.stacks~=1 then return nil end
    local pinged=r.pingAt and r.pingAt>=S.preparation
    local jumped=r.jumpedAt and r.jumpedAt>=S.preparation
    if not pinged and not jumped then return "Missing ping and jump" end
    if not pinged then return "Missing ping" end
    if not jumped then return "Missing jump" end
end
local function combine(self,a,b)
    local sum=a.stacks+b.stacks;local s=self.state
    local missing=oneFailure(a.isPlayer and a or b.isPlayer and b)
    if sum~=4 then
        wipe(self,"Contact did not total 4")
    elseif missing then
        wipe(self,missing)
    else
        a.stacks,b.stacks=0,0;a.clearedAt,b.clearedAt=s.time,s.time
        a.pingUntil,b.pingUntil=0,0
        if a.isPlayer or b.isPlayer then
            s.matchTime=s.time-S.preparation;s.matchSum=4
        end
    end
    if a.isPlayer or b.isPlayer then s.lastAddition=sum end
end
local function swept(a,b)
    local x,y=(a.previousX or a.x)-(b.previousX or b.x),(a.previousY or a.y)-(b.previousY or b.y)
    local dx,dy=(a.x-b.x)-x,(a.y-b.y)-y
    local length=dx*dx+dy*dy
    local f=length>0 and max(0,min(1,-(x*dx+y*dy)/length)) or 0
    return (x+f*dx)^2+(y+f*dy)^2
end
local function hazards(self)
    local s=self.state;local own=s.raiders[s.playerIndex]
    if s.player.x^2+s.player.y^2>s.arenaRadius^2 then
        s.arenaExit=true;kill(self,own,"Left the training arena")
    end
    if not s.applied then return end
    -- Every active contact participates, regardless of camp or chosen target.
    -- Only exactly four clears; every other sum wipes immediately.
    for i=1,19 do
        local a=s.raiders[i]
        for j=i+1,20 do
            local b=s.raiders[j];local key=i*20+j
            local touching=(a.x-b.x)^2+(a.y-b.y)^2<=S.contactRadius^2
            if not self.contacts[key] and not a.dead and not b.dead and a.stacks>0 and b.stacks>0 and swept(a,b)<=S.contactRadius^2 then
                combine(self,a,b)
            end
            self.contacts[key]=touching or nil
        end
    end
    local cleared,dead=0,0
    for _,r in ipairs(s.raiders) do
        if r.dead then dead=dead+1 elseif r.stacks==0 then cleared=cleared+1 end
    end
    s.cleared,s.raidDeaths=cleared,dead
end
local function segmentDistance(x,y,dx,dy,px,py)
    local length=dx*dx+dy*dy
    local f=length>0 and max(0,min(1,((px-x)*dx+(py-y)*dy)/length)) or 0
    return (x+f*dx-px)^2+(y+f*dy-py)^2
end
local function blocked(s,r,x,y,target,margin)
    -- The entire segment must stay outside the shared 2s' meeting area,
    -- including local obstacle detours. This does not alter player movement.
    if r.stacks==3 and segmentDistance(r.x,r.y,x-r.x,y-r.y,0,0)<S.centerRadius^2 then return true end
    for _,other in ipairs(s.raiders) do
        -- A 2 can meet other 2s in the center; every other active body is
        -- an obstacle, irrespective of its hidden number. Contacts themselves
        -- still use the unchanged swept hazard path, never a group exemption.
        if other~=r and other~=target and not other.dead and other.stacks>0 then
            local compatible=r.stacks==2 and other.stacks==2
                and other.x^2+other.y^2<9
            -- Bots keep a small real clearance around the user, rather than
            -- opening a broad safe corridor. Moving into their route can hit.
            local clearance=other.isPlayer and min(margin,S.contactRadius+.12) or margin
            if not compatible and segmentDistance(r.x,r.y,x-r.x,y-r.y,other.x,other.y)<clearance^2 then return true end
        end
    end
    return false
end
-- Small deterministic obstacle detours, evaluated only when the direct route
-- is obstructed. No per-tick tables, teleporting or contact immunity.
local function route(s,r,x,y,target)
    if r.stacks==3 and segmentDistance(r.x,r.y,x-r.x,y-r.y,0,0)<S.centerRadius^2 then
        local angle=math.atan2(r.y,r.x)
        local orbit=S.centerRadius+2
        if x*x+y*y<S.centerRadius^2 then
            -- A user 1 who enters the reserved center must come back out.
            -- Wait outside rather than chasing them through the 2s.
            x,y=cos(angle)*orbit,sin(angle)*orbit
        else
            if not r.centerSide then
                local delta=(math.atan2(y,x)-angle+pi)%(2*pi)-pi
                r.centerSide=math.abs(math.abs(delta)-pi)<.01 and (r.id%2==0 and 1 or -1) or (delta>=0 and 1 or -1)
            end
            local radius=sqrt(r.x*r.x+r.y*r.y)
            local turn=max(.35,math.acos(min(1,orbit/max(radius,.001))))
            local nextAngle=angle+r.centerSide*turn
            x,y=cos(nextAngle)*orbit,sin(nextAngle)*orbit
        end
    end
    if not blocked(s,r,x,y,target,2.1) then r.detour=nil;return x,y end
    local angle=math.atan2(y-r.y,x-r.x)
    local side=r.detour or (r.id%2==0 and 1 or -1)
    for turn=1,8 do
        for attempt=1,2 do
            local sign=attempt==1 and side or -side
            local a=angle+sign*turn*pi/8
            local nx,ny=r.x+cos(a)*2.8,r.y+sin(a)*2.8
            if nx*nx+ny*ny<(s.arenaRadius-1)^2 and not blocked(s,r,nx,ny,target,1.85) then
                r.detour=sign;return nx,ny
            end
        end
    end
    return r.x,r.y
end
local function move(s,r,x,y,dt,target)
    x,y=route(s,r,x,y,target)
    local dx,dy=x-r.x,y-r.y;local distance=sqrt(dx*dx+dy*dy)
    r.moving=distance>.08
    if distance>.08 then
        local step=min(distance,(r.runSpeed or 7)*dt)
        r.x,r.y=r.x+dx/distance*step,r.y+dy/distance*step
        r.yaw=math.atan2(dy,dx)
    end
end
local function available(s,r,other)
    if other==r or other.dead or other.stacks~=1 then return false end
    -- A ping announces this living 1 for the remainder of its toxin. The
    -- four-second visual is not a timeout on a raider's memory of the target.
    -- This also permits a distant 3 to respond during the initial reveal.
    if not other.pingAt then return false end
    for _,seeker in ipairs(s.raiders) do
        if seeker~=r and not seeker.dead and seeker.stacks==3 and seeker.target==other.id then return false end
    end
    return true
end
local function targetFor(s,r)
    local target=r.target and s.raiders[r.target]
    if target and available(s,r,target) then return target end
    r.target=nil;r.centerSide=nil;local best=math.huge
    for _,other in ipairs(s.raiders) do
        if available(s,r,other) then
            local distance=sqrt((r.x-other.x)^2+(r.y-other.y)^2)
            -- Stable per-run preferences create crossing routes. Re-evaluate
            -- only on acquisition; a seeker never jitters between targets.
            local priority=r.searchPriority and r.searchPriority[other.id] or 0
            local score=distance+priority-(other.group~=r.group and (r.crossCampBias or 0) or 0)
            if score<best then target,best=other,score end
        end
    end
    if best<math.huge then r.target=target.id;return target end
end
-- Reused by offline strategy drivers. Runtime calls this for simulated raiders
-- only; it never steers the user or changes the accepted movement controller.
function S.BotDestination(s,r)
    if r.stacks==2 then return 0,0 end
    if r.stacks==3 then
        local target=targetFor(s,r)
        if target then return target.x,target.y,target end
    end
end
S.Route=route
local function mechanics(self,dt)
    local s=self.state;local p=s.player;local own=s.raiders[s.playerIndex]
    own.previousX,own.previousY=self._previousX or p.x,self._previousY or p.y
    own.x,own.y,own.z,own.yaw,own.dead=p.x,p.y,p.z,p.yaw,p.dead
    if not s.applied and s.time>=S.preparation then s.applied=true end
    -- The existing movement controller records actual takeoff. A held key,
    -- pre-reveal jump or NPC animation must never satisfy the user's action.
    if s.applied and own.stacks==1 and not p.dead and p.jumpStartedAt
        and p.jumpStartedAt>=S.preparation and p.jumpStartedAt<=s.time then
        own.jumpedAt=p.jumpStartedAt
    end
    -- Snapshot all bot positions before anyone moves, preserving real sweeps.
    for _,r in ipairs(s.raiders) do
        if not r.isPlayer then r.previousX,r.previousY=r.x,r.y;r.moving=false;r.z=0 end
        if r.dead or r.stacks~=3 then r.target=nil;r.centerSide=nil end
    end
    for _,r in ipairs(s.raiders) do
        if not r.isPlayer then
            if s.applied and s.time>=S.preparation+r.reaction and not r.dead and r.stacks>0 then
                if r.stacks==1 then
                    if s.time>=(r.nextPing or 0) then mark(s,r) end
                    if r.pingAt then
                        local jump=(s.time-r.pingAt)%1.1
                        r.z=jump<.6 and sin(jump/.6*pi)*1.15 or 0
                    end
                else
                    local x,y,target=S.BotDestination(s,r)
                    if x then move(s,r,x,y,dt,target) end
                end
            end
        end
    end
end
local function step(self,input,dt)
    local clipped=min(dt,max(0,self.duration-self.state.time))
    self._baseStep(self,input,clipped,self.state.elapsed+clipped)
    local s=self.state
    if s.time>=self.duration-1e-8 then
        local missing=oneFailure(s.raiders[s.playerIndex])
        if missing and not s.wipe then wipe(self,missing) end
        for _,r in ipairs(s.raiders) do if r.stacks>0 and not r.dead then wipe(self,"Toxins expired");break end end
        hazards(self);s.status="finished"
    elseif s.applied and (s.player.dead or s.cleared==20) then s.status="finished" end
end
local function result(self)
    local r=self._baseResult(self)
    if r then
        local s=self.state;r.version=self.version;r.matchTime=s.matchTime
        r.perfect=s.cleared==20 and s.raidDeaths==0
        r.highscoreEligible=r.highscoreEligible and r.perfect and s.matchTime~=nil
    end
    return r
end
function S.New(options)
    options=options or {}
    local self=EL.Simulation.New({loop=1,seed=options.seed,mode=options.mode,timeScale=options.timeScale,assist=options.assist})
    self.version=S.Version(options);self.duration=S.preparation+S.duration
    self._baseStep,self._baseResult=self._step,self.GetResult
    self._step,self.GetResult,self.Ping=step,result,ping
    self._moveWaves,self._checkHazards=mechanics,hazards
    self._moveBoss=function() end
    self.Revive=function() return false end
    self.UseAbility=function() return false,"Unavailable" end
    self._queue,self._queueIndex,self.contacts={},1,{}
    local s=self.state
    s.scenario,s.arenaRadius,s.raiders,s.speed="sentinels",40,{},self.options.timeScale
    s.revealEnds=S.preparation+S.Reveal(options);s.cleared,s.raidDeaths=0,0
    -- Two pre-spread camps with globally shuffled roles. Unequal 1/3 counts
    -- per camp require cross-camp matches; all roles occur on both sides.
    s.groups={}
    for i,position in ipairs(S.bossPositions) do s.groups[i]={x=position.x,y=position.y} end
    local positions={{-8,-9},{-2,-10},{4,-8},{9,-3},{8,4},{3,9},{-3,8},{-8,3},{0,-3},{1,3}}
    -- Mix short / neighboring user seeds before the first layout decision.
    for i=1,3 do self:_random() end
    local pairCount=4+math.floor(self:_random()*4)
    local twoCount=20-pairCount*2
    local assignments={}
    for i=1,pairCount do assignments[#assignments+1]=1;assignments[#assignments+1]=3 end
    for i=1,twoCount do assignments[#assignments+1]=2 end
    s.assignmentCounts={pairCount,twoCount,pairCount}
    local valid=false
    repeat
        for i=20,2,-1 do local j=1+math.floor(self:_random()*i);assignments[i],assignments[j]=assignments[j],assignments[i] end
        local counts={0,0,0}
        for i=1,10 do local n=assignments[i];counts[n]=counts[n]+1 end
        valid=counts[1]>0 and counts[1]<pairCount and counts[2]>0 and counts[2]<twoCount and counts[3]>0 and counts[3]<pairCount and counts[1]~=counts[3]
    until valid
    for group=1,2 do
        local home=s.groups[group]
        local angle=self:_random()*2*pi
        local stretch=.72+self:_random()*.38
        for member=1,10 do
            local px,py=positions[member][1],positions[member][2]
            local dx=(px*cos(angle)-py*sin(angle))*stretch+(self:_random()-.5)*1.5
            local dy=(px*sin(angle)+py*cos(angle))*stretch+(self:_random()-.5)*1.5
            if group==2 then dx,dy=-dx,-dy end
            local r={id=#s.raiders+1,group=group,x=home.x+dx,y=home.y+dy,z=0,yaw=math.atan2(-dy,-dx),
                stacks=assignments[(group-1)*10+member],reaction=.25+self:_random()*1.5}
            r.previousX,r.previousY=r.x,r.y;s.raiders[#s.raiders+1]=r
        end
    end
    -- Draw traffic after role/spawn assignment so the same seed remains fully
    -- reproducible. Ones announce first; threes then see multiple candidates.
    for _,r in ipairs(s.raiders) do
        r.runSpeed=5.8+self:_random()*2
        r.reaction=r.stacks==1 and .15+self:_random()*.55 or r.stacks==3 and .8+self:_random()*1.5 or .2+self:_random()*2
        r.crossCampBias=self:_random()*65
        r.searchPriority={}
        for i=1,20 do r.searchPriority[i]=self:_random()*25 end
    end
    local number=S.Number(options)
    if number==0 then number=1+math.floor(self:_random()*3) end
    s.playerNumber=number
    local candidates={}
    for i,r in ipairs(s.raiders) do if r.stacks==number then candidates[#candidates+1]=i end end
    s.playerIndex=candidates[1+math.floor(self:_random()*#candidates)]
    local r=s.raiders[s.playerIndex];r.isPlayer=true
    local p=s.player;p.x,p.y,p.yaw,p.displayYaw=r.x,r.y,r.yaw,r.yaw
    p.previousX,p.previousY,p.previousYaw,p.previousDisplayYaw=p.x,p.y,p.yaw,p.yaw
    return self
end
