-- Original baked stonework, projected through the accepted native camera.
-- A bounded tile mesh keeps texture distortion small. Clip in world space so
-- looking down/up never drops an entire near-plane tile or stretches its UVs.
local _,EL=...
local Arena={};Arena.__index=Arena;EL.SentinelsArena=Arena
local abs=math.abs
local cameraKeys={"cx","cy","cz","fx","fy","fz","rx","ry","rz","ux","uy","uz","kx","ky","ox","oy","width","height","near"}
local MEDIA="Interface\\AddOns\\EncounterLab\\Media\\SentinelsFloor.tga"
function Arena.New(parent)
    local self=setmetatable({tiles={},textures={},a={},b={},last={},drawn=0},Arena)
    for iy=0,11 do for ix=0,11 do
        local x,y=-75+ix*12.5,-68+iy*136/12
        self.tiles[#self.tiles+1]={x,y,x+12.5,y,x+12.5,y+136/12,x,y+136/12}
    end end
    -- Clipped convex quads have at most nine vertices/seven fan triangles.
    for i=1,#self.tiles*7 do
        local t=parent:CreateTexture(nil,"ARTWORK")
        t:SetSize(1,1);t:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",0,0)
        t:SetTexture(MEDIA);t:SetSnapToPixelGrid(false);t:SetTexelSnappingBias(0);t:Hide()
        self.textures[i]=t
    end
    return self
end
function Arena:Hide()
    for i=1,self.drawn do self.textures[i]:Hide() end
    self.drawn=0
    self.valid=false
end
function Arena:Render(r)
    local changed=not self.valid
    for _,key in ipairs(cameraKeys) do
        if self.last[key]~=r[key] then changed=true;self.last[key]=r[key] end
    end
    if not changed then return end
    self.valid=true
    local clip=EL.Renderer.ClipPolygon
    local a,b=self.a,self.b;local drawn=0
    local dc=-r.cx*r.fx-r.cy*r.fy-r.cz*r.fz
    local rc=-r.cx*r.rx-r.cy*r.ry-r.cz*r.rz
    local uc=-r.cx*r.ux-r.cy*r.uy-r.cz*r.uz
    local right,top=r.width-r.ox,r.height-r.oy
    for _,tile in ipairs(self.tiles) do
        local n=clip(tile,4,b,r.fx,r.fy,dc-r.near-.02)
        n=clip(b,n,a,r.ox*r.fx+r.kx*r.rx,r.ox*r.fy+r.kx*r.ry,r.ox*dc+r.kx*rc)
        n=clip(a,n,b,right*r.fx-r.kx*r.rx,right*r.fy-r.kx*r.ry,right*dc-r.kx*rc)
        n=clip(b,n,a,r.oy*r.fx+r.ky*r.ux,r.oy*r.fy+r.ky*r.uy,r.oy*dc+r.ky*uc)
        n=clip(a,n,b,top*r.fx-r.ky*r.ux,top*r.fy-r.ky*r.uy,top*dc-r.ky*uc)
        for i=1,n do a[i*2-1],a[i*2]=r:Project(b[i*2-1],b[i*2],0) end
        for i=2,n-1 do
            local x1,y1,x2,y2,x3,y3=a[1],a[2],a[i*2-1],a[i*2],a[i*2+1],a[i*2+2]
            local u1,v1,u2,v2,u3,v3=(b[1]+75)/150,(68-b[2])/136,
                (b[i*2-1]+75)/150,(68-b[i*2])/136,(b[i*2+1]+75)/150,(68-b[i*2+2])/136
            local area=(x2-x1)*(y3-y1)-(y2-y1)*(x3-x1)
            if abs(area)>.001 then
                if area<0 then x2,y2,x3,y3,u2,v2,u3,v3=x3,y3,x2,y2,u3,v3,u2,v2 end
                drawn=drawn+1;local t=self.textures[drawn]
                t:SetTexCoord(u1,v1,u2,v2,u3,v3,u3,v3)
                t:SetVertexOffset(1,x1,y1-1);t:SetVertexOffset(2,x2,y2)
                t:SetVertexOffset(3,x3-1,y3-1);t:SetVertexOffset(4,x3-1,y3)
                if drawn>self.drawn then t:Show() end
            end
        end
    end
    for i=drawn+1,self.drawn do self.textures[i]:Hide() end
    self.drawn=drawn
end
