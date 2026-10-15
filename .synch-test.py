from pathlib import Path
exec(Path('.lua-test-support.py').read_text())
lua.execute('''
local events
for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
events.scripts.OnEvent(events,'ADDON_LOADED','MiniBars')
assert(MiniBarsDB.synch==false)
SlashCmdList.MINIBARS('unlock')
local function resize(handle,dx,dy)
    cursorX,cursorY,mouseDown=0,0,true
    handle.scripts.OnMouseDown(nil,'LeftButton')
    cursorX,cursorY=dx,dy
    events.scripts.OnUpdate(events,0.5)
    mouseDown=false; events.scripts.OnUpdate(events,0.1)
end
resize(MiniBarsTargetResizeHandle,80,-30)
assert(MiniBarsDB.target.widthFactor==1.5 and MiniBarsDB.widthFactor==1)
SlashCmdList.MINIBARS(' SYNCH   ON ')
assert(MiniBarsDB.synch and MiniBarsDB.target.widthFactor==1)
resize(MiniBarsResizeHandle,80,-30)
assert(MiniBarsDB.widthFactor==1.5 and MiniBarsDB.heightFactor==1.5)
assert(MiniBarsDB.target.widthFactor==1.5 and MiniBarsDB.target.heightFactor==1.5)
resize(MiniBarsTargetResizeHandle,-160,0)
assert(MiniBarsDB.widthFactor==0.5 and MiniBarsDB.target.widthFactor==0.5)
assert(MiniBarsDB.heightFactor==1.5 and MiniBarsDB.target.heightFactor==1.5)
assert(MiniBarsFrame.width==MiniBarsTargetFrame.width and MiniBarsFrame.height==MiniBarsTargetFrame.height)
SlashCmdList.MINIBARS('synch invalid'); assert(MiniBarsDB.synch)
SlashCmdList.MINIBARS('synch off')
resize(MiniBarsTargetResizeHandle,160,0)
assert(MiniBarsDB.widthFactor==0.5 and MiniBarsDB.target.widthFactor==1.5)
SlashCmdList.MINIBARS('synch on')
SlashCmdList.MINIBARS('reset')
assert(MiniBarsDB.synch and MiniBarsDB.widthFactor==1 and MiniBarsDB.target.widthFactor==1)
print('PASS: synch default, on/off, both resize directions, dimensions, limits, parsing and reset')
''')
# Reload with persisted synchronization and mismatched legacy sizes.
lua.execute("MiniBarsDB.widthFactor=1.25; MiniBarsDB.heightFactor=0.75; MiniBarsDB.target.widthFactor=2")
lua.execute(Path('MiniBars.lua').read_text(), 'MiniBars')
lua.execute('''
local events=frames[#frames]
events.scripts.OnEvent(events,'ADDON_LOADED','MiniBars')
assert(MiniBarsDB.synch and MiniBarsDB.target.widthFactor==1.25 and MiniBarsDB.target.heightFactor==0.75)
print('PASS: persisted synch after reload')
''')
