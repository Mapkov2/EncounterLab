-- Independently drawn stonework, based on the visible Sentinels room layout.
-- No map image, raid WMO, or third-party artwork is bundled. The fixed mesh
-- uses the renderer's already-calibrated camera; no second camera or input path.
local EL={}
local Arena={};Arena.__index=Arena;EL.SentinelsArena=Arena
local abs,sqrt=math.abs,math.sqrt
local stone={.30,.31,.23};local edge={.42,.43,.31}
local cut={.17,.20,.15};local bevel={.36,.38,.27}
local teal={.15,.32,.28};local red={.35,.21,.15}
local function polygon(self,points,color)
    self.mesh[#self.mesh+1]={points=points,color=color}
end
local function rect(self,x,y,w,h,color)
    polygon(self,{x,y,x+w,y,x+w,y+h,x,y+h},color)
end
local function stroke(self,points,width,color,closed)
    local n=#points/2
    for i=1,(closed and n or n-1) do
        local j=i%n+1
        local x,y,xx,yy=points[i*2-1],points[i*2],points[j*2-1],points[j*2]
        local dx,dy=xx-x,yy-y;local length=sqrt(dx*dx+dy*dy)
        if length>0 then
            local nx,ny=-dy/length*width/2,dx/length*width/2
            polygon(self,{x+nx,y+ny,x-nx,y-ny,xx-nx,yy-ny,xx+nx,yy+ny},color)
        end
    end
end
local function outline(self,points)
    stroke(self,points,.55,cut,true)
    stroke(self,points,.16,edge,true)
end
local function build(self)
    -- Long rectangular platform, two lateral plinths, recessed green channels.
    rect(self,-75,-68,150,136,{.07,.10,.07})
    rect(self,-65,-59,130,118,{.18,.29,.08})
    rect(self,-60,-55,120,110,{.30,.49,.055})
    for side=-1,1,2 do
        for i=0,8 do
            local y=-52+i*12
            rect(self,side<0 and -58 or 43,y,15,1.1,{.42,.60,.10})
            rect(self,side<0 and -58 or 43,y+4,15,.4,{.23,.39,.055})
        end
    end
    polygon(self,{-44,-52,44,-52,44,-17,57,-11,57,11,44,17,44,52,-44,52,-44,17,-57,11,-57,-11,-44,-17},cut)
    -- The platform outline above is concave: use convex pieces for its fill.
    self.mesh[#self.mesh]=nil
    rect(self,-44,-52,88,104,edge)
    for side=-1,1,2 do
        polygon(self,{side*43,-18,side*57,-11,side*57,11,side*43,18},edge)
        polygon(self,{side*44,-14,side*54,-9,side*54,9,side*44,14},cut)
        polygon(self,{side*45,-11,side*52,-7,side*52,7,side*45,11},bevel)
        polygon(self,{side*47,-6,side*51,-4,side*51,4,side*47,6},side<0 and teal or red)
    end
    rect(self,-41,-49,82,98,cut)
    rect(self,-39.8,-47.8,79.6,95.6,stone)
    -- Large fitted slabs, with fine seams rather than a gameplay grid.
    for iy=0,11 do
        for ix=0,7 do
            local x,y=-39.5+ix*9.9,-47.5+iy*7.9
            local s=((ix*7+iy*11)%9-4)*.0025
            rect(self,x+.035,y+.035,9.83,7.83,{stone[1]+s,stone[2]+s,stone[3]+s})
        end
    end
    -- Stepped corner carvings, mirrored like the original stone surround.
    for sx=-1,1,2 do for sy=-1,1,2 do
        local function path(values)
            local p={};for i=1,#values,2 do p[i],p[i+1]=values[i]*sx,values[i+1]*sy end
            return p
        end
        stroke(self,path({8,47,37,47,37,22,33,22,33,39,26,39,26,43,8,43}),.8,cut,false)
        stroke(self,path({13,45,29,45,29,41,35,41,35,28}),.22,edge,false)
        stroke(self,path({20,41,24,41,24,37,31,37,31,32}),.5,cut,false)
        polygon(self,path({30,30,35,33,35,39}),sx<0 and teal or red)
        polygon(self,path({33,19,38,22,38,27}),sx<0 and teal or red)
        outline(self,path({10,40,19,37,29,25,30,17,25,13,21,21,13,27,5,29}))
    end end
    -- The broad central angular crest supplies orientation without UI markers.
    for sx=-1,1,2 do for sy=-1,1,2 do
        local p={0,24,8,24,15,17,15,12,23,8,27,0,19,3,14,8,7,8,7,14,0,18}
        for i=1,#p,2 do p[i],p[i+1]=p[i]*sx,p[i+1]*sy end
        outline(self,p)
    end end
    outline(self,{-5,-7,5,-7,10,0,5,7,-5,7,-10,0})
    outline(self,{-5,33,5,33,8,38,5,43,-5,43,-8,38})
    outline(self,{-5,-33,5,-33,8,-38,5,-43,-5,-43,-8,-38})
    -- Narrow approach/exit bridges at the ends of the platform.
    for sy=-1,1,2 do
        rect(self,-9,sy<0 and -68 or 52,18,16,bevel)
        for i=0,3 do rect(self,-9,sy*(54+i*4),18,.35,cut) end
    end
end

local data={mesh={}};build(data)
for _,p in ipairs(data.mesh) do
 print(table.concat(p.color,",").."|"..table.concat(p.points,","))
end
