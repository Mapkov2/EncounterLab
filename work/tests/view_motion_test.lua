local EL={}
assert(loadfile('EncounterLab/ViewMotion.lua'))('EncounterLab',EL)
local checks=0
local function check(value,label) assert(value,label);checks=checks+1 end
local function close(a,b) return math.abs(a-b)<1e-9 end
local function angle(a) return (a+math.pi)%(2*math.pi)-math.pi end
local p={x=0,y=0,z=0,yaw=0,displayYaw=0,dead=false}
local c={yaw=0,pitch=.4,distance=60,targetX=0,targetY=0,targetZ=1}
local op,oc={},{}
local motion=EL.ViewMotion.New()
local function step(dt) motion:Update(p,c,dt,op,oc) end
step(.004)
check(close(oc.yaw,0) and close(op.x,0),'initial pose has no startup movement')
p.x,c.targetX,c.yaw,p.yaw,p.displayYaw=6,6,.024,.024,.024
for i=1,6 do
 step(.004)
 -- The first 4 ms contain a linear ramp, not an endpoint held retroactively.
 -- Its triangular area contributes half a step to the moving time average.
 check(close(op.x,i-.5) and close(oc.targetX,op.x),'camera and player integrate the same translation segment')
 check(close(oc.yaw,(i-.5)*.004) and close(op.displayYaw,oc.yaw),'body and camera integrate the same rotation segment')
end
step(.004)
check(close(op.x,6) and close(oc.yaw,.024),'last input sample settles within 24 ms')
check(p.x==6 and c.yaw==.024 and p.yaw==.024,'presentation must not write input or simulation state')
for i=1,20 do step(.004) end
check(close(op.x,6) and close(oc.yaw,.024),'stationary pose reaches its exact endpoint with no drift')
-- The same continuous timeline with different render partitions has the same
-- weighted view. Expected values are its analytic integral, not filter replay.
for _,schedule in ipairs({{.004,.004,.004},{.006,.006},{.003,.007,.002}}) do
 motion:Reset();p.x,c.targetX,c.yaw=0,0,0;step(.004)
 local t=0
 for _,dt in ipairs(schedule) do
  t=t+dt;p.x,c.targetX,c.yaw=8*t/.012,8*t/.012,.2*t/.012
  step(dt)
 end
 check(close(op.x,2) and close(oc.yaw,.05),'the same linear timeline has the same integrated view for different frame partitions')
end
-- An isolated cursor count is a sampled ramp. Check both ends of the ramp
-- entering/leaving the window against its analytic area and continuous speed.
motion:Reset();p.x,c.targetX=0,0;step(.004)
local h=1e-6
local times={0,h,.004-h,.004,.004+h,.024-h,.024,.024+h,.028-h,.028,.028+h}
local values={[1]=0}
for i=2,#times do
 local t=times[i]
 p.x,c.targetX=6*math.min(t/.004,1),6*math.min(t/.004,1)
 step(t-times[i-1]);values[i]=op.x
 local expected
 if t<=.004 then expected=1500*t*t/(2*.024)
 elseif t<=.024 then expected=6*(t-.002)/.024
 elseif t<.028 then expected=6-1500*(.028-t)^2/(2*.024)
 else expected=6 end
 check(close(op.x,expected),'cursor-count transition differs from its analytic area')
end
check(math.abs(values[2]/h)<.1,'cursor count starts with an abrupt presentation velocity')
for _,i in ipairs({4,7,10}) do
 local before=(values[i]-values[i-1])/(times[i]-times[i-1])
 local after=(values[i+1]-values[i])/(times[i+1]-times[i])
 check(math.abs(after-before)<.1,'cursor count entering or leaving history jumps in velocity')
end
motion:Reset();c.yaw=math.pi-.01;step(.004)
c.yaw=-math.pi+.01;step(.004)
check(math.abs(angle(oc.yaw-(math.pi-.01)))<.021,'yaw wrap must not turn through zero')
step(.1)
check(oc.yaw==c.yaw and op.x==p.x,'long frame cannot replay stale camera history')
step(.004);p.x,c.targetX=100,100;motion:Reset();step(.004)
check(close(op.x,100) and close(oc.targetX,100),'teleport reset must not sweep through old positions')
step(0);check(oc.yaw==c.yaw,'zero-time preview preserves exact raw pose')
local rows,firstRow=motion.rows,motion.rows[1]
for i=1,12000 do
 p.x,c.targetX=i/100,i/100;c.yaw=angle(i*.003);p.displayYaw=c.yaw
 step(.0005)
 check(motion.count<=128 and op.x<=p.x+1e-9 and op.x>=p.x-.49,'history is bounded and does not extrapolate positions')
end
check(motion.rows==rows and motion.rows[1]==firstRow,'motion does not allocate per-frame history objects')
print('View motion: '..checks..' checks passed; analytic time window, wrap, reset, shared pose and bounded storage')
