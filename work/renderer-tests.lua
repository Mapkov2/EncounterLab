local created = { frame = 0, actor = 0, line = 0, texture = 0, scene = 0 }
local methods = {}
local function noop() end
for name in ('SetClipsChildren EnableMouse SetCameraNearClip SetCameraFarClip SetLightAmbientColor SetLightDiffuseColor SetLightDirection SetLightVisible SetAllowOverlappedModels SetUseCenterForOrigin SetAnimation SetAlpha SetColorTexture SetTexture SetVertexColor SetThickness SetVertexOffset SetPoint ClearAllPoints SetAllPoints SetText SetTextColor SetJustifyH SetJustifyV SetShadowColor SetShadowOffset SetTexCoord SetBlendMode SetSnapToPixelGrid SetTexelSnappingBias ClearModel'):gmatch('%S+') do methods[name]=noop end
-- Unknown methods must stay nil so missing native API/template assumptions fail.
local objmeta = { __index = methods }
local function object(kind, parent)
    if created[kind] then created[kind] = created[kind] + 1 end
    return setmetatable({ kind=kind, parent=parent, shown=true, width=1600, height=900, scale=0.75, left=20, bottom=30 }, objmeta)
end
function methods:GetParent() return self.parent end
function methods:GetFrameLevel() return 10 end
function methods:SetFrameLevel(level) self.level=level end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetEffectiveScale() return self.scale end
function methods:GetLeft() return self.left end
function methods:GetBottom() return self.bottom end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetScale(scale) self.modelScale=scale end
function methods:SetPosition(x,y,z) self.x,self.y,self.z=x,y,z end
function methods:SetYaw(yaw) self.yaw=yaw end
function methods:SetAnimation(animation,variation,speed) self.animation,self.animationVariation,self.animationSpeed=animation,variation,speed;self.animationCalls=(self.animationCalls or 0)+1 end
function methods:SetVertexOffset(index,x,y)
 self.vertices=self.vertices or {};self.vertices[index]={x,y}
end
function methods:SetFont(path,size,flags) self.font,self.fontSize,self.fontFlags=path,size,flags;return true end
function methods:GetFont() return self.font or 'mock',self.fontSize or 13,self.fontFlags or '' end
function methods:SetStartPoint(anchor,parent,x,y) assert(type(parent)=='table'); assert(type(x)=='number' and type(y)=='number'); self.sx,self.sy=x,y end
function methods:SetEndPoint(anchor,parent,x,y) assert(type(parent)=='table'); assert(type(x)=='number' and type(y)=='number'); self.ex,self.ey=x,y end
function methods:CreateTexture() return object('texture',self) end
function methods:CreateLine() return object('line',self) end
function methods:CreateFontString() return object('label',self) end
local actorTemplates={ModelSceneActorTemplate=true}
function methods:CreateActor(name,template)
 assert(type(name)=='string'); assert(type(template)=='string')
 assert(actorTemplates[template], 'ModelScene:CreateActor(): Couldn\'t find inherited node "'..template..'"')
 return object('actor',self)
end
function methods:SetCameraPosition(x,y,z) self.cx,self.cy,self.cz=x,y,z;self.cameraUpdates=(self.cameraUpdates or 0)+1 end
function methods:GetCameraFieldOfView() return self.fov or math.pi/4 end
function methods:SetCameraFieldOfView(fov) self.fov=fov end
function methods:SetCameraOrientationByAxisVectors(fx,fy,fz,rx,ry,rz,ux,uy,uz)
 self.forward={fx,fy,fz};self.right={rx,ry,rz};self.up={ux,uy,uz}
end
function methods:SetCameraOrientationByYawPitchRoll(yaw,pitch,roll)
 assert(roll==0,'practice camera must not roll')
 local cy,sy,cp,sp=math.cos(yaw),math.sin(yaw),math.cos(pitch),math.sin(pitch)
 self.forward={cp*cy,cp*sy,-sp};self.right={sy,-cy,0};self.up={sp*cy,sp*sy,cp}
 self.cameraYaw,self.cameraPitch=yaw,pitch
