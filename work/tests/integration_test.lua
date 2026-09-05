-- Lua 5.1 integration smoke. Explicit API allowlists: unknown methods remain nil.
local base=(arg and arg[1]) or 'EncounterLab/'
local frames,now,combat,keyboard,mouse={},2,false,{},{}
local cursorX,cursorY,focus,deltaReads=300,300,nil,0
local deltaCursorX,deltaCursorY=cursorX,cursorY
local cvars={enableMouseSpeed="0",mouseSpeed="0.7",cameraYawMoveSpeed="180",cameraPitchMoveSpeed="90",cameraYawSmoothSpeed="180",cameraPitchSmoothSpeed="90",mouseInvertYaw="0",mouseInvertPitch="0"}
C_CVar={}
function C_CVar.GetCVar(name) return cvars[name] end
function C_CVar.SetCVar(name,value) assert(cvars[name]~=nil,"unexpected CVar "..tostring(name));cvars[name]=tostring(value);return true end
function GetCVar(name) return C_CVar.GetCVar(name) end
function SetCVar(name,value) return C_CVar.SetCVar(name,value) end
function GetCVarBool(name) return cvars[name]=="1" end
local bindingReads,nativeBindings=0,{MOVEFORWARD={'W','UP'},MOVEBACKWARD={'S','DOWN'},STRAFELEFT={'Q'},STRAFERIGHT={'E'},TURNLEFT={'A','LEFT'},TURNRIGHT={'D','RIGHT'},JUMP={'SPACE'},TOGGLERUN={'NUMPADDIVIDE'}}
local common,scene,actor={},{},{}
local function noop() end
local function allow(t,names) for name in names:gmatch('%S+') do t[name]=noop end end
allow(common,'SetClampedToScreen SetMovable SetResizable EnableMouseWheel SetClipsChildren RegisterForDrag StartMoving StartSizing StopMovingOrSizing SetTextColor SetJustifyH SetJustifyV SetAutoFocus SetMaxLetters SetNumeric SetThickness SetVertexOffset SetShadowColor SetShadowOffset SetTexCoord SetBlendMode SetTextInsets SetWordWrap SetSnapToPixelGrid SetTexelSnappingBias')
allow(scene,'SetCameraNearClip SetCameraFarClip SetLightAmbientColor SetLightDiffuseColor SetLightDirection SetLightVisible SetAllowOverlappedModels')
allow(actor,'SetUseCenterForOrigin SetScale SetAnimation SetPosition SetYaw ClearModel')
local function object(kind,parent,name)
 local o={kind=kind,parent=parent,name=name,shown=true,width=900,height=650,points={},scripts={},events={},level=parent and parent.level+1 or 1,children={}}
 setmetatable(o,{__index=function(_,k) return (kind=='ModelScene' and scene[k]) or (kind=='Actor' and actor[k]) or common[k] end})
 if parent then parent.children[#parent.children+1]=o end
 if kind=='Frame' or kind=='ModelScene' or kind=='Button' or kind=='EditBox' then frames[#frames+1]=o end
 if name then _G[name]=o end
 return o
end
function common:GetParent() return self.parent end
function common:GetFrameLevel() return self.level end
function common:SetFrameLevel(n) local delta=n-self.level;self.level=n;for _,child in ipairs(self.children) do child:SetFrameLevel(child.level+delta) end end
function common:SetFrameStrata(strata) self.strata=strata end
function common:EnableMouse(enabled) self.mouseEnabled=enabled end
function common:SetFont(path,size,flags) assert(type(path)=='string' and type(size)=='number');self.font,self.fontSize,self.fontFlags=path,size,flags;return true end
function common:GetFont() return self.font or STANDARD_TEXT_FONT,self.fontSize or 13,self.fontFlags or '' end
function common:SetTexture(path) assert(type(path)=='string' or type(path)=='number' or path==nil);self.texture=path;return true end
function common:SetVertexColor(...) self.vertexColor={...} end
function common:SetColorTexture(...) self.color={...} end
function common:CreateMaskTexture() return object('MaskTexture',self) end
function common:AddMaskTexture(mask) self.mask=mask end
function common:HookScript(k,v) local prior=self.scripts[k];self.scripts[k]=function(...) if prior then prior(...) end;return v(...) end end
function common:SetResizeBounds(...) self.resizeBounds={...} end
function common:SetScript(k,v) self.scripts[k]=v end
function common:GetScript(k) return self.scripts[k] end
function common:RegisterEvent(e) self.events[e]=true end
function common:UnregisterEvent(e) self.events[e]=nil end
function common:Show() local prior=self.shown;self.shown=true;if not prior and self.scripts.OnShow then self.scripts.OnShow(self) end end
function common:Hide() local prior=self.shown;self.shown=false;if prior and self.scripts.OnHide then self.scripts.OnHide(self) end end
function common:IsShown() return self.shown end
function common:SetShown(shown) if shown then self:Show() else self:Hide() end end
function common:SetSize(w,h) self.width,self.height=w,h;if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end end
function common:GetSize() return self:GetWidth(),self:GetHeight() end
function common:GetWidth() return self.all and self.all:GetWidth() or self.width end
function common:GetHeight() return self.all and self.all:GetHeight() or self.height end
function common:SetWidth(w) self.width=w end
function common:SetHeight(h) self.height=h end
function common:GetEffectiveScale() return .75 end
function common:SetScale(scale) self.scale=scale end
function common:GetLeft() return 20 end
function common:GetBottom() return 30 end
function common:SetPoint(point,...) self.points[point]={...} end
function common:ClearAllPoints() self.points={};self.all=nil end
function common:SetAllPoints(p) self.all=p or self.parent end
function common:SetFontString(font) self.fontString=font end
function common:SetText(t) self.text=t;if self.fontString then self.fontString:SetText(t) end end
function common:GetText() return self.text or '' end
function common:SetAlpha(a) self.alpha=a end
function common:EnableKeyboard(on) assert(not combat,'keyboard method used in combat');self.keyboard=on end
function common:SetPropagateKeyboardInput(on) assert(not combat,'keyboard propagation changed in combat');self.propagate=on end
function common:ClearFocus() if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
function common:CreateTexture() return object('Texture',self) end
function common:CreateLine() return object('Line',self) end
function common:CreateFontString() return object('FontString',self) end
function common:GetRegions() return unpack(self.children) end
function common:SetStartPoint(a,p,x,y) assert(type(p)=='table' and type(x)=='number' and type(y)=='number') end
function common:SetEndPoint(a,p,x,y) assert(type(p)=='table' and type(x)=='number' and type(y)=='number') end
local actorTemplates={ModelSceneActorTemplate=true}
function scene:CreateActor(name,template)
 assert(type(name)=='string' and type(template)=='string')
 assert(actorTemplates[template], 'ModelScene:CreateActor(): Couldn\'t find inherited node "'..template..'"')
 return object('Actor',self)
end
function scene:GetCameraFieldOfView() return self.fov or math.pi/4 end
function scene:SetCameraFieldOfView(fov) assert(type(fov)=="number");self.fov=fov end
function scene:SetCameraPosition(x,y,z) self.cx,self.cy,self.cz=x,y,z end
function scene:SetCameraOrientationByAxisVectors(fx,fy,fz,rx,ry,rz,ux,uy,uz) self.f={fx,fy,fz};self.r={rx,ry,rz};self.u={ux,uy,uz} end
function scene:SetCameraOrientationByYawPitchRoll(yaw,pitch,roll)
 assert(roll==0,'practice camera must not roll')
 local cy,sy,cp,sp=math.cos(yaw),math.sin(yaw),math.cos(pitch),math.sin(pitch)
 self.f={cp*cy,cp*sy,-sp};self.r={sy,-cy,0};self.u={sp*cy,sp*sy,cp}
 self.cameraYaw,self.cameraPitch=yaw,pitch
end
function scene:Project3DPointTo2D(x,y,z)
 local vx,vy,vz=x-self.cx,y-self.cy,z-self.cz; local f,r,u=self.f,self.r,self.u
 local d=vx*f[1]+vy*f[2]+vz*f[3];if d<=.1 then return end
 return (self:GetWidth()/2+(self.projectionXSign or 1)*680*(vx*r[1]+vy*r[2]+vz*r[3])/d)*.75,(self:GetHeight()/2+680*(vx*u[1]+vy*u[2]+vz*u[3])/d)*.75,d
end
function actor:SetYaw(yaw) self.yaw=yaw end
function actor:IsLoaded() return true end
function actor:SetModelByFileID(fileID) assert(type(fileID)=="number" and fileID>0);self.fileID=fileID;return true end
function actor:GetActiveBoundingBox() return -13.88788,-13.88788,0,13.88788,13.88788,27.77576 end
function actor:SetModelByUnit() return true end
function actor:SetModelByCreatureDisplayID(id) self.displayID=id;return true end
function CreateFrame(kind,name,parent) return object(kind,parent,name) end
UIParent=object('Frame');UIParent:SetSize(1920,1080)
STANDARD_TEXT_FONT='mock';SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=noop}
function GetTime() return now end
function time() return 1788500000 end
function date() return '2026-09-04' end
function InCombatLockdown() return combat end
function GetCurrentKeyBoardFocus() return focus end
function IsKeyDown(k) return keyboard[k] end
function IsMouseButtonDown(k) return mouse[k] end
function GetCursorDelta()
 deltaReads=deltaReads+1
 local dx,dy=cursorX-deltaCursorX,deltaCursorY-cursorY
 return dx,dy
end
function GetCursorPosition() return cursorX,cursorY end
function ChatFrame_OpenChat() end
function EJ_GetCreatureInfo() return 1,'Rashok','description',12345 end
function GetLocale() return 'enUS' end
function GetBindingKey(action) bindingReads=bindingReads+1;return unpack(nativeBindings[action] or {}) end
function SetBinding() error('training must never modify native bindings') end
function SaveBindings() error('training must never save native bindings') end
local EL={};for _,f in ipairs({'Namespace.lua','Locale.lua','Theme.lua','MouseCapture.lua','Persistence.lua','Simulation.lua','Sszorak.lua','Sentinels.lua','Rehearsal.lua','SceneAssets.lua','ArenaRoom.lua','ViewMotion.lua','Renderer.lua','TempestRenderer.lua','SentinelsRenderer.lua','SentinelsArena.lua','Input.lua','ReferenceTrace.lua','Interface.lua','TrainingUI.lua','SentinelsUI.lua','Bootstrap.lua'}) do assert(loadfile(base..f))('EncounterLab',EL) end
local failures,checks=0,0
local function test(name,fn) checks=checks+1;local ok,err=pcall(fn);if ok then print('PASS '..name) else failures=failures+1;print('FAIL '..name..': '..tostring(err)) end end
local function fire(frame,event,...) assert(frame.scripts[event],'missing '..event);return frame.scripts[event](frame,...) end
local function clickText(ui,text)
 for _,b in ipairs(ui.modalWidgets or {}) do if b.caption.text==text then return fire(b,'OnClick') end end
 error('button missing '..text)
end
local events=frames[#frames];fire(events,'OnEvent','ADDON_LOADED','EncounterLab')
local ui,rawUIUpdate
local function openArena()
 ui:Show()
 if ui.selectingEncounter then ui:SelectEncounter(ui.options.scenario) end
end
test('bootstrap opens encounter selection without rendering or showing the arena',function()
 SlashCmdList.ENCOUNTERLAB('');ui=EL.instance;assert(ui and ui.frame:IsShown())
 rawUIUpdate=ui.Update
 function ui:Update(elapsed)
  local result=rawUIUpdate(self,elapsed)
  deltaCursorX,deltaCursorY=cursorX,cursorY
  return result
 end
 ui:Update(.1)
 assert(ui.selectingEncounter and ui.modal:IsShown() and ui.modalTitle.text=='Encounters')
 assert(not ui.viewport:IsShown() and not ui.menu:IsShown() and not ui.bottom:IsShown())
 assert(not ui.renderer.projectionValid and not ui.sim and not ui:IsGameplayInputAllowed())
 ui:Start();assert(not ui.sim,'start shortcut bypasses selection')
 ui:SelectEncounter('rashok');ui:Update(.1)
 assert(ui.renderer:GetDiagnostics().projection=='calibrated')
end)
test('first launch uses the full screen and keeps setup accessible',function()
 assert(ui.options.fullscreen==true and EL.Store.GetOptions().fullscreen==true)
 assert(ui.frame.scale==1 and ui.frame.all==UIParent,'fullscreen must use UIParent at scale 1')
 assert(ui.viewport.all==ui.frame,'arena does not cover the full window')
 assert(ui.menu:IsShown() and not ui:IsGameplayInputAllowed(),'setup must block scene input')
end)
test('fullscreen choice survives saved options reload',function()
 ui:SetFullscreen(false);assert(not ui.options.fullscreen and not EL.Store.GetOptions().fullscreen)
 assert(ui.frame.all==nil and ui.viewport.all==nil,'windowed mode retains full-screen anchors')
 assert(ui.side:IsShown() and ui.frame.scale<=1,'windowed controls or fit missing')
 local db=EL.Store.db;EL.Store.Initialize(db);assert(EL.Store.GetOptions().fullscreen==false)
 ui:ToggleFullscreen();assert(ui.options.fullscreen and EL.Store.GetOptions().fullscreen)
end)
test('menu and dock controls stay above the scene input capture',function()
 local capture=ui.input.frame:GetFrameLevel()
 assert(ui.menu:GetFrameLevel()>capture,'menu covered by scene input')
 assert(ui.top:GetFrameLevel()>capture and ui.side:GetFrameLevel()>capture,'menu children covered by scene input')
 assert(ui.bottom:GetFrameLevel()>capture,'dock covered by scene input')
 ui:ShowSettings();assert(ui.modal:GetFrameLevel()>capture and ui.modal:GetFrameLevel()>ui.menu:GetFrameLevel(),'modal covered by scene input or setup')
 assert(ui.modalBlocker:IsShown() and ui.modalBlocker.mouseEnabled and ui.modalBlocker.all==ui.frame,'modal must intercept clicks across the window')
 assert(ui.modalBlocker:GetFrameLevel()>ui.menu:GetFrameLevel() and ui.modalBlocker:GetFrameLevel()>ui.bottom:GetFrameLevel(),'underlying GUI escapes modal blocker')
 assert(ui.modal:GetFrameLevel()>ui.modalBlocker:GetFrameLevel(),'modal blocker covers its controls')
 ui:CloseModal();assert(not ui.modalBlocker:IsShown(),'closing modal leaves an invisible click blocker')
end)
test('start clears menu chrome and Escape opens and resumes training',function()
 ui:Start();assert(not ui.menu:IsShown() and ui:IsGameplayInputAllowed())
 keyboard.W=true;ui.input:KeyDown('W');ui.input.buttons.RightButton=true
 ui:HandleEscape();assert(ui.menu:IsShown() and ui.sim.state.status=='paused' and not ui:IsGameplayInputAllowed())
 assert(next(ui.input.keys)==nil and next(ui.input.buttons)==nil,'menu reopening leaves held input latched')
 local sample=ui.input:Sample();assert(sample.forward==0 and sample.strafe==0)
 ui:HandleEscape();assert(not ui.menu:IsShown() and ui.sim.state.status=='running' and ui:IsGameplayInputAllowed())
 keyboard={}
end)
test('closing setup preserves a pause the user made earlier',function()
 ui:Start();ui:TogglePause();ui:SetMenuVisible(true);ui:SetMenuVisible(false)
 assert(ui.sim.state.status=='paused','setup closing resumes a pre-existing user pause')
end)
test('modal opened from setup keeps training paused until setup closes',function()
 ui:Start();ui:SetMenuVisible(true);ui:ShowHelp();ui:ShowSettings();ui:CloseModal()
 assert(ui.menu:IsShown() and ui.sim.state.status=='paused' and not ui:IsGameplayInputAllowed())
 ui:SetMenuVisible(false);assert(ui.sim.state.status=='running')
end)
test('F11 from setup settings keeps training paused until modal closes',function()
 ui:Start();ui:SetMenuVisible(true);ui:ShowSettings();ui.input:KeyDown('F11')
 assert(not ui.options.fullscreen and ui.modal:IsShown() and ui.sim.state.status=='paused','F11 resumes beneath an open modal')
 assert(not ui.input:GameplayAllowed(),'windowed modal permits gameplay input')
 ui:CloseModal();assert(ui.sim.state.status=='running','modal did not inherit the setup pause')
 ui:SetFullscreen(true)
end)
test('closing setup under an open modal transfers its pause ownership',function()
 ui:Start();ui:SetMenuVisible(true);ui:ShowSettings();ui:SetMenuVisible(false)
 assert(not ui.menu:IsShown() and ui.modal:IsShown() and ui.sim.state.status=='paused','closing setup resumes beneath a modal')
 ui:CloseModal();assert(ui.sim.state.status=='running')
end)
test('fullscreen round trip with a modal retains the original resume intent',function()
 ui:Start();ui:SetMenuVisible(true);ui:ShowSettings();ui:SetFullscreen(false);ui:SetFullscreen(true)
 assert(ui.menu:IsShown() and ui.modal:IsShown() and ui.sim.state.status=='paused')
 ui:CloseModal();assert(ui.sim.state.status=='paused','modal closing resumes beneath fullscreen setup')
 ui:SetMenuVisible(false);assert(ui.sim.state.status=='running','fullscreen round trip lost the menu/modal pause owner')
 ui:TogglePause();ui:SetMenuVisible(true);ui:ShowSettings();ui:SetFullscreen(false);ui:SetFullscreen(true)
 ui:CloseModal();ui:SetMenuVisible(false);assert(ui.sim.state.status=='paused','fullscreen round trip resumes a pre-existing user pause')
end)
test('native movement bindings include alternate keys and walking',function()
 ui:Start();assert(bindingReads>0 and ui.input:Binding('forward')=='W')
 assert(ui.input:Matches('forward','UP') and ui.input:Binding('walk')=='NUMPADDIVIDE')
 keyboard.UP=true;ui.input:KeyDown('UP');assert(ui.input:Sample().forward==1)
 keyboard={};fire(ui.input.frame,'OnKeyUp','UP')
 local reads=bindingReads;for i=1,20 do ui.input:Sample() end;assert(bindingReads==reads,'physical sampling repeatedly scans bindings')
 ui:ShowSettings();local labels={}
 for _,control in ipairs(ui.modalWidgets) do labels[control.caption:GetText()]=true end
 assert(labels['Forward: W / UP'] and labels['Walk / run: NUMPADDIVIDE'],'controls must show imported aliases and walking binding')
 ui:CloseModal()
end)
test('strafe keys move toward the intended screen side for either native projection handedness',function()
 local preset,bindings=ui.options.bindingPreset,ui.options.bindings
 local problems={}
 for _,projectionSign in ipairs({1,-1}) do
  ui.renderer.frame.projectionXSign=projectionSign
  ui.renderer:Resize()
  for _,yaw in ipairs({0,math.pi/2,-2.6}) do
   for _,rightMouse in ipairs({false,true}) do
    local custom={};for action,key in pairs(EL.Input.DEFAULT_BINDINGS) do custom[action]=key end
    if not rightMouse then custom.left,custom.right,custom.turnLeft,custom.turnRight='A','D','Q','E' end
    ui.options.bindingPreset,ui.options.bindings='custom',custom
    for _,held in ipairs({'A','D','AD'}) do
     keyboard,mouse={},{}
     ui:Start()
     local player=ui.sim.state.player
     player.x,player.y,player.yaw=0,0,yaw
     player.previousX,player.previousY,player.previousYaw=0,0,yaw
     ui.camera.yaw,ui.camera.renderYaw=yaw,yaw
     ui:Update(0) -- Calibrate this native camera before accepting movement.
     for key in held:gmatch('.') do keyboard[key]=true;fire(ui.input.frame,'OnKeyDown',key) end
     if rightMouse then mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton') end
     ui:Update(.2)
     local origin=ui.renderer.frame:Project3DPointTo2D(0,0,0)
     local position=ui.renderer.frame:Project3DPointTo2D(player.x,player.y,0)
     local delta=position-origin
     local valid=held=='A' and delta<-.1 or held=='D' and delta>.1 or
      held=='AD' and math.abs(player.x)<1e-9 and math.abs(player.y)<1e-9
     if not valid then problems[#problems+1]=string.format('projection=%d yaw=%.2f RMB=%s keys=%s screen delta=%.3f',projectionSign,yaw,tostring(rightMouse),held,delta) end
    end
   end
  end
 end
 keyboard,mouse={},{}
 ui.renderer.frame.projectionXSign=nil
 ui.renderer:Resize()
 ui.options.bindingPreset,ui.options.bindings=preset,bindings
 ui:Start();ui:Update(0)
 assert(#problems==0,table.concat(problems,'; '))
end)

test('all modal entry points',function() for _,name in ipairs({'ShowScores','ShowHistory','ShowHelp','ShowSettings','ShowAbilities','ShowDiagnostics'}) do ui[name](ui);assert(ui.modal:IsShown());ui:CloseModal() end end)
test('modal text height resets',function() ui:ShowSettings();ui:ShowHelp();assert(ui.modalBody:GetHeight()>=350,'help retains short settings height '..ui.modalBody:GetHeight()) end)
test('modal text anchor resets',function() ui:ShowScores();ui:ShowHelp();local p=ui.modalBody.points.TOPLEFT;assert(p[#p]==-58,'help retains scores y='..tostring(p[#p])) end)
test('minimum window size contains the menu without overlapping its dock',function()
 ui:SetFullscreen(false)
 local top=ui.menu.points.TOPLEFT;local dock=ui.bottom.points.BOTTOM
 local menuBottom=-top[#top]+ui.menu:GetHeight()
 local dockTop=ui.frame.resizeBounds[2]-dock[#dock]-ui.bottom:GetHeight()
 assert(menuBottom<dockTop,'minimum window makes menu and dock overlap')
 local retry=ui.retryButton.points.TOPLEFT;local scores=ui.highscoresButton.points.TOPLEFT
 assert(-retry[#retry]+ui.retryButton:GetHeight()<-scores[#scores],'retry overlaps highscores')
 local sideTop,sideBottom=ui.side.points.TOPLEFT,ui.side.points.BOTTOMRIGHT
 local sideHeight=ui.menu:GetHeight()+sideTop[#sideTop]-sideBottom[#sideBottom]
 local last=ui.fullscreenButton.points.TOPLEFT
 assert(-last[#last]+ui.fullscreenButton:GetHeight()<sideHeight,'last menu action clips outside sidebar')
 ui:SetFullscreen(true)
end)
test('start and restart lifecycle',function() ui:Start();local old=ui.sim;ui:Start(true);assert(old._destroyed);assert(ui.sim~=old and ui.sim.state.status=='running' and not ui.recorded) end)
test('fresh camera follows initial facing',function() ui:Start();assert(ui.camera.yaw==ui.sim.state.player.yaw);ui:Update(.1);assert(ui.camera.targetX==ui.sim.state.player.x and ui.camera.targetY==ui.sim.state.player.y) end)
test('mouse capture retains held movement',function() ui.input:Acquire();keyboard.W=true;ui.input:KeyDown('W');mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');assert(ui.input:Sample().forward==1,'mouse Acquire clears W');keyboard.W=nil end)
test('both mouse buttons move forward',function() ui.input:Acquire();mouse.LeftButton=true;mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','LeftButton');fire(ui.input.frame,'OnMouseDown','RightButton');assert(ui.input:Sample().forward==1,'second mouse Acquire clears first button');mouse={} end)
test('fresh RMB filters a stale frame delta without snapping camera or facing',function()
 keyboard,mouse={},{};cursorX,cursorY=300,300;ui:Start();ui:Update(0)
 local player=ui.sim.state.player
 player.yaw,player.displayYaw,player.previousYaw,player.previousDisplayYaw=0,0,0,0
 ui.camera.yaw,ui.camera.renderYaw=0,0
 deltaCursorX,deltaCursorY=cursorX-8,cursorY+3
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
 assert(ui.camera.yaw==0 and player.yaw==0,'stale frame delta snapped fresh RMB')
 assert(ui.camera.playerFacingYaw==nil,'stale frame delta falsely aligned RMB facing')
 mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton');ui.input:Acquire()
end)
test('free orbit remains steady and RMB only aligns facing when the cursor moves',function()
 keyboard,mouse={},{};cursorX,cursorY=300,300;ui:Start()
 local player=ui.sim.state.player
 player.x,player.y,player.yaw,player.displayYaw=0,0,0,0
 player.previousX,player.previousY,player.previousYaw,player.previousDisplayYaw=0,0,0,0
 ui.camera.yaw,ui.camera.renderYaw=0,0;ui:Update(0)
 mouse.LeftButton=true;fire(ui.input.frame,'OnMouseDown','LeftButton');ui:Update(0)
 cursorX=cursorX-40;ui:Update(.02)
 local orbit=ui.camera.yaw
 assert(math.abs(orbit)>.001,'drag did not orbit the scene camera')
 assert(math.abs(player.yaw)<1e-9,'LMB changed player facing')
 for i=1,10 do ui:Update(.01) end
 assert(math.abs(ui.camera.yaw-orbit)<1e-9,'holding a stationary cursor drifts the camera')
 mouse.LeftButton=nil;fire(ui.input.frame,'OnMouseUp','LeftButton')
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
 assert(math.abs(player.yaw)<1e-9,'RMB press snaps player facing after a free orbit')
 assert(math.abs(ui.camera.yaw-orbit)<1e-9,'RMB press snaps the orbit camera')
 local time,x,y=ui.sim.state.time,player.x,player.y
 cursorX=cursorX+2;ui:Update(1/240)
 local delta=(player.yaw-ui.camera.yaw+math.pi)%(2*math.pi)-math.pi
 assert(math.abs(delta)<1e-9,'RMB cursor movement does not align player with the camera')
 assert(math.abs(ui.sim.state.time-time-1/240)<1e-9 and player.x==x and player.y==y,'stationary RMB input must advance time without translating')
 assert(math.abs((ui.renderer.playerActor.yaw-ui.camera.renderYaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'stationary actor did not align in the same rendered sample')
 keyboard,mouse={},{};fire(ui.input.frame,'OnMouseUp','RightButton');ui.input:Acquire()
end)

test('240 FPS mouse movement survives quiet frames before fixed simulation ticks',function()
 keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start()
 local p=ui.sim.state.player
 p.x,p.y,p.yaw,p.displayYaw=0,0,0,0
 p.previousX,p.previousY,p.previousYaw,p.previousDisplayYaw=0,0,0,0
 ui.camera.yaw,ui.camera.renderYaw=0,0;ui:Update(0)
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
 keyboard.W=true;fire(ui.input.frame,'OnKeyDown','W')
 for frame=1,12 do
  if frame%2==1 then cursorX=cursorX+1 end
  ui:Update(1/240)
  if frame%4==0 then
   local error=(p.yaw-ui.camera.yaw+math.pi)%(2*math.pi)-math.pi
   assert(math.abs(error)<1e-9,'fixed tick lost mouse facing sampled on an earlier render frame')
   local dx,dy=p.x-p.previousX,p.y-p.previousY
   local c,s=math.cos(ui.camera.yaw),math.sin(ui.camera.yaw)
   assert(dx*c+dy*s>0 and math.abs(dx*s-dy*c)<1e-9,'W kept the old heading after the camera turned')
  end
 end
 keyboard,mouse={},{};fire(ui.input.frame,'OnMouseUp','RightButton');ui.input:Acquire()
end)

test('144 FPS straight mouse movement applies facing and translation on every render',function()
 local function angle(value) return (value+math.pi)%(2*math.pi)-math.pi end
 for _,key in ipairs({'W','S'}) do
  keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start()
  ui:Update(0)
  keyboard[key]=true;fire(ui.input.frame,'OnKeyDown',key)
  mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
  local lastBody,lastCamera,movedFrames=nil,nil,0
  for frame=1,48 do
   local time,x,y=ui.sim.state.time,ui.sim.state.player.x,ui.sim.state.player.y
   cursorX=cursorX+1;ui:Update(1/144)
   local player=ui.sim.state.player
   assert(math.abs(ui.sim.state.time-time-1/144)<1e-9,'movement did not consume this input frame')
   if math.abs(player.x-x)+math.abs(player.y-y)>1e-9 then movedFrames=movedFrames+1 end
   assert(math.abs(ui.renderer.sourcePlayer.x-player.x)<1e-9 and math.abs(ui.renderer.sourcePlayer.y-player.y)<1e-9,'presentation received stale simulation input')
   assert(math.abs(angle(player.yaw-ui.camera.yaw))<1e-9,key..': logical facing trails the current RMB camera')
   if frame>8 then
    local body,camera=ui.renderer.playerActor.yaw,ui.renderer.renderCamera.renderYaw
    assert(math.abs(angle(body-camera))<1e-9,key..': player body trails the live mouse camera')
    if lastBody then
     assert(math.abs(angle(body-lastBody)-angle(camera-lastCamera))<1e-9,key..': body rotation speed varies against a steady camera')
    end
    lastBody,lastCamera=body,camera
   end
  end
  assert(movedFrames==48,'some movement frames still wait for a mechanics tick')
  keyboard,mouse={},{};fire(ui.input.frame,'OnMouseUp','RightButton');ui.input:Acquire()
 end
end)

test('moving RMB strafe preserves body offsets at 60, 144 and 240 FPS, including fast turns',function()
 local function angle(value) return (value+math.pi)%(2*math.pi)-math.pi end
 local profiles={{'Q',math.pi/2},{'E',-math.pi/2},{'WQ',math.pi/4},{'WE',-math.pi/4},{'SQ',-math.pi/4},{'SE',math.pi/4}}
 for _,fps in ipairs({60,144,240}) do
  for _,speed in ipairs({-20,20}) do
   for _,profile in ipairs(profiles) do
    keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
    for key in profile[1]:gmatch('.') do keyboard[key]=true;fire(ui.input.frame,'OnKeyDown',key) end
    mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
    cursorX=cursorX+.01
    for frame=1,math.ceil(fps*.3) do ui:Update(1/fps) end
    local lastBody,lastCamera
    for frame=1,math.ceil(fps*.4) do
     local time,px,py=ui.sim.state.time,ui.sim.state.player.x,ui.sim.state.player.y
     cursorX=cursorX-speed/(fps*.054);ui:Update(1/fps)
     local p=ui.sim.state.player
     if time==ui.sim.state.time then assert(p.x==px and p.y==py,'render-sampled facing changed fixed movement') end
     assert(math.abs(angle(p.yaw-ui.camera.yaw))<1e-9,'logical facing trails RMB during strafe')
     local body,camera=ui.renderer.playerActor.yaw,ui.renderer.renderCamera.renderYaw
     assert(math.abs(angle(body-camera-profile[2]))<1e-7,profile[1]..' body offset drifts during mouse turn at '..fps..' FPS')
     if lastBody then assert(math.abs(angle(body-lastBody)-angle(camera-lastCamera))<1e-7,'body reverses or catches up against a steady camera') end
     assert(math.abs(ui.renderer.renderCamera.targetX-ui.renderer.renderPlayer.x)<1e-9 and math.abs(ui.renderer.renderCamera.targetY-ui.renderer.renderPlayer.y)<1e-9,'camera translation diverges from rendered player')
     lastBody,lastCamera=body,camera
    end
    keyboard,mouse={},{};fire(ui.input.frame,'OnMouseUp','RightButton');ui.input:Acquire()
   end
  end
 end
end)

test('stationary and airborne RMB facing follows the camera in the same render',function()
 local function begin()
  keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
  keyboard.W=true;fire(ui.input.frame,'OnKeyDown','W')
  mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
  cursorX=cursorX+1;ui:Update(1/60)
  assert(ui.camera.playerFacingYaw~=nil,'straight grounded mouse facing is unavailable')
 end

 begin()
 keyboard.W=nil;fire(ui.input.frame,'OnKeyUp','W');ui:Update(0)
 local player=ui.sim.state.player
 local yaw,time,x,y=player.yaw,ui.sim.state.time,player.x,player.y
 cursorX=cursorX+2;ui:Update(1/240)
 assert(player.yaw~=yaw,'stationary RMB delta did not update logical facing')
 assert(math.abs(ui.sim.state.time-time-1/240)<1e-9 and player.x==x and player.y==y,'stationary RMB input must advance time without translating')
 assert(math.abs((ui.renderer.playerActor.yaw-ui.camera.renderYaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'stationary RMB actor trails the camera')

 begin()
 keyboard.SPACE=true;fire(ui.input.frame,'OnKeyDown','SPACE');ui:Update(1/60)
 player=ui.sim.state.player
 assert(player.z>0,'airborne RMB fixture did not jump')
 yaw=player.yaw
 cursorX=cursorX+2;ui:Update(1/240)
 assert(player.yaw~=yaw,'airborne RMB delta did not update logical facing')
 assert(ui.camera.playerFacingYaw~=nil,'airborne RMB facing was rejected')
 assert(math.abs((ui.renderer.playerActor.yaw-ui.renderer.renderCamera.playerFacingYaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'airborne actor trails the presented RMB camera')
 keyboard,mouse={},{};fire(ui.input.frame,'OnMouseUp','RightButton');ui.input:Acquire()
end)

test('forced movement, death and inactive controls reject RMB facing',function()
 local function begin()
  keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
  mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
  cursorX=cursorX+1;ui:Update(1/60)
  assert(ui.camera.playerFacingYaw~=nil,'RMB facing fixture did not align')
 end
 local cases={
  {'roll',function() assert(ui.sim:UseAbility('roll')) end},
  {'leap',function() assert(ui.sim:UseAbility('leap')) end},
  {'death',function() ui.sim:_kill('test') end},
 }
 for _,case in ipairs(cases) do
  begin();case[2]()
  local yaw=ui.sim.state.player.yaw
  cursorX=cursorX+2;ui:Update(1/240)
  assert(ui.sim.state.player.yaw==yaw,case[1]..' accepted RMB facing')
  assert(ui.camera.playerFacingYaw==nil,case[1]..' exposed rejected mouse-facing presentation')
 end

 begin();local yaw=ui.sim.state.player.yaw;ui:TogglePause();cursorX=cursorX+2;ui:Update(1/240)
 assert(ui.sim.state.player.yaw==yaw and ui.camera.playerFacingYaw==nil,'paused session accepted RMB facing')
 begin();yaw=ui.sim.state.player.yaw;mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton');cursorX=cursorX+2;ui:Update(1/240)
 assert(ui.sim.state.player.yaw==yaw and ui.camera.playerFacingYaw==nil,'released RMB continued facing')
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('both buttons align and move immediately; partial release preserves the remaining role',function()
 keyboard,mouse={},{};ui:Start()
 local originalEnabled,originalSpeed=cvars.enableMouseSpeed,cvars.mouseSpeed
 local player=ui.sim.state.player
 player.x,player.y,player.yaw,player.displayYaw=0,0,0,0
 player.previousX,player.previousY,player.previousYaw,player.previousDisplayYaw=0,0,0,0
 ui.camera.yaw,ui.camera.renderYaw=.75,.75
 mouse.LeftButton=true;fire(ui.input.frame,'OnMouseDown','LeftButton')
 ui:Update(0)
 assert(player.yaw==0,'LMB-only press changed player facing')
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
 local time=ui.sim.state.time
 ui:Update(1/240)
 assert(math.abs(ui.sim.state.time-time-1/240)<1e-9,'both-button movement must consume the current frame')
 assert(math.abs(player.yaw-.75)<1e-9,'both-button press did not align logical facing immediately')
 assert(math.abs((ui.renderer.playerActor.yaw-.75+math.pi)%(2*math.pi)-math.pi)<1e-9,'both-button press did not align actor immediately')
 assert(ui.input:Sample().forward==1,'both buttons do not report forward movement')
 keyboard.S=true;fire(ui.input.frame,'OnKeyDown','S')
 assert(ui.input:Sample().forward==0,'both buttons override a held backward key')
 assert(ui.input.mouse.active,'drag does not capture relative mouse input')
 assert(cvars.enableMouseSpeed=='1' and tonumber(cvars.mouseSpeed)==.1,'drag must retain its temporary cursor settings')
 keyboard.S=nil;fire(ui.input.frame,'OnKeyUp','S')
 local x,y=player.x,player.y
 ui:Update(1/60)
 local dx,dy=player.x-x,player.y-y
 assert(dx*math.cos(.75)+dy*math.sin(.75)>0,'both-button forward did not use aligned facing')
 mouse.LeftButton=nil;fire(ui.input.frame,'OnMouseUp','LeftButton')
 assert(ui.input.mouse.active,'partial release drops the remaining mouse capture')
 local rightOnly=ui.input:Sample()
 assert(rightOnly.forward==0 and rightOnly.lockFacing and rightOnly.yaw==ui.camera.yaw,'LMB release did not retain RMB-only role')
 assert(cvars.enableMouseSpeed=='1' and tonumber(cvars.mouseSpeed)==.1,'partial release must retain the cursor lease')
 mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
 assert(not ui.input.mouse.active,'final release retains mouse capture')
 assert(cvars.enableMouseSpeed==originalEnabled and cvars.mouseSpeed==originalSpeed,'final release changed mouse settings')
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('Both-to-RMB applies post-release residual to camera and facing without a relative reread',function()
 local function angle(value) return (value+math.pi)%(2*math.pi)-math.pi end
 keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
 local originalEnabled,originalSpeed=cvars.enableMouseSpeed,cvars.mouseSpeed
 local player=ui.sim.state.player
 player.yaw,player.displayYaw,player.previousYaw,player.previousDisplayYaw=0,0,0,0
 ui.camera.yaw,ui.camera.renderYaw,ui.camera.pitch=0,0,.5
 mouse.LeftButton,mouse.RightButton=true,true
 fire(ui.input.frame,'OnMouseDown','LeftButton');fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
 local reads=deltaReads
 cursorX,cursorY=cursorX+2,cursorY+1
 mouse.LeftButton=nil;fire(ui.input.frame,'OnMouseUp','LeftButton')
 local releaseYaw,releasePitch=ui.camera.yaw,ui.camera.pitch
 assert(deltaReads==reads,'Both-to-RMB mouse-up reread relative delta')
 cursorX,cursorY=cursorX+1,cursorY+.5
 ui:Update(1/240)
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 assert(deltaReads==reads,'Both-to-RMB cached sample reread relative delta')
 assert(math.abs(angle(yaw-releaseYaw))>.001 and pitch<releasePitch,'Both-to-RMB lost post-release yaw or pitch residual')
 assert(math.abs(angle(player.yaw-yaw))<1e-9,'remaining RMB did not face final camera yaw')
 assert(math.abs(angle(ui.renderer.playerActor.yaw-yaw))<1e-9,'remaining RMB actor did not face final camera yaw')
 assert(ui.input.buttons.RightButton and not ui.input.buttons.LeftButton,'Both-to-RMB lost remaining button role')
 ui:Update(1/240)
 assert(math.abs(angle(ui.camera.yaw-yaw))<1e-9 and math.abs(ui.camera.pitch-pitch)<1e-9,'Both-to-RMB residual replayed')
 assert(math.abs(angle(player.yaw-yaw))<1e-9 and math.abs(angle(ui.renderer.playerActor.yaw-yaw))<1e-9,'Both-to-RMB facing drifted after residual')
 mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
 assert(cvars.enableMouseSpeed==originalEnabled and cvars.mouseSpeed==originalSpeed,'Both-to-RMB changed mouse CVars')
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('Both-to-LMB applies post-release residual to camera while preserving last RMB facing',function()
 local function angle(value) return (value+math.pi)%(2*math.pi)-math.pi end
 keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
 local originalEnabled,originalSpeed=cvars.enableMouseSpeed,cvars.mouseSpeed
 local player=ui.sim.state.player
 player.yaw,player.displayYaw,player.previousYaw,player.previousDisplayYaw=0,0,0,0
 ui.camera.yaw,ui.camera.renderYaw,ui.camera.pitch=0,0,.5
 mouse.LeftButton,mouse.RightButton=true,true
 fire(ui.input.frame,'OnMouseDown','LeftButton');fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
 local reads=deltaReads
 cursorX,cursorY=cursorX+2,cursorY+1
 mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
 local releaseYaw,releasePitch=ui.camera.yaw,ui.camera.pitch
 assert(deltaReads==reads,'Both-to-LMB mouse-up reread relative delta')
 cursorX,cursorY=cursorX+1,cursorY+.5
 ui:Update(1/240)
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 assert(deltaReads==reads,'Both-to-LMB cached sample reread relative delta')
 assert(math.abs(angle(yaw-releaseYaw))>.001 and pitch<releasePitch,'Both-to-LMB lost camera-only yaw or pitch residual')
 assert(math.abs(angle(player.yaw-releaseYaw))<1e-9,'Both-to-LMB changed logical facing after RMB release')
 assert(math.abs(angle(ui.renderer.playerActor.yaw-releaseYaw))<1e-9,'Both-to-LMB actor followed LMB-only orbit')
 assert(ui.input.buttons.LeftButton and not ui.input.buttons.RightButton,'Both-to-LMB lost remaining button role')
 ui:Update(1/240)
 assert(math.abs(angle(ui.camera.yaw-yaw))<1e-9 and math.abs(ui.camera.pitch-pitch)<1e-9,'Both-to-LMB residual replayed')
 assert(math.abs(angle(player.yaw-releaseYaw))<1e-9 and math.abs(angle(ui.renderer.playerActor.yaw-releaseYaw))<1e-9,'Both-to-LMB last RMB facing drifted')
 mouse.LeftButton=nil;fire(ui.input.frame,'OnMouseUp','LeftButton')
 assert(cvars.enableMouseSpeed==originalEnabled and cvars.mouseSpeed==originalSpeed,'Both-to-LMB changed mouse CVars')
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('quick RMB delta before the first sample survives mouse-up once at 60, 144 and 240 FPS',function()
 local function angle(value) return (value+math.pi)%(2*math.pi)-math.pi end
 for _,fps in ipairs({60,144,240}) do
  keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
  local player=ui.sim.state.player
  player.yaw,player.displayYaw,player.previousYaw,player.previousDisplayYaw=0,0,0,0
  ui.camera.yaw,ui.camera.renderYaw=0,0
  local startPitch=ui.camera.pitch
  mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
  cursorX,cursorY=cursorX+2,cursorY+1
  local reads=deltaReads
  mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
  assert(deltaReads==reads,'quick mouse-up read frame-wide relative delta at '..fps..' FPS')
  ui:Update(1/fps)
  local yaw,pitch=ui.camera.yaw,ui.camera.pitch
  assert(math.abs(yaw)>.001,'final RMB delta was dropped at '..fps..' FPS')
  assert(pitch<startPitch,'quick absolute residual used relative pitch direction at '..fps..' FPS')
  assert(math.abs(angle(player.yaw-yaw))<1e-9,'final RMB facing did not reach logical orientation at '..fps..' FPS')
  assert(math.abs(angle(ui.renderer.playerActor.yaw-yaw))<1e-9,'final RMB facing did not reach actor at '..fps..' FPS')
  for frame=1,math.ceil(fps/60)+2 do ui:Update(1/fps) end
  assert(math.abs(angle(ui.camera.yaw-yaw))<1e-9,'released RMB delta turned camera twice at '..fps..' FPS')
  assert(math.abs(ui.camera.pitch-pitch)<1e-9,'released RMB delta changed pitch twice at '..fps..' FPS')
  assert(math.abs(angle(player.yaw-yaw))<1e-9,'released RMB facing did not persist through a fixed tick at '..fps..' FPS')
  assert(math.abs(angle(ui.renderer.playerActor.yaw-yaw))<1e-9,'released RMB actor facing drifted after a fixed tick at '..fps..' FPS')
 end
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('cursor sample followed by mouse-up in the same frame applies yaw and pitch once',function()
 keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
 local player=ui.sim.state.player
 player.yaw,player.displayYaw,player.previousYaw,player.previousDisplayYaw=0,0,0,0
 ui.camera.yaw,ui.camera.renderYaw,ui.camera.pitch=0,0,.5
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(0)
 cursorX,cursorY=cursorX+2,cursorY-1
 rawUIUpdate(ui,1/240)
 local yaw,pitch,reads=ui.camera.yaw,ui.camera.pitch,deltaReads
 assert(math.abs(yaw)>.001 and pitch>.5,'relative sample did not apply yaw and pitch')
 assert(math.abs((player.yaw-yaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'relative sample did not align logical facing')
 mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
 assert(deltaReads==reads,'same-frame mouse-up reread frame-wide relative delta')
 assert(ui.camera.yaw==yaw and ui.camera.pitch==pitch,'same-frame mouse-up applied the cursor delta twice')
 deltaCursorX,deltaCursorY=cursorX,cursorY
 ui:Update(1/240)
 assert(ui.camera.yaw==yaw and ui.camera.pitch==pitch,'post-release frame replayed sampled cursor delta')
 assert(math.abs((player.yaw-yaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'sampled facing changed after release')
 assert(math.abs((ui.renderer.playerActor.yaw-yaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'sampled actor facing changed after release')
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('every UI exit releases dragging and restores the original mouse settings',function()
 local originalEnabled,originalSpeed=cvars.enableMouseSpeed,cvars.mouseSpeed
 local exits={
  {'menu',function() ui:SetMenuVisible(true) end},
  {'modal',function() ui:ShowHelp() end},
  {'hide',function() ui:Hide() end},
  {'focus',function() focus={};ui:Update(.01);focus=nil end},
  {'combat',function() combat=true;fire(events,'OnEvent','PLAYER_REGEN_DISABLED');combat=false end},
  {'error',function()
   local render=ui.renderer.Render;ui.renderer.Render=function() error('deliberate drag render failure') end
   fire(ui.frame,'OnUpdate',.01);ui.renderer.Render=render
  end},
  {'logout',function()
   for _,frame in ipairs(frames) do if frame.events.PLAYER_LOGOUT and frame.scripts.OnEvent then fire(frame,'OnEvent','PLAYER_LOGOUT') end end
  end},
 }
 for _,exit in ipairs(exits) do
  keyboard,mouse={},{};openArena();ui:Start()
  mouse.LeftButton=true;fire(ui.input.frame,'OnMouseDown','LeftButton')
   assert(ui.input.mouse.active,exit[1]..': drag capture did not start')
   assert(cvars.enableMouseSpeed=='1' and tonumber(cvars.mouseSpeed)==.1,exit[1]..': drag has no cursor lease')
  exit[2]()
   assert(not ui.input.mouse.active,exit[1]..': mouse capture was not released')
   assert(cvars.enableMouseSpeed==originalEnabled and cvars.mouseSpeed==originalSpeed,exit[1]..': exit changed mouse settings')
 end
 keyboard,mouse={},{};openArena();ui:Start()
end)

test('RMB plus every WASD direction follows the sampled camera while sweeping at 60, 144 and 240 FPS',function()
 local cases={{'W',1,0},{'S',-1,0},{'A',0,1},{'D',0,-1},
              {'WA',1,1},{'WD',1,-1},{'SA',-1,1},{'SD',-1,-1}}
 for _,fps in ipairs({60,144,240}) do
  for _,case in ipairs(cases) do
   keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
   local p=ui.sim.state.player
   p.x,p.y,p.previousX,p.previousY=0,0,0,0
   p.yaw,p.displayYaw,p.previousYaw,p.previousDisplayYaw=0,0,0,0
   ui.camera.yaw,ui.camera.renderYaw,ui.camera.pitch=0,0,.5
   for key in case[1]:gmatch('.') do keyboard[key]=true;fire(ui.input.frame,'OnKeyDown',key) end
   mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
   for frame=1,fps/2 do
    local x,y,time=p.x,p.y,ui.sim.state.time
    cursorX=cursorX+20/fps
    ui:Update(1/fps)
    local yaw=ui.camera.yaw
    assert(math.abs((p.yaw-yaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'RMB heading trails mouse for '..case[1])
    if ui.sim.state.time>time then
     local dx,dy=p.x-x,p.y-y
     local forward=dx*math.cos(yaw)+dy*math.sin(yaw)
     local strafe=(-dx*math.sin(yaw)+dy*math.cos(yaw))*(ui.renderer.lateralInputSign or 1)
     local distance=math.sqrt(dx*dx+dy*dy)
     local norm=math.sqrt(case[2]^2+case[3]^2)
     assert(distance>0,'WASD did not move for '..case[1])
     assert(math.abs(forward/distance-case[2]/norm)<1e-8,'forward movement used old camera heading for '..case[1])
     assert(math.abs(strafe/distance-case[3]/norm)<1e-8,'strafe movement used old camera heading for '..case[1])
    end
   end
   local yaw,pitch=ui.camera.yaw,ui.camera.pitch
   mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
   assert(ui.camera.yaw==yaw and ui.camera.pitch==pitch,'WASD/RMB release changes camera angle')
  end
 end
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('small RMB pitch changes reach both scene cameras directly in fullscreen and windowed mode',function()
 local yawSpeed,pitchSpeed=cvars.cameraYawMoveSpeed,cvars.cameraPitchMoveSpeed
 local wasFullscreen=ui.options.fullscreen
 cvars.cameraYawMoveSpeed,cvars.cameraPitchMoveSpeed='270','45'
 for _,fullscreen in ipairs({true,false}) do
  for _,fps in ipairs({60,144,240}) do
   keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:SetFullscreen(fullscreen);ui:Start();ui:Update(0)
   ui.camera.pitch=.5
   local expected=.5
   mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
   for i=1,48 do
    local dy=i<=24 and .125 or -.125
    cursorY=cursorY+dy
    expected=expected-dy*.054*(45/180)
    ui:Update(1/fps)
    assert(math.abs(ui.camera.pitch-expected)<1e-9,'vertical input uses horizontal speed or loses fractional motion')
    assert(math.abs(ui.renderer.frame.cameraPitch-ui.renderer.renderCamera.pitch)<1e-9,'character scene and presented view disagree')
    local floorScene=ui.renderer.assets.floor[1].actor.parent
    assert(floorScene==ui.renderer.frame and math.abs(floorScene.cameraPitch-ui.renderer.renderCamera.pitch)<1e-9,'floor and character must use the same presented camera')
   end
   assert(math.abs(ui.camera.pitch-.5)<1e-9,'vertical direction reversal does not return to the starting angle')
   mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
   local pitch=ui.camera.pitch;ui:Update(1/fps)
   assert(ui.camera.pitch==pitch,'release adds a vertical camera jump')
  end
 end
 cvars.cameraYawMoveSpeed,cvars.cameraPitchMoveSpeed=yawSpeed,pitchSpeed
 keyboard,mouse={},{};ui:SetFullscreen(wasFullscreen);ui.input:Acquire()
end)

test('RMB strafe reaches the drawn camera immediately, including taps shorter than a mechanics step',function()
 for _,fps in ipairs({144,240}) do
  keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
  local p=ui.sim.state.player
  p.x,p.y,p.previousX,p.previousY=20,0,20,0
  p.yaw,p.previousYaw,p.displayYaw,p.previousDisplayYaw=math.pi,math.pi,math.pi,math.pi
  ui.camera.yaw=math.pi
  mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
  local x,y=p.x,p.y
  keyboard.A=true;fire(ui.input.frame,'OnKeyDown','A')
  ui:Update(1/fps)
  local sign=ui.renderer.lateralInputSign or 1
  assert(math.abs(p.y-(y-7/fps*sign))<1e-9,'short strafe input waits for a mechanics tick')
  assert(math.abs(ui.renderer.renderPlayer.y-p.y)<1e-9,'drawn player uses an older position than the camera heading')
  assert(math.abs(ui.camera.targetY-p.y)<1e-9,'camera follows a delayed strafe position')
  keyboard.A=nil;fire(ui.input.frame,'OnKeyUp','A');keyboard.D=true;fire(ui.input.frame,'OnKeyDown','D')
  ui:Update(1/fps)
  assert(math.abs(p.x-x)<1e-9 and math.abs(p.y-y)<1e-9,'opposite short strafe taps have unequal displacement')
  keyboard.D=nil;fire(ui.input.frame,'OnKeyUp','D');ui:Update(1/fps)
  assert(math.abs(p.y-y)<1e-9,'releasing strafe leaves a simulation movement tail')
  for i=1,math.ceil(EL.ViewMotion.WINDOW*fps)+1 do ui:Update(1/fps) end
  assert(math.abs(ui.renderer.renderPlayer.y-y)<1e-9,'stopped presentation exceeds its bounded window')
 end
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('circle strafing holds a fixed target at the same screen position through direction changes',function()
 local function angle(value) return (value+math.pi)%(2*math.pi)-math.pi end
 local worstScreen,worstPosition,cases=0,0,0
 for _,fullscreen in ipairs({true,false}) do
  for _,intervals in ipairs({{1/60},{1/144},{1/240},{1/75,1/165,1/90,1/240}}) do
   keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:SetFullscreen(fullscreen);ui:Start();ui:Update(0)
   ui.sim._queue,ui.sim._queueIndex={},1
   ui.sim.state.pools,ui.sim.state.waves={},{}
   local p=ui.sim.state.player
   p.x,p.y,p.previousX,p.previousY=28,0,28,0
   p.yaw,p.previousYaw,p.displayYaw,p.previousDisplayYaw=math.pi,math.pi,math.pi,math.pi
   ui.sim.state.boss.x,ui.sim.state.boss.y,ui.sim.state.boss.z=0,0,0
   ui.camera.yaw,ui.camera.pitch=math.pi,.35
   mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
   local expectedX,expectedY,elapsed,index=28,0,0,0
   while elapsed<1.5-1e-9 do
    index=index+1
    local dt=math.min(intervals[(index-1)%#intervals+1],1.5-elapsed)
    local left=math.floor(elapsed/.25)%2==0
    keyboard.A,keyboard.D=left or nil,not left or nil
    fire(ui.input.frame,left and 'OnKeyDown' or 'OnKeyUp','A')
    fire(ui.input.frame,left and 'OnKeyUp' or 'OnKeyDown','D')
    local sign=(left and 1 or -1)*(ui.renderer.lateralInputSign or 1)
    local radius=math.sqrt(expectedX^2+expectedY^2)
    local theta=math.atan2(expectedY,expectedX)-sign*math.asin(7*dt/radius)
    local nextRadius=math.sqrt(radius^2-(7*dt)^2)
    expectedX,expectedY=nextRadius*math.cos(theta),nextRadius*math.sin(theta)
    local yaw=angle(theta+math.pi)
    local gain=.054*(tonumber(cvars.cameraYawMoveSpeed)/180)*(ui.options.mouseSensitivity/.006)
    cursorX=cursorX-angle(yaw-ui.camera.yaw)/gain
    ui:Update(dt)
    local sx=ui.renderer:Project(0,0,0)
    assert(sx,'fixed target left the camera')
    worstScreen=math.max(worstScreen,math.abs(sx-ui.renderer.ox))
    worstPosition=math.max(worstPosition,math.sqrt((p.x-expectedX)^2+(p.y-expectedY)^2))
    assert(math.abs(ui.renderer.renderCamera.targetX-ui.renderer.renderPlayer.x)<1e-9 and math.abs(ui.renderer.renderCamera.targetY-ui.renderer.renderPlayer.y)<1e-9,'camera/player use different translation times')
    elapsed=elapsed+dt
   end
   cases=cases+1
  end
 end
 print(string.format('Circle strafe: %d cases, max target displacement %.9f UI units, max trajectory error %.9f yards',cases,worstScreen,worstPosition))
 -- Averaging a short curved pose introduces a subpixel geometric remainder;
 -- retain a 0.0001 UI-unit bound and the original simulation accuracy bound.
 assert(worstScreen<1e-4 and worstPosition<1e-7,'target tracking mixes unrelated camera/player poses or changes the trajectory')
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('recorded input retains accepted sensitivity while the coherent view settles within 24 ms',function()
 local savedYaw,savedPitch=cvars.cameraYawMoveSpeed,cvars.cameraPitchMoveSpeed
 cvars.cameraYawMoveSpeed,cvars.cameraPitchMoveSpeed='180','90'
 keyboard,mouse={},{};cursorX,cursorY=300,300;openArena();ui:Start();ui:Update(0)
 ui.sim._queue,ui.sim._queueIndex={},1
 ui.sim.state.pools,ui.sim.state.waves={},{}
 ui.sim.state.player.x,ui.sim.state.player.y=0,0
 ui.camera.yaw,ui.camera.pitch=0,.6
 keyboard.A=true;fire(ui.input.frame,'OnKeyDown','A')
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
 local fixture=assert(loadfile('tests/recorded_mouse_fixture.lua'))()
 local worstYaw,worstPitch,oldWorst=0,0,0
 local shownYaw,shownPitch,maxShownYaw,maxShownPitch=nil,nil,0,0
 local rawVelocity,viewVelocity,rawJitter,viewJitter={0,0},{0,0},{0,0},{0,0}
 local expectedYaw,expectedPitch=0,.6
 for _,row in ipairs(fixture) do
  local yaw,pitch=ui.camera.yaw,ui.camera.pitch
  cursorX,cursorY=cursorX+row[2],cursorY+row[3]
  ui:Update(row[1])
  local shown=ui.renderer.renderCamera
  if shownYaw then
   maxShownYaw=math.max(maxShownYaw,math.abs((shown.yaw-shownYaw+math.pi)%(2*math.pi)-math.pi))
   maxShownPitch=math.max(maxShownPitch,math.abs(shown.pitch-shownPitch))
   local raw={((ui.camera.yaw-yaw+math.pi)%(2*math.pi)-math.pi)/row[1],(ui.camera.pitch-pitch)/row[1]}
   local view={((shown.yaw-shownYaw+math.pi)%(2*math.pi)-math.pi)/row[1],(shown.pitch-shownPitch)/row[1]}
   for axis=1,2 do
    rawJitter[axis]=rawJitter[axis]+(raw[axis]-rawVelocity[axis])^2
    viewJitter[axis]=viewJitter[axis]+(view[axis]-viewVelocity[axis])^2
    rawVelocity[axis],viewVelocity[axis]=raw[axis],view[axis]
   end
  end
  shownYaw,shownPitch=shown.yaw,shown.pitch
  expectedYaw=(expectedYaw-row[2]*.054+math.pi)%(2*math.pi)-math.pi
  expectedPitch=math.max(0,math.min(math.pi*.49,expectedPitch-row[3]*.027))
  assert(math.abs((ui.camera.yaw-expectedYaw+math.pi)%(2*math.pi)-math.pi)<1e-9,'accepted yaw response changed')
  assert(math.abs(ui.camera.pitch-expectedPitch)<1e-9,'accepted pitch response changed')
  local turn=math.abs((ui.camera.yaw-yaw+math.pi)%(2*math.pi)-math.pi)
  worstYaw=math.max(worstYaw,turn)
  worstPitch=math.max(worstPitch,math.abs(ui.camera.pitch-pitch))
  oldWorst=math.max(oldWorst,math.abs(row[2])*.054)
  if row[2]==0 then assert(turn<1e-9,'quiet X sample must not extrapolate a camera turn') end
  if row[3]==0 then assert(ui.camera.pitch==pitch,'quiet Y sample must not extrapolate pitch') end
 end
 assert(oldWorst>math.rad(1.6),'fixture must reproduce the reported coarse input')
 assert(math.abs(worstYaw-oldWorst)<1e-9,'accepted angular gain changed')
 assert(cvars.mouseSpeed=='0.1','accepted physical cursor setting changed')
 local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 keyboard.A=nil;fire(ui.input.frame,'OnKeyUp','A')
 mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton');ui:Update(1/240)
 assert(ui.camera.yaw==yaw and ui.camera.pitch==pitch,'release leaves a camera correction tail')
 print(string.format('Recorded mouse: %d transitions retain input sensitivity; view max yaw %.6f -> %.6f, pitch %.6f -> %.6f degrees (offline replay)',#fixture,math.deg(worstYaw),math.deg(maxShownYaw),math.deg(worstPitch),math.deg(maxShownPitch)))
 print(string.format('Recorded angular velocity change RMS ratio: yaw %.6f, pitch %.6f',math.sqrt(viewJitter[1]/rawJitter[1]),math.sqrt(viewJitter[2]/rawJitter[2])))
 -- Variable frame duration and consecutive cursor counts can increase the
 -- largest individual displayed step. Compare the velocity discontinuities
 -- across the complete recording, keeping raw angle equality above as a gate.
 -- 0.6.7 measured RMS ratios .134984/.132700 on this exact recording.
 -- Require the segment integral to improve both axes, alongside unchanged
 -- raw input and the independent variable-cadence analytic regression.
 for axis=1,2 do assert(viewJitter[axis]<rawJitter[axis]*.0121,'segment presentation regresses to the 0.6.7 velocity discontinuities') end
 for i=1,6 do ui:Update(1/240) end
 local shown=ui.renderer.renderCamera
 assert(math.abs((shown.yaw-yaw+math.pi)%(2*math.pi)-math.pi)<1e-9 and math.abs(shown.pitch-pitch)<1e-9,'presented view has a release tail beyond 24 ms')
 cvars.cameraYawMoveSpeed,cvars.cameraPitchMoveSpeed=savedYaw,savedPitch
 keyboard,mouse={},{};ui.input:Acquire()
end)

test('jump is a single edge',function() ui:Start();keyboard.SPACE=true;ui.input:KeyDown('SPACE');assert(ui.input:Sample().jump);ui.input:KeyDown('SPACE');assert(not ui.input:Sample().jump);keyboard.SPACE=nil;fire(ui.input.frame,'OnKeyUp','SPACE');ui.input:KeyDown('SPACE');assert(ui.input:Sample().jump);keyboard={} end)
test('binding reset updates label and storage',function() ui:ShowSettings();ui.input:BeginBinding('ability');ui.input:KeyDown('G');assert(ui.input:Binding('ability')=='G');ui:ShowSettings();clickText(ui,'Reset custom bindings');assert(ui.input:Binding('ability')=='F' and EL.Store.GetOptions().bindings.ability=='F') end)
test('teleport setup works from abilities modal',function() ui:Start();ui:ShowAbilities();clickText(ui,'Place teleport point');assert(ui.sim.state.abilities.teleport,'opening modal paused run so setup always fails') end)
test('gateway setup works from abilities modal',function() ui:Start();ui:ShowAbilities();clickText(ui,'Place gateway');assert(ui.sim.state.abilities.gateway,'opening modal paused run so setup always fails') end)
test('paused leap does not arm unusable aim',function() ui:Start();ui:TogglePause();ui.options.selectedAbility='leap';ui:UseSelectedAbility();assert(not ui.aiming,'paused leap arms target then fails on click') end)
test('combat releases capture without protected reconfiguration',function() ui:Start();ui:ShowHelp();combat=true;fire(events,'OnEvent','PLAYER_REGEN_DISABLED');assert(not ui.frame:IsShown() and not ui.input.active and not ui.input.frame:IsShown());assert(not ui.modalBlocker:IsShown(),'combat hide leaves modal click blocker');assert(ui.sim.state.interrupted);assert(not ui.frame.scripts.OnUpdate);combat=false;openArena() end)
test('simulation renderer hazard contracts',function() ui:Start();ui.sim:Advance(.5,{});ui.sim:Advance(.5,{});assert(ui.sim.state.slam and ui.sim.state.slam.ends);ui:Update(.1);for i=1,14 do ui.sim:Advance(.5,{}) end;for _,p in ipairs(ui.sim.state.pools) do assert(p.radius==10) end;for _,w in ipairs(ui.sim.state.waves) do assert(w.radius==3.875) end;ui:Update(.1) end)
test('frontal center warning is visible without hints and clears after the cast',function()
 ui.options.hints=false;ui:Start();ui.renderer:SetHints(false)
 ui.sim.state.frontal={x=0,y=0,yaw=0,starts=0,ends=5,width=math.pi/2}
 ui:Update(.1)
 assert(ui.centerText.text=='Frontal - move out of its path','active frontal has no center warning with hints off')
 ui.sim.state.frontal=nil;ui:Update(.1)
 assert(ui.centerText.text=='','finished frontal leaves a stale center warning')
end)

test('cast countdown follows active mechanic',function()
 ui:Start();ui.sim:Advance(.5,{});ui.sim:Advance(.5,{});ui:Update(.1);assert(ui.castFrame:IsShown() and ui.castText.text:find('Slam'));assert(ui.castFill:GetWidth()>1);ui.sim.state.slam=nil;ui.sim.state.frontal={x=0,y=0,yaw=0,starts=ui.sim.state.time,ends=ui.sim.state.time+5};ui:Update(.1);assert(ui.castText.text:find('Frontal'));ui.sim.state.frontal=nil;ui:Update(.1);assert(not ui.castFrame:IsShown())
end)
test('completed results record once and survive reload',function()
 if ui.sim then ui.sim:Destroy();ui.sim=nil end;EL.Store.Initialize(nil);ui:Start();while ui.sim.state.status=='running' do ui.sim:Advance(.5,{}) end;ui:Update(.1);local history=EL.Store.GetHistory();assert(#history==1 and history[1].completed);assert(ui.lastRecord.saved);ui:Update(.1);assert(#EL.Store.GetHistory()==1);local old=EL.Store.db;EL.Store.Initialize(old);assert(#EL.Store.GetHistory()==1 and #EL.Store.GetBoard('reference',1)==1)
end)
test('completed HUD keeps final score visible',function() ui.recorded=false;ui:Update(.1);local summary=ui.centerText.text;ui:Update(.1);assert(ui.centerText.text==summary,'next HUD update erases final score') end)
test('assisted scores stay out of normal board',function() local before=#EL.Store.GetBoard('reference',1);ui:Start();ui:TogglePause();ui:TogglePause();while ui.sim.state.status=='running' do ui.sim:Advance(.5,{}) end;ui:Update(.1);assert(#EL.Store.GetBoard('reference',1)==before);assert(#EL.Store.GetBoard('assisted',1)==1) end)
test('pause key repeat remains paused until release',function() ui:Start();keyboard.P=true;ui.input:KeyDown('P');assert(ui.sim.state.status=='paused');ui.input:KeyDown('P');assert(ui.sim.state.status=='paused','Clear removes pause key edge latch');keyboard.P=nil;fire(ui.input.frame,'OnKeyUp','P') end)
test('modal close preserves existing user pause',function() ui:Start();ui:TogglePause();ui:ShowHelp();ui:ShowSettings();ui:CloseModal();assert(ui.sim.state.status=='paused') end)
test('modal nesting returns running state',function() ui:Start();ui:ShowHelp();ui:ShowSettings();ui:CloseModal();assert(ui.sim.state.status=='running' and ui.sim.state.assisted) end)
test('abandoned run enters history without a leaderboard result',function()
 ui:Start();ui.sim:Advance(.5,{});local before=#EL.Store.GetHistory();ui:Start(true);local h=EL.Store.GetHistory();assert(#h==before+1 and h[1].interrupted and not h[1].highscoreEligible and not h[1].completed)
end)
test('unloaded models do not advance invisible hazards',function()
 ui:Start();ui.renderer.diagnostics.playerModel='loading';ui:Update(.1);assert(ui.sim.state.elapsed==0);ui.renderer.diagnostics.playerModel='ready';ui.renderer.diagnostics.bossModel='ready';ui:Update(.1);assert(ui.sim.state.elapsed>0)
end)
test('render overflow pauses and invalidates the result',function()
 ui:Start();for i=1,513 do ui.sim.state.waves[i]={id=i,x=20,y=0,previousX=20,previousY=0,dx=0,dy=0,radius=3.875,alpha=1} end;ui:Update(.1);assert(ui.sim.state.status=='paused' and ui.sim.state.interrupted and ui.renderFailure)
end)
test('runtime drawing error releases all inputs',function()
 ui:Start();local render=ui.renderer.Render;ui.renderer.Render=function() error('deliberate render failure') end;fire(ui.frame,'OnUpdate',.1);assert(not ui.frame:IsShown() and not ui.input.active and not ui.frame.scripts.OnUpdate);ui.renderer.Render=render;openArena()
end)
test('Sszorak selection exposes only Tempest starting points',function()
 keyboard,mouse={},{};openArena();ui:ShowEncounters();clickText(ui,'Sszorak')
 assert(ui.options.scenario=='sszorak' and not ui.modal:IsShown() and ui.menuVisible)
 assert(ui.drillOptionsButton:IsShown() and ui.trainingButton.caption.text=='Encounters')
 ui:ShowTrainingTools()
 clickText(ui,'Middle')
 assert(ui.options.sszorakDrill=='tempest' and EL.Store.GetOptions().sszorakCheckpoint==2)
 clickText(ui,'Start training');ui:Update(0);ui:Update(.1)
 assert(ui.sim.state.scenario=='sszorak' and ui.sim.state.time>16 and not ui.loadingScene)
 assert(ui.renderer.encounter=='sszorak' and ui.renderer.bossActor:IsShown() and ui.renderer.bossActor.displayID==142788)
 assert(ui.renderer.bossLabel.text=='Sszorak' and ui.renderer.tempestRenderer)
 assert(ui.renderer.assets.floor[1].radius==42)
 assert(ui.checkpointButton:IsShown() and ui.replayButton:IsShown())
end)
test('Sszorak renderer reuses geometry and clears old encounter effects',function()
 ui.options.sszorakDrill='combined';ui.options.sszorakCheckpoint=2;ui:SaveOptions();ui:Start();ui:Update(0)
 local count=#frames;local tornado=ui.renderer.tempestRenderer.tornadoes[1]
 for i=1,20 do ui:Update(.1) end
 assert(#frames==count and ui.renderer.tempestRenderer.tornadoes[1]==tornado)
 assert(tornado.actor:IsShown() and tornado.actor.fileID==2529592,'active tornado has no native model')
 ui.options.scenario='rashok';ui:SaveOptions();ui:Start();now=now+1;ui:Update(.1)
 assert(not tornado.actor:IsShown() and ui.renderer.assets.floor[1].radius==100)
 assert(ui.renderer.encounter=='rashok' and not ui.rehearsal)
 assert(not ui.checkpointButton:IsShown())
end)
test('mistake replay freezes live state and abilities while allowing camera orbit',function()
 ui.options.scenario='sszorak';ui.options.sszorakDrill='tempest';ui.options.sszorakCheckpoint=1;ui:SaveOptions();ui:Start();ui:Update(0)
 ui.sim._checkHazards=function() end
 for i=1,60 do ui:Update(1/60) end
 ui.sim.state.failureSerial=1;ui.sim.state.failure={serial=1,reason='Tempest tornado',time=ui.sim.state.time,x=0,y=-8}
 ui.sim:_kill('Tempest tornado');ui:Update(0)
 assert(ui.rehearsal.frozen);local time=ui.sim.state.time;local yaw,pitch=ui.camera.yaw,ui.camera.pitch
 ui:BeginReplay();assert(ui.replay and ui.sim.state.status=='paused' and ui.replayBar:IsShown())
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton');ui:Update(1/60)
 cursorX,cursorY=cursorX+5,cursorY+3;ui:Update(1/60)
 assert(ui.camera.yaw~=yaw and ui.sim.state.time==time)
 ui:UseAbility('blink');ui:Revive();assert(ui.sim.state.player.dead and not ui.sim.state.abilities.cooldowns.blink)
 ui:SeekReplay(-1);ui:Update(.1);assert(ui.sim.state.time==time)
 mouse.RightButton=nil;fire(ui.input.frame,'OnMouseUp','RightButton')
 ui:EndReplay();assert(not ui.replay and not ui.replayBar:IsShown() and ui.sim.state.status=='running')
 assert(ui.camera.yaw==yaw and ui.camera.pitch==pitch)
end)
test('checkpoint retry exits replay and restores seed, mechanics and unranked status',function()
 local seed=ui.sim.options.seed;ui:BeginReplay();ui:RetryCheckpoint()
 assert(not ui.replay and ui.sim.rewound and ui.sim.state.status=='running' and ui.sim.state.assisted)
 assert(ui.sim.options.seed==seed and not ui.sim.state.player.dead and not ui.rehearsal.frozen)
 assert(ui.renderer.replayTrail==nil and not ui.replayBar:IsShown())
 ui.sim._checkHazards=function() end;ui.sim._moveWaves=function() end
 while ui.sim.state.status=='running' do ui.sim:Advance(.5,{}) end
 ui:Update(.1);assert(ui.lastRecord.saved and not ui.lastRecord.entry.highscoreEligible)
 assert(ui.lastRecord.entry.version==ui.sim.version)
end)
test('leaving replay transfers pause ownership to open menus and modals',function()
 ui:SetFullscreen(true);ui:Start();ui.sim.state.failureSerial=1;ui.sim.state.failure={serial=1,reason='Tempest tornado',time=ui.sim.state.time,x=0,y=-8}
 ui.sim:_kill('Tempest tornado');ui:Update(0);ui:BeginReplay()
 ui:SetMenuVisible(true);ui:EndReplay()
 assert(ui.sim.state.status=='paused' and ui.menuResume)
 ui:SetMenuVisible(false);assert(ui.sim.state.status=='running')
 ui:BeginReplay();ui:ShowSettings();ui:EndReplay()
 assert(ui.sim.state.status=='paused' and ui.modalResume)
 ui:CloseModal();assert(ui.sim.state.status=='running')
end)
test('Sszorak scores use selected drill version and restart repeats the original drill',function()
 ui.options.sszorakDrill='tempest';ui.options.sszorakCheckpoint=3;ui:SaveOptions();ui:Start()
 local version=ui.sim.version
 ui.options.sszorakCheckpoint=1;ui:SaveOptions();ui:Start(true)
 assert(ui.sim.version==version and ui.sim.drill=='tempest')
 ui:ShowScores();assert(ui.modalTitle.text:find('Tempest'))
 ui:ShowHistory();assert(ui.modalBody.text:find('Sszorak'))
 ui:CloseModal()
end)
test('replay hide releases camera input and never resumes hidden gameplay',function()
 ui:Start();ui.sim.state.failureSerial=1;ui.sim.state.failure={serial=1,reason='Tempest tornado',time=ui.sim.state.time,x=0,y=-8}
 ui.sim:_kill('Tempest tornado');ui:Update(0);ui:BeginReplay()
 mouse.RightButton=true;fire(ui.input.frame,'OnMouseDown','RightButton')
 ui:Hide();assert(not ui.replay and not ui.input.active and ui.sim.state.status=='paused')
 assert(not ui.replayBar:IsShown() and ui.renderer.replayTrail==nil)
 mouse,keyboard={},{};ui.options.scenario='rashok';ui:SaveOptions();openArena();ui:Start()
end)
test('selector hides an existing run in both layouts and cancellation never reveals it',function()
 for _,fullscreen in ipairs({true,false}) do
  ui:SetFullscreen(fullscreen);ui:Start();local before=ui.sim.state.elapsed
  ui:ShowEncounters();ui:Update(.2)
  assert(ui.sim.state.elapsed==before and not ui.viewport:IsShown() and not ui.bottom:IsShown())
  assert(not ui.menu:IsShown() and not ui:IsGameplayInputAllowed())
  ui:ToggleFullscreen()
  assert(not ui.viewport:IsShown() and not ui.menu:IsShown())
  ui:HandleEscape();assert(not ui.frame:IsShown() and not ui.input.active)
  ui:Show();assert(ui.selectingEncounter and not ui.viewport:IsShown())
  ui:SelectEncounter('sszorak');assert(ui.viewport:IsShown() and ui.menu:IsShown())
  assert(ui.preview.scenario=='sszorak' and ui.renderer.encounter=='sszorak')
 end
end)
test('custom button captions survive resizing, hover and layout switches',function()
 for _,fullscreen in ipairs({true,false}) do
  ui:SetFullscreen(fullscreen)
  for _,scenario in ipairs({'rashok','sszorak','sentinels'}) do
   ui:SelectEncounter(scenario);ui:UpdateControls()
   for _,b in ipairs({ui.normalButton,ui.practiceButton,ui.hintsButton,ui.speedButton,ui.fullscreenButton}) do
    local caption=b:GetText();assert(caption and caption~='' and not b.fontString)
    assert(b.caption.points.CENTER and b.caption:GetWidth()==b:GetWidth()-12 and b.caption:GetHeight()==b:GetHeight()-4)
    fire(b,'OnEnter');fire(b,'OnLeave');assert(b:GetText()==caption and b.caption:IsShown())
    local w,h=b:GetSize();b:SetSize(w+17,h+4)
    assert(b.caption:GetWidth()==w+5 and b.caption:GetHeight()==h)
    b:SetSize(w,h);assert(b:GetText()==caption)
   end
  end
 end
 assert(ui.normalButton:GetText()=='Normal' and ui.practiceButton:GetText()=='Practice')
 local small=EL.UI.CreateButton(ui.menu,'X',26,24,function()end)
 assert(small:GetText()=='X' and small.caption:GetWidth()==14 and small.caption:GetHeight()==20)
end)
test('Sentinels preview renders before Start in both layouts without a live raid state',function()
 for _,fullscreen in ipairs({true,false}) do
  ui:CloseModal();ui:SelectEncounter('rashok');ui:SetFullscreen(fullscreen)
  ui:Show();ui:SelectEncounter('sentinels')
  assert(not ui.sim and not ui.preview.groups and not ui.preview.raiders)
  local frameCount=#frames
  for i=1,120 do ui:Update(1/60) end
  assert(not ui.renderFailure,tostring(ui.renderFailure))
  assert(ui.frame:IsShown() and ui.viewport:IsShown() and ui.menu:IsShown())
  assert(ui.preview.status=='ready' and ui.preview.time==0 and not ui.sim)
  assert(#frames==frameCount,'preview allocated frames during drawing')
  local rr=ui.renderer.sentinelsRenderer
  assert(rr.bosses[1].actor:IsShown() and rr.bosses[2].actor:IsShown())
  assert(not rr.center:IsShown(),'preview invented a player-side assignment')
  for _,slot in ipairs(rr.raiders) do assert(not slot.actor:IsShown() and not slot.marker:IsShown() and not slot.ping:IsShown()) end
 end
end)

test('Sentinels selection, role options and native model rendering use the existing scene',function()
 ui:CloseModal();ui:ShowEncounters();ui:SelectEncounter('sentinels')
 assert(ui.options.scenario=='sentinels' and ui.encounterButton:GetText()=='Entombed Sentinels')
 assert(not ui.loopButtons[1]:IsShown() and ui.randomNumberLabel:IsShown() and ui.drillOptionsButton:IsShown())
 ui:SelectDrill(3);ui:Start();ui:Update(.1)
 assert(ui.sim.state.scenario=='sentinels' and ui.lastRunOptions.sentinelsNumber==0)
 assert(ui.renderer.sentinelsRenderer.renderer.frame==ui.renderer.frame)
 local own=ui.sim.state.raiders[ui.sim.state.playerIndex]
 assert(own.stacks>=1 and own.stacks<=3 and ui.rehearsal==nil)
 local rr=ui.renderer.sentinelsRenderer
 assert(rr.bosses[1].actor:IsShown() and rr.bosses[2].actor:IsShown())
 assert(rr.bosses[1].actor.displayID==143437 and rr.bosses[2].actor.displayID==143436)
 assert(not ui.renderer.bossActor:IsShown())
 local frameCount=#frames
 for i=1,120 do ui:Update(1/60) end
 assert(#frames==frameCount,'Sentinels allocated frames during gameplay')
end)
test('Sentinels reveals colored orbs briefly and routes the ability action into simulated pings',function()
 ui:Start();while ui.sim.state.playerNumber~=1 do ui:Start() end;for i=1,200 do ui:Update(1/60) end
 local s=ui.sim.state;local own=s.raiders[s.playerIndex];local rr=ui.renderer.sentinelsRenderer
 assert(s.applied and not own.pingUntil)
 local marker=rr.raiders[s.playerIndex].marker
 assert(marker.visibleStacks==1 and marker:IsShown())
 assert(not rr.raiders[s.playerIndex].label:GetText():match('^[123]$'))
 ui:UseSelectedAbility();assert(not own.pingUntil, 'generic ability action pinged')
 assert(ui.sentinelsPingButton:IsShown() and not ui.abilityButton:IsShown())
 fire(ui.sentinelsPingButton,'OnClick');assert(own.pingUntil>s.time)
 ui:Update(.1);assert(rr.raiders[s.playerIndex].ping:GetText():find('Ping_Marker_Icon_OnMyWay',1,true))
 for i=1,120 do ui:Update(1/60) end
 for i,r in ipairs(s.raiders) do
  if not r.isPlayer and r.stacks>0 then
   assert(not rr.raiders[i].label:GetText():match('^[123]$'))
   if rr.raiders[i].marker:IsShown() then assert(rr.raiders[i].marker.visibleStacks==0) end
  end
 end
 assert(ui.sentinelsPingButton:GetText()=='PING YOURSELF')
end)
test('one dedicated ping click and a manual jump allow a simulated 3 to clear the player',function()
 ui:Start();while ui.sim.state.playerNumber~=1 do ui:Start() end
 while ui.sim.state.time<3.1 do ui:Update(1/60) end
 fire(ui.sentinelsPingButton,'OnClick')
 local own=ui.sim.state.raiders[ui.sim.state.playerIndex];local firstPing=own.pingAt
 keyboard.SPACE=true;fire(ui.input.frame,'OnKeyDown','SPACE');ui:Update(1/60)
 keyboard.SPACE=nil;fire(ui.input.frame,'OnKeyUp','SPACE')
 while ui.sim.state.status=='running' do ui:Update(1/60) end
 assert(own.jumpedAt,'the real jump binding must satisfy the requirement')
 assert(firstPing and own.pingAt==firstPing and ui.sim.state.matchTime and not ui.sim.state.player.dead)
end)
test('Sentinels restart keeps original role, help and scores have encounter-owned content',function()
 ui.options.sentinelsNumber=1;ui:SaveOptions();ui:Start(true)
 assert(ui.sim.state.raiders[ui.sim.state.playerIndex].stacks==1)
 ui:ShowTrainingTools();assert(ui.modalBody:GetText():find('2: move to the center',1,true));ui:CloseModal()
 ui:ShowScores();assert(ui.modalTitle:GetText():find('Sentinels',1,true));ui:CloseModal()
 ui:ShowAbilities();assert(ui.modalTitle:GetText():find('Sentinels',1,true));ui:CloseModal()
 local oldSeed=ui.lastRunOptions.seed;ui:Revive();assert(ui.sim.state.elapsed==0 and ui.lastRunOptions.seed~=oldSeed)
end)
test('new attempts draw fresh seeds and hidden roles; explicit repeat is reproducible',function()
 local roles,camps={},{}
 for i=1,24 do
  local old=ui.lastRunOptions.seed;ui:Start();assert(ui.lastRunOptions.seed~=old)
  local state=ui.sim.state;roles[state.playerNumber]=true;camps[state.raiders[state.playerIndex].group]=true
  ui:Update(.1);assert(ui.footerText:GetText()=='Your number appears with Helical Toxins')
 end
 assert(roles[1] and roles[2] and roles[3] and camps[1] and camps[2])
 local state=ui.sim.state;local seed,role,index=ui.lastRunOptions.seed,state.playerNumber,state.playerIndex
 ui:Start(true);assert(ui.lastRunOptions.seed==seed and ui.sim.state.playerNumber==role and ui.sim.state.playerIndex==index)
 ui:Update(.1);assert(ui.sentinelsPingButton:IsShown())
 fire(ui.sentinelsPingButton,'OnClick');assert(not ui.sim.state.raiders[index].pingAt)
end)
test('leaving Sentinels hides every actor and label and returns to normal abilities',function()
 local rr=ui.renderer.sentinelsRenderer
 ui:SelectEncounter('rashok')
 assert(not ui.sentinelsPingButton:IsShown() and ui.abilityButton:IsShown() and ui.loopButtons[1]:IsShown())
 for _,slot in ipairs(rr.raiders) do assert(not slot.actor:IsShown() and not slot.label:IsShown() and not slot.ping:IsShown() and not slot.marker:IsShown()) end
 for _,slot in ipairs(rr.bosses) do assert(not slot.actor:IsShown() and not slot.label:IsShown()) end
 ui:Start();ui:Update(.1);assert(ui.sim.state.scenario~='sentinels')
 assert(not ui.abilityButton:GetText():find('Ping yourself',1,true))
end)

test('Sentinels underflow shows the raid wipe reason and cannot record a ranked clear',function()
 ui:SelectEncounter('sentinels');ui:Start();ui:Update(.1);ui:Update(.1)
 local s=ui.sim.state;local own=s.raiders[s.playerIndex];local other=s.raiders[s.playerIndex==1 and 2 or 1]
 for _,r in ipairs(s.raiders) do r.stacks=0 end
 own.stacks,other.stacks=1,2
 own.x,own.y,own.previousX,own.previousY=0,0,0,0
 other.x,other.y,other.previousX,other.previousY=.5,0,.5,0
 s.player.x,s.player.y=0,0;s.applied=true;s.time=6
 ui.sim:_checkHazards();ui:Update(.2)
 assert(ui.centerText:GetText():find('RAID WIPE',1,true) and ui.centerText:GetText():find('Contact did not total 4',1,true))
 assert(not ui.sim:GetResult().highscoreEligible)
end)
print(string.format('INTEGRATION %d checks; %d failed. Mock/static proof only; no live WoW proof.',checks,failures))
os.exit(failures==0 and 0 or 1)
