-- Exercise the real ground projection across orbit, near-plane and viewport
-- intersections. This does not load WoW models or prove their visual appearance.
local EL={L=setmetatable({},{__index=function(_,k)return k end})}
assert(loadfile('EncounterLab/Renderer.lua'))('EncounterLab',EL)
assert(loadfile('EncounterLab/SentinelsArena.lua'))('EncounterLab',EL)
local created,updates=0,0
local parent={}
function parent:CreateTexture()
    created=created+1
    local t={}
    function t:SetSize() end
    function t:SetPoint() end
    function t:SetTexture(path) assert(path:find('SentinelsFloor.tga',1,true)) end
    function t:SetSnapToPixelGrid() end
    function t:SetTexelSnappingBias() end
    function t:Show() self.shown=true end
    function t:Hide() self.shown=false end
    function t:SetTexCoord(...) self.uv={...} end
    function t:SetVertexOffset(i,x,y)
        updates=updates+1;self.xy=self.xy or {};self.xy[i]={x,y}
    end
    return t
end
local arena=EL.SentinelsArena.New(parent);local capacity=created
local sin,cos,pi=math.sin,math.cos,math.pi
local cases=0
for _,width in ipairs({640,1920}) do
 for _,pitch in ipairs({.025,.15,.6,1.45}) do
  for step=0,11 do
   local yaw=step*pi/6;local r=setmetatable({projectionValid=true,near=.1,
       cx=32*cos(yaw+.8),cy=32*sin(yaw+.8),cz=4,width=width,height=width*.56,
       fx=cos(yaw)*cos(pitch),fy=sin(yaw)*cos(pitch),fz=-sin(pitch),
       rx=-sin(yaw),ry=cos(yaw),rz=0,
       ux=cos(yaw)*sin(pitch),uy=sin(yaw)*sin(pitch),uz=cos(pitch),
       kx=width*.7,ky=width*.7,ox=width/2,oy=width*.28},EL.Renderer)
   arena:Render(r);assert(arena.drawn>0 and arena.drawn<=capacity)
   for i=1,arena.drawn do
    local t=arena.textures[i];assert(t.shown)
    for vertex=1,4 do
     local u,v=t.uv[vertex*2-1],t.uv[vertex*2]
     assert(u>=-1e-6 and u<=1.000001 and v>=-1e-6 and v<=1.000001)
     local x,y=r:Project(u*150-75,68-v*136,0)
     local vx=t.xy[vertex][1]+(vertex>=3 and 1 or 0)
     local vy=t.xy[vertex][2]+((vertex==1 or vertex==3) and 1 or 0)
     assert(math.abs(vx-x)<.00001 and math.abs(vy-y)<.00001,'UV must remain anchored to the same world point')
     assert(x>=-.0001 and x<=r.width+.0001 and y>=-.0001 and y<=r.height+.0001,'clip before projecting')
    end
   end
   local before=updates;arena:Render(r);assert(updates==before,'stationary camera does no terrain work')
   arena:Hide();assert(arena.drawn==0)
   for _,t in ipairs(arena.textures) do assert(not t.shown) end
   arena:Render(r);assert(arena.drawn>0,'same-camera return restores hidden terrain')
   assert(created==capacity,'orbit and encounter returns allocate no textures')
   cases=cases+1
  end
 end
end
print('SENTINELS ARENA '..cases..' camera cases passed; UV anchoring, clipping, caching and reuse. No live visual proof.')
