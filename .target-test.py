from pathlib import Path
exec(Path('.lua-test-support.py').read_text())
lua.execute('''
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
local function rows(parent)
    local result={}
    for _,f in ipairs(frames) do
        if f.parent==parent and rawget(f,'fill') and rawget(f,'visible') then result[#result+1]=f end
    end
    return result
end
local helpful={{name='Target buff',icon=12345,spellId=1,duration=30,expirationTime=130},
    {name='Permanent',spellId=2,duration=0,expirationTime=0}}
local harmful={{name='Target debuff',spellId=3,duration=20,expirationTime=120}}
C_UnitAuras={GetUnitAuras=function(unit,filter)
    if unit=='player' then return {} end
    return filter=='HELPFUL' and helpful or harmful
end}
events.scripts.OnEvent(events,'ADDON_LOADED','MiniBars')
assert(#rows(MiniBarsTargetFrame)==2)
assert(rows(MiniBarsTargetFrame)[1].lastName=='Target buff')
assert(rows(MiniBarsTargetFrame)[1].lastIcon==12345)
assert(rows(MiniBarsTargetFrame)[1].icon.height==20)
assert(rows(MiniBarsTargetFrame)[1].icon.point[4]==-3)
assert(rows(MiniBarsTargetFrame)[1].point[5]-rows(MiniBarsTargetFrame)[2].point[5]==20)
assert(rows(MiniBarsTargetFrame)[2].fill.color[1]==0.9)
harmful={}; events.scripts.OnEvent(events,'UNIT_AURA','target')
assert(#rows(MiniBarsTargetFrame)==1)
targetExists=false; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
assert(#rows(MiniBarsTargetFrame)==0)
targetExists=true; helpful={}; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
assert(#rows(MiniBarsTargetFrame)==0,'Previous target leaked')
SlashCmdList.MINIBARS('unlock')
assert(#rows(MiniBarsFrame)==3 and #rows(MiniBarsTargetFrame)==3)
local playerWidth=MiniBarsDB.widthFactor
mouseDown=true; cursorX=0; cursorY=0
MiniBarsTargetResizeHandle.scripts.OnMouseDown(nil,'LeftButton')
cursorX=160; cursorY=-60; events.scripts.OnUpdate(events,0.5)
assert(MiniBarsDB.target.widthFactor==2 and MiniBarsDB.target.heightFactor==2)
assert(MiniBarsDB.widthFactor==playerWidth and MiniBarsDB.heightFactor==1)
for _,parent in ipairs({MiniBarsFrame,MiniBarsTargetFrame}) do
    for _,row in ipairs(rows(parent)) do
        assert(row.name.fontSize==12 and row.time.fontSize==12 and row.measure.fontSize==12)
        assert(row.time.width==42)
        assert(row.icon.height==row.height and row.icon.width==row.height)
    end
end
mouseDown=false; events.scripts.OnUpdate(events,0.1)
local targetRow=rows(MiniBarsTargetFrame)[1]
targetRow.scripts.OnDragStop()
assert(MiniBarsDB.target.position.x==700)
SlashCmdList.MINIBARS('lock')
assert(#rows(MiniBarsFrame)==0 and #rows(MiniBarsTargetFrame)==0)
assert(not targetRow.mouse)
SlashCmdList.MINIBARS('reset')
assert(MiniBarsDB.target.widthFactor==1 and MiniBarsDB.target.heightFactor==1)
assert(MiniBarsDB.target.position==nil and MiniBarsDB.position==nil)
-- Legacy target buffs and debuffs use distinct queries and filters.
C_UnitAuras=nil
UnitBuff=function(unit,index)
    if unit=='target' and index==1 then return 'Legacy buff',nil,nil,nil,30,130,'other',nil,nil,1 end
end
UnitDebuff=function(unit,index)
    if unit=='target' and index==1 then return 'Legacy debuff',nil,nil,nil,15,115,'other',nil,nil,2 end
end
events.scripts.OnEvent(events,'UNIT_AURA','target')
assert(#rows(MiniBarsTargetFrame)==2)
clock=131; events.scripts.OnUpdate(events,0.5)
assert(#rows(MiniBarsTargetFrame)==0)
print('PASS: target buffs/debuffs, modern/legacy APIs, removal, target switch, independent resize/position, fixed fonts, previews, lock, reset, expiration')
''')