end
function methods:Project3DPointTo2D(x,y,z)
 self.projectCalls=(self.projectCalls or 0)+1
 local vx,vy,vz=x-self.cx,y-self.cy,z-self.cz
 local f,r,u=self.forward,self.right,self.up
 local d=vx*f[1]+vy*f[2]+vz*f[3]
 if d<=0.1 then return end
 local sx=self.width/2+(self.projectionXSign or 1)*680*(vx*r[1]+vy*r[2]+vz*r[3])/d
 local sy=self.height/2+680*(vx*u[1]+vy*u[2]+vz*u[3])/d
 return sx*self.scale,sy*self.scale,d
end
function methods:IsLoaded() return not self.unloaded end
function methods:SetModelByFileID(id) self.model=id;return true end
function methods:GetActiveBoundingBox() return -13.88788,-13.88788,0,13.88788,13.88788,27.77576 end
methods.GetMaxBoundingBox=methods.GetActiveBoundingBox
function methods:SetModelByUnit() return true end
function methods:SetModelByCreatureDisplayID() return true end
function CreateFrame(kind,name,parent)
 if kind=='ModelScene' then created.scene=created.scene+1 end
 return object('frame',parent)
end
function GetTime() return 2 end
function EJ_GetCreatureInfo(index,encounter)
 assert(index==1 and encounter==2525)
 return 1,'Rashok','description',12345
end
local EL={}
assert(loadfile('EncounterLab/Namespace.lua'))('EncounterLab',EL)
assert(loadfile('EncounterLab/Locale.lua'))('EncounterLab',EL)
assert(loadfile('EncounterLab/SceneAssets.lua'))('EncounterLab',EL)
assert(loadfile('EncounterLab/ViewMotion.lua'))('EncounterLab',EL)
assert(loadfile('EncounterLab/Renderer.lua'))('EncounterLab',EL)
local r=EL.Renderer.New(object('frame'))
assert(created.actor==548,'startup must prepare floor, effect pools, and character actors with native templates')
assert(created.scene==1,'world geometry must not be split across independent 3D views')
assert(r.frame.level<r.ground.level and r.ground.level<r.overlay.level,'telegraphs must remain visible above native terrain and below labels')
assert(r.playerActor.parent==r.frame and r.bossActor.parent==r.frame,'characters must share the world camera')
for _,slot in ipairs(r.assets.floor) do assert(slot.actor.parent==r.frame,'floor uses a separate world camera') end
for _,group in ipairs(r.assets.groups) do
 for _,slot in ipairs(group.slots) do assert(slot.actor.parent==r.frame,'hazard uses a separate world camera') end
end
assert(created.line==366,'normal rendering must not allocate thousands of optional hit-outline lines')
r:SetHints(true)
local counts={created.frame,created.actor,created.line,created.texture}
local state={player={x=0,y=0,z=0,yaw=0},boss={x=12,y=0,yaw=math.pi},pools={},waves={},time=1,status='running'}
for i=1,401 do local a=i*2*math.pi/401;state.waves[i]={x=25*math.cos(a),y=25*math.sin(a),radius=3.875} end
for _,scale in ipairs({0.64,0.75,1}) do
 r.frame.scale=scale
 for _,yaw in ipairs({0,math.pi/2,math.pi,4.2}) do
  for _,pitch in ipairs({0.075*math.pi,0.4,1.3}) do
   local cam={yaw=yaw,pitch=pitch,distance=60,targetX=0,targetY=0,targetZ=1.2}
   r:Render(state,cam)
   assert(r.frame.cameraYaw==yaw and r.frame.cameraPitch==pitch,'camera must use the native yaw/pitch/roll API')
   for _,p in ipairs({{0,0},{4,3},{-2,-5}}) do
    local sx,sy=r:Project(p[1],p[2],0)
    assert(sx and sy)
    local px,py=r:GetGroundPoint((sx+r.frame.left)*scale,(sy+r.frame.bottom)*scale)
    assert(px and math.abs(px-p[1])<1e-7 and math.abs(py-p[2])<1e-7,'projection/picking round trip')
    local nx,ny=r.frame:Project3DPointTo2D(p[1],p[2],0)
    assert(math.abs(sx-nx/scale)<1e-7 and math.abs(sy-ny/scale)<1e-7,'native projection parity')
   end
  end
 end
