local base=(arg and arg[1]) or "EncounterLab/"
local EL={}
for _,file in ipairs({"Namespace.lua","Simulation.lua","Sentinels.lua","Persistence.lua"}) do assert(loadfile(base..file))("EncounterLab",EL) end
local checks,failed=0,0
local function test(name,fn)
    checks=checks+1;local ok,err=pcall(fn)
    print((ok and "PASS " or "FAIL ")..name..(ok and "" or ": "..tostring(err)))
    if not ok then failed=failed+1 end
end
local function sim(number,seed,mode)
    return EL.Sentinels.New({sentinelsNumber=number,seed=seed or 12345,mode=mode})
end
local function advance(s,seconds)
    local goal=s.state.elapsed+seconds
    while s.state.elapsed<goal-1e-8 and s.state.status=="running" do s:Advance(math.min(1/60,goal-s.state.elapsed),{}) end
end
local function solve(s,hz)
    hz=hz or 60
    local threes={}
    for _,r in ipairs(s.state.raiders) do if r.stacks==3 then threes[#threes+1]=r end end
    while s.state.status=="running" do
        local r=s.state.raiders[s.state.playerIndex];local p=s.state.player
        local input={}
        if s.state.applied and r.stacks>0 then
            if r.stacks==1 then input.jump=math.floor(s.state.time*2)%2==0;if not r.pingAt then s:Ping() end
            else
                local x,y,target=EL.Sentinels.BotDestination(s.state,r)
                if x then
                    x,y=EL.Sentinels.Route(s.state,r,x,y,target)
                    local dx,dy=x-p.x,y-p.y
                    input={forward=dx*dx+dy*dy>.01 and 1 or 0,yaw=math.atan2(dy,dx),lockFacing=true}
                end
            end
        end
        s:Advance(1/hz,input)
        for _,r in ipairs(threes) do
            local x,y=r.previousX,r.previousY;local dx,dy=r.x-x,r.y-y
            local length=dx*dx+dy*dy
            local t=length>0 and math.max(0,math.min(1,-(x*dx+y*dy)/length)) or 0
            assert((x+t*dx)^2+(y+t*dy)^2>=EL.Sentinels.centerRadius^2-1e-6,'a 3 crossed the reserved middle')
        end
        assert(s.state.elapsed<34)
    end
    return s:GetResult()
end
test("two distinct 10-player sides, unsorted balanced assignments and deterministic seed",function()
    for role=1,3 do
        local a,b=sim(role),sim(role);assert(#a.state.raiders==20)
        local counts={0,0,0};local sides={{0,0,0},{0,0,0}}
        for i,r in ipairs(a.state.raiders) do
            counts[r.stacks]=counts[r.stacks]+1
            assert(r.x==b.state.raiders[i].x and r.y==b.state.raiders[i].y)
            sides[r.group][r.stacks]=sides[r.group][r.stacks]+1
            assert(r.partner==nil and r.target==nil, 'preassigned matching survived')
            local home=a.state.groups[r.group]
            assert((r.x-home.x)^2+(r.y-home.y)^2<16^2)
            assert((r.group==1 and r.x<-8) or (r.group==2 and r.x>8))
        end
        assert(counts[1]==counts[3] and counts[1]>=4 and counts[1]<=7 and counts[2]==20-2*counts[1])
        for _,side in ipairs(sides) do assert(side[1]>0 and side[2]>0 and side[3]>0 and side[1]~=side[3]) end
        assert(a.state.groups[2].x-a.state.groups[1].x>40)
        assert(a.state.raiders[a.state.playerIndex].stacks==role)
    end
end)
test("brief reveal conceals every other stack count while own count remains visible",function()
    local s=sim(3);local own=s.state.raiders[s.state.playerIndex]
    assert(not EL.Sentinels.VisibleNumber(s.state,own));advance(s,3.1)
    for _,r in ipairs(s.state.raiders) do assert(EL.Sentinels.VisibleNumber(s.state,r)==r.stacks) end
    advance(s,2)
    for _,r in ipairs(s.state.raiders) do assert(EL.Sentinels.VisibleNumber(s.state,r)==(r.isPlayer and 3 or nil)) end
    assert(not own.pingUntil)
end)
test("concealed 1 must ping to attract a 3; no assigned-partner knowledge",function()
    local s=sim(1);local own=s.state.raiders[s.state.playerIndex]
    local partner
    for _,r in ipairs(s.state.raiders) do
        if r~=own and r.group==own.group and not partner then partner=r else if r~=own then r.stacks=0 end end
    end
    local home=s.state.groups[own.group]
    own.x,own.y=home.x,home.y-8;s.state.player.x,s.state.player.y=own.x,own.y
    partner.x,partner.y,partner.stacks=home.x,home.y+8,3
    advance(s,15)
    assert(own.stacks==1 and partner.stacks==3 and not partner.target and not s.state.matchTime)
    assert(s:Ping());assert(own.pingUntil>s.state.time)
    local result=solve(s)
    assert(result.perfect and result.highscoreEligible)
end)
test("correct strategy clears all 20 across roles and seeded layouts",function()
    for role=1,3 do for seed=1,tonumber(arg and arg[2]) or 30 do
        local s=sim(role,seed*571);local result=solve(s)
        assert(result.perfect and result.highscoreEligible,"role "..role.." seed "..seed.." cleared "..s.state.cleared.." reason "..tostring(s.state.failure))
        assert(result.matchTime>0 and result.matchTime<30)
    end end
end)
test("all 2s use the shared center; 3s can seek a ping across camps",function()
    local sim=sim(3);local state=sim.state;state.time=6;state.applied=true
    for _,r in ipairs(state.raiders) do
        if r.stacks==2 then local x,y=EL.Sentinels.BotDestination(state,r);assert(x==0 and y==0)
        elseif r.stacks==3 then assert(EL.Sentinels.BotDestination(state,r)==nil) end
    end
    local seeker=state.raiders[state.playerIndex];local target
    for _,r in ipairs(state.raiders) do if r.stacks==1 and r.group~=seeker.group then target=r;break end end
    target.pingAt=6;target.pingUntil=10
    local x,y,found=EL.Sentinels.BotDestination(state,seeker)
    assert(found==target and x==target.x and y==target.y)
    state.time=11;local _,_,remembered=EL.Sentinels.BotDestination(state,seeker);assert(remembered==target)
    target.stacks=0;assert(EL.Sentinels.BotDestination(state,seeker)==nil)
end)
test("bosses move on reveal and reach the same center in preview, running and pause",function()
    local sim=sim(1);local state=sim.state
    for i=1,2 do
        state.time=0;local x,y,moving=EL.Sentinels.BossPosition(state,i)
        assert(x==EL.Sentinels.bossPositions[i].x and y==0 and not moving)
        state.time=4;x,y,moving=EL.Sentinels.BossPosition(state,i);assert(math.abs(x)==13 and moving)
        state.status="paused";local paused=EL.Sentinels.BossPosition(state,i);assert(paused==x)
        state.status="running";state.time=5;x,y,moving=EL.Sentinels.BossPosition(state,i)
        assert(math.abs(x)==3 and y==0 and not moving)
    end
    assert(state.groups[1].x==-23 and state.groups[2].x==23, "boss travel moved the raid spawn camps")
end)

test("visible nearby 1+3 can match early, without a private assigned partner",function()
    local s=sim(3);local state=s.state;state.time=3.5;state.applied=true
    local seeker=state.raiders[state.playerIndex];local target
    for _,r in ipairs(state.raiders) do if r.stacks==1 and r.group==seeker.group then target=r;break end end
    target.x,target.y=seeker.x+3,seeker.y
    assert(EL.Sentinels.BotDestination(state,seeker)==nil)
    target.pingAt=state.time
    local _,_,found=EL.Sentinels.BotDestination(state,seeker)
    assert(found==target and not target.pingUntil)
    state.time=6
    local _,_,remembered=EL.Sentinels.BotDestination(state,seeker);assert(remembered==target, 'announced target forgotten after reveal')
end)
test("role assignment changes with seed, not with a fixed spatial slot",function()
    local a=sim(1,111);local different=false
    for seed=112,120 do
        local b=sim(1,seed)
        for i,r in ipairs(a.state.raiders) do if r.stacks~=b.state.raiders[i].stacks then different=true end end
    end
    assert(different)
end)
test("live raid groups do not share the preview layout or another run",function()
    local a,b=sim(1),sim(1)
    for i,position in ipairs(EL.Sentinels.bossPositions) do
        assert(a.state.groups[i]~=position and a.state.groups[i]~=b.state.groups[i])
        assert(a.state.groups[i].x==position.x and a.state.groups[i].y==position.y)
    end
    a.state.groups[1].x=0
    assert(b.state.groups[1].x==-23 and EL.Sentinels.bossPositions[1].x==-23)
end)
local function collision(a,b)
    local s=sim(a);local own=s.state.raiders[s.state.playerIndex]
    for _,r in ipairs(s.state.raiders) do r.x,r.y,r.previousX,r.previousY=60+r.id*4,0,60+r.id*4,0;r.stacks=0 end
    local other=s.state.raiders[own.id==1 and 2 or 1]
    own.x,own.y,own.previousX,own.previousY=0,0,0,0
    other.x,other.y,other.previousX,other.previousY=.5,0,.5,0
    own.stacks,other.stacks=a,b;s.state.player.x,s.state.player.y=0,0
    s.state.applied=true;s.state.time=6
    if a==1 then own.pingAt,own.jumpedAt=6,6 end -- Arithmetic tests isolate the contact rule.
    s:_checkHazards()
    return s,own,other
end
test("1+3 and 2+2 clear both participants",function()
    for _,pair in ipairs({{1,3},{2,2},{3,1}}) do
        local s,a,b=collision(pair[1],pair[2]);assert(a.stacks==0 and b.stacks==0 and not s.state.player.dead)
    end
end)
test("wrong contact 3+2 and 3+3 wipes all 20 and cannot be revived",function()
    for _,pair in ipairs({{3,2},{3,3}}) do
        local s,a,b=collision(pair[1],pair[2]);assert(a.dead and b.dead and s.state.player.dead)
        assert(s.state.lastAddition==pair[1]+pair[2] and not s:Revive())
        assert(s.state.wipe and s.state.status=="finished" and s.state.raidDeaths==20)
        for _,r in ipairs(s.state.raiders) do assert(r.dead) end
        assert(not s:GetResult().highscoreEligible)
    end
end)
test("all nine active stack pairings either clear exactly four or immediately wipe",function()
    for first=1,3 do for second=1,3 do
        local s,a,b=collision(first,second)
        if first+second==4 then
            assert(not s.state.wipe and a.stacks==0 and b.stacks==0)
            assert(not a.dead and not b.dead and not s.state.player.dead)
        else
            assert(s.state.wipe and s.state.status=="finished" and s.state.raidDeaths==20)
            assert(s.state.failure=="Contact did not total 4" and s.state.lastAddition==first+second)
            assert(a.stacks==first and b.stacks==second,'wrong sums must not create new stack assignments')
            for _,r in ipairs(s.state.raiders) do assert(r.dead) end
            assert(not s:GetResult().highscoreEligible)
        end
    end end
end)
test("swept contact catches crossing between frames",function()
    local s,a,b=collision(2,2);s.contacts={};a.stacks,b.stacks=1,3;a.pingAt,a.jumpedAt=6,6
    a.previousX,a.x=-4,4;b.previousX,b.x=4,-4;s:_checkHazards()
    assert(a.stacks==0 and b.stacks==0)
end)
test("timeout fails the attempt and receives no rank",function()
    local s=sim(2);s._moveWaves=function() end;advance(s,33)
    local result=s:GetResult();assert(s.state.failure=="Toxins expired" and not result.highscoreEligible and not result.perfect)
end)
test("pause freezes bots, timers and pings; movement abilities cannot solve toxins",function()
    local s=sim(1);advance(s,3.1);assert(s:Ping());s:SetPaused(true)
    local t=s.state.time;local r=s.state.raiders[1];local x,y=r.x,r.y
    s:Advance(1,{});assert(s.state.time==t and x==r.x and y==r.y and not s:Ping())
    assert(not s:UseAbility("immunity") and not s:UseAbility("blink"))
    s:SetPaused(false);assert(s.state.assisted)
end)
test("normal reveal is fixed and practice reveal has independent version",function()
    assert(EL.Sentinels.Reveal({mode="reference",sentinelsReveal=5})==2)
    assert(EL.Sentinels.Reveal({mode="practice",sentinelsReveal=5})==5)
    assert(EL.Sentinels.Version({mode="practice",sentinelsReveal=5})~=EL.Sentinels.Version({mode="practice",sentinelsReveal=2}))
end)
test("successful scores preserve matching time and partition by role",function()
    EL.Store.Initialize({})
    local result=solve(sim(1));local record=EL.Store.RecordResult(result)
    assert(record.saved and record.rank==1 and record.entry.matchTime==result.matchTime)
    local slower={};for k,v in pairs(result) do slower[k]=v end;slower.matchTime=result.matchTime+1
    EL.Store.RecordResult(slower)
    local board=EL.Store.GetBoard("reference",1,nil,result.version)
    assert(#board==2 and board[1].matchTime<board[2].matchTime)
    assert(#EL.Store.GetBoard("reference",1,nil,EL.Sentinels.Version({sentinelsNumber=2}))==0)
end)
test("30, 60 and 144 Hz all complete the strategy without changing movement",function()
    for _,hz in ipairs({30,60,144}) do for role=1,3 do assert(solve(sim(role,314159),hz).perfect) end end
end)
test("random roles cover both camps and all numbers, reproduce by seed, and vary composition",function()
    local seen,counts={},{}
    for seed=1,120 do
        local a,b=sim(0,seed*571),sim(0,seed*571)
        local r=a.state.raiders[a.state.playerIndex]
        assert(a.state.playerIndex==b.state.playerIndex and a.state.playerNumber==b.state.playerNumber)
        seen[r.stacks..":"..r.group]=true;counts[a.state.assignmentCounts[1]]=true
        assert(a.version:find("sentinels%-9%-0%-"))
        if seed<=30 then assert(solve(a).perfect, "random role failed seed "..seed) end
    end
    for n=1,3 do for camp=1,2 do assert(seen[n..":"..camp]) end end
    for n=4,7 do assert(counts[n]) end
end)
test("unannounced player 1 is never acquired even during visible reveal",function()
    local sim=sim(1);local state=sim.state;state.applied=true;state.time=3.5
    local own=state.raiders[state.playerIndex];local seeker
    for _,r in ipairs(state.raiders) do if r.stacks==3 then seeker=r;break end end
    for _,r in ipairs(state.raiders) do if r~=own and r~=seeker then r.stacks=0 end end
    seeker.x,seeker.y=own.x+3,own.y
    assert(EL.Sentinels.BotDestination(state,seeker)==nil)
    assert(sim:Ping());local _,_,target=EL.Sentinels.BotDestination(state,seeker);assert(target==own)
end)
test("NPC ones ping and repeatedly jump; threes seek instead of announcing",function()
    local sim=sim(2);sim._checkHazards=function() end
    advance(sim,4.5)
    local jumps={}
    for step=1,90 do
        sim:Advance(1/60,{})
        for _,r in ipairs(sim.state.raiders) do
            if not r.isPlayer and r.stacks==1 then
                assert(r.pingAt and not r.moving)
                jumps[r.id]=jumps[r.id] or {low=false,high=false}
                if r.z==0 then jumps[r.id].low=true end
                if r.z>.8 then jumps[r.id].high=true end
            elseif r.stacks==3 then assert(not r.pingAt) end
        end
    end
    for _,height in pairs(jumps) do assert(height.low and height.high) end
    assert(next(jumps))
end)
test("a single player ping attracts a 3 through repeated jumping across layouts",function()
    for _,pingTime in ipairs({3.1,8.1}) do for seed=1,20 do
        local sim=sim(1,seed*571);local sent=false;local acquired=false
        while sim.state.status=="running" do
            if not sent and sim.state.time>=pingTime then assert(sim:Ping());sent=true end
            sim:Advance(1/60,{jump=math.floor(sim.state.time*2)%2==0})
            for _,r in ipairs(sim.state.raiders) do if r.target==sim.state.playerIndex then acquired=true end end
        end
        assert(sent and acquired and sim.state.matchTime and not sim.state.player.dead,
            "one click failed at "..pingTime.." seed "..seed)
        assert(sim:GetResult().perfect)
    end end
end)
test("distant 3 responds immediately to one announcement and drops invalid targets",function()
    local sim=sim(1);local state=sim.state;state.applied=true;state.time=3.1
    local own=state.raiders[state.playerIndex];local seeker
    for _,r in ipairs(state.raiders) do if r.stacks==3 then seeker=r;break end end
    seeker.x,seeker.y=own.x+20,own.y
    assert(sim:Ping())
    local _,_,found=EL.Sentinels.BotDestination(state,seeker);assert(found==own)
    state.time=12
    local _,_,remembered=EL.Sentinels.BotDestination(state,seeker);assert(remembered==own)
    own.dead=true;assert(EL.Sentinels.BotDestination(state,seeker)==nil)
end)
test("NPC underflow and overflow wipe an already-cleared player too",function()
    for _,numbers in ipairs({{1,1},{1,2},{2,1},{2,3},{3,2},{3,3}}) do
    local s=sim(1);local own=s.state.raiders[s.state.playerIndex];local pair={}
    for _,r in ipairs(s.state.raiders) do
        r.stacks=0;r.x,r.y,r.previousX,r.previousY=r.id*4,20,r.id*4,20
        if r~=own and #pair<2 then pair[#pair+1]=r end
    end
    s.state.player.x,s.state.player.y=0,20
    own.x,own.y,own.previousX,own.previousY=0,20,0,20
    for i,r in ipairs(pair) do r.stacks=numbers[i];r.x,r.previousX=i*.3,i*.3;r.y,r.previousY=0,0 end
    s.state.applied=true;s:_checkHazards()
    assert(s.state.wipe and own.dead and s.state.player.dead and s.state.raidDeaths==20)
    end
end)

test("moving into close crossing traffic causes a swept raid wipe",function()
    local s=sim(2);local own=s.state.raiders[s.state.playerIndex];local peers={}
    for _,r in ipairs(s.state.raiders) do r.stacks=0;if r~=own and #peers<2 then peers[#peers+1]=r end end
    local seeker,target=peers[1],peers[2]
    own.stacks,own.x,own.y=2,0,12
    seeker.stacks,seeker.x,seeker.y=3,-3,13.6
    target.stacks,target.x,target.y=1,3,13.6
    local x,y=EL.Sentinels.Route(s.state,seeker,target.x,target.y,target)
    assert(x==target.x and y==target.y,'bots must not open an oversized safe corridor around the user')
    own.previousX,own.previousY,own.y=0,12,12.6
    seeker.previousX,seeker.previousY,seeker.x=-3,13.6,1
    target.previousX,target.previousY=target.x,target.y
    s.state.player.x,s.state.player.y=0,12.6;s.state.applied=true;s:_checkHazards()
    assert(s.state.wipe and s.state.failure=='Contact did not total 4')
end)

test("seeded traffic varies speed, reactions and cross-camp preferences without target jitter",function()
    local cross,total,fast,slow=0,0,false,false
    for seed=1,100 do
        local a,b=sim(2,seed*571),sim(2,seed*571)
        local s=a.state;s.time=6;s.applied=true
        for i,r in ipairs(s.raiders) do
            local twin=b.state.raiders[i]
            assert(r.runSpeed==twin.runSpeed and r.reaction==twin.reaction and r.crossCampBias==twin.crossCampBias)
            fast=fast or r.runSpeed>7.5;slow=slow or r.runSpeed<6
            for j=1,20 do assert(r.searchPriority[j]==twin.searchPriority[j]) end
            if r.stacks==1 then r.pingAt=6 end
        end
        for _,r in ipairs(s.raiders) do if r.stacks==3 then
            local _,_,target=EL.Sentinels.BotDestination(s,r);assert(target)
            total=total+1;if target.group~=r.group then cross=cross+1 end
            local _,_,again=EL.Sentinels.BotDestination(s,r);assert(again==target)
        end end
    end
    assert(fast and slow and cross/total>.4 and cross/total<.75,'mixed crossing traffic, not a fixed camp rule')
end)
local function ownOne()
    local s=sim(1);local own=s.state.raiders[s.state.playerIndex];local partner
    for _,r in ipairs(s.state.raiders) do
        if r~=own then
            r.stacks=0
            if not partner then partner=r end
        end
    end
    partner.stacks,partner.reaction,partner.x,partner.y=3,100,0,20
    partner.previousX,partner.previousY=partner.x,partner.y
    return s,own,partner
end
local function meet(s,own,partner)
    partner.x,partner.y=own.x+.5,own.y
    partner.previousX,partner.previousY=partner.x,partner.y
    own.previousX,own.previousY=own.x,own.y
    s:_checkHazards()
end
test("player 1 must perform both manual actions before a correct contact",function()
    for _,actions in ipairs({'none','ping','jump','ping-jump','jump-ping'}) do
        local s,own,partner=ownOne();advance(s,3.1)
        if actions=='ping' or actions=='ping-jump' then assert(s:Ping()) end
        if actions:find('jump',1,true) then s:Advance(1/60,{jump=true});assert(own.jumpedAt) end
        if actions=='jump-ping' then assert(s:Ping()) end
        meet(s,own,partner)
        if actions=='ping-jump' or actions=='jump-ping' then
            assert(not s.state.wipe and own.stacks==0 and s.state.matchTime)
        else
            local reason=actions=='none' and 'Missing ping and jump' or actions=='ping' and 'Missing jump' or 'Missing ping'
            assert(s.state.wipe and s.state.failure==reason and s.state.raidDeaths==20)
            assert(not s.state.matchTime and not s:GetResult().highscoreEligible)
        end
    end
end)
test("pre-reveal and paused jump input cannot satisfy the player's required jump",function()
    local s,own,partner=ownOne();advance(s,2.5)
    assert(not s:Ping())
    s:Advance(1/60,{jump=true});assert(s.state.player.jumpStartedAt<EL.Sentinels.preparation)
    advance(s,.7);assert(not own.jumpedAt);assert(s:Ping())
    s:SetPaused(true);s:Advance(.2,{jump=true});assert(not own.jumpedAt)
    s:SetPaused(false);meet(s,own,partner)
    assert(s.state.wipe and s.state.failure=='Missing jump')
end)
test("missing actions fail at expiry and restart never inherits completion",function()
    for _,action in ipairs({'none','jump','ping'}) do
        local s,own=ownOne();advance(s,3.1)
        if action=='jump' then s:Advance(1/60,{jump=true}) elseif action=='ping' then assert(s:Ping()) end
        advance(s,33)
        local reason=action=='none' and 'Missing ping and jump' or action=='ping' and 'Missing jump' or 'Missing ping'
        assert(s.state.wipe and s.state.failure==reason and not s:GetResult().highscoreEligible)
        local fresh=sim(1,s.options.seed);local r=fresh.state.raiders[fresh.state.playerIndex]
        assert(not r.pingAt and not r.jumpedAt)
    end
end)
test("opposite-camp threes take outside routes while twos retain direct center access",function()
    local sides={}
    for direction=0,7 do
        local s=sim(2);local state=s.state
        for _,r in ipairs(state.raiders) do r.stacks=0 end
        local r,target=state.raiders[direction+1],state.raiders[direction+11]
        local angle=direction*math.pi/4
        r.stacks,r.x,r.y=3,23*math.cos(angle),23*math.sin(angle)
        target.stacks,target.x,target.y=1,-r.x,-r.y
        local reached=false
        for step=1,1000 do
            local x,y=EL.Sentinels.Route(state,r,target.x,target.y,target)
            local dx,dy=x-r.x,y-r.y;local length=math.sqrt(dx*dx+dy*dy)
            if length>0 then
                local travel=math.min(length,7/60)
                local px,py=r.x,r.y
                r.x,r.y=r.x+dx/length*travel,r.y+dy/length*travel
                local sx,sy=r.x-px,r.y-py
                local t=math.max(0,math.min(1,-(px*sx+py*sy)/(sx*sx+sy*sy)))
                assert((px+t*sx)^2+(py+t*sy)^2>=EL.Sentinels.centerRadius^2-1e-6)
            end
            if r.centerSide then sides[r.centerSide]=true end
            if (r.x-target.x)^2+(r.y-target.y)^2<1 then reached=true;break end
        end
        assert(reached,'outside route must still reach the announced 1')
        r.stacks,r.x,r.y=2,23*math.cos(angle),23*math.sin(angle)
        local x,y=EL.Sentinels.Route(state,r,0,0)
        assert(x==0 and y==0,'2s still go directly to the shared center')
    end
    assert(sides[-1] and sides[1],"both outside directions remain available")
end)
test("a 3 waits outside when the target 1 enters the reserved center",function()
    local s=sim(2);local state=s.state
    for _,r in ipairs(state.raiders) do r.stacks=0 end
    local r,target=state.raiders[1],state.raiders[2]
    r.stacks,r.x,r.y=3,-10,0;target.stacks,target.x,target.y=1,0,0
    local x,y=EL.Sentinels.Route(state,r,0,0,target)
    assert(math.abs(x-r.x)<1e-8 and math.abs(y-r.y)<1e-8,'do not chase a misplaced 1 into the middle')
end)
print(string.format("SENTINELS %d cases; %d failed. Offline simulation proof only.",checks,failed))
os.exit(failed==0 and 0 or 1)
