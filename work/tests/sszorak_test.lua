local base=(arg and arg[1]) or "EncounterLab/"
local EL={}
for _,file in ipairs({"Namespace.lua","Simulation.lua","Sszorak.lua","Rehearsal.lua","Persistence.lua"}) do assert(loadfile(base..file))("EncounterLab",EL) end
local checks,failed=0,0
local function test(name,fn)
    checks=checks+1;local ok,err=pcall(fn)
    print((ok and "PASS " or "FAIL ")..name..(ok and "" or ": "..tostring(err)))
    if not ok then failed=failed+1 end
end
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a).." ~= "..tostring(b)) end
local function sim(drill,checkpoint,seed)
    return EL.Sszorak.New({sszorakDrill=drill,sszorakCheckpoint=checkpoint,seed=seed or 95137})
end
local function advance(s,seconds,input,hz)
    local goal=s.state.elapsed+seconds;hz=hz or 60
    while s.state.elapsed<goal-1e-8 and s.state.status=="running" do s:Advance(math.min(1/hz,goal-s.state.elapsed),input) end
end
local function nocollisions(s) s._checkHazards=function() end end
test("Tempest seed reproduces tornado paths and different seeds change them",function()
    local a,b,c=sim("tempest"),sim("tempest"),sim("tempest",1,888)
    for i,h in ipairs(a.state.tornadoes) do near(h.phase,b.state.tornadoes[i].phase);assert(h.phase~=c.state.tornadoes[i].phase) end
end)
test("retired drill options can never restore wind, cysts or forced movement",function()
    assert(#EL.Sszorak.drills==1 and EL.Sszorak.drills[1]=="tempest")
    for _,old in ipairs({"wind","combined","tempest","bad"}) do
        local s=sim(old);nocollisions(s)
        assert(s.drill=="tempest" and #s.state.tornadoes==36)
        advance(s,40)
        assert(not s.state.cysts and not s.state.tunnels and not s.state.windIndex)
        near(s.state.player.x,0);near(s.state.player.y,-8)
    end
end)
test("all drill checkpoints finish on their own timeline",function()
    for _,d in ipairs(EL.Sszorak.drills) do
        for i,t in ipairs(EL.Sszorak.Checkpoints(d)) do
            local s=sim(d,i);nocollisions(s)
            near(s.state.time,t)
            advance(s,70,nil,144)
            near(s.state.time,s.duration);near(s.state.elapsed,s.duration-t)
            near(s.state.aliveTime+s.state.deadTime,s.state.elapsed)
            local r=s:GetResult();assert(r and r.version==s.version and r.loop==1)
        end
    end
end)
test("relative swept contact catches crossing a tornado between samples",function()
    local s=sim("tempest")
    s.state.tornadoes={{id=1,active=true,x=0,y=0,previousX=0,previousY=0,radius=2.2}}
    s._previousX,s._previousY=-5,0;s.state.player.x,s.state.player.y=5,0
    s:_checkHazards();assert(s.state.player.dead and s.state.failure.reason=="Tempest tornado")
end)
test("platform fall is unranked and revive returns to safety",function()
    local s=sim("wind",2);s.state.player.x=43;s:_checkHazards()
    assert(s.state.arenaExit and s.state.player.dead)
    assert(s:Revive());near(s.state.player.x,0);near(s.state.player.y,-8)
end)
test("tornado positions and unforced movement agree across frame rates",function()
    local ref
    for _,hz in ipairs({30,60,144,240}) do
        local s=sim("tempest",2);nocollisions(s)
        advance(s,4,nil,hz)
        if not ref then ref=s else
            near(s.state.player.x,ref.state.player.x);near(s.state.player.y,ref.state.player.y)
            for i,h in ipairs(s.state.tornadoes) do near(h.x,ref.state.tornadoes[i].x);near(h.y,ref.state.tornadoes[i].y) end
        end
    end
end)
test("new scenario reuses accepted facing and immediate planar movement",function()
    local a,b=sim("tempest"),EL.Simulation.New({})
    nocollisions(a);nocollisions(b)
    a.state.player.x,a.state.player.y,b.state.player.x,b.state.player.y=0,0,0,0
    for i=1,120 do
        local yaw=i*.005
        a:SetPlayerFacing(yaw);b:SetPlayerFacing(yaw)
        local input={forward=1,strafe=1,lockFacing=true}
        a:Advance(1/240,input);b:Advance(1/240,input)
        near(a.state.player.x,b.state.player.x);near(a.state.player.y,b.state.player.y)
    end
end)
test("replay retains at most six seconds and a bounded number of frames",function()
    for _,hz in ipairs({20,60,144}) do
        local s=sim("tempest");nocollisions(s);local r=EL.Rehearsal.New(s)
        for i=1,hz*9 do s:Advance(1/hz,{});r:Capture(s) end
        local lo,hi=r:Bounds()
        assert(hi-lo<=6.00001 and hi-lo>5.8 and r.count<=182)
    end
end)
test("failure freezes history including the exact collision frame",function()
    local s=sim("tempest");local r=EL.Rehearsal.New(s)
    nocollisions(s);advance(s,1);r:Capture(s)
    s._checkHazards=sim("tempest")._checkHazards
    s.state.player.x=44;s:_checkHazards();r:Capture(s)
    assert(r.frozen and r.failure.reason=="Fell off the platform")
    local count=r.count;advance(s,1);r:Capture(s);assert(count==r.count)
    local _,hi=r:Bounds();near(hi,1)
end)
test("replay seeking is observational and does not reveal future deaths",function()
    local s=sim("tempest");nocollisions(s);local r=EL.Rehearsal.New(s)
    advance(s,.1,{forward=1});r:Capture(s)
    local x,y,time=s.state.player.x,s.state.player.y,s.state.time
    local halfway=r:Sample(.05)
    near(halfway.player.y,-8+(y+8)*.5)
    halfway.player.x=100;near(s.state.player.x,x);near(s.state.time,time)
    s.state.failureSerial=1;s.state.failure={serial=1,reason="Tempest tornado",time=.1,x=x,y=y};s.state.player.dead=true;r:Capture(s)
    assert(not r:Sample(.05).player.dead)
    assert(r:Sample(.1).player.dead)
end)
test("checkpoint restores exact state without sharing mutable tables",function()
    local s=sim("combined",2);nocollisions(s);local r=EL.Rehearsal.New(s)
    local initialX=s.state.player.x
    advance(s,1,{forward=1});r:Capture(s)
    s.state.tornadoes[1].x=30;s.state.abilities.cooldowns.blink=900
    local retry=r:Retry()
    assert(retry.rewound and retry.state.assisted and retry.state.status=="running")
    near(retry.state.player.x,initialX);near(retry.state.time,16)
    assert(not retry.state.abilities.cooldowns.blink and retry.state.tornadoes[1].x~=30)
    advance(retry,60);assert(not retry:GetResult().highscoreEligible)
    assert(s.state.tornadoes[1].x==30)
end)
test("saved options sanitize unknown scenarios and checkpoint ranges",function()
    EL.Store.Initialize(nil)
    local o=EL.Store.SaveOptions({scenario="sszorak",sszorakDrill="tempest",sszorakCheckpoint=99})
    assert(o.scenario=="sszorak" and o.sszorakCheckpoint==3)
    o=EL.Store.SaveOptions({scenario="bad",sszorakDrill="bad",sszorakCheckpoint=-20})
    assert(o.scenario=="rashok" and o.sszorakDrill=="tempest" and o.sszorakCheckpoint==1)
end)
test("highscores separate encounters, drills and starting checkpoints",function()
    EL.Store.Initialize(nil)
    for _,d in ipairs(EL.Sszorak.drills) do
        for i=1,#EL.Sszorak.Checkpoints(d) do
            local s=sim(d,i);nocollisions(s);s._moveWaves=function() end
            advance(s,70)
            local record=EL.Store.RecordResult(s:GetResult());assert(record.saved and record.rank==1)
            assert(#EL.Store.GetBoard("reference",1,nil,s.version)==1)
        end
    end
    assert(#EL.Store.GetBoard("reference",1,nil,EL.SCENARIO_VERSION)==0)
    local saved=EL.Store.db;EL.Store.Initialize(saved)
    assert(#EL.Store.GetBoard("reference",1,nil,sim("tempest",2).version)==1)
end)
test("denser Tempest ramps from four to thirty-six and its path runs 35 percent faster",function()
    local s=sim("tempest");nocollisions(s)
    local function active() local n=0;for _,h in ipairs(s.state.tornadoes) do if h.active then n=n+1 end end;return n end
    assert(active()==4 and #s.state.tornadoes==36)
    advance(s,6.01);assert(active()==8)
    local h=s.state.tornadoes[1];local age=s.state.time*1.35
    local radius=3+31*(1-math.cos(age*.24))*.5
    near(h.x,math.cos(h.phase+h.direction*age*.36)*radius)
    advance(s,42);assert(active()==36)
    assert(s.version=='sszorak-3-tempest-1','changed difficulty must never reuse the old board')
end)
print(string.format("SSZORAK %d checks; %d failed. Offline mechanics/replay proof only.",checks,failed))
if failed>0 then os.exit(1) end
