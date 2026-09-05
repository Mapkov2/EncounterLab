local base=(arg and arg[1]) or 'EncounterLab/'
local EL={Sszorak={tornadoCapacity=36}};assert(loadfile(base..'TempestRenderer.lua'))('EncounterLab',EL)
local now,actors,lines,reject,loaded=0,{},0,false,true
function GetTime() return now end
local function newLine()
    lines=lines+1
    return {SetColorTexture=function() end,SetThickness=function() end,Hide=function(self) self.shown=false end}
end
local scene={CreateActor=function(_,name,template)
    assert(template=='ModelSceneActorTemplate' and name~='')
    local a={calls=0}
    function a:SetScale(s) self.scale=s end
    function a:SetModelByFileID(id) self.fileID=id;return not reject end
    function a:IsLoaded() return loaded end
    function a:SetPosition(x,y,z) self.x,self.y,self.z=x,y,z end
    function a:SetAnimation(id,variation,speed,offset) self.animation,self.speed,self.offset=id,speed,offset;self.calls=self.calls+1 end
    function a:Show() self.shown=true end
    function a:Hide() self.shown=false end
    actors[#actors+1]=a;return a
end}
local renderer={frame=scene,ground={CreateLine=newLine},diagnostics={},DrawRing=function(_,r) for _,l in ipairs(r.lines) do l.shown=true end end}
function renderer:DrawWorldLine() end
local checks,failures=0,0
local function test(name,fn)
    checks=checks+1;local ok,e=pcall(fn)
    print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(e)))
    if not ok then failures=failures+1 end
end
local fx,state
test('Tempest owns thirty-seven native effects, with no line spiral',function()
    fx=EL.TempestRenderer.New(renderer)
    assert(#actors==37 and lines==668)
    assert(actors[1].fileID==2529592 and actors[37].fileID==7637242)
    assert(not fx.tornadoes[1].spiral)
    state={time=0,status='running',boss={x=0,y=0,casting=true,castStarts=0},tornadoes={{id=1,x=10,y=-5,active=true,birth=0,radius=2.2}}}
    fx:Draw(renderer,state)
    assert(actors[1].shown and actors[37].shown)
    assert(math.abs(actors[1].x*actors[1].scale-10)<1e-9)
end)
test('native animation advances without restarting every render',function()
    state.time=.5;fx:Draw(renderer,state);assert(actors[1].calls==1)
    state.time=1.2;state.boss.casting=false;fx:Draw(renderer,state)
    assert(actors[1].animation==158 and actors[1].calls==2 and not actors[37].shown)
    state.time=1.3;fx:Draw(renderer,state);assert(actors[1].calls==2)
    assert(#actors==37 and lines==668)
end)
test('native effects pause, resume and seek with the replay clock',function()
    state.status='paused';fx:Draw(renderer,state);assert(actors[1].speed==0)
    state.status='running';state.speed=.5;fx:Draw(renderer,state);assert(actors[1].speed==.5)
    state.time=3;state.playbackSpeed=.25;fx:Draw(renderer,state,{count=0})
    assert(actors[1].speed==.25 and actors[1].offset==2)
    state.time=2;state.playbackSpeed=0;fx:Draw(renderer,state,{count=0})
    assert(actors[1].speed==0 and actors[1].offset==1)
end)
test('models hide after encounter switch and restart for a new run',function()
    fx:Hide();assert(not actors[1].shown and not actors[37].shown)
    state.time=0;state.boss.casting=true;state.tornadoes[1]={id=1,x=0,y=0,active=true,birth=0,radius=2.2}
    local calls=actors[1].calls;fx:Draw(renderer,state);assert(actors[1].shown and actors[1].calls==calls+1)
end)
test('loading or rejected models leave visible collision footprints',function()
    loaded=false;local pending=EL.TempestRenderer.New(renderer)
    pending:Draw(renderer,state)
    assert(pending.tornadoes[1].base.lines[1].shown and not pending.tornadoes[1].actor.shown)
    loaded=true;now=1;pending:Draw(renderer,state)
    assert(pending.tornadoes[1].actor.shown and not pending.tornadoes[1].base.lines[1].shown)
    reject=true;local missing=EL.TempestRenderer.New(renderer);missing:Draw(renderer,state)
    assert(missing.tornadoes[1].base.lines[1].shown and not missing.tornadoes[1].actor.shown)
end)
print(string.format('TEMPEST RENDERER %d checks; %d failed. Native API mock proof only.',checks,failures))
if failures>0 then os.exit(1) end
