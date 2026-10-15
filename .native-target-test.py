from pathlib import Path
exec(Path('.lua-test-support.py').read_text())
lua.execute('''
local baseCreate=CreateFrame
local container, playerContainer, registrations={},{},{}
local rawReads=0
C_AddOns={LoadAddOn=function(name) assert(name=='Blizzard_AuraContainer'); return true end}
AuraContainerSortMethod={ExpirationOnly=5}
AuraContainerSortDirection={Normal=0}
AnchorUtil={FlowDirection={Right=1,Up=2}}
Enum={StatusBarTimerDirection={RemainingTime=1}}
C_UnitAuras={GetUnitAuras=function(unit)
 if unit=='target' then rawReads=rawReads+1; error('Auras cannot be accessed when secret while tainted') end
 return {}
end}
function CreateFrame(kind,name,parent,template)
 local f=baseCreate(kind,name,parent)
 if kind=='AuraContainer' then
  assert(template=='CustomAuraContainerTemplate')
  f.groups={}
  f.SetFlowLayoutAnchorPoint=function(self,point) assert(point=='BOTTOMLEFT') end
  f.SetFlowLayoutGrowthDirection=function(self,h,v) assert(h==1 and v==2) end
  f.SetFlowLayoutMaximumLineSize=function(self,width) self.lineWidth=width end
  f.SetAuraGroupLayout=function(self,key,layout) self.groups[key].layout=layout end
  f.AddAuraGroup=function(self,key,filter,options)
   assert(key==filter and (filter=='HELPFUL' or filter=='HARMFUL'))
   assert(options.candidateFilters.maxDuration==math.huge)
   assert(options.sortMethod==5 and options.sortDirection==0)
   self.groups[key]=options
   local button=baseCreate('Button',nil,self)
   local r={button=button,filter=filter,container=self}; registrations[#registrations+1]=r
   button.SetIcon=function(_,region) r.icon=region end
   button.SetSpellName=function(_,region) r.name=region end
   button.SetDurationBar=function(_,region,opts) assert(opts.direction==1); r.bar=region end
   button.SetDurationText=function(_,region,opts) r.time=region end
   options.initializeFrame(button)
   -- Simulate lockdown after the engine's initializer: no button writes/reads.
   setmetatable(button,{__index=function(_,method) return function() error('Denied button call '..method) end end})
  end
  f.SetUnit=function(self,unit)
   assert(unit=='target' or unit=='player'); self.unit=unit
   if unit=='target' then container=self else playerContainer=self end
  end
  f.UpdateAllAuras=function(self) self.refreshed=true end
  f.SetShown=function(self,value) self.visible=value end
 end
 return f
end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
events.scripts.OnEvent(events,'ADDON_LOADED','MiniBars')
assert(container.unit=='target' and container.refreshed and container.visible)
assert(#registrations==3 and rawReads==0,'Native backend must not query restricted target APIs')
assert(playerContainer.unit=='player' and playerContainer.parent==MiniBarsFrame)
assert(container.parent==MiniBarsTargetFrame)
assert(playerContainer.groups.HARMFUL and not playerContainer.groups.HELPFUL)
assert(registrations[3].container==playerContainer and registrations[3].bar.color[1]==0.9)
for _,r in ipairs(registrations) do
 assert(r.icon and r.name and r.bar and r.time,'Missing native display binding')
 assert(r.name.fontSize==12 and r.time.fontSize==12)
end
assert(registrations[1].bar.color[1]==0.9 and registrations[2].bar.color[1]==1)
events.scripts.OnEvent(events,'UNIT_AURA','target')
events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
events.scripts.OnUpdate(events,0.5)
assert(rawReads==0)
targetExists=false
events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
assert(not container.visible,'Target container remained visible after clearing target')
events.scripts.OnUpdate(events,0.5)
assert(not container.visible,'Polling reopened target container without target')
SlashCmdList.MINIBARS('unlock')
assert(not container.visible,'Native auras overlap previews without target')
assert(MiniBarsTargetResizeHandle.visible,'Target previews unavailable without target')
SlashCmdList.MINIBARS('lock')
assert(not container.visible,'Locking reopened target container without target')
targetExists=true; targetAttackable=false; container.refreshed=false
events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
assert(container.visible and container.refreshed,'Friendly target did not restore and refresh container')
targetAttackable=true
SlashCmdList.MINIBARS('unlock'); assert(not container.visible)
mouseDown=true; cursorX=0; cursorY=0
MiniBarsTargetResizeHandle.scripts.OnMouseDown(nil,'LeftButton')
cursorX=160; cursorY=-60; events.scripts.OnUpdate(events,0.5)
assert(container.groups.HARMFUL.layout.elementWidth==320)
assert(container.groups.HELPFUL.layout.elementHeight==40)
for _,r in ipairs(registrations) do
 if r.container==container then assert(r.icon.width==40 and r.name.width==154)
 else assert(r.icon.width==20 and r.name.width==74) end
end
mouseDown=false
SlashCmdList.MINIBARS('lock'); assert(container.visible)
SlashCmdList.MINIBARS('reset')
assert(container.groups.HARMFUL.layout.elementWidth==160)
assert(container.groups.HELPFUL.layout.elementHeight==20)
assert(rawReads==0)
print('PASS: native target binding under denied aura queries, restricted buttons, colors, fonts, preview, resize, reset and no polling reads')
''')

# Failed module construction must leave a usable addon and an actionable diagnostic.
exec(Path('.lua-test-support.py').read_text())
lua.execute('''
C_AddOns={LoadAddOn=function() error('Test module unavailable') end}
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
events.scripts.OnEvent(events,'ADDON_LOADED','MiniBars')
local output={}
print=function(message) output[#output+1]=message end
SlashCmdList.MINIBARS('debug')
assert(table.concat(output,' ').find(table.concat(output,' '),'Test module unavailable',1,true))
SlashCmdList.MINIBARS('unlock')
assert(MiniBarsDB.locked==false)
''')
print('PASS: native initialization failure remains diagnosable and previews work')
