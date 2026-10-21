from pathlib import Path

classes = ('WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID',
           'DEATHKNIGHT', 'MONK', 'DEMONHUNTER', 'EVOKER', 'NEW_BETA_CLASS')
races = {'Alliance': ('Human', 'Dwarf', 'NightElf', 'Gnome', 'Draenei'),
         'Horde': ('Orc', 'Scourge', 'Tauren', 'Troll', 'BloodElf'),
         'Neutral': ('Pandaren', 'NEW_BETA_RACE')}

for class_name in classes:
    for faction, faction_races in races.items():
        for race in faction_races:
            exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
            lua.globals().TEST_CLASS = class_name
            lua.globals().TEST_RACE = race
            lua.globals().TEST_FACTION = faction
            lua.execute('''
UnitClass=function() return 'Localized class', TEST_CLASS end
UnitRace=function() return 'Localized race', TEST_RACE end
UnitFactionGroup=function() return TEST_FACTION end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function bars()
 local result={}
 for _,f in ipairs(frames) do
  if f.parent==LH_AuraBarsFrame and rawget(f,'fill') and rawget(f,'visible') then
   result[f.name.text]=true
  end
 end
 return result
end
local hidden, running=false,true
local ids={900101,900102,900103,900104,900105,900106}
GetNumSpellTabs=function() return 3 end
GetSpellTabInfo=function(tab) return 'Localized section', nil, (tab-1)*2, 2 end
GetSpellBookItemInfo=function(slot)
 if slot==6 then return 'FLYOUT', 500 end
 return 'SPELL', ids[slot]
end
GetFlyoutInfo=function(id) assert(id==500);return 'Flyout',nil,3,true end
GetFlyoutSlotInfo=function(id,slot)
 if slot==1 then return 900106,900107,true end
 if slot==2 then return 900108,0,false end
 return 900109,0,true
end
C_Spell={GetSpellName=function(id) return 'Ability'..id end,
 GetSpellCooldown=function(id)
  if hidden then error('Restricted cooldown') end
  if id==61304 or not running then return {startTime=0,duration=0,isEnabled=true} end
  return {startTime=100,duration=120,isEnabled=true}
 end}
GetSpellBaseCooldown=function() return 120000 end
C_UnitAuras={GetUnitAuras=function(unit,filter)
 if unit~='player' or filter=='HARMFUL' then return {} end
 return {{name='Received buff',spellId=999201,duration=1800,expirationTime=280},
         {name='Racial proc',spellId=999202,duration=15,expirationTime=115},
         {name='Permanent passive',spellId=999203,duration=0,expirationTime=0}}
end}
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
local found=bars()
for _,id in ipairs({900101,900102,900103,900104,900105,900107,900109}) do
 assert(found['Ability'..id],TEST_CLASS..' legacy spell missing: '..id)
end
assert(not found.Ability900106 and not found.Ability900108)
assert(found['Received buff'] and found['Racial proc'] and not found['Permanent passive'])
-- Every class and racial ability uses the hidden-cooldown cast fallback.
running=false;events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
assert(not bars().Ability900103)
hidden=true
for _,id in ipairs({900101,900103,900105,900107}) do
 events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','cast',id)
 assert(bars()['Ability'..id],TEST_CLASS..' cast fallback missing')
end
-- A modern spellbook includes class sections, overrides, flyouts and beta IDs.
hidden=false;running=true
Enum={SpellBookSpellBank={Player=0},SpellBookItemType={Spell=1,Flyout=2,FutureSpell=3}}
C_SpellBook={GetNumSpellBookSkillLines=GetNumSpellTabs,
 GetSpellBookSkillLineInfo=function(line) return {itemIndexOffset=(line-1)*2,numSpellBookItems=2} end,
 GetSpellBookItemInfo=function(slot)
  if slot==6 then return {itemType=2,actionID=500} end
  return {itemType=slot==5 and 3 or 1,spellID=ids[slot],isPassive=slot==3,isOffSpec=slot==4}
 end}
events.scripts.OnEvent(events,'SPELLS_CHANGED')
found=bars()
assert(found.Ability900101 and found.Ability900102 and found.Ability900107 and found.Ability900109)
assert(not found.Ability900103 and not found.Ability900104 and not found.Ability900105)
assert(not found.Ability900106 and not found.Ability900108)
-- A newly learned ability is discovered, then removed when unlearned.
C_SpellBook.GetSpellBookItemInfo=function(slot) return {itemType=1,spellID=910000+slot} end
events.scripts.OnEvent(events,'SPELLS_CHANGED')
found=bars(); assert(found.Ability910006 and not found.Ability900101)
clock=281;events.scripts.OnUpdate(events,0.5)
assert(next(bars())==nil,'Expired cooldowns or buffs remain')
''')
    print(f'PASS: {class_name}, all faction/race fixtures, legacy/modern sections, flyouts, cast fallback, buffs, learning and expiry')
