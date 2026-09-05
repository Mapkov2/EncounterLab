local base=(arg and arg[1]) or 'EncounterLab/'
local EL={L=setmetatable({},{__index=function(_,k) return k end}),SceneAssets={ReadBounds=function() end}}
assert(loadfile(base..'Sentinels.lua'))('EncounterLab',EL)
assert(loadfile(base..'SentinelsRenderer.lua'))('EncounterLab',EL)
local allocated,colorWrites=0,0
local function region()
    allocated=allocated+1
    local f={shown=true}
    for _,key in ipairs({'EnableMouse','SetJustifyH','SetShadowColor','SetShadowOffset','SetFont','SetUseCenterForOrigin','SetYaw','SetAnimation','ClearModel'}) do f[key]=function() end end
    function f:SetPoint(...) self.point={...} end
    function f:ClearAllPoints() self.point=nil end
    function f:SetAllPoints(target) self.anchor=target end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetScale(scale) self.scale=scale end
    function f:SetTexture(file) self.file=file end
    function f:AddMaskTexture(mask) self.mask=mask end
    function f:SetColorTexture(...) self.color={...};colorWrites=colorWrites+1 end
    function f:SetPosition(...) self.position={...} end
    function f:SetAnimation(id) self.animation=id end
    function f:SetText(value) self.text=value end
    function f:SetModelByUnit() return true end
    function f:SetModelByCreatureDisplayID() return true end
    function f:IsLoaded() return true end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:IsShown() return self.shown end
    f.CreateTexture,f.CreateMaskTexture,f.CreateFontString,f.CreateActor=region,region,region,region
    return f
end
CreateFrame=region
function GetTime() return 0 end
local renderer={frame=region(),overlay=region(),width=900,height=650,ky=680,
    renderPlayer={x=20,y=30,z=0},playerLabel=region(),bossLabel=region(),bossActor=region(),bossRing={lines={}}}
function renderer:Project(x,y,z) if self.clipped then return end;return x+300,y+200,40 end
local fx=EL.SentinelsRenderer.New(renderer)
local s={status='running',time=3.5,applied=true,revealEnds=5,raiders={},playerIndex=1,groups={{x=-23,y=2},{x=23,y=-2}}}
for i=1,20 do s.raiders[i]={x=i,y=i,z=0,yaw=0,group=i<=10 and 1 or 2,stacks=(i-1)%3+1,isPlayer=i==1} end
local initial=allocated
local preview={status='ready',time=0}
for i=1,120 do fx:Draw(renderer,preview) end
assert(not preview.groups and not preview.raiders and not preview.playerIndex, 'renderer mutated sparse preview')
assert(not fx.center:IsShown(), 'preview has no assigned player side')
for i,slot in ipairs(fx.bosses) do
    assert(slot.actor:IsShown() and slot.actor.position[1]==EL.Sentinels.bossPositions[i].x and slot.actor.position[2]==EL.Sentinels.bossPositions[i].y)
end
for _,slot in ipairs(fx.raiders) do assert(not slot.actor:IsShown() and not slot.marker:IsShown() and not slot.label:IsShown() and not slot.ping:IsShown()) end
assert(allocated==initial, 'preview allocated native regions')
fx:Draw(renderer,s)
for i,slot in ipairs(fx.bosses) do
    assert(math.abs(slot.actor.position[1])==18 and slot.actor.position[2]==0, 'boss did not move during the reveal')
end
assert(fx.center.point[4]==300 and fx.center.point[5]==197, '2s marker is not in the shared center')
for i,slot in ipairs(fx.raiders) do
    assert(slot.marker:IsShown() and not slot.label:IsShown(), 'numeric overhead caption survived')
    local green,red=0,0
    for _,orb in ipairs(slot.marker.orbs) do
        assert(orb.body.mask and orb.body.mask.anchor==orb.body, 'orb is not round')
        if orb.body.color[2]>orb.body.color[1] then green=green+1 else red=red+1 end
    end
    assert(green==s.raiders[i].stacks and red==4-green, 'green/red stack mapping is wrong')
end
local own=fx.raiders[1].marker
assert(math.abs(own.point[4]*own.scale-320)<1e-8 and math.abs(own.point[5]*own.scale-230)<1e-8,
    'orbs are not anchored over the displayed player pose')
local writes=colorWrites
for i=1,300 do fx:Draw(renderer,s) end
assert(allocated==initial and colorWrites==writes, 'steady rendering allocated regions or repainted colors')
s.time=5.1;fx:Draw(renderer,s)
-- A bouncing NPC must animate its body as well as changing its world height.
s.raiders[2].stacks=1;s.raiders[2].z=1;fx:Draw(renderer,s)
assert(fx.raiders[2].actor.animation==37 and fx.raiders[2].actor.position[3]==1)
s.raiders[2].z=0;fx:Draw(renderer,s);assert(fx.raiders[2].actor.animation==0)
for _,slot in ipairs(fx.bosses) do assert(math.abs(slot.actor.position[1])==3 and slot.actor.position[2]==0) end
assert(own.visibleStacks==1)
for i=2,20 do
    local m=fx.raiders[i].marker;assert(m.visibleStacks==0 and m:IsShown())
    for j=2,4 do for c=1,4 do assert(m.orbs[j].body.color[c]==m.orbs[1].body.color[c], 'concealment leaked the count') end end
end
s.raiders[1].stacks=3;fx:Draw(renderer,s);assert(own.visibleStacks==3)
s.raiders[1].stacks=0;fx:Draw(renderer,s);assert(not own:IsShown())
s.raiders[2].dead=true;fx:Draw(renderer,s);assert(not fx.raiders[2].marker:IsShown())
renderer.clipped=true;fx:Draw(renderer,s)
for _,slot in ipairs(fx.raiders) do assert(not slot.marker:IsShown()) end
renderer.clipped=false;s.applied=false;fx:Draw(renderer,s)
for _,slot in ipairs(fx.raiders) do assert(not slot.marker:IsShown()) end
s.applied=true;fx:Draw(renderer,s);fx:Hide()
for _,slot in ipairs(fx.raiders) do assert(not slot.marker:IsShown()) end
fx:Draw(renderer,s);fx:Draw(renderer,preview)
for _,slot in ipairs(fx.raiders) do assert(not slot.actor:IsShown() and not slot.marker:IsShown() and not slot.label:IsShown() and not slot.ping:IsShown()) end
assert(not fx.center:IsShown(), 'return to preview retained a live side marker')
fx:Draw(renderer,s);fx:Destroy()
for _,slot in ipairs(fx.raiders) do assert(not slot.marker:IsShown()) end
assert(allocated==initial)
print('SENTINELS RENDERER PASS: four colored orbs, 1/2/3 mapping, no numbers, concealed peers, projection, pooled lifecycle')
