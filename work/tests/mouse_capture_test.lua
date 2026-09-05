local EL = {}
assert(loadfile('EncounterLab/MouseCapture.lua'))('EncounterLab', EL)
local values, writes, fail, x, y, frameDX, frameDY, deltaReads, cursorReads, capture
local passed = 0
local function check(condition, label) assert(condition, label); passed=passed+1 end
local function equal(actual, expected, label)
    check(actual == expected, label..': '..tostring(actual)..' ~= '..tostring(expected))
end
local function reset()
    if capture then capture:End() end
    values={enableMouseSpeed='0',mouseSpeed='.700',cameraYawMoveSpeed='240',cameraPitchMoveSpeed='120',mouseInvertYaw='1',mouseInvertPitch='0'}
    writes,fail,x,y,frameDX,frameDY,deltaReads,cursorReads={}, {}, 120,220,0,0,0,0
    EncounterLabDB={};C_CVar=nil
    function GetCVar(name) if fail['read:'..name] then error('read failed') end;return values[name] end
    function SetCVar(name,value)
        writes[#writes+1]={name,value}
        if fail[name] or fail[name..':'..value] then error('write failed') end
        values[name]=tostring(value);return true
    end
    function GetCursorPosition() cursorReads=cursorReads+1;return x,y end
    function GetCursorDelta()
        deltaReads=deltaReads+1
        return frameDX,frameDY
    end
    capture=EL.MouseCapture.New()
    return capture
end

local function setFrameDelta(dx, dy, move)
    frameDX, frameDY = dx, dy
    if move then x, y = x + dx, y - dy end
end

capture=reset();setFrameDelta(90,40,false)
check(capture:Begin(),'cursor capture begins');equal(capture.inputMode,'absolute','one coordinate space selected')
equal(deltaReads,0,'capture never reads relative input')
check(capture.invertYaw and not capture.invertPitch,'native inversions sampled')
equal(capture.yawScale,240/180,'native Mouse Look Speed sampled')
equal(capture.pitchScale,120/180,'native vertical speed sampled separately')
equal(values.enableMouseSpeed,'1','cursor sensitivity temporarily enabled')
equal(values.mouseSpeed,'0.1','accepted cursor speed restored while dragging')
equal(#writes,2,'two capture writes at gesture start')
check(EncounterLabDB.mouseRecovery~=nil,'restoration journal stored')
local dx,dy=capture:Delta();equal(dx,0,'old raw delta cannot snap x');equal(dy,0,'old raw delta cannot snap y')
x,y=x+.125,y-.25;setFrameDelta(100,-60,false)
dx,dy=capture:Delta();equal(dx,.125,'fractional screen x retained');equal(dy,-.25,'fractional screen y retained')
dx,dy=capture:ReleaseDelta();equal(dx,0,'release does not duplicate x');equal(dy,0,'release does not duplicate y')
equal(deltaReads,0,'different raw counts never enter the cursor baseline')
equal(#writes,2,'render and release samples never write CVars')
local second=EL.MouseCapture.New();local ok,reason=second:Begin()
check(not ok,'second owner rejected');equal(reason,'capture_busy','busy reason');check(second:End(),'unused end safe')
check(capture:Begin(),'begin idempotent');equal(#writes,2,'second button does not replace the original settings')
check(capture:End(),'end restores settings');equal(values.enableMouseSpeed,'0','cursor enable restored');equal(values.mouseSpeed,'.700','exact original speed restored')
equal(#writes,4,'restore writes once per changed setting');equal(EncounterLabDB.mouseRecovery,nil,'successful restoration clears journal')
check(capture:End(),'repeated end succeeds');equal(#writes,4,'repeated end writes nothing')
dx,dy=capture:Delta();equal(dx,0,'inactive x');equal(dy,0,'inactive y')

capture=reset();check(capture:Begin(),'quick gesture starts')
x,y=x+.5,y+.75;dx,dy=capture:ReleaseDelta()
equal(dx,.5,'quick down-drag-up x retained');equal(dy,.75,'quick down-drag-up y retained')
equal(deltaReads,0,'quick gesture ignores frame-wide relative data');capture:End()

capture=reset();GetCursorDelta=nil
check(capture:Begin(),'relative API is not required');x,y=108,235
dx,dy=capture:Delta();equal(dx,-12,'absolute x delta');equal(dy,15,'absolute y delta')
x=nil;dx,dy=capture:Delta();equal(dx,0,'missing cursor ignored');equal(dy,0,'missing cursor y ignored')
x,y=900,700;dx,dy=capture:Delta();equal(dx,0,'returning cursor resets x baseline');equal(dy,0,'returning cursor resets y baseline')
capture:End()

capture=reset();GetCursorPosition=nil
ok,reason=capture:Begin();check(not ok,'missing cursor rejects capture');equal(reason,'cursor_unavailable','missing cursor reason');equal(#writes,0,'missing cursor never alters settings')
capture=reset();GetCVar=nil;SetCVar=nil
ok,reason=capture:Begin();check(not ok,'cannot lease unavailable settings');equal(reason,'settings_unavailable','missing settings reason');equal(#writes,0,'missing settings writes nothing')

capture=reset();fail.mouseSpeed=true
ok,reason=capture:Begin();check(not ok,'partial setup failure rejects capture');equal(reason,'settings_unavailable','partial setup reason')
equal(values.enableMouseSpeed,'0','partial setup restores first change');equal(values.mouseSpeed,'.700','failed write retains original speed')
equal(EncounterLabDB.mouseRecovery,nil,'partial setup rollback clears journal')
fail={};check(capture:Begin(),'capture retries after setup failure');capture:End()

capture=reset();check(capture:Begin(),'capture before restore failure');fail.enableMouseSpeed=true
check(not capture:End(),'failed restore is reported');equal(values.mouseSpeed,'.700','other setting restored independently')
check(EncounterLabDB.mouseRecovery~=nil,'pending restore retained')
ok,reason=capture:Begin();check(not ok,'pending restoration blocks new capture');equal(reason,'recovery_pending','pending restore reason')
fail={};check(capture:End(),'failed restore retries');equal(values.enableMouseSpeed,'0','retry restores original')
equal(EncounterLabDB.mouseRecovery,nil,'retry clears journal')

capture=reset();check(capture:Begin(),'capture before external setting change');values.mouseSpeed='0.9'
check(capture:End(),'external setting can end capture');equal(values.mouseSpeed,'0.9','external mouse speed is not overwritten');equal(values.enableMouseSpeed,'0','still-owned enable restored')
capture=reset();values.enableMouseSpeed='1';values.mouseSpeed='0.1'
check(capture:Begin(),'already matching cursor begins');equal(#writes,0,'already matching CVars need no writes')
check(capture:End(),'already matching cursor ends');equal(#writes,0,'unchanged settings need no restoration')

capture=reset();values.enableMouseSpeed='1';values.mouseSpeed='.10'
EncounterLabDB.mouseRecovery={version=1,original={enableMouseSpeed='0',mouseSpeed='.8'},applied={enableMouseSpeed='1',mouseSpeed='.10'}}
check(capture:Begin(),'old owned recovery restored before capture')
equal(capture.record.original.enableMouseSpeed,'0','legacy enable restored before lease');equal(capture.record.original.mouseSpeed,'.8','legacy speed restored before lease')
equal(#writes,4,'recovery precedes a fresh cursor lease');check(EncounterLabDB.mouseRecovery==capture.record,'new lease replaces legacy journal');capture:End()
capture=reset();values.enableMouseSpeed='1';values.mouseSpeed='.7'
EncounterLabDB.mouseRecovery={version=1,original={enableMouseSpeed='0',mouseSpeed='.8'},applied={enableMouseSpeed='1',mouseSpeed='.10'}}
check(capture:Begin(),'external legacy change does not block capture')
equal(capture.record.original.enableMouseSpeed,'0','legacy enable restored before new lease');equal(capture.record.original.mouseSpeed,'.7','new lease preserves external speed for restoration');capture:End()
capture=reset();values.enableMouseSpeed='1';values.mouseSpeed='.10';fail.enableMouseSpeed=true
EncounterLabDB.mouseRecovery={version=1,original={enableMouseSpeed='0',mouseSpeed='.8'},applied={enableMouseSpeed='1',mouseSpeed='.10'}}
ok,reason=capture:Begin();check(not ok,'failed legacy recovery blocks capture');equal(reason,'recovery_pending','recovery reason')
equal(values.mouseSpeed,'.8','second legacy setting still restored');check(EncounterLabDB.mouseRecovery~=nil,'failed legacy record retained')
fail={};check(capture:Begin(),'legacy recovery retries');equal(capture.record.original.enableMouseSpeed,'0','legacy retry restores enable before new lease');capture:End()

capture=reset();values.enableMouseSpeed='1';values.mouseSpeed='.10'
local malformed={version=1,original={enableMouseSpeed='0',mouseSpeed='-2'},applied={enableMouseSpeed='1',mouseSpeed='.10'}}
equal(EL.MouseCapture.Recover(malformed),nil,'malformed recovery ignored');equal(#writes,0,'malformed recovery writes nothing')
malformed.original.mouseSpeed='.8';malformed.applied.other='1'
equal(EL.MouseCapture.Recover(malformed),nil,'unknown recovery field ignored');equal(#writes,0,'unknown field writes nothing')
capture=reset();C_CVar={GetCVar=GetCVar,SetCVar=SetCVar};GetCVar=nil;SetCVar=nil
check(capture:Begin(),'namespaced CVar reads supported');check(capture.invertYaw,'namespaced inversion sampled');capture:End()


for _,bad in ipairs({'unavailable','-1','inf'}) do
 capture=reset();values.cameraPitchMoveSpeed=bad
 check(capture:Begin(),'invalid vertical preference has a safe fallback')
 equal(capture.pitchScale,capture.yawScale*.5,'fallback follows WoW slider axis ratio')
 capture:End()
end
capture=reset();values.cameraPitchMoveSpeed='30'
check(capture:Begin(),'independent vertical preference starts');equal(capture.pitchScale,30/180,'independent pitch is not derived from yaw');capture:End()
capture=reset();values.cameraPitchMoveSpeed='0'
check(capture:Begin(),'disabled vertical preference starts');equal(capture.pitchScale,0,'explicit zero pitch retained');capture:End()

capture=reset();values.mouseSpeed='1.000000'
check(capture:Begin(),'recorded user profile begins')
equal(#writes,2,'recorded profile acquires both accepted overrides')
equal(values.mouseSpeed,'0.1','recorded profile uses accepted drag speed')
check(capture:End(),'recorded user profile restores')
equal(#writes,4,'both owned settings are restored')
equal(values.mouseSpeed,'1.000000','recorded original speed is restored exactly')
equal(values.enableMouseSpeed,'0','recorded user profile ends with native override disabled')

print('Mouse capture: '..passed..' checks passed')