end
assert(created.frame==counts[1] and created.actor==counts[2] and created.line==counts[3] and created.texture==counts[4], 'Render allocated new native regions')
local d=r:GetDiagnostics();assert(d.waves==401 and d.overflow==0 and d.playerModel=='ready' and d.bossModel=='ready')
assert(d.nativeFloor and d.nativeWaves==401 and not d.projectedGround,'loaded native graphics must replace fallback geometry')
assert(not r.floor[1].drawn and not r.waveFills[1].drawn,'native graphics still update projected floor or wave fills')
assert(d.worldScenes==1,'diagnostics must identify the shared world scene')
local projectionCalls=r.frame.projectCalls
local cameraUpdates=r.frame.cameraUpdates
r:Render(state,{yaw=.72,pitch=.38,distance=30,targetX=5,targetY=-3,targetZ=1.2})
assert(r.frame.cameraUpdates==cameraUpdates+1,'render must submit only one world camera update')
assert(r.frame.projectCalls==projectionCalls,'camera motion must not continuously recalibrate projection intrinsics')
r:Resize();r:Render(state,{yaw=.72,pitch=.38,distance=30,targetX=5,targetY=-3,targetZ=1.2})
assert(r.frame.projectCalls==projectionCalls+3,'resizing must refresh native projection calibration')
r.frame.fov=.9;r:Render(state,{yaw=.72,pitch=.38,distance=30,targetX=5,targetY=-3,targetZ=1.2})
assert(r.frame.projectCalls==projectionCalls+6 and r.assets.floor[1].actor.parent.fov==.9,'changed FOV must recalibrate the scene shared by floor and characters')
local function near(actual,expected,why) assert(type(actual)=='number' and math.abs(actual-expected)<1e-7,why..': '..tostring(actual)..' expected '..expected) end
local function copy(value)
 if type(value)~='table' then return value end
 local out={};for key,item in pairs(value) do out[key]=copy(item) end;return out
end
local function equal(actual,expected)
 if type(actual)~='table' or type(expected)~='table' then return actual==expected end
 for key,value in pairs(actual) do if not equal(value,expected[key]) then return false end end
 for key in pairs(expected) do if actual[key]==nil then return false end end
 return true
end
local animated={
 player={x=10,y=20,z=4,yaw=-3.1,previousX=2,previousY=4,previousZ=0,previousYaw=3.1},
 boss={x=-6,y=6,z=4,yaw=-3.1,previousX=-2,previousY=2,previousZ=0,previousYaw=3.1},
 pools={},waves={{x=8,y=4,previousX=-8,previousY=-4,radius=3.875}},time=1,status='running',
}
local camera={yaw=0,pitch=.3,distance=60,targetX=0,targetY=0,targetZ=1.2}
local originalState,originalCamera=copy(animated),copy(camera)
local ringPosition,fillPosition
local drawRing,drawFill,nativeWave=r.DrawRing,r.DrawHazardFill,r.assets.Wave
r.assets.Wave=function() return false end -- Test the projected fallback as well as native effects below.
r.DrawRing=function(self,ring,x,y,...)
 if ring==self.waveRings[1] then ringPosition={x,y} end
 return drawRing(self,ring,x,y,...)
end
r.DrawHazardFill=function(self,texture,x,y,...)
 if texture==self.waveFills[1] then fillPosition={x,y} end
 return drawFill(self,texture,x,y,...)
