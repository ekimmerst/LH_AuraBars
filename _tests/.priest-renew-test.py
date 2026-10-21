from pathlib import Path
exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
UnitClass=function() return 'Priester','PRIEST' end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function renewRow()
 for _,f in ipairs(frames) do
  if f.parent==LH_AuraBarsFrame and rawget(f,'fill') and rawget(f,'visible') and f.name.text=='Erneuerung' then return f end
 end
end
local data={}
C_UnitAuras={GetUnitAuras=function(unit,filter)
 if unit=='player' and filter=='HELPFUL' then return data end
 return {}
end}
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
assert(not renewRow())
data={{name='Erneuerung',spellId=139,sourceUnit='player',duration=15,expirationTime=115}}
events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','renew',139)
events.scripts.OnEvent(events,'UNIT_AURA','player')
assert(renewRow(),'Self-cast Renew missing with hostile target')
clock=105; events.scripts.OnUpdate(events,0.1)
assert(renewRow().time.text=='10.0','Renew remaining duration incorrect')
data[1].expirationTime=120
events.scripts.OnEvent(events,'UNIT_AURA','player')
assert(renewRow().time.text=='15.0','Renew refresh did not reset timer')
targetAttackable=false; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
assert(not renewRow(),'Current visibility rule hides player buffs with friendly/self target')
targetAttackable=true; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
assert(renewRow(),'Renew did not return with hostile target')
data={}; events.scripts.OnEvent(events,'UNIT_AURA','player')
assert(not renewRow(),'Removed Renew still visible')
print('PASS: self-cast Renew application, countdown, refresh, target visibility and removal with readable aura data')
''')

