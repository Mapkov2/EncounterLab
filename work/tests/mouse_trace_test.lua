-- Verify the bounded diagnostic cannot alter controls or sample when unarmed.
local EL={VERSION="test",L=setmetatable({},{__index=function(_,key) return key end})}
assert(loadfile("EncounterLab/MouseCapture.lua"))("EncounterLab",EL)
assert(loadfile("EncounterLab/Input.lua"))("EncounterLab",EL)
local now,reads,checks=0,0,0
function GetTime() return now end
function GetCursorDelta() reads=reads+1;return .125,-.25 end
function GetFramerate() return 144 end
local function check(value,label) assert(value,label);checks=checks+1 end
local frame={GetWidth=function() return 1200 end,GetHeight=function() return 760 end,GetEffectiveScale=function() return .75 end}
local ui={options={fullscreen=true,mouseSensitivity=.006},renderer={frame=frame},camera={yaw=1,pitch=.3},Notice=function() end}
function ui.renderer:PrepareTraceStamp() self.stampPrepared=true end
function ui.renderer:ShowTraceSample(index) self.stampSample=index end
function ui.renderer:HideTraceStamp() self.stampSample=nil end
local input=setmetatable({ui=ui,buttons={RightButton=true},sample={forward=0,strafe=1},
    mouse={active=false,x=200,y=300,yawScale=1,pitchScale=.5,record={original={mouseSpeed=".7",enableMouseSpeed="0"},applied={mouseSpeed="0.1"}}}}, {__index=EL.Input})
local state={status="running",time=1,player={x=20,y=30,z=0,yaw=1}}
input:TraceFrame(1/144,state);check(reads==0,"normal input makes no diagnostic API calls")
input:ArmTrace();local trace=EncounterLabMouseTrace
check(trace==input.trace and trace.status=="armed","only explicit arming creates the recording")
input:TraceFrame(1/144,state);check(reads==0 and #trace.samples==0,"wait for mouse capture")
input.mouse.active=true;state.status="paused"
input:TraceFrame(1/144,state);check(reads==0,"paused menu is not recorded")
state.status="running";now=10;input:TraceFrame(1/144,state)
check(trace.startedAt==10 and trace.status=="recording","recording starts with training and mouse held")
check(trace.originalMouseSpeed==".7" and trace.viewportWidth==1200 and trace.uiScale==.75,"capture context stored")
check(trace.captureMouseSpeed=="0.1" and trace.cameraGain==.054,"trace records the applied cursor speed and gain")
local row=trace.samples[1]
check(trace.schema==3 and #trace.columns==41,"video comparison trace is versioned")
check(ui.renderer.stampPrepared and ui.renderer.stampSample==1 and row[32]==1,"visible sample identifies the exact recorded row")
check(row[33]==false and row[41]==false,"missing boss and viewport APIs do not truncate the row")
check(row[18]==false and row[22]==false and row[28]==1200 and row[30]==.75,"optional native scene APIs fail safely without sparse rows")
check(#row==#trace.columns and row[5]==.125 and row[6]==-.25 and row[7]==2,"raw input and button roles remain separate")
check(row[8]==1 and row[9]==.3 and row[10]==20 and row[17]==144,"current camera, player and frame rate recorded")
check(ui.camera.yaw==1 and ui.camera.pitch==.3 and state.player.x==20,"diagnostics never apply relative deltas")
input.mouse.active=false;input.mouse.x=nil;input.mouse.y=nil;input.buttons.RightButton=nil
GetCursorDelta=function() error("unavailable") end
GetFramerate=function() return 0/0 end
now=11;input:TraceFrame(1/144,state);row=trace.samples[2]
check(row[3]==false and row[5]==false and row[7]==0 and row[17]==false,"release and optional API failure are safe")
now=20;input:TraceFrame(1/144,state)
check(input.trace==nil and trace.status=="complete" and trace.finishedAt==20,"ten second bound stops sampling")
check(ui.renderer.stampSample==nil,"recording completion hides the visible stamp")
local count=#trace.samples;input:TraceFrame(1/144,state)
check(#trace.samples==count,"completed trace stays stable")
input:ArmTrace();input.mouse.active=true;trace=input.trace;trace.limit=2
now=21;input:TraceFrame(.001,state);now=21.001;input:TraceFrame(.001,state)
check(input.trace==nil and #trace.samples==2,"sample cap bounds high FPS allocation")
input:ArmTrace();trace=input.trace;now=22;input:TraceFrame(.01,state)
state.status="paused";input:TraceFrame(.01,state)
check(input.trace==nil and trace.status=="training_stopped","training interruption finalizes the capture")
check(EncounterLabMouseTrace==trace,"result retained in separate SavedVariable")
GetCVar=function(name) return ({enableMouseSpeed="1",mouseSpeed=".5",cameraYawMoveSpeed="270",cameraPitchMoveSpeed="135"})[name] end
frame.GetCameraPosition=function() return -10,20,5 end
frame.GetCameraForward=function() return 1,0,0 end
state.status="running";input:ArmTrace();now=23;input:TraceFrame(.01,state);row=input.trace.samples[1]
check(row[19]==.5 and row[20]==270 and row[22]==-10 and row[25]==1,"comparison records effective settings and native camera state")
state.boss={x=10,y=15,z=2}
frame.Project3DPointTo2D=function(_,x,y,z) return x*3,y*3+z end
ui.renderer.Project=function(_,x,y,z) return x*4,y*4+z end
frame.GetLeft=function() return 12 end
frame.GetBottom=function() return 24 end
now=23.01;input:TraceFrame(.01,state);row=input.trace.samples[2]
check(row[32]==2 and row[33]==10 and row[34]==15 and row[35]==2,"sample row records this frame's boss position")
check(row[36]==30 and row[37]==47 and row[38]==40 and row[39]==62 and row[40]==12 and row[41]==24,"native and overlay projections remain distinct with viewport origin")
check(ui.renderer.stampSample==2 and #row==41,"video stamp advances with the complete row")
print("Mouse trace: "..checks.." checks passed")