end
r:Render(animated,camera)
near(r.playerActor.x,10,'omitted alpha keeps current actor pose')
near(ringPosition[1],8,'omitted alpha keeps current wave pose')
r:Render(animated,camera,.25)
near(r.playerActor.x,4,'player interpolation x');near(r.playerActor.y,8,'player interpolation y');near(r.playerActor.z,1,'player interpolation z')
near(r.bossActor.x,-3/r.bossScale,'boss interpolation x');near(r.bossActor.y,3/r.bossScale,'boss interpolation y');near(r.bossActor.z,1/r.bossScale,'boss interpolation z')
local expectedYaw=3.1+(2*math.pi-6.2)*.25
near(math.sin(r.playerActor.yaw),math.sin(expectedYaw),'player takes shortest yaw path')
near(math.cos(r.playerActor.yaw),math.cos(expectedYaw),'player yaw remains near pi')
near(math.sin(r.bossActor.yaw),math.sin(expectedYaw),'boss takes shortest yaw path')
near(ringPosition[1],-4,'wave outline interpolation x');near(ringPosition[2],-2,'wave outline interpolation y')
near(fillPosition[1],-4,'wave fill interpolation x');near(fillPosition[2],-2,'wave fill interpolation y')
assert(equal(animated,originalState),'render interpolation mutated simulation state')
assert(equal(camera,originalCamera),'render interpolation mutated camera input')
assert(created.frame==counts[1] and created.actor==counts[2] and created.line==counts[3] and created.texture==counts[4], 'Interpolation allocated new native regions')
r.DrawRing,r.DrawHazardFill,r.assets.Wave=drawRing,drawFill,nativeWave
local motion={player={x=0,y=0,z=0,yaw=0,previousYaw=0,displayYaw=1,previousDisplayYaw=.5,moving=true},pools={},waves={},time=2,status='running'}
r:Render(motion,camera,.5)
near(r.playerActor.yaw,.75,'model interpolates displayed facing independently of logical facing')
local hx,hy=r:Project(2,0,0)
near(r.heading.ex,hx,'heading keeps logical facing x');near(r.heading.ey,hy,'heading keeps logical facing y')
assert(r.playerActor.animation==5,'authoritative movement must animate running even without a position delta')
local animationCalls=r.playerActor.animationCalls
r:Render(motion,camera,.5)
assert(r.playerActor.animation==5 and r.playerActor.animationCalls==animationCalls,'stationary render frames restart or interrupt the run animation')
local p=motion.player
p.displayYaw,p.previousDisplayYaw=-3.1,3.1;r:Render(motion,camera,.25)
near(math.sin(r.playerActor.yaw),math.sin(expectedYaw),'displayed facing takes shortest yaw path')
motion.status='paused';r:Render(motion,camera);assert(r.playerActor.animation==0,'paused movement keeps running')
motion.status='running';p.movingBackward=true;r:Render(motion,camera);assert(r.playerActor.animation==13,'backpedal uses forward running animation')
p.movingBackward=false;p.walking=true;r:Render(motion,camera);assert(r.playerActor.animation==4,'walking uses run animation')
p.moving=false;p.displayTurn=1;r:Render(motion,camera);assert(r.playerActor.animation==11,'left turn animation missing')
p.displayTurn=-1;r:Render(motion,camera);assert(r.playerActor.animation==12,'right turn animation missing')
p.displayTurn=0;p.z=1;p.jumpStartedAt=2;motion.time=2.1;r:Render(motion,camera);assert(r.playerActor.animation==37,'jump start animation missing')
motion.time=2.9;r:Render(motion,camera);assert(r.playerActor.animation==38,'airborne jump loop missing')
p.z=0;p.walking=false;p.moving=true;p.landedAt=3;motion.time=3;r:Render(motion,camera);assert(r.playerActor.animation==187,'running landing animation missing')
p.moving=false;motion.time=3.1;r:Render(motion,camera);assert(r.playerActor.animation==187,'stopping cancels the running landing too early')
motion.time=3.4;r:Render(motion,camera);assert(r.playerActor.animation==39,'stationary landing recovery missing')
motion.time=4.2;r:Render(motion,camera);assert(r.playerActor.animation==0,'completed landing never returns to idle')
p.landedAt=5;motion.time=5;r:Render(motion,camera);assert(r.playerActor.animation==39,'stationary landing starts a running landing')
p.dead=true;r:Render(motion,camera);assert(r.playerActor.animation==1,'death does not take animation priority')
assert(created.frame==counts[1] and created.actor==counts[2] and created.line==counts[3] and created.texture==counts[4], 'Movement animation transitions allocated new native regions')
local function frontalCovers(x,y)
 for i=1,r.drawnFrontalFills or 0 do
  local v=r.frontalFills[i].vertices
  local ax,ay,bx,by,cx,cy=v[1][1],v[1][2]+1,v[2][1],v[2][2],v[3][1]+1,v[3][2]+1
  local one=(bx-ax)*(y-ay)-(by-ay)*(x-ax)
  local two=(cx-bx)*(y-by)-(cy-by)*(x-bx)
  local three=(ax-cx)*(y-cy)-(ay-cy)*(x-cx)
  if one>=-1e-7 and two>=-1e-7 and three>=-1e-7 then return true end
 end
 return false
