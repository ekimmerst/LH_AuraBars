from pathlib import Path

exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
UnitClass=function() return 'Jaeger','HUNTER' end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function count()
 local n=0
 for _,f in ipairs(frames) do
  if f.parent==LH_AuraBarsFrame and rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
 end
 return n
end
-- Learned ranks, talents and hunter racial abilities are discovered without a whitelist.
local ids={3044,14287,19434,2643,14290,1510,14295,1499,13809,13813,13795,14311,3045,19263,5384,781,19386,19503,19574,23989,20736,2974,1495,6991,136,883,982,1515,1543,999999}
GetSpellTabInfo=function() return 'Jaeger',nil,0,#ids end
GetSpellBookItemInfo=function(i) return 'SPELL',ids[i] end
local raw={}
C_Spell={GetSpellName=function(id) return 'Zauber'..id end,
 GetSpellCooldown=function(id) return raw[id] or {startTime=0,duration=0,isEnabled=true} end}
local helpful={
 {name='Schnellfeuer',spellId=3045,duration=30,expirationTime=130},
 {name='Tier heilen',spellId=136,duration=15,expirationTime=115},
 {name='Jagdfieber',spellId=34720,duration=15,expirationTime=115},
 {name='Langer erhaltener Buff',spellId=13165,duration=1800,expirationTime=400},
 {name='Aspekt des Affen',spellId=13163,duration=0,expirationTime=0}}
local harmful={{name='Erschuetternder Schuss',spellId=5116,duration=15,expirationTime=115}}
C_UnitAuras={GetUnitAuras=function(unit,filter)
 if unit~='player' then return {} end
 return filter=='HARMFUL' and harmful or helpful
end}
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
assert(count()==4,'Hunter buffs, proc and player debuff missing')
for _,id in ipairs(ids) do raw[id]={startTime=100,duration=180,isEnabled=true} end
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
assert(count()==4+#ids,'Legacy hunter spellbook cooldown discovery failed')
raw[3044]={startTime=100,duration=1.5,isEnabled=true,isOnGCD=true}
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
assert(count()==3+#ids,'GCD must not create a bar')
-- Modern spellbook includes new beta abilities but excludes passive/off-spec entries.
Enum={SpellBookSpellBank={Player=0}}
C_SpellBook={GetNumSpellBookSkillLines=function() return 1 end,
 GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=3} end,
 GetSpellBookItemInfo=function(i) return {spellID=9000+i,isPassive=i==2,isOffSpec=i==3} end}
raw[9001]={startTime=100,duration=120,isEnabled=true}
raw[9002]=raw[9001]; raw[9003]=raw[9001]
events.scripts.OnEvent(events,'SPELLS_CHANGED')
assert(count()==5,'Modern hunter spellbook filtering failed')
helpful={}; harmful={}
events.scripts.OnEvent(events,'UNIT_AURA','player')
assert(count()==1,'Removed hunter auras persist')
clock=221; events.scripts.OnUpdate(events,0.1)
assert(count()==0,'Expired hunter cooldown persists')
print('PASS: hunter legacy/modern spells, talents, racial abilities, buffs, procs, debuffs, permanent/long aura filters, GCD, removal and expiry')
''')
