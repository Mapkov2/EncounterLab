-- Independent analytic regression: uniform movement must remain uniform when
-- render intervals vary. A current value held over the entire prior interval
-- introduces a cadence-dependent half-frame bias even without noisy input.
local EL={}
assert(loadfile(arg[1] or 'EncounterLab/ViewMotion.lua'))('EncounterLab',EL)
local checks=0
local function check(value,label) assert(value,label);checks=checks+1 end
local window=EL.ViewMotion.WINDOW
local function run(intervals)
 local motion=EL.ViewMotion.New()
 local p={x=0,y=0,z=0,yaw=0,displayYaw=0}
 local c={yaw=0,pitch=.4,distance=60,targetX=0,targetY=0,targetZ=1}
 local op,oc={},{}
 motion:Update(p,c,.004,op,oc)
 local time,worst,previousTime,previousX=0,0
 for index=1,600 do
  local dt=intervals[(index-1)%#intervals+1]
  time=time+dt
  p.x,c.targetX=7*time,7*time
  p.yaw,p.displayYaw,c.yaw=.3*time,.3*time,.3*time
  motion:Update(p,c,dt,op,oc)
  if time>window+1e-9 then
   -- The exact mean of a line over [t-window,t] lies at its midpoint.
   worst=math.max(worst,math.abs(op.x-7*(time-window/2)))
   check(math.abs(op.x-oc.targetX)<1e-9,'camera and player presentation lost their common position')
   check(math.abs(oc.yaw-.3*(time-window/2))<1e-9,'steady turning depends on frame cadence')
   if previousTime then check(math.abs((op.x-previousX)/(time-previousTime)-7)<1e-8,'steady strafe gains velocity jitter from varying frame times') end
   previousTime,previousX=time,op.x
  end
 end
 check(worst<1e-9,'linear movement has a cadence-dependent delay')
 return worst
end
local worst=0
for _,intervals in ipairs({{1/60},{1/144},{1/240},{.003,.008,.004,.006,.005},{1/75,1/165,1/90,1/240}}) do
 worst=math.max(worst,run(intervals))
end
print(string.format('View cadence: %d checks passed; max analytic position error %.12f yards',checks,worst))
