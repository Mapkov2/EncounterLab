local base=(arg and arg[1]) or 'EncounterLab/'
local EL={}
for _,file in ipairs({'Namespace.lua','Simulation.lua','TwinFangs.lua','Rehearsal.lua','Persistence.lua'}) do assert(loadfile(base..file))('EncounterLab',EL) end
local T=EL.TwinFangs
local checks,failed=0,0
local function test(name,fn)
    checks=checks+1;local ok,err=pcall(fn)
    print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)))
    if not ok then failed=failed+1 end
end
local function near(a,b) assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b)) end
local function new(seed) return T.New({seed=seed or 8137}) end
local function advance(s,seconds,input,hz)
    local goal=s.state.elapsed+seconds
    while s.state.elapsed<goal-1e-8 and s.state.status=='running' do s:Advance(math.min(1/(hz or 60),goal-s.state.elapsed),input) end
end
local function noHits(s) s._checkHazards=function() end end
test('seed preserves direction, initial pose and storm; different seeds vary both directions',function()
    local a,b=new(),new();local directions,headings={},{}
    for i=1,100 do local s=new(i*17419).state;directions[s.direction]=true;headings[s.beamStart]=true end
    assert(directions[-1] and directions[1]);local count=0;for _ in pairs(headings) do count=count+1 end;assert(count>90)
    near(a.state.player.x,b.state.player.x)
    for i,h in ipairs(a.state.impacts) do local k=b.state.impacts[i];near(h.x,k.x);near(h.y,k.y);near(h.impact,k.impact) end
end)
test('warning, full channel, storm and pool cleanup use exact endpoints',function()
    local s=new();noHits(s)
    advance(s,3.99);assert(not s.state.beamActive and s.state.flood)
    advance(s,.02);assert(s.state.beamActive)
    advance(s,13.99);near(s.state.time,18);assert(not s.state.beamActive and not s.state.flood)
    advance(s,10);near(s.state.time,24);assert(s.state.status=='finished')
    for _,h in ipairs(s.state.impacts) do assert(not h.warning and not h.pool) end
    local r=s:GetResult();assert(r.perfect and r.version==T.VERSION and r.highscoreEligible)
    near(r.elapsed,24);near(r.aliveTime+r.deadTime,r.elapsed)
end)
test('beam catches crossing between samples and does not hit behind the boss',function()
    assert(T.BeamContact(20,-6,20,6,0,0))
    assert(T.BeamContact(20,0,20,0,-.15,.15))
    assert(not T.BeamContact(-20,-6,-20,6,0,0))
    assert(not T.BeamContact(20,8,21,8,0,.01))
    assert(T.BeamContact(-20,6,-20,-6,math.pi,math.pi+.02))
end)
test('standing in warning sector is safe until the cast completes',function()
    local s=new();s.state.impacts={};s.state.beamStart=0
    s.state.player.x,s.state.player.y=24,0
    advance(s,3.99);assert(not s.state.player.dead)
    advance(s,.02);assert(s.state.player.dead and s.state.failure.reason=='Vile Flood')
end)
test('impact warning is harmless and collision begins at its deadline',function()
    local s=new();s.state.impacts={{id=1,placed=true,x=0,y=-20,spawn=0,impact=1.5,expires=7.5,radius=4}}
    s.state.player.x,s.state.player.y=0,-20
    advance(s,1.49);assert(not s.state.player.dead)
    advance(s,.02);assert(s.state.player.dead and s.state.failure.reason=='Sanguine Storm')
end)
test('leaving an impact before detonation succeeds; entering a live pool fails',function()
    local s=new();s.state.impacts={{id=1,placed=true,x=0,y=-20,spawn=0,impact=1.5,expires=7.5,radius=4}}
    s.state.player.x,s.state.player.y=0,-20;s:SetPlayerFacing(0)
    advance(s,1.51,{forward=1});assert(not s.state.player.dead)
    s.state.player.x,s.state.player.y=0,-20
    advance(s,.02);assert(s.state.player.dead and s.state.failure.reason=='Congealed Gore')
end)
test('pool sweep catches traversal and expired pools cannot hit',function()
    local s=new();s.state.impacts={{id=1,placed=true,x=0,y=-20,impact=1,expires=2,radius=4}}
    s._previousX,s._previousY=-10,-20;s.state.player.x,s.state.player.y=10,-20
    s._fromTime,s.state.time=1.4,1.5;s:_checkHazards();assert(s.state.player.dead)
    local b=new();b.state.impacts=s.state.impacts;b._previousX,b._previousY=-10,-20;b.state.player.x,b.state.player.y=10,-20
    b._fromTime,b.state.time=2.1,2.2;b:_checkHazards();assert(not b.state.player.dead)
end)
test('player bait locks at warning start, not at impact',function()
    local s=new();noHits(s);local first=s.state.impacts[1];local x,y=first.x,first.y
    s:SetPlayerFacing(0);advance(s,1,{forward=1});near(first.x,x);near(first.y,y)
    advance(s,.5,{forward=1});local nextBait=s.state.impacts[5]
    assert(nextBait.placed);near(nextBait.x,s.state.player.x);near(nextBait.y,s.state.player.y)
end)
test('simulation and storm agree across 30, 60, 144 and 240 fps',function()
    local ref
    for _,hz in ipairs({30,60,144,240}) do
        local s=new();noHits(s);s:SetPlayerFacing(0);advance(s,3,{forward=1},hz)
        if ref then
            near(s.state.player.x,ref.state.player.x);near(s.state.beamYaw,ref.state.beamYaw)
            for i,h in ipairs(s.state.impacts) do near(h.x,ref.state.impacts[i].x);near(h.y,ref.state.impacts[i].y) end
        else ref=s end
    end
end)
test('accepted RMB-facing and strafe movement are shared without retuning',function()
    local a,b=new(),EL.Simulation.New({});noHits(a);noHits(b)
    a.state.player.x,a.state.player.y,b.state.player.x,b.state.player.y=0,0,0,0
    for i=1,120 do
        local yaw=i*.006;a:SetPlayerFacing(yaw);b:SetPlayerFacing(yaw)
        local input={forward=1,strafe=-1,lockFacing=true}
        a:Advance(1/240,input);b:Advance(1/240,input)
        near(a.state.player.x,b.state.player.x);near(a.state.player.y,b.state.player.y)
    end
end)
test('pause and invalid elapsed cannot produce ranked normal results',function()
    local s=new();noHits(s);s:SetPaused(true);s:Advance(.2);near(s.state.elapsed,0)
    s:SetPaused(false);advance(s,25);assert(s:GetResult().assisted)
    local b=new();b:Advance(.6);assert(b.state.status=='paused' and b.state.interrupted)
end)
test('arena exit, revive and checkpoint retries cannot create a clean score',function()
    local s=new();local replay=EL.Rehearsal.New(s);advance(s,.2)
    s.state.player.x=50;s:_checkHazards();assert(s.state.arenaExit and s.state.player.dead)
    replay:Capture(s);assert(replay.frozen and replay:Sample(s.state.time).scenario=='twinfangs')
    assert(s:Revive() and s.state.assisted)
    local retry=replay:Retry();assert(retry.rewound and retry.state.assisted and not retry.state.player.dead)
    near(retry.state.time,0);noHits(retry);advance(retry,24);assert(not retry:GetResult().highscoreEligible)
    noHits(s);advance(s,24);assert(not s:GetResult().highscoreEligible)
end)
test('saved selection and scores are isolated from existing encounters',function()
    EL.Store.Initialize({});EL.Store.SaveOptions({scenario='twinfangs'})
    assert(EL.Store.GetOptions().scenario=='twinfangs')
    local s=new();noHits(s);advance(s,24);local record=EL.Store.RecordResult(s:GetResult());assert(record.rank)
    assert(#EL.Store.GetBoard('reference',1,nil,T.VERSION)==1)
    assert(#EL.Store.GetBoard('reference',1,nil,EL.SCENARIO_VERSION)==0)
end)
print(string.format('TWIN FANGS %d checks; %d failed. Offline simulation proof only.',checks,failed))
if failed>0 then os.exit(1) end
