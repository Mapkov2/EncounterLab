-- Independently arranged client-owned scenery. These are room-inspired sets,
-- not extracted raid WMOs; all geometry shares the gameplay scene and camera.
local _,EL=...
local Room={};Room.__index=Room;EL.ArenaRoom=Room
local pi,cos,sin,min,max=math.pi,math.cos,math.sin,math.min,math.max
local serial=0
local function visible(slot,on)
    if slot.shown==on then return end
    slot.shown=on
    if on then slot.actor:Show() else slot.actor:Hide() end
end
local function add(self,set,fileID,x,y,z,size,axis,cap,yaw,occludes)
    local actor=self.scene:CreateActor(self.prefix..(#self.actors+1),"ModelSceneActorTemplate")
    actor:Hide();actor:SetUseCenterForOrigin(true,true,false)
    local ok,accepted=pcall(actor.SetModelByFileID,actor,fileID)
    local slot={actor=actor,x=x,y=y,z=z,size=size,axis=axis,cap=cap,yaw=yaw or 0,
        occludes=occludes,requested=ok and accepted~=false,nextCheck=0,shown=false}
    set[#set+1]=slot;self.actors[#self.actors+1]=slot
    return slot
end
function Room.New(scene)
    serial=serial+1
    return setmetatable({scene=scene,prefix="EncounterLabRoom"..serial.."_",sets={},actors={}},Room)
end
function Room:SetEncounter(id)
    if self.id==id then return end
    if self.active then for _,slot in ipairs(self.active) do visible(slot,false) end end
    self.id=id
    local set=self.sets[id]
    if not set then
        set={};self.sets[id]=set
        if id=="sentinels" then
            -- Rectangular hall around the independent Sentinels floor. Four
            -- corner pylons flank the green channels; keep the two camp lanes
            -- and the central convergence entirely clear of scenery.
            set.projectedFloor=true
            for side=-1,1,2 do
                for _,y in ipairs({-35,35}) do
                    add(self,set,2457910,side*57,y,-2,23,"height",false,side*pi/2,true)
                    add(self,set,1591566,side*67,y,-3,28,"width",false,side*pi/2,true)
                end
                for _,x in ipairs({-29,29}) do
                    add(self,set,1591566,x,side*62,-3,27,"width",false,side<0 and 0 or pi,true)
                end
                add(self,set,8117702,side*65,0,-2,19,"width",false,side<0 and 0 or pi,true)
            end
        elseif id=="sszorak" then
            -- Carved Zandalari stone; six architectural bays match the reference
            -- orientation. Ula'tek murals are the actual client raid decorations.
            set.floor=add(self,set,2438939,0,0,-.06,84,"floor",true)
            for i=0,5 do
                local a=i*pi/3
                add(self,set,2457910,cos(a+pi/6)*49,sin(a+pi/6)*49,-2,19,"height",false,a+pi/6,true)
                add(self,set,8117702,cos(a)*52,sin(a)*52,-2,24,"width",false,a+pi,true)
            end
        else
            -- Black-dragon stone/metal floor with an inset conduit and Aberrus
            -- windows. The 75-yard ranked area retains its accepted coordinates.
            set.floor=add(self,set,4581082,0,0,-.06,210,"floor",true)
            add(self,set,192537,0,0,-.035,19,"floor",true)
            for i=0,7 do
                local a=i*pi/4
                add(self,set,4904617,cos(a)*111,sin(a)*111,-3,36,"width",false,a+pi,true)
            end
            for i=0,3 do
                local a=pi/4+i*pi/2
                add(self,set,4883277,cos(a)*99,sin(a)*99,10,14,"height",false,a,true)
            end
        end
    end
    self.active=set
end
local function load(slot,now)
    if slot.ready or not slot.requested or now<slot.nextCheck then return end
    slot.nextCheck=now+.5
    if not slot.actor:IsLoaded() then return end
    local bx,by,bz,tx,ty,tz=EL.SceneAssets.ReadBounds(slot.actor)
    if not bx then return end
    local span=slot.axis=="height" and tz-bz or slot.axis=="floor" and min(tx-bx,ty-by) or max(tx-bx,ty-by)
    local scale=slot.size/span
    if scale<=0 or scale~=scale or scale>1000 then return end
    slot.actor:SetScale(scale)
    slot.actor:SetYaw(slot.yaw)
    slot.actor:SetPosition(slot.x/scale,slot.y/scale,slot.z/scale-(slot.cap and tz or bz))
    slot.actor:SetAnimation(0,0,0,0)
    slot.ready=true
end
function Room:Update(now,camera)
    if self.dead or not self.active then return false end
    local loaded=0
    for _,slot in ipairs(self.active) do
        load(slot,now)
        if slot.ready then
            loaded=loaded+1
            local alpha=1
            if slot.occludes and camera then
                -- Fade nearby foreground scenery smoothly; it must never hide
                -- the character or make an orbiting camera jump through a wall.
                local depth=(slot.x-camera.cx)*camera.fx+(slot.y-camera.cy)*camera.fy
                alpha=min(1,max(0,(depth-12)/18))
            end
            if slot.alpha~=alpha then slot.actor:SetAlpha(alpha);slot.alpha=alpha end
            visible(slot,alpha>0)
        end
    end
    self.loaded=loaded
    return self.active.floor and self.active.floor.ready==true or false
end
function Room:Destroy()
    self.dead=true
    for _,slot in ipairs(self.actors) do visible(slot,false);slot.actor:ClearModel() end
end
