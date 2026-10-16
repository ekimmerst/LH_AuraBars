import os
from pathlib import Path

# Reuse the existing Lua 5.1 WoW UI mock without its Paladin assertions.
exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
local events
for _, f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function visible()
 local result={}
 for _,f in ipairs(frames) do
  if rawget(f,'fill') and rawget(f,'visible') then result[#result+1]=f end
 end
 return result
end
UnitClass=function() return 'Rogue','ROGUE' end
local ids={2983,1856,13750,14177,1766}
GetSpellTabInfo=function() return 'Rogue',nil,0,#ids end
GetSpellBookItemInfo=function(index) return 'SPELL',ids[index] end
local raw={}
C_Spell={GetSpellName=function(id) return 'Spell'..id end,
 GetSpellCooldown=function(id) return raw[id] or {startTime=0,duration=0,isEnabled=true} end}
local data={}
C_UnitAuras={GetUnitAuras=function(unit,filter) if unit=="target" or filter=="HARMFUL" then return {} end return data end}
events.scripts.OnEvent(events,'ADDON_LOADED','MiniAuraBars')
data={{name='Slice',spellId=5171,duration=30,expirationTime=130},
 {name='Proc',spellId=999999,duration=120,expirationTime=220},
 {name='Stealth',spellId=1784,duration=0,expirationTime=0}}
events.scripts.OnEvent(events,'UNIT_AURA','player')
assert(#visible()==2)
for _,id in ipairs(ids) do raw[id]={startTime=100,duration=180,isEnabled=true} end
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN'); assert(#visible()==7)
raw[1766]={startTime=100,duration=1,isEnabled=true,isOnGCD=true}
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN'); assert(#visible()==6)
-- Reset and cached fallback when cooldown data becomes inaccessible.
raw[1856]={startTime=0,duration=0,isEnabled=true}
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN'); assert(#visible()==5)
clock=110
C_Spell.GetSpellCooldown=function() error('blocked') end
events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','vanish',1856)
assert(#visible()==6)
targetAttackable=false; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED'); assert(#visible()==0)
targetAttackable=true; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED'); assert(#visible()==6)
-- Modern spellbook: include active spells, exclude passive and off-spec.
C_Spell.GetSpellCooldown=function(id)
 if id==61304 then return {startTime=0,duration=0,isEnabled=true} end
 return {startTime=110,duration=20,isEnabled=true,isOnGCD=false}
end
Enum={SpellBookSpellBank={Player=0}}
C_SpellBook={GetNumSpellBookSkillLines=function() return 2 end,
 GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=3} end,
 GetSpellBookItemInfo=function(i) return {spellID=9000+i,isPassive=i==2,isOffSpec=i==3} end}
events.scripts.OnEvent(events,'SPELLS_CHANGED'); assert(#visible()==3)
data={}; events.scripts.OnEvent(events,'UNIT_AURA','player'); assert(#visible()==1)
clock=131; events.scripts.OnUpdate(events,0.1); assert(#visible()==0)
print('PASS: rogue buffs/procs, long buffs, permanent filter, legacy/modern spellbook, cooldowns, GCD, reset, blocked cast fallback, target, removal, expiry')
''')
