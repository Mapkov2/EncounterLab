-- Lua 5.1 focused input contract; no WoW player commands are mocked or executed.
local base=(arg and arg[1]) or 'EncounterLab/'
local EL = { L = setmetatable({}, { __index=function(_, key) return key end }), F=string.format }
function EL.Clamp(value, low, high) return math.max(low, math.min(high, value)) end
local saved = 0
EL.Store = { SaveOptions=function() saved = saved + 1 end }
local keyboard, mouse, combat, focus, shift, ctrl, native, bindingReads = {}, {}, false, nil, false, false, nil, 0
local frames = {}
local cursorX,cursorY,cursorDX,cursorDY,deltaReads,cvars,cvarWrites,uiScale=200,100,0,0,0,{},0,1
local frame = {}
function frame:SetAllPoints() end
function frame:SetFrameLevel() end
function frame:EnableMouse() end
function frame:EnableMouseWheel() end
function frame:EnableKeyboard(value) assert(not combat, 'protected keyboard mutation in combat'); self.keyboard=value end
function frame:SetPropagateKeyboardInput(value) assert(not combat, 'protected propagation mutation in combat'); self.propagate=value end
function frame:SetScript(event, fn) self.scripts[event]=fn end
function frame:RegisterEvent(event) self.events[event]=true end
function frame:UnregisterEvent(event) self.events[event]=nil end
function frame:Show() self.shown=true end
function frame:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function CreateFrame()
 local result=setmetatable({ scripts={},events={},shown=true }, {__index=frame})
 frames[#frames+1]=result
 return result
end
function InCombatLockdown() return combat end
function GetCurrentKeyBoardFocus() return focus end
function IsKeyDown(key, excludeBindingState) assert(excludeBindingState==true,'physical key state required');return keyboard[key] end
function IsMouseButtonDown(button) return mouse[button] end
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return ctrl end
function GetCursorDelta() deltaReads=deltaReads+1;return cursorDX,cursorDY end
function GetCursorPosition() return cursorX,cursorY end
function GetCVar(name) return cvars[name] end
function SetCVar(name,value) cvarWrites=cvarWrites+1;cvars[name]=tostring(value);return true end
UIParent={GetEffectiveScale=function() return uiScale end}
function GetAppropriateTopLevelParent() return UIParent end
function ChatFrame_OpenChat() end
assert(loadfile(base..'MouseCapture.lua'))('EncounterLab', EL)
assert(loadfile(base..'Input.lua'))('EncounterLab', EL)
local passed = 0
local function equal(actual, expected, label)
 assert(actual == expected, label..': expected '..tostring(expected)..', got '..tostring(actual));passed=passed+1
end
local function near(actual, expected, label)
 assert(math.abs(actual-expected)<1e-9,label..': expected '..expected..', got '..actual);passed=passed+1
end
local function reset(profile)
 if EL.Input.latest then EL.Input.latest:Release() end
 keyboard, mouse, combat, focus, shift, ctrl = {}, {}, false, nil, false, false
 cursorX,cursorY,cursorDX,cursorDY,deltaReads,uiScale=200,100,0,0,0,1
 cvarWrites=0
 cvars={enableMouseSpeed='0',mouseSpeed='0.7',cameraYawMoveSpeed='180',cameraPitchMoveSpeed='90',mouseInvertYaw='0',mouseInvertPitch='0'}
 EncounterLabDB={}
 local ui={ options={bindingPreset=profile or 'custom'}, camera={yaw=0,pitch=.5,distance=30}, gameplay=true, notices={}, calls={} }
 ui.viewport={GetFrameLevel=function() return 2 end}
 ui.modal={IsShown=function() return ui.modalShown end}
 function ui:IsGameplayInputAllowed() return self.gameplay end
 function ui:Notice(message) self.notices[#self.notices+1]=message end
 function ui:Hide(reason) self.hidden=reason or true;self.input:Release() end
 function ui:PauseForFocus(reason) self.pausedForFocus=reason;self.input:Release() end
 function ui:ShowSettings() self.settingsShown=true;self.calls.settings=(self.calls.settings or 0)+1 end
 function ui:UpdateControls() self.calls.controls=(self.calls.controls or 0)+1 end
 function ui:CloseModal() self.modalShown=false end
 function ui:TogglePause() self.calls.pause=(self.calls.pause or 0)+1;self.input:Clear() end
 function ui:Revive() self.calls.revive=(self.calls.revive or 0)+1;self.input:Clear() end
 function ui:UseSelectedAbility() self.calls.ability=(self.calls.ability or 0)+1 end
 function ui:HandleEscape() self.calls.escape=(self.calls.escape or 0)+1;self.input:Clear() end
 function ui:ToggleFullscreen() self.calls.fullscreen=(self.calls.fullscreen or 0)+1;self.input:Clear() end
 ui.input=EL.Input.New(ui);ui.input:Acquire();EL.Input.latest=ui.input
 local rawSample=ui.input.Sample
 function ui.input:Sample(...)
  local result=rawSample(self,...)
  cursorDX,cursorDY=0,0
  return result
 end
 return ui,ui.input
end
local function moveCursor(dx,dy)
 cursorX,cursorY=cursorX+dx,cursorY-dy
 cursorDX,cursorDY=cursorDX+dx,cursorDY+dy
end
local function moveAbsolute(dx,dy)
 cursorX,cursorY=cursorX+dx,cursorY+dy
 cursorDX,cursorDY=cursorDX+dx,cursorDY-dy
end
local function key(input, name, down)
 keyboard[name]=down or nil
 input.frame.scripts[down and 'OnKeyDown' or 'OnKeyUp'](input.frame,name)
end
local function button(input, name, down)
 mouse[name]=down or nil
 input.frame.scripts[down and 'OnMouseDown' or 'OnMouseUp'](input.frame,name)
end

do
 local ui,input=reset()
 key(input,'A',true);equal(input:Sample().turn,1,'A turns left');equal(input:Sample().strafe,0,'A alone does not strafe')
 button(input,'RightButton',true);equal(input:Sample().turn,0,'RMB suppresses keyboard turn');equal(input:Sample().strafe,1,'RMB+A strafes')
 equal(input:Sample().yaw,nil,'RMB press alone preserves player heading')
 moveCursor(1,0);near(input:Sample().yaw,ui.camera.yaw,'RMB movement faces scene camera')
 key(input,'A',false);key(input,'D',true);equal(input:Sample().turn,0,'RMB suppresses right keyboard turn');equal(input:Sample().strafe,-1,'RMB+D strafes right')
 key(input,'D',false);button(input,'RightButton',false);key(input,'Q',true);equal(input:Sample().strafe,1,'Q strafes left')
 key(input,'E',true);equal(input:Sample().strafe,0,'opposed strafe cancels')
 key(input,'W',true);key(input,'S',true);equal(input:Sample().forward,0,'opposed forward cancels')
 key(input,'W',false);equal(input:Sample().forward,-1,'S moves backward')
 button(input,'LeftButton',true);button(input,'RightButton',true);equal(input:Sample().forward,0,'backpedal cancels both-button forward')
 key(input,'S',false);equal(input:Sample().forward,1,'both buttons move forward')
 key(input,'S',true)
 mouse.RightButton=nil;equal(input:Sample().forward,-1,'physical mouse release clears lost mouse-up')
 keyboard.S=nil;equal(input:Sample().forward,0,'physical keyboard release clears lost key-up')
 input:Clear();keyboard.W=true;equal(input:Sample().forward,0,'global held key without captured down cannot move')
end

do
 local ui,input=reset()
 button(input,'LeftButton',true);input:Sample();near(ui.camera.yaw,0,'press captures cursor origin without stale motion')
 moveCursor(1,1)
 equal(input:Sample().yaw,nil,'LMB does not change player facing');near(ui.camera.yaw,-.054,'LMB uses the calibrated screen delta gain')
 near(ui.camera.pitch,.527,'screen delta pitch direction')
 input:Sample();near(ui.camera.yaw,-.054,'stationary cursor never keeps turning')
 button(input,'RightButton',true);moveCursor(1,0);input:Sample();near(ui.camera.yaw,-.108,'adding second button does not discard drag delta')
 button(input,'LeftButton',false);equal(cvarWrites,2,'second button reuses the active cursor lease')
 button(input,'RightButton',false);input:Sample();near(ui.camera.yaw,-.108,'released mouse stops camera')
 equal(cvarWrites,4,'final mouse release restores both cursor CVars')
 ui.gameplay=false;key(input,'W',true);button(input,'RightButton',true)
 input.frame.scripts.OnMouseWheel(input.frame,1)
 equal(input:Sample().forward,0,'menu blocks movement');equal(input.buttons.RightButton,nil,'menu blocks mouse look');near(ui.camera.distance,30,'menu blocks zoom')
 key(input,'ESCAPE',true);input:Sample();key(input,'ESCAPE',true);equal(ui.calls.escape,1,'Escape remains available and ignores repeats across menu updates')
 key(input,'ESCAPE',false);key(input,'F11',true);input:Sample();key(input,'F11',true);equal(ui.calls.fullscreen,1,'fullscreen toggle ignores repeats across menu updates')
 key(input,'P',true);equal(ui.calls.pause,1,'Pause shortcut works through setup gameplay gate')
 key(input,'P',false);ui.modalShown=true;key(input,'P',true);equal(ui.calls.pause,1,'modal still blocks Pause shortcut')
 ui.modalShown=false;input:Release();button(input,'LeftButton',true)
 equal(input.active,true,'arena click reacquires keyboard behind setup after focus loss')
 equal(next(input.buttons),nil,'setup reacquisition does not start mouse look')
 key(input,'P',true);equal(ui.calls.pause,2,'Pause works after reacquiring behind setup')
 input:Release();ui.modalShown=true;button(input,'LeftButton',true)
 equal(input.active,false,'click through modal cannot reacquire arena input')
end

do
 local relativeAPI=GetCursorDelta
 GetCursorDelta=nil
 local ui,input=reset()
 uiScale=2
 button(input,'LeftButton',true);input:Sample()
 equal(input.mouse.inputMode,'absolute','capture uses absolute coordinates')
 moveAbsolute(2,-4);input:Sample()
 near(ui.camera.yaw,-.108,'camera yaw is independent of UI scale')
 near(ui.camera.pitch,.608,'camera pitch is independent of UI scale')
 button(input,'LeftButton',false);equal(cvarWrites,4,'absolute input lifecycle restores both cursor CVars')
 GetCursorDelta=relativeAPI
end

do
 local ui,input=reset()
 cvars.cameraYawMoveSpeed='90';cvars.mouseInvertYaw='1';cvars.mouseInvertPitch='1'
 button(input,'RightButton',true);input:Sample();moveCursor(1,1);input:Sample()
 near(ui.camera.yaw,.027,'WoW yaw inversion and half Mouse Look Speed are honored')
 near(ui.camera.pitch,.473,'WoW pitch inversion is honored')
 ui.options.invertY=true;moveCursor(0,1);input:Sample()
 near(ui.camera.pitch,.5,'addon invert Y toggles native preference')
 uiScale=.5;moveCursor(1,0);input:Sample();near(ui.camera.yaw,.054,'UI scale does not change turn sensitivity')
 uiScale=1;ui.options.mouseSensitivity=.012;moveCursor(1,0);input:Sample();near(ui.camera.yaw,.108,'addon sensitivity is an optional multiplier on WoW speed')
 key(input,'Q',true);key(input,'E',true);key(input,'A',true)
 equal(input:Sample().strafe,0,'duplicate left actions cannot overpower opposing right action')
 input:Clear();equal(cvarWrites,4,'Clear restores both cursor settings')
 equal(cvars.mouseSpeed,'0.7','Clear leaves cursor speed unchanged')
end

do
 local ui,input=reset()
 key(input,'SPACE',true);equal(input:Sample().jump,true,'jump queues edge');key(input,'SPACE',true);equal(input:Sample().jump,false,'held jump has no repeat edge')
 key(input,'NUMPADDIVIDE',true);equal(input:Sample().walk,true,'walk key toggles walking');key(input,'NUMPADDIVIDE',true);equal(input:Sample().walk,true,'walk repeat ignored')
 key(input,'P',true);key(input,'P',true);equal(ui.calls.pause,1,'pause remains latched across Clear')
 key(input,'W',true);button(input,'RightButton',true);input:Release();equal(input.active,false,'release disables input');equal(input:Sample().forward,0,'release clears movement');equal(next(input.buttons),nil,'release clears mouse buttons')
 input:Acquire();key(input,'W',true);focus={};input:Sample();equal(input.active,false,'text focus releases input')
 focus=nil;input:Acquire();key(input,'LALT',true);equal(input.active,false,'Alt releases for OS focus switch')
 input:Acquire();combat=true;input:Release();equal(input.frame.shown,false,'combat release hides capture without protected mutation')
 combat=false;input:Acquire();input.frame:Hide();equal(input.active,false,'hiding capture clears active state')
end

do
 local ui,input=reset()
 cursorDX,cursorDY=7,-3
 button(input,'RightButton',true);equal(input:Sample().yaw,nil,'fresh RMB press filters stale frame delta')
 near(ui.camera.yaw,0,'stale frame delta cannot snap camera on fresh RMB')
 moveCursor(1,0);local aligned=input:Sample().yaw
 near(aligned,ui.camera.yaw,'drag starts RMB alignment')
 near(input:Sample().yaw,aligned,'quiet render frame preserves latest dragged facing')
 equal(input:Sample().lockFacing,true,'quiet render frame retains facing lock')
 button(input,'RightButton',false);button(input,'RightButton',true)
 equal(input:Sample().yaw,nil,'RMB release resets alignment before the next press')
 button(input,'LeftButton',true)
 local both=input:Sample()
 near(both.yaw,ui.camera.yaw,'both buttons begin alignment without a drag')
 equal(both.lockFacing,true,'both buttons lock facing immediately')
 equal(both.forward,1,'both buttons move forward')
 button(input,'LeftButton',false)
 local rightOnly=input:Sample()
 near(rightOnly.yaw,ui.camera.yaw,'releasing LMB preserves the held RMB alignment')
 equal(rightOnly.forward,0,'releasing LMB ends both-button forward movement')
 equal(input.mouse.active,true,'releasing LMB retains RMB mouse capture')
 moveCursor(1,0);near(input:Sample().yaw,ui.camera.yaw,'RMB keeps facing the camera after partial release')
 button(input,'LeftButton',true);input:Sample()
 button(input,'RightButton',false)
 local leftOnly=input:Sample()
 equal(leftOnly.yaw,nil,'releasing RMB leaves LMB as camera-only orbit')
 equal(leftOnly.lockFacing,false,'LMB-only orbit does not lock player facing')
 equal(leftOnly.forward,0,'releasing RMB ends both-button forward movement')
 equal(input.mouse.active,true,'releasing RMB retains LMB mouse capture')
 local orbit=ui.camera.yaw
 moveCursor(1,0);equal(input:Sample().yaw,nil,'LMB motion after partial release never aligns facing')
 near(ui.camera.yaw,orbit-.054,'LMB motion continues orbit after RMB release')
 button(input,'LeftButton',false);equal(input.mouse.active,false,'final LMB release ends mouse capture')
 button(input,'RightButton',true);input:Sample()
 mouse.RightButton=nil;equal(input:Sample().yaw,nil,'physical lost RMB release ends alignment')
 button(input,'RightButton',true);equal(input:Sample().yaw,nil,'press after lost RMB release does not inherit alignment')
 moveCursor(1,0);input:Sample();input:Clear();button(input,'RightButton',true)
 equal(input:Sample().yaw,nil,'Clear resets RMB alignment')
 moveCursor(1,0);input:Sample();input:Release();input:Acquire();button(input,'RightButton',true)
 equal(input:Sample().yaw,nil,'Release and Acquire reset RMB alignment')
end

do
 local ui,input=reset()
 local startYaw,startPitch=ui.camera.yaw,ui.camera.pitch
 button(input,'RightButton',true)
 moveAbsolute(.5,.25)
 local reads=deltaReads
 button(input,'RightButton',false)
 equal(deltaReads,reads,'quick mouse-up never reads frame-wide relative delta')
 local final=input:Sample()
 equal(type(final.yaw),'number','mouse-up exposes one final RMB facing sample')
 near(final.yaw,ui.camera.yaw,'mouse-up preserves the final RMB delta for one sample')
 equal(ui.camera.yaw~=startYaw,true,'quick RMB gesture applies its real delta before the first sample')
 near(ui.camera.pitch,startPitch-.00675,'quick absolute residual uses screen-coordinate pitch direction')
 equal(final.lockFacing,true,'final RMB delta remains an aligned sample after release')
 equal(input:Sample().yaw,nil,'final RMB alignment is consumed once')
 equal(input.mouse.active,false,'final RMB release leaves capture inactive')
 equal(cvarWrites,4,'final RMB delta lifecycle restores both cursor CVars')
end

do
 local ui,input=reset()
 button(input,'RightButton',true);input:Sample()
 moveCursor(.5,.25)
 local aligned=EL.Input.Sample(input)
 equal(type(aligned.yaw),'number','same-frame sample aligns RMB before release')
 local yaw,pitch,reads=ui.camera.yaw,ui.camera.pitch,deltaReads
 button(input,'RightButton',false)
 equal(deltaReads,reads,'same-frame mouse-up does not reread relative delta')
 near(ui.camera.yaw,yaw,'same-frame mouse-up does not double yaw')
 near(ui.camera.pitch,pitch,'same-frame mouse-up does not double pitch')
 cursorDX,cursorDY=0,0
 equal(input:Sample().yaw,nil,'already-sampled same-frame release does not replay facing')
 equal(cvarWrites,4,'same-frame sample and release restore both cursor CVars')
end

do
 local ui,input=reset()
 button(input,'LeftButton',true);button(input,'RightButton',true);input:Sample()
 local startYaw,startPitch,reads=ui.camera.yaw,ui.camera.pitch,deltaReads
 moveAbsolute(.5,.25)
 button(input,'LeftButton',false)
 local releaseYaw,releasePitch=ui.camera.yaw,ui.camera.pitch
 equal(deltaReads,reads,'Both-to-RMB mouse-up never reads relative delta')
 moveAbsolute(.25,.125)
 local rightOnly=input:Sample()
 equal(deltaReads,reads,'Both-to-RMB cached sample never reads relative delta')
 near(releaseYaw,startYaw-.027,'Both-to-RMB applies pre-release yaw residual')
 near(releasePitch,startPitch-.00675,'Both-to-RMB applies pre-release pitch residual')
 near(ui.camera.yaw,startYaw-.0405,'Both-to-RMB applies post-release yaw residual')
 near(ui.camera.pitch,startPitch-.010125,'Both-to-RMB applies post-release pitch residual')
 near(rightOnly.yaw,ui.camera.yaw,'remaining RMB faces final camera after post-release residual')
 equal(rightOnly.lockFacing,true,'remaining RMB keeps facing locked')
 equal(rightOnly.forward,0,'partial LMB release ends both-button movement')
 equal(input.mouse.active,true,'remaining RMB retains capture')
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 local quiet=input:Sample()
 near(ui.camera.yaw,yaw,'Both-to-RMB residual is not replayed')
 near(ui.camera.pitch,pitch,'Both-to-RMB pitch residual is not replayed')
 near(quiet.yaw,yaw,'remaining RMB retains final facing on quiet frame')
 button(input,'RightButton',false)
 equal(cvarWrites,4,'Both-to-RMB partial release restores both cursor CVars')
end

do
 local ui,input=reset()
 button(input,'LeftButton',true);button(input,'RightButton',true);input:Sample()
 local startYaw,startPitch,reads=ui.camera.yaw,ui.camera.pitch,deltaReads
 moveAbsolute(.5,.25)
 button(input,'RightButton',false)
 local releaseYaw,releasePitch=ui.camera.yaw,ui.camera.pitch
 equal(deltaReads,reads,'Both-to-LMB mouse-up never reads relative delta')
 moveAbsolute(.25,.125)
 local leftOnly=input:Sample()
 equal(deltaReads,reads,'Both-to-LMB cached sample never reads relative delta')
 near(releaseYaw,startYaw-.027,'Both-to-LMB stores last RMB yaw')
 near(releasePitch,startPitch-.00675,'Both-to-LMB applies pre-release pitch residual')
 near(ui.camera.yaw,startYaw-.0405,'Both-to-LMB applies later camera-only yaw residual')
 near(ui.camera.pitch,startPitch-.010125,'Both-to-LMB applies later camera-only pitch residual')
 near(leftOnly.yaw,releaseYaw,'Both-to-LMB exposes last RMB yaw once')
 equal(leftOnly.lockFacing,true,'Both-to-LMB preserves final RMB facing sample')
 equal(leftOnly.forward,0,'partial RMB release ends both-button movement')
 equal(input.mouse.active,true,'remaining LMB retains capture')
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 local quiet=input:Sample()
 near(ui.camera.yaw,yaw,'Both-to-LMB residual is not replayed')
 near(ui.camera.pitch,pitch,'Both-to-LMB pitch residual is not replayed')
 equal(quiet.yaw,nil,'remaining LMB becomes camera-only after cached facing')
 button(input,'LeftButton',false)
 equal(cvarWrites,4,'Both-to-LMB partial release restores both cursor CVars')
end


-- Native relative input and visible cursor positions need not share units.
do
 local ui,input=reset()
 button(input,'RightButton',true);input:Sample()
 for i=1,60 do
  cursorX,cursorY=cursorX+.25,cursorY-.125
  cursorDX,cursorDY=8,-4
  input:Sample()
 end
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 button(input,'RightButton',false)
 near(ui.camera.pitch,pitch,'releasing after differently-scaled raw and screen deltas must not snap pitch')
 near(ui.camera.yaw,yaw,'releasing after differently-scaled raw and screen deltas must not snap yaw')
 input:Sample()
 near(ui.camera.pitch,pitch,'release remains stable on the next rendered frame')
end

-- Same physical screen travel at every UI scale, and WoW speed read anew on
-- each drag. These are user settings, not ModelScene viewer defaults.
do
 for _,scale in ipairs({.5,.75,1,1.5}) do
  local ui,input=reset();uiScale=scale;cvars.cameraYawMoveSpeed='90'
  button(input,'RightButton',true);moveAbsolute(10,0);input:Sample()
  near(ui.camera.yaw,-.27,'native half-speed camera is independent of UI scale')
  button(input,'RightButton',false);local yaw=ui.camera.yaw
  cvars.cameraYawMoveSpeed='270'
  button(input,'RightButton',true);moveAbsolute(10,0);input:Sample()
  near(ui.camera.yaw-yaw,-.81,'next gesture reads changed WoW Mouse Look Speed')
  button(input,'RightButton',false)
 end
 local ui,input=reset();button(input,'RightButton',true);input:Sample()
 moveAbsolute(1,-1);input:Sample()
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 for i=1,100 do cursorDX,cursorDY=500,-500;input:Sample() end
 button(input,'RightButton',false)
 near(ui.camera.yaw,yaw,'screen edge never accumulates a hidden yaw residual')
 near(ui.camera.pitch,pitch,'screen edge never accumulates a hidden pitch residual')
 equal(deltaReads,0,'capture never mixes relative mouse counts with cursor coordinates')
end

do
 local ui,input=reset();cvars.cameraYawMoveSpeed='270';cvars.cameraPitchMoveSpeed='45'
 button(input,'RightButton',true);moveAbsolute(1,1);input:Sample()
 near(ui.camera.yaw,-.081,'horizontal axis retains the accepted WoW yaw speed')
 near(ui.camera.pitch,.4865,'vertical axis uses the independent WoW pitch speed')
 button(input,'RightButton',false)
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 cvars.cameraPitchMoveSpeed='0'
 button(input,'RightButton',true);moveAbsolute(0,-1);input:Sample()
 near(ui.camera.pitch,pitch,'zero native pitch speed does not inherit yaw speed')
 near(ui.camera.yaw,yaw,'pure vertical input cannot change yaw')
 button(input,'RightButton',false)
 cvars.cameraPitchMoveSpeed='90'
 button(input,'RightButton',true);moveAbsolute(0,-1);input:Sample()
 near(ui.camera.pitch,pitch+.027,'new gesture reads changed vertical WoW preference')
 button(input,'RightButton',false)
end

native={ MOVEFORWARD={'I','UP'},MOVEBACKWARD={'K','DOWN'},STRAFELEFT={'J'},STRAFERIGHT={'L'},TURNLEFT={'LEFT'},TURNRIGHT={'RIGHT'},JUMP={'SPACE','SHIFT-SPACE'},TOGGLERUN={'NUMPADDIVIDE'} }
function GetBindingKey(action) bindingReads=bindingReads+1;return unpack(native[action] or {}) end

do
 local ui,input=reset('wow')
 equal(input:Binding('forward'),'I','native primary imported');equal(input:BindingLabel('forward'),'I / UP','both imported keys visible')
 key(input,'UP',true);equal(input:Sample().forward,1,'native secondary moves');key(input,'UP',false);key(input,'W',true);equal(input:Sample().forward,0,'old default is not imported movement')
 shift=true;key(input,'SPACE',true);equal(input:Sample().jump,true,'native Shift chord triggers jump');key(input,'SPACE',false);shift=false
 local count=bindingReads;input:Sample();input:Sample();equal(bindingReads,count,'bindings not rescanned every render')
 native.MOVEFORWARD={'O','UP'};input.frame.scripts.OnEvent(input.frame,'UPDATE_BINDINGS');equal(input:Binding('forward'),'O','binding update refreshes runtime')
 equal(ui.calls.controls,1,'binding update refreshes control labels')
 equal(ui.calls.settings,nil,'binding update does not open settings')
 ui.modalShown,ui.modalPage=true,'settings';input.frame.scripts.OnEvent(input.frame,'UPDATE_BINDINGS')
 equal(ui.calls.settings,1,'binding update refreshes visible settings')
 combat=true;input.frame.scripts.OnEvent(input.frame,'UPDATE_BINDINGS');equal(ui.calls.settings,1,'binding update never reacquires keyboard through settings in combat')
 combat=false;ui.modalShown=false
 native.MOVEFORWARD={'F','UP'};input:RefreshBindings();equal(input:Binding('ability'),'F1','local action conflict receives free key')
 key(input,'F',true);equal(input:Sample().forward,1,'conflicting key remains native movement');equal(ui.calls.ability,nil,'movement never accidentally fires local ability')
 input:BeginBinding('ability');equal(ui.options.bindingPreset,'custom','editing switches to custom');equal(ui.options.bindings.forward,'F','custom snapshots effective native primary')
 key(input,'G',true);equal(input:Binding('ability'),'G','custom replacement stored');equal(ui.options.bindings.ability,'G','stored custom replacement')
 native.MOVEFORWARD={'W'};input:Acquire();equal(input:Binding('forward'),'F','custom remains independent of WoW updates')
 input:Destroy();equal(input.frame.events.UPDATE_BINDINGS,nil,'destroy releases event');equal(input.frame.scripts.OnEvent,nil,'destroy releases event callback')
end

do
 native.MOVEFORWARD={'ALT-W','UP'};native.STRAFELEFT={'BUTTON4'};native.STRAFERIGHT={}
 local ui,input=reset('wow')
 equal(input:Binding('forward'),'UP','supported secondary survives unsupported Alt primary')
 equal(input:BindingLabel('left'),'Unbound','mouse movement import is explicitly unbound')
 equal(input:BindingLabel('right'),'Unbound','native unbound action stays unbound')
 ui.options.bindingPreset='custom';ui.options.bindings={forward='CTRL-SHIFT-I'};input:RefreshBindings()
 ctrl,shift=true,true;key(input,'I',true);equal(input:Sample().forward,1,'custom Ctrl Shift movement chord works')
 shift=false;equal(input:Sample().forward,0,'modifier release stops chord')
end

print('EncounterLab input: '..passed..' assertions passed; mock/source proof only.')
