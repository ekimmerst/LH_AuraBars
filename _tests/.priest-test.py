from pathlib import Path

exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
UnitClass=function() return 'Priester','PRIEST' end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function count()
 local n=0
 for _,f in ipairs(frames) do
  if f.parent==MiniAuraBarsFrame and rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
 end
 return n
end
-- Learned ranks, talents and priest racial abilities are discovered without a whitelist.
local ids={17,8092,8122,15487,10060,19236,2944,999999}
GetSpellTabInfo=function() return 'Priester',nil,0,#ids end
GetSpellBookItemInfo=function(i) return 'SPELL',ids[i] end
local raw={}
C_Spell={GetSpellName=function(id) return 'Zauber'..id end,
 GetSpellCooldown=function(id) return raw[id] or {startTime=0,duration=0,isEnabled=true} end}
local helpful={
 {name='Machtwort: Schild',spellId=17,duration=30,expirationTime=130},
 {name='Erneuerung',spellId=139,duration=15,expirationTime=115},
 {name='Willensentzug',spellId=15271,duration=15,expirationTime=115},
 {name='Machtwort: Seelenstaerke',spellId=1243,duration=1800,expirationTime=400},
 {name='Schattengestalt',spellId=15473,duration=0,expirationTime=0}}
local harmful={{name='Geschwaechte Seele',spellId=6788,duration=15,expirationTime=115}}
C_UnitAuras={GetUnitAuras=function(unit,filter)
 if unit~='player' then return {} end
 return filter=='HARMFUL' and harmful or helpful
end}
events.scripts.OnEvent(events,'ADDON_LOADED','MiniAuraBars')
assert(count()==4,'Priest buffs, proc and player debuff missing')
for _,id in ipairs(ids) do raw[id]={startTime=100,duration=180,isEnabled=true} end
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
assert(count()==12,'Legacy priest spellbook cooldown discovery failed')
raw[8092]={startTime=100,duration=1.5,isEnabled=true,isOnGCD=true}
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
assert(count()==11,'GCD must not create a bar')
-- Modern spellbook includes new beta abilities but excludes passive/off-spec entries.
Enum={SpellBookSpellBank={Player=0}}
C_SpellBook={GetNumSpellBookSkillLines=function() return 1 end,
 GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=3} end,
 GetSpellBookItemInfo=function(i) return {spellID=9000+i,isPassive=i==2,isOffSpec=i==3} end}
raw[9001]={startTime=100,duration=120,isEnabled=true}
raw[9002]=raw[9001]; raw[9003]=raw[9001]
events.scripts.OnEvent(events,'SPELLS_CHANGED')
assert(count()==5,'Modern priest spellbook filtering failed')
helpful={}; harmful={}
events.scripts.OnEvent(events,'UNIT_AURA','player')
assert(count()==1,'Removed priest auras persist')
clock=221; events.scripts.OnUpdate(events,0.1)
assert(count()==0,'Expired priest cooldown persists')
print('PASS: priest legacy/modern spells, talents, racial abilities, buffs, procs, debuffs, permanent/long aura filters, GCD, removal and expiry')
''')
