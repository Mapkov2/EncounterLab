-- Reference state is exposed through read-only proxies. Any write or controller
-- call fails; only our diagnostic frame and its SavedVariable may be changed.
local EL={VERSION="test",L=setmetatable({},{__index=function(_,key) return key end}),Print=function() end,F=string.format}
local now,combat,reads,frames=0,false,0,0
function GetTime() return now end
function InCombatLockdown() return combat end
function GetCursorPosition() reads=reads+1;return 120,240 end
function GetCursorDelta() return .533,0 end
function GetFramerate() return 240 end
local settings={enableMouseSpeed="1",mouseSpeed="0.1",cameraYawMoveSpeed="180",cameraPitchMoveSpeed="90",mouseInvertYaw="0",mouseInvertPitch="0"}
function GetCVar(name) reads=reads+1;return settings[name] end
function SetCVar() error("diagnostic wrote a CVar") end
C_CVar={GetCVar=GetCVar,SetCVar=SetCVar}
C_AddOns={GetAddOnMetadata=function() return "reference-test" end}
function hooksecurefunc() error("diagnostic installed a hook") end
function CreateFrame(kind)
    assert(kind=="Frame");frames=frames+1
    local f={scripts={},events={}}
    function f:SetScript(key,value) self.scripts[key]=value end
    function f:RegisterEvent(key) self.events[key]=true end
    function f:UnregisterAllEvents() self.events={} end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    return f
end
local function readonly(root)
    local cache={}
    local function wrap(value)
        if type(value)~="table" then return value end
        if cache[value] then return cache[value] end
        local proxy={};cache[value]=proxy
        return setmetatable(proxy,{__index=function(_,key) return wrap(value[key]) end,
            __newindex=function() error("reference data was modified") end})
    end
    return wrap(root)
end
local shown=true
local scene={IsShown=function() return shown end,GetWidth=function() return 2560 end,
    GetHeight=function() return 1440 end,GetEffectiveScale=function() return .533333 end,
    GetCameraPosition=function() return -50,3,14 end,GetCameraForward=function() return .97,0,-.24 end,
    GetCameraFieldOfView=function() return .8 end}
local focus={position={x=10,y=20,z=0},orientation={yaw=.7}}
local camera={orientation={yaw=.7,pitch=.2},focus=focus,cdist=60,camerarotationprevmousex=119.467,camerarotationprevmousey=240}
local game={currenttime=1,keys={rmouse={current=false},lmouse={current=false}},
    environment_gameplay={cameramanager={camera=camera},modelsceneframe=scene},
    MainGameLoop=function() error("reference controller was called") end}
local reference={games={game},Config={Camera={MouseSpeed=.1}},
    CVars={cvarvalues={cameraYawMoveSpeed="180",mouseSpeed="1",enableMouseSpeed="0"}}}
local referenceProxy=readonly(reference)
assert(loadfile("EncounterLab/ReferenceTrace.lua"))("EncounterLab",EL)
assert(loadfile("EncounterLab/MouseCapture.lua"))("EncounterLab",EL)
assert(loadfile("EncounterLab/Input.lua"))("EncounterLab",EL)
local trace=EL.ReferenceTrace
local failures,checks=0,0
local function test(name,fn)
    checks=checks+1
    local ok,err=pcall(fn)
    if not ok then failures=failures+1;print("FAIL "..name..": "..tostring(err)) else print("PASS "..name) end
end
local function reset()
    trace:Stop("test_reset");trace.compareInput=nil
    EL.instance=nil;now=0;combat=false;shown=true
    XPRACTICE=referenceProxy
    XPRACTICE_SAVEDATA=readonly({Config={Camera={CameraSpeed=4.5},SCREEN_SIZE="FULLSCREEN"}})
    reference.games={game};game.dead=false;game.currenttime=1;game.keys.rmouse.current=true
    game.environment_gameplay.cameramanager.camera=camera
    settings.mouseSpeed="0.1"
end
local function tick(t)
    now=t
    local fn=trace.frame and trace.frame.scripts.OnUpdate
    if fn then fn(trace.frame,.004) end
