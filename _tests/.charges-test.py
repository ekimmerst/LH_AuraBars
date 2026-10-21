from pathlib import Path

exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
UnitClass=function() return 'Mage','MAGE' end
GetNumSpellTabs=function() return 1 end
GetSpellTabInfo=function() return 'Mage',nil,0,1 end
GetSpellBookItemInfo=function() return 'SPELL',900001 end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function count()
 local n=0
 for _,f in ipairs(frames) do
  if f.parent==LH_AuraBarsFrame and rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
 end
 return n
end
local current, maximum, start, duration, rate=1,2,100,30,1
C_Spell={GetSpellName=function() return 'Recharge' end,
 GetSpellCooldown=function() return {startTime=0,duration=0,isEnabled=true} end,
 GetSpellCharges=function() return {currentCharges=current,maxCharges=maximum,
  cooldownStartTime=start,cooldownDuration=duration,chargeModRate=rate} end}
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
assert(count()==1,'Recharge with one usable charge missing')
current=2;events.scripts.OnEvent(events,'SPELL_UPDATE_CHARGES');assert(count()==0)
current=0;events.scripts.OnEvent(events,'SPELL_UPDATE_CHARGES');assert(count()==1)
rate=2;clock=116;events.scripts.OnEvent(events,'SPELL_UPDATE_CHARGES');assert(count()==0,'Recharge rate ignored')
clock=100;rate=1
-- Legacy charge API follows the same rules.
C_Spell.GetSpellCharges=nil
GetSpellCharges=function() return current,maximum,start,duration,rate end
events.scripts.OnEvent(events,'SPELL_UPDATE_CHARGES');assert(count()==1)
local secret={}
issecretvalue=function(v) return v==secret end
current=secret;events.scripts.OnEvent(events,'SPELL_UPDATE_CHARGES')
assert(count()==1,'Known recharge lost when charge counts become restricted')
clock=131;events.scripts.OnUpdate(events,0.5);assert(count()==0)
current=2;clock=100;events.scripts.OnEvent(events,'SPELL_UPDATE_CHARGES');assert(count()==0)
''')
print('PASS: modern/legacy charges, partial/full/empty charges, recharge rate, restricted counts and expiry')