end
local frontalChecks=0
r:SetHints(false)
for _,yaw in ipairs({0,math.pi/2,math.pi,4.7}) do
 local danger={player={x=0,y=0,z=0,yaw=0},pools={},waves={},time=50,status='running',frontal={x=0,y=0,yaw=yaw,width=math.pi/2,starts=48.25,ends=53.25}}
 for _,camera in ipairs({{yaw=.7,pitch=1.2,distance=60},{yaw=0,pitch=.2,distance=15,targetX=20,targetY=0,targetZ=1.2},{yaw=math.pi,pitch=.3,distance=30,targetX=80,targetY=0,targetZ=1.2}}) do
  r:Render(danger,camera)
  assert(r.drawnFrontalFills<=#r.frontalFills,'frontal exceeds its fixed triangle pool')
  for x=-60,60,15 do for y=-60,60,15 do
   local sx,sy=r:Project(x,y,0)
   if sx and sx>1 and sx<r.width-1 and sy>1 and sy<r.height-1 then
    local dot=x*math.cos(yaw)+y*math.sin(yaw)
    local threshold=math.sqrt(x*x+y*y)*math.cos(math.pi/4)
    if math.abs(dot-threshold)>1e-6 then
     assert(frontalCovers(sx,sy)==(dot>threshold),'frontal fill disagrees with the actual unlimited 90-degree hit cone')
     frontalChecks=frontalChecks+1
    end
   end
  end end
 end
end
assert(frontalChecks>100,'frontal geometry coverage did not exercise enough visible points')
local behindBoss={player={x=20,y=0,z=0,yaw=0},pools={},waves={},time=50,status='running',frontal={x=0,y=0,yaw=0,width=math.pi/2,starts=48.25,ends=53.25}}
r:Render(behindBoss,{yaw=0,pitch=.2,distance=5,targetX=20,targetY=0,targetZ=1.2})
assert(r.drawnFrontalFills>0,'frontal disappears when its origin is behind the near camera')
behindBoss.frontal=nil;r:Render(behindBoss,camera)
assert(r.drawnFrontalFills==0,'frontal fill survives after the attack ends')
for _,t in ipairs(r.frontalFills) do assert(not t.drawn,'frontal triangle was left visible') end
assert(created.frame==counts[1] and created.actor==counts[2] and created.line==counts[3] and created.texture==counts[4], 'Frontal rendering allocated native regions')
state.waves={};r:Render(state,{yaw=0,pitch=.3,distance=60});assert(not r.waveRings[401].active)
assert(r.traceStamp==nil,'normal rendering must not create diagnostic chrome')
function methods:SetText(text) self.text=text end
function methods:SetColorTexture(red,green,blue,alpha) self.color={red,green,blue,alpha} end
r:PrepareTraceStamp()
local stamp=r.traceStamp
assert(not stamp.frame.shown,'arming must wait for the first recorded frame')
local stampFrames,stampTextures=created.frame,created.texture
for _,index in ipairs({1,2,2049,4096}) do
 r:ShowTraceSample(index)
 local decoded=0
 for i=1,12 do decoded=decoded*2+(stamp.bits[i].color[1]==1 and 1 or 0) end
 assert(decoded+1==index and stamp.label.text==string.format('EL TRACE %04d',index),'binary and text stamps must identify the same sample')
end
r:HideTraceStamp();r:PrepareTraceStamp()
assert(not stamp.frame.shown and created.frame==stampFrames and created.texture==stampTextures,'stopping hides and rearming reuses stamp regions')
r:Destroy();r:Destroy();assert(r:GetDiagnostics().destroyed)
print('PASS renderer: Lua5.1; native actor templates; 36 camera/UI-scale cases; 108 projection/pick round trips; actor/wave interpolation and shortest yaw; independent body facing; stable movement and jump/landing animations; native floor/effects and projected fallback; cached projection; '..frontalChecks..' frontal coverage checks; immutable state/camera; 401 waves; no native region growth; reuse cleanup')