end
test("normal addon load allocates no observer and reads no input",function()
    assert(frames==0 and reads==0 and not trace.frame)
    trace:Sample(.01);assert(reads==0)
end)
test("missing reference preserves the previous recording",function()
    EncounterLabReferenceTrace={previous=true};XPRACTICE=nil
    assert(not trace:Arm() and EncounterLabReferenceTrace.previous and frames==0)
end)
test("arming waits for a scene and RMB without touching reference state",function()
    reset();game.keys.rmouse.current=false
    assert(trace:Arm());local r=trace.record;local before=reads
    tick(1);assert(r.status=="armed" and #r.samples==0 and reads==before)
    game.keys.rmouse.current=true;shown=false;tick(2);assert(#r.samples==0)
    shown=true;tick(3);assert(r.status=="recording" and #r.samples==1)
    assert(r.configuredCameraSpeed==4.5 and r.configuredCursorSpeed==.1 and r.referenceVersion=="reference-test")
    assert(r.rememberedMouseSpeed==1 and r.rememberedMouseOverride==0)
end)
test("camera input consumed by the reference is separate from observer input",function()
    local r=trace.record;local row=r.samples[1]
    assert(#row==#r.columns and row[4]==120 and row[9]==119.467 and row[11]==.7)
    assert(row[13]==10 and row[18]==-50 and row[21]==.97 and row[24]==240)
    assert(row[25]==1 and row[26]==.1 and row[29]==0 and row[33]==.533333)
    assert(camera.orientation.yaw==.7 and focus.position.x==10)
end)
test("unchanged reference frames are not counted twice",function()
    local r=trace.record;tick(3.004);assert(#r.samples==1)
    game.currenttime=1.004;settings.mouseSpeed="0.5";tick(3.008)
    assert(#r.samples==2 and r.samples[2][26]==.5,"read actual CVar changes during capture")
end)
test("ten seconds stops all observer scripts and event registrations",function()
    local r=trace.record;tick(13)
    assert(r.status=="complete" and not trace.record and not trace.frame.shown)
    assert(next(trace.frame.scripts)==nil and next(trace.frame.events)==nil)
    local n=reads;tick(14);assert(reads==n and EncounterLabReferenceTrace==r)
end)
test("waiting timeout removes the observer",function()
    reset();reference.games={};assert(trace:Arm());local r=trace.record
    tick(180);assert(r.status=="timeout" and not trace.record and #r.samples==0)
end)
test("sample capacity independently bounds allocation",function()
    reset();assert(trace:Arm());local r=trace.record;r.limit=2
    tick(1);game.currenttime=2;tick(1.004)
    assert(#r.samples==2 and r.status=="complete" and not trace.record)
end)
test("closing or changing the reference scene stops recording",function()
    reset();trace:Arm();tick(1);local r=trace.record
    game.dead=true;tick(1.004);assert(r.status=="reference_view_changed")
    reset();trace:Arm();tick(1);r=trace.record
    game.environment_gameplay.cameramanager.camera={focus=focus,orientation={}}
    tick(1.004);assert(r.status=="reference_view_changed")
end)
test("combat and world/logout events stop the observer",function()
    for _,event in ipairs({"PLAYER_LOGOUT","PLAYER_LEAVING_WORLD","PLAYER_REGEN_DISABLED"}) do
        reset();trace:Arm();local r=trace.record
        trace.frame.scripts.OnEvent(trace.frame,event)
        assert(r.status==event and not trace.record)
    end
    reset();trace:Arm();local r=trace.record;combat=true;tick(1)
    assert(r.status=="combat");assert(not trace:Arm())
end)
test("opening EncounterLab prevents overlapping capture ownership",function()
    reset();trace:Arm();local r=trace.record
    EL.instance={frame={IsShown=function() return true end}}
    tick(1);assert(r.status=="training_view_opened" and #r.samples==0)
end)
test("unavailable optional API results leave dense numeric-or-false rows",function()
    reset();local old=scene.GetCameraPosition
    scene.GetCameraPosition=function() error("optional native getter unavailable") end
    local saved=GetCursorDelta;GetCursorDelta=function() return 0/0,math.huge end
    trace:Arm();tick(1);local r=trace.record;local row=r.samples[1]
    assert(#row==#r.columns and row[6]==false and row[7]==false and row[18]==false)
    scene.GetCameraPosition=old;GetCursorDelta=saved
end)
test("unexpected reference read failure cleans up rather than breaking either addon",function()
    reset();trace:Arm();local r=trace.record;local old=scene.IsShown
    scene.IsShown=function() error("unsupported reference shape") end
    tick(1);assert(r.status=="reference_read_failed" and not trace.frame.scripts.OnUpdate)
    scene.IsShown=old
end)
local traceRenderer={PrepareTraceStamp=function() end,HideTraceStamp=function() end}
test("comparison advances only after a completed EncounterLab recording",function()
    reset()
    local ui={options={},renderer=traceRenderer,Notice=function() end,frame={IsShown=function(self) return self.shown end}}
    function ui:Show() self.frame.shown=true end
    function ui:Hide() self.frame.shown=false;self.hideCalls=(self.hideCalls or 0)+1 end
    ui.input=setmetatable({ui=ui},{__index=EL.Input})
    EL.instance=ui
    assert(trace:BeginComparison(ui));assert(ui.input.trace and trace.compareInput==ui.input)
    ui.input:StopTrace("complete")
    assert(ui.hideCalls==1 and not ui.frame.shown and trace.record.status=="armed" and not trace.compareInput)
    trace:Stop("test_reset");trace:BeginComparison(ui);ui.input:StopTrace("input_released")
    assert(not trace.record and not trace.compareInput and ui.hideCalls==1)
end)
test("normal mouse recording does not launch a comparison",function()
    reset();local ui={Notice=function() end,options={},renderer=traceRenderer}
    local input=setmetatable({ui=ui},{__index=EL.Input})
    input:ArmTrace();input:StopTrace("complete");assert(not trace.record)
end)
test("leaving the arena cancels a comparison before the first sample",function()
    reset()
    local ui={options={},renderer=traceRenderer,Notice=function() end,Show=function() end}
    local input=setmetatable({ui=ui,keys={},presses={},buttons={},
        mouse={End=function() end},frame={EnableKeyboard=function() end}}, {__index=EL.Input})
    ui.input=input
    assert(trace:BeginComparison(ui));local record=input.trace
    input:Release()
    assert(record.status=="input_released" and not input.trace and not trace.compareInput and not trace.record)
end)
trace:Stop("test_end")
print("Reference comparison: "..checks.." checks, "..failures.." failures")
if failures>0 then os.exit(1) end
