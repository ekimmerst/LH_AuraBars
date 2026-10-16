from pathlib import Path

for spell_id in (20572, 33697, 33702):
    exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
    lua.globals().bloodfuryID = spell_id
    lua.execute('''
    UnitClass=function() return 'Warlock','WARLOCK' end
    local events
    for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
    local function count()
        local n=0
        for _,f in ipairs(frames) do
            if rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
        end
        return n
    end
    local secret={}
    issecretvalue=function(v) return v==secret end
    C_UnitAuras={GetUnitAuras=function(unit) if unit=="target" then return {} end return secret end}
    events.scripts.OnEvent(events,'ADDON_LOADED','MiniAuraBars')
    events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','pet','cast',bloodfuryID)
    assert(count()==0,'Pet cast must not create timer')
    events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','cast',bloodfuryID)
    assert(count()==1,'Hidden aura needs cast timer')
    clock=110; events.scripts.OnUpdate(events,0.5)
    assert(count()==1,'Hidden scan lost timer')
    clock=116; events.scripts.OnUpdate(events,0.5)
    assert(count()==0,'Estimate must expire')
    events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','cast',bloodfuryID)
    C_UnitAuras.GetUnitAuras=function(unit,filter) if unit=="target" or filter=="HARMFUL" then return {} end return {
        {name='Spell'..bloodfuryID,spellId=bloodfuryID,duration=20,expirationTime=136}
    } end
    events.scripts.OnEvent(events,'UNIT_AURA','player')
    assert(count()==1,'Readable aura duplicated estimate')
    assert(MiniAuraBarsDB.bloodfuryDuration==20,'Actual duration must be learned')
    C_UnitAuras.GetUnitAuras=function(unit) if unit=="target" then return {} end return {} end
    events.scripts.OnEvent(events,'UNIT_AURA','player')
    assert(count()==0,'Readable removal must clear buff')
    C_UnitAuras.GetUnitAuras=function(unit) if unit=="target" then return {} end error('Restricted') end
    events.scripts.OnEvent(events,'UNIT_SPELLCAST_SUCCEEDED','player','cast',bloodfuryID)
    clock=132; events.scripts.OnUpdate(events,0.5)
    assert(count()==1,'Learned duration or denied scan failed')
    clock=137; events.scripts.OnUpdate(events,0.5)
    assert(count()==0)
    print('PASS: Bloodfury '..bloodfuryID)
    ''')
