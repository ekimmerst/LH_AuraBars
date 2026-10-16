from pathlib import Path
exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
local events
for _, f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function count()
 local n=0
 for _,f in ipairs(frames) do
  if f.parent==MiniAuraBarsFrame and rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
 end
 return n
end
UnitClass=function() return 'Warlock','WARLOCK' end
local ids={172,348,6789}
GetSpellTabInfo=function() return 'Warlock',nil,0,#ids end
GetSpellBookItemInfo=function(i) return 'SPELL',ids[i] end
local mode='ready'
C_Spell={GetSpellName=function(id) return 'Spell'..id end,
 GetSpellCooldown=function(id)
  if mode=='hidden' then error('blocked') end
  if mode=='gcd' then return {startTime=100,duration=1.5,isEnabled=true,isOnGCD=true} end
  if mode=='real' and id==6789 then return {startTime=100,duration=120,isEnabled=true} end
  return {startTime=0,duration=0,isEnabled=true}
 end}
GetSpellBaseCooldown=function(id) return id==6789 and 120000 or 0 end
events.scripts.OnEvent(events,'ADDON_LOADED','MiniAuraBars')
for _,modeValue in ipairs({'ready','gcd','hidden'}) do
 mode=modeValue
 for _,id in ipairs({172,348}) do
  MiniAuraBarsDB.cooldownDurations['Spell'..id]=18
  events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','cast',id)
  assert(count()==0,mode..' created false DoT cooldown')
 end
end
mode='hidden'
events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','cast',6789)
assert(count()==1,'Real base cooldown fallback missing')
mode='ready'
events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','cast',6789)
assert(count()==0,'Readable ready result failed to clear estimate')
mode='real'
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
assert(count()==1,'Real cooldown missing')
print('PASS: Corruption/Immolate ready, GCD, hidden data, stale cache; real cooldown and fallback')
''')
