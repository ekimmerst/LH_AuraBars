from pathlib import Path
exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
lua.execute('''
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
events.scripts.OnEvent(events,'ADDON_LOADED','MiniAuraBars')
assert(MiniAuraBarsDB.synch==false)
SlashCmdList.MINIAURABARS('unlock')
local function resize(handle,dx,dy)
    cursorX,cursorY,mouseDown=0,0,true
    handle.scripts.OnMouseDown(nil,'LeftButton')
    cursorX,cursorY=dx,dy
    events.scripts.OnUpdate(events,0.5)
    mouseDown=false; events.scripts.OnUpdate(events,0.1)
end
resize(MiniAuraBarsTargetResizeHandle,80,-30)
assert(MiniAuraBarsDB.target.widthFactor==1.5 and MiniAuraBarsDB.widthFactor==1)
SlashCmdList.MINIAURABARS(' SYNCH   ON ')
assert(MiniAuraBarsDB.synch and MiniAuraBarsDB.target.widthFactor==1)
resize(MiniAuraBarsResizeHandle,80,-30)
assert(MiniAuraBarsDB.widthFactor==1.5 and MiniAuraBarsDB.heightFactor==1.5)
assert(MiniAuraBarsDB.target.widthFactor==1.5 and MiniAuraBarsDB.target.heightFactor==1.5)
resize(MiniAuraBarsTargetResizeHandle,-160,0)
assert(MiniAuraBarsDB.widthFactor==0.5 and MiniAuraBarsDB.target.widthFactor==0.5)
assert(MiniAuraBarsDB.heightFactor==1.5 and MiniAuraBarsDB.target.heightFactor==1.5)
assert(MiniAuraBarsFrame.width==MiniAuraBarsTargetFrame.width and MiniAuraBarsFrame.height==MiniAuraBarsTargetFrame.height)
SlashCmdList.MINIAURABARS('synch invalid'); assert(MiniAuraBarsDB.synch)
SlashCmdList.MINIAURABARS('synch off')
resize(MiniAuraBarsTargetResizeHandle,160,0)
assert(MiniAuraBarsDB.widthFactor==0.5 and MiniAuraBarsDB.target.widthFactor==1.5)
SlashCmdList.MINIAURABARS('synch on')
SlashCmdList.MINIAURABARS('reset')
assert(MiniAuraBarsDB.synch and MiniAuraBarsDB.widthFactor==1 and MiniAuraBarsDB.target.widthFactor==1)
print('PASS: synch default, on/off, both resize directions, dimensions, limits, parsing and reset')
''')
# Reload with persisted synchronization and mismatched legacy sizes.
lua.execute("MiniAuraBarsDB.widthFactor=1.25; MiniAuraBarsDB.heightFactor=0.75; MiniAuraBarsDB.target.widthFactor=2")
lua.execute((Path(__file__).resolve().parent.parent / 'MiniAuraBars.lua').read_text(), 'MiniAuraBars')
lua.execute('''
local events=frames[#frames]
events.scripts.OnEvent(events,'ADDON_LOADED','MiniAuraBars')
assert(MiniAuraBarsDB.synch and MiniAuraBarsDB.target.widthFactor==1.25 and MiniAuraBarsDB.target.heightFactor==0.75)
print('PASS: persisted synch after reload')
''')
