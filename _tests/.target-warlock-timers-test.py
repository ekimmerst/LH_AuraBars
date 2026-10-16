from pathlib import Path
exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
UnitClass=function() return 'Warlock','WARLOCK' end
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function rows()
 local result={}
 for _,f in ipairs(frames) do
  if f.parent==MiniAuraBarsTargetFrame and rawget(f,'fill') and rawget(f,'visible') then result[#result+1]=f end
 end
 return result
end
local data={{name='Spell172',spellId=6223,duration=0,expirationTime=0,sourceUnit='player',auraInstanceID=1}}
C_UnitAuras={GetUnitAuras=function() return {} end,
 GetAuraDataByIndex=function(unit,index,filter)
  if unit=='target' and filter=='HARMFUL' then return data[index] end
 end}
events.scripts.OnEvent(events,'ADDON_LOADED','MiniAuraBars')
assert(#rows()==1,'Empty batch hid indexed DoT / missing duration hid own DoT')
assert(rows()[1].fill.maximum==18 and rows()[1].fill.value==18)
clock=110; events.scripts.OnUpdate(events,0.5)
assert(rows()[1].fill.value==8,'Polling restarted estimated duration')
clock=119; events.scripts.OnUpdate(events,0.5)
assert(#rows()==0,'Expired estimate restarted')
data={}; events.scripts.OnEvent(events,'UNIT_AURA','target')
data={{name='Spell172',duration=0,expirationTime=0,sourceUnit='other'}}
events.scripts.OnEvent(events,'UNIT_AURA','target'); assert(#rows()==0)
data[1].sourceUnit='player'
events.scripts.OnEvent(events,'UNIT_AURA','target'); assert(#rows()==1)
data[1].duration=18; data[1].expirationTime=125
events.scripts.OnEvent(events,'UNIT_AURA','target')
assert(rows()[1].fill.value==6,'Real timer did not replace estimate')
data={}; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED'); assert(#rows()==0)
-- A nil indexed response must still try the legacy query.
UnitDebuff=function(unit,index)
 if unit=='target' and index==1 then return 'Legacy DoT',1,nil,nil,15,134,'player',nil,nil,348 end
end
events.scripts.OnEvent(events,'UNIT_AURA','target'); assert(#rows()==1)
local output, originalPrint = {}, print
print=function(message) output[#output+1]=message end
local secret={}
issecretvalue=function(value) return value==secret end
C_UnitAuras.GetUnitAuras=function()
 return {{name=secret,spellId=secret,duration=secret,expirationTime=secret,sourceUnit=secret}}
end
C_UnitAuras.GetAuraDataByIndex=function() error('Test API denied') end
SlashCmdList.MINIAURABARS('debug')
print=originalPrint
local diagnostic=table.concat(output,'\\n')
assert(diagnostic:find('Target diagnostics 1.5.4',1,true))
assert(diagnostic:find('name = hidden',1,true))
assert(diagnostic:find('ERROR:',1,true))
assert(diagnostic:find('Usable HARMFUL',1,true))
print('PASS: Warlock missing timers, empty batch, nil index, countdown, expiration, removal, real timers and target changes')
''')
