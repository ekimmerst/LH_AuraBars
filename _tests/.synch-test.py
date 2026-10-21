from pathlib import Path
exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
assert(LH_AuraBarsDB.synch==false)
SlashCmdList.LH_AURABARS('unlock')
local function resize(handle,dx,dy)
    cursorX,cursorY,mouseDown=0,0,true
    handle.scripts.OnMouseDown(nil,'LeftButton')
    cursorX,cursorY=dx,dy
    events.scripts.OnUpdate(events,0.5)
    mouseDown=false; events.scripts.OnUpdate(events,0.1)
end
resize(LH_AuraBarsTargetResizeHandle,80,-30)
assert(LH_AuraBarsDB.target.widthFactor==1.5 and LH_AuraBarsDB.widthFactor==1)
SlashCmdList.LH_AURABARS(' SYNCH   ON ')
assert(LH_AuraBarsDB.synch and LH_AuraBarsDB.target.widthFactor==1)
resize(LH_AuraBarsResizeHandle,80,-30)
assert(LH_AuraBarsDB.widthFactor==1.5 and LH_AuraBarsDB.heightFactor==1.5)
assert(LH_AuraBarsDB.target.widthFactor==1.5 and LH_AuraBarsDB.target.heightFactor==1.5)
resize(LH_AuraBarsTargetResizeHandle,-160,0)
assert(LH_AuraBarsDB.widthFactor==0.5 and LH_AuraBarsDB.target.widthFactor==0.5)
assert(LH_AuraBarsDB.heightFactor==1.5 and LH_AuraBarsDB.target.heightFactor==1.5)
assert(LH_AuraBarsFrame.width==LH_AuraBarsTargetFrame.width and LH_AuraBarsFrame.height==LH_AuraBarsTargetFrame.height)
SlashCmdList.LH_AURABARS('synch invalid'); assert(LH_AuraBarsDB.synch)
SlashCmdList.LH_AURABARS('synch off')
resize(LH_AuraBarsTargetResizeHandle,160,0)
assert(LH_AuraBarsDB.widthFactor==0.5 and LH_AuraBarsDB.target.widthFactor==1.5)
SlashCmdList.LH_AURABARS('synch on')
SlashCmdList.LH_AURABARS('reset')
assert(LH_AuraBarsDB.synch and LH_AuraBarsDB.widthFactor==1 and LH_AuraBarsDB.target.widthFactor==1)
print('PASS: synch default, on/off, both resize directions, dimensions, limits, parsing and reset')
''')
# Reload with persisted synchronization and mismatched legacy sizes.
lua.execute("LH_AuraBarsDB.widthFactor=1.25; LH_AuraBarsDB.heightFactor=0.75; LH_AuraBarsDB.target.widthFactor=2")
lua.execute((Path(__file__).resolve().parent.parent / 'LH_AuraBars.lua').read_text(), 'LH_AuraBars')
lua.execute('''
local events=frames[#frames]
events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
assert(LH_AuraBarsDB.synch and LH_AuraBarsDB.target.widthFactor==1.25 and LH_AuraBarsDB.target.heightFactor==0.75)
print('PASS: persisted synch after reload')
''')
