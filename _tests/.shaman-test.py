from pathlib import Path

exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
UnitClass=function() return 'Schamane','SHAMAN' end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function count()
 local n=0
 for _,f in ipairs(frames) do
  if f.parent==LH_AuraBarsFrame and rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
 end
 return n
end
-- Learned ranks, talents and shaman racial abilities are discovered without a whitelist.
local ids={8042,10414,8050,29228,8056,10473,8046,57994,17364,16166,16188,16190,8177,2484,8143,1535,8190,2894,2062,32182,2825,30823,51533,51514,20608,556,2008,324,974,52127,61295,999999}
GetSpellTabInfo=function() return 'Schamane',nil,0,#ids end
GetSpellBookItemInfo=function(i) return 'SPELL',ids[i] end
local raw={}
C_Spell={GetSpellName=function(id) return 'Zauber'..id end,
 GetSpellCooldown=function(id) return raw[id] or {startTime=0,duration=0,isEnabled=true} end}
local helpful={
 {name='Elementarbeherrschung',spellId=16166,duration=30,expirationTime=130},
 {name='Schnelligkeit der Natur',spellId=16188,duration=15,expirationTime=115},
 {name='Freizaubern',spellId=16246,duration=15,expirationTime=115},
 {name='Langer erhaltener Buff',spellId=13165,duration=1800,expirationTime=400},
 {name='Waffenverzauberung',spellId=8024,duration=0,expirationTime=0}}
local harmful={{name='Flammenschock',spellId=8050,duration=15,expirationTime=115}}
C_UnitAuras={GetUnitAuras=function(unit,filter)
 if unit~='player' then return {} end
 return filter=='HARMFUL' and harmful or helpful
end}
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
assert(count()==4,'Shaman buffs, proc and player debuff missing')
for _,id in ipairs(ids) do raw[id]={startTime=100,duration=180,isEnabled=true} end
events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
assert(count()==4+#ids,'Legacy shaman spellbook cooldown discovery failed')
raw[8042]={startTime=100,duration=1.5,isEnabled=true,isOnGCD=true}
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
assert(count()==5,'Modern shaman spellbook filtering failed')
helpful={}; harmful={}
events.scripts.OnEvent(events,'UNIT_AURA','player')
assert(count()==1,'Removed shaman auras persist')
clock=221; events.scripts.OnUpdate(events,0.1)
assert(count()==0,'Expired shaman cooldown persists')
print('PASS: shaman legacy/modern spells, talents, racial abilities, buffs, procs, debuffs, permanent/long aura filters, GCD, removal and expiry')
''')
