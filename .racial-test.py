from pathlib import Path

# Fresh Lua runtime per supported class.
for class_name in ('PALADIN', 'ROGUE', 'WARRIOR', 'WARLOCK'):
    exec(Path('.lua-test-support.py').read_text())
    lua.globals().TEST_CLASS = class_name
    lua.execute('''
    local events
    for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
    local function count()
     local n=0
     for _,f in ipairs(frames) do if rawget(f,'fill') and rawget(f,'visible') then n=n+1 end end
     return n
    end
    UnitClass=function() return 'Test Class',TEST_CLASS end
    GetSpellTabInfo=function(tab) return tab==1 and 'General' or 'Warlock',nil,tab==1 and 0 or 1,1 end
    GetSpellBookItemInfo=function(i) return 'SPELL',i==1 and 20572 or 6789 end
    local running=true
    C_Spell={GetSpellName=function(id) return id==20572 and 'Bloodfury' or 'Spell'..id end,
     GetSpellCooldown=function(id)
      if id==20572 and running then return {startTime=100,duration=120,isEnabled=true} end
      return {startTime=0,duration=0,isEnabled=true}
     end}
    events.scripts.OnEvent(events,'ADDON_LOADED','MiniBars'); assert(count()==1,'Legacy General racial cooldown missing')
    running=false; events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN'); assert(count()==0)
    Enum={SpellBookSpellBank={Player=0}}
    C_SpellBook={GetNumSpellBookSkillLines=function() return 2 end,
     GetSpellBookSkillLineInfo=function(line) return {itemIndexOffset=line==1 and 0 or 1,numSpellBookItems=1} end,
     GetSpellBookItemInfo=function(i) return {spellID=i==1 and 20572 or 6789,isPassive=false,isOffSpec=false} end}
    running=true; events.scripts.OnEvent(events,'SPELLS_CHANGED'); assert(count()==1,'Modern General racial cooldown missing')
    C_UnitAuras={GetUnitAuras=function() return {
     {name='Bloodfury',spellId=20572,duration=15,expirationTime=115},
     {name='Permanent Racial',spellId=999999,duration=0,expirationTime=0}
    } end}
    events.scripts.OnEvent(events,'UNIT_AURA','player'); assert(count()==2,'Timed racial buff missing or permanent buff visible')
    C_UnitAuras.GetUnitAuras=function() return {} end
    events.scripts.OnEvent(events,'UNIT_AURA','player'); assert(count()==1)
    clock=221; events.scripts.OnUpdate(events,0.5); assert(count()==0,'Expired racial cooldown remains')
    print('PASS: '..TEST_CLASS..' racial cooldown, legacy/modern spellbook, timed buff, permanent filter, reset and expiration')
    ''')
