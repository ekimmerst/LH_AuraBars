from pathlib import Path

addon = Path(__file__).resolve().parent.parent
exec((addon / '_tests/.lua-test-support.py').read_text())
lua.execute('''
registry, notices, callbacks, buttons = {}, {}, {}, {}
Settings = {}
function Settings.RegisterVerticalLayoutSubcategory(parent, title)
 local category = {parent=parent, title=title}
 local layout = {rows={}}
 function layout:AddInitializer(row) table.insert(self.rows, row) end
 category.layout=layout
 return category, layout
end
function Settings.RegisterAddOnCategory(category) registeredCategory=category end
function Settings.RegisterProxySetting(category, variable, kind, label, default, get, set)
 assert(not registry[variable])
 local setting={category=category, default=default, get=get, set=set}
 registry[variable]=setting
 return setting
end
function Settings.CreateCheckbox(category, setting, tooltip)
 table.insert(category.layout.rows, {setting=setting, tooltip=tooltip})
end
function Settings.NotifyUpdate(variable) notices[variable]=(notices[variable] or 0)+1 end
function CreateSettingsListSectionHeaderInitializer(title) return {title=title} end
function CreateSettingsButtonInitializer(label, text, callback, tooltip)
 buttons[text]=callback
 return {label=label, tooltip=tooltip}
end
EventRegistry={}
function EventRegistry:RegisterCallback(event, callback, owner)
 callbacks[event]=callbacks[event] or {}
 table.insert(callbacks[event], {callback, owner})
end
function fire(event, ...)
 for _, entry in ipairs(callbacks[event]) do entry[1](entry[2], ...) end
end
LH_Tweaks={modules={}}
''')
# Use the real host's module queue and category registration methods.
core = addon.parent / 'LH_Tweaks'
host = (core / 'LH_Tweaks.lua').read_text()
registration = host.split('function Hub:RegisterModule(id, title, build)')[1].split('\nfunction Hub:RestoreDefaults')[0]
lua.execute('local Hub=LH_Tweaks\nfunction Hub:RegisterModule(id, title, build)' + registration)
host_settings = (core / 'Settings.lua').read_text()
registration = host_settings.split('function Hub:RegisterModulePage(id)')[1].split('\nlocal function RegisterSettings')[0]
lua.execute('local Hub=LH_Tweaks\nfunction Hub:RegisterModulePage(id)' + registration)
lua.execute((addon / 'Settings.lua').read_text(), 'LH_AuraBars')
lua.execute('''
assert(LH_Tweaks.modules.LH_AuraBars and not registeredCategory)
local events
for _, frame in ipairs(frames) do if frame.scripts.OnEvent then events=frame end end
events.scripts.OnEvent(events, 'ADDON_LOADED', 'LH_AuraBars')
LH_Tweaks.category={title='LH Tweaks'}
LH_Tweaks:RegisterModulePage('LH_AuraBars')
local category=registeredCategory
assert(category.parent==LH_Tweaks.category and category.title=='LH AuraBars')
local unlock, synch=registry.LH_AuraBars_unlocked, registry.LH_AuraBars_synch
assert(not unlock.get() and not synch.get())
assert(unlock.default==false and synch.default==false)
unlock.set(true)
assert(unlock.get() and not LH_AuraBarsDB.locked)
LH_AuraBarsDB.widthFactor=1.5
synch.set(true)
assert(synch.get() and LH_AuraBarsDB.target.widthFactor==1.5)
SlashCmdList.LH_AURABARS('lock')
assert(not unlock.get() and notices.LH_AuraBars_unlocked>0)
SlashCmdList.LH_AURABARS('unlock')
LH_AuraBarsDB.position={x=600,y=300}
LH_AuraBarsDB.target.position={x=300,y=300}
buttons['Reset layout']()
assert(unlock.get() and synch.get())
assert(not LH_AuraBarsDB.position and not LH_AuraBarsDB.target.position)
assert(LH_AuraBarsDB.widthFactor==1 and LH_AuraBarsDB.target.widthFactor==1)
LH_AuraBarsDB.cooldownDurations[123]=42
LH_AuraBarsDB.sealDurations.example=30
LH_AuraBarsDB.widthFactor=1.5
fire('Settings.CategoryDefaulted', {})
assert(unlock.get() and LH_AuraBarsDB.widthFactor==1.5)
fire('Settings.CategoryDefaulted', category)
assert(not unlock.get() and not synch.get() and LH_AuraBarsDB.widthFactor==1)
assert(LH_AuraBarsDB.cooldownDurations[123]==42 and LH_AuraBarsDB.sealDurations.example==30)
unlock.set(true);synch.set(true)
fire('Settings.Defaulted')
assert(not unlock.get() and not synch.get())
buttons['Print diagnostics']()
-- Simulate a new character load with saved state before immediate page registration.
LH_AuraBarsDB.locked=false;LH_AuraBarsDB.synch=true
LH_AuraBarsDB.widthFactor=1.25;LH_AuraBarsDB.heightFactor=0.75
LH_Tweaks:RegisterModule('immediate', 'Immediate', function(c) assert(c.parent==LH_Tweaks.category) end)
''')
lua.execute((addon / 'LH_AuraBars.lua').read_text(), 'LH_AuraBars')
lua.execute('''
local events=frames[#frames]
events.scripts.OnEvent(events, 'ADDON_LOADED', 'LH_AuraBars')
assert(registry.LH_AuraBars_unlocked.get() and registry.LH_AuraBars_synch.get())
assert(LH_AuraBarsDB.target.widthFactor==1.25 and LH_AuraBarsDB.target.heightFactor==0.75)
''')
for extension in ('png', 'tga'):
    assert (addon / f'Media/Icon.{extension}').read_bytes() == (core / f'Icon.{extension}').read_bytes()
toc = (addon / 'LH_AuraBars.toc').read_text()
assert '## Group: LH_Tweaks' in toc and '## Dependencies: LH_Tweaks' in toc
assert 'Settings.lua' in toc
print('PASS: real host registration, native controls, slash synchronization, scoped defaults, layout reset, cache preservation, diagnostics, saved state and shared icons')
