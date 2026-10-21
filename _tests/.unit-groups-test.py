from pathlib import Path
exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local data={player={HELPFUL={{name='Received buff',spellId=999,duration=30,expirationTime=130,sourceUnit='other'}},
 HARMFUL={{name='Player debuff',spellId=998,duration=20,expirationTime=120,sourceUnit='target'}}},
 target={HELPFUL={{name='Target buff',spellId=997,duration=40,expirationTime=140}},
 HARMFUL={{name='Target debuff',spellId=996,duration=25,expirationTime=125,sourceUnit='player'}}}}
C_UnitAuras={GetUnitAuras=function(unit,filter) return data[unit][filter] end}
local cooling=true
GetSpellCooldown=function(id)
 if cooling and id==1310898 then return 100,60,1 end
 return 0,0,1
end
local function shown(parent)
 local names={}; local count=0
 for _,f in ipairs(frames) do
  if f.parent==parent and rawget(f,'fill') and rawget(f,'visible') then
   names[f.lastName]=f; count=count+1
  end
 end
 return names,count
end
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
local player,pn=shown(LH_AuraBarsFrame)
local target,tn=shown(LH_AuraBarsTargetFrame)
assert(pn==3 and player['Received buff'] and player['Player debuff'] and player['Spell1310898'])
assert(tn==2 and target['Target buff'] and target['Target debuff'])
assert(not target['Spell1310898'],'Player cooldown leaked into target group')
assert(player['Player debuff'].fill.color[1]==0.9)
-- A target cast must never start a player cooldown.
cooling=false; events.scripts.OnEvent(events,'SPELL_UPDATE_COOLDOWN')
events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','target','cast',1310898)
player,pn=shown(LH_AuraBarsFrame); assert(pn==2 and not player['Spell1310898'])
data.player.HARMFUL={}; events.scripts.OnEvent(events,'UNIT_AURA','player')
player,pn=shown(LH_AuraBarsFrame); assert(pn==1 and player['Received buff'])
target,tn=shown(LH_AuraBarsTargetFrame); assert(tn==2)
data.target={HELPFUL={},HARMFUL={}}
events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
target,tn=shown(LH_AuraBarsTargetFrame); assert(tn==0)
player,pn=shown(LH_AuraBarsFrame); assert(pn==1)
print('PASS: player/target aura ownership, received Paladin buffs, player debuffs, cooldown isolation, removal and target change')
''')
