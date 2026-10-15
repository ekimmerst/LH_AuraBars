import os
from pathlib import Path

exec(Path('.lua-test-support.py').read_text())
lua.execute('''
local events
for _, f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function count()
 local n=0
 for _,f in ipairs(frames) do
  if rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
 end
 return n
end
local data={}
C_UnitAuras={GetUnitAuras=function() return data end}
C_Spell={GetSpellName=function(id) return 'Spell'..id end,
 GetSpellCooldown=function(id)
  if id==20271 then return {startTime=100,duration=600,isEnabled=true} end
  return {startTime=0,duration=0,isEnabled=true}
 end}
IsSpellKnown=function() return true end
events.scripts.OnEvent(events,'ADDON_LOADED','MiniBars')
for _,class in ipairs({'PALADIN','ROGUE','WARRIOR'}) do
 UnitClass=function() return class,class end
 clock=100
 data={{name='Spell20271',spellId=20271,duration=600,expirationTime=280}}
 events.scripts.OnEvent(events,'SPELLS_CHANGED')
 local baseline=count()
 clock=100.1
 events.scripts.OnUpdate(events,0.1)
 assert(count()==baseline+1, class..': long buff must appear below 180 seconds')
 clock=99
 events.scripts.OnUpdate(events,0.1)
 assert(count()==baseline, class..': buff above 180 seconds must hide')
 clock=281
 events.scripts.OnUpdate(events,0.1)
 assert(count()==baseline, class..': expired buff must hide')
 if class=='PALADIN' then assert(baseline>=1,'long cooldown must remain visible') end
end
print('PASS: all classes, exact 180-second boundary, automatic entry, long total duration, expiry, long cooldown')
''')
