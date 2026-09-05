local _, EL = ...
local Motion = {}
Motion.__index = Motion
EL.ViewMotion = Motion

-- Presentation only. Input and simulation retain the complete current sample.
-- Integrate linear segments between sampled camera/player poses over 24 ms.
-- Treating an endpoint as constant over its entire preceding frame injects
-- frame-duration jitter. Exact segment areas keep a common 12 ms mean delay
-- and continuous view velocity, without predicting future input. A stopped
-- pose is reached within the window after its final sample.
Motion.WINDOW = 0.024
local CAPACITY, VALUES = 128, 11
local pi, min, abs = math.pi, math.min, math.abs
local function angle(delta) return (delta+pi)%(2*pi)-pi end

function Motion.New()
    local self = setmetatable({rows={}, sums={}, sample={}, previous={}},Motion)
    for i=1,CAPACITY do
        local row={duration=0}
        for j=1,VALUES*2 do row[j]=0 end
        self.rows[i]=row
    end
    for j=1,VALUES do self.sums[j]=0;self.sample[j]=0;self.previous[j]=0 end
    return self
end

function Motion:Reset() self.first=nil end

function Motion:Seed()
    local row=self.rows[1]
    self.first,self.count,self.stillFor=1,1,0
    row.duration=Motion.WINDOW
    for j=1,VALUES do
        row[j],row[j+VALUES]=self.sample[j],self.sample[j]
        self.sums[j]=row[j]*Motion.WINDOW
    end
end

function Motion:Update(player,camera,elapsed,outPlayer,outCamera)
    for key in pairs(outPlayer) do outPlayer[key]=nil end
    for key,value in pairs(player) do outPlayer[key]=value end
    for key in pairs(outCamera) do outCamera[key]=nil end
    for key,value in pairs(camera) do outCamera[key]=value end
    local valid=type(elapsed)=="number" and elapsed==elapsed and elapsed>0 and elapsed<Motion.WINDOW
    if not valid then self:Reset();return end
    local s=self.sample
    local yaw=camera.renderYaw or camera.yaw or 0
    local facing=camera.playerFacingYaw or player.displayYaw or player.yaw or 0
    if self.first then
        yaw=s[4]+angle(yaw-s[4])
        facing=s[5]+angle(facing-s[5])
    end
    local x,y,z=player.x,player.y,player.z or 0
    local pitch,distance=camera.pitch or pi*.075,camera.distance or 60
    local tx,ty,tz=camera.targetX or x,camera.targetY or y,camera.targetZ or z+1.2
    local pyaw=player.yaw or 0
    if self.first then pyaw=s[11]+angle(pyaw-s[11]) end
    local unchanged=self.first and x==s[1] and y==s[2] and z==s[3]
        and abs(yaw-s[4])<1e-12 and abs(facing-s[5])<1e-12
        and pitch==s[6] and distance==s[7] and tx==s[8] and ty==s[9] and tz==s[10]
        and abs(pyaw-s[11])<1e-12
    local previous=self.previous
    for j=1,VALUES do previous[j]=s[j] end
    s[1],s[2],s[3],s[4],s[5]=x,y,z,yaw,facing
    s[6],s[7],s[8],s[9],s[10],s[11]=pitch,distance,tx,ty,tz,pyaw
    self.stillFor=unchanged and (self.stillFor or 0)+elapsed or 0
    if not self.first or self.stillFor>=Motion.WINDOW then
        self:Seed()
    else
        local remaining=elapsed
        while remaining>1e-12 do
            local row=self.rows[self.first]
            local removed=min(remaining,row.duration)
            local fraction=removed/row.duration
            for j=1,VALUES do
                -- Trim only the expired part of the oldest segment. Its new
                -- start remains on the original line to the stored endpoint.
                local start=row[j]
                local nextStart=start+(row[j+VALUES]-start)*fraction
                self.sums[j]=self.sums[j]-(start+nextStart)*(.5*removed)
                row[j]=nextStart
            end
            row.duration,remaining=row.duration-removed,remaining-removed
            if row.duration<=1e-12 then
                self.first,self.count=self.first%CAPACITY+1,self.count-1
            end
        end
        if self.count>=CAPACITY then self:Seed()
        else
            local row=self.rows[(self.first+self.count-1)%CAPACITY+1]
            row.duration=elapsed
            for j=1,VALUES do
                row[j],row[j+VALUES]=previous[j],s[j]
                self.sums[j]=self.sums[j]+(previous[j]+s[j])*(.5*elapsed)
            end
            self.count=self.count+1
        end
    end
    local sum,window=self.sums,Motion.WINDOW
    outPlayer.x,outPlayer.y,outPlayer.z=sum[1]/window,sum[2]/window,sum[3]/window
    outPlayer.displayYaw,outPlayer.yaw=sum[5]/window,sum[11]/window
    outCamera.yaw,outCamera.renderYaw,outCamera.pitch=sum[4]/window,sum[4]/window,sum[6]/window
    outCamera.distance=sum[7]/window
    outCamera.targetX,outCamera.targetY,outCamera.targetZ=sum[8]/window,sum[9]/window,sum[10]/window
    outCamera.playerFacingYaw=outPlayer.displayYaw
end
