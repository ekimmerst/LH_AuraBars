from pathlib import Path

for class_name, dot_id in [('PALADIN', 20187), ('ROGUE', 703), ('WARRIOR', 772), ('WARLOCK', 172), ('PRIEST', 589), ('HUNTER', 1978), ('SHAMAN', 8050)]:
    exec((Path(__file__).resolve().parent / '.lua-test-support.py').read_text())
    lua.globals().TEST_CLASS, lua.globals().DOT_ID = class_name, dot_id
    lua.execute('''
    UnitClass=function() return TEST_CLASS,TEST_CLASS end
    local events
    for _,f in ipairs(frames) do if f.scripts.OnEvent then events=f end end
    local function count()
        local n=0
        for _,f in ipairs(frames) do
            if f.parent==LH_AuraBarsTargetFrame and rawget(f,'fill') and rawget(f,'visible') then n=n+1 end
        end
        return n
    end
    local secret={}
    issecretvalue=function(v) return v==secret end
    local data={HELPFUL={{name='Enemy buff',spellId=999,duration=30,expirationTime=130}},
        HARMFUL={{name='Class debuff',spellId=DOT_ID,duration=20,expirationTime=120},
            {name='Other caster debuff',spellId=secret,duration=25,expirationTime=125}}}
    local denied=false
    local indexed=function(unit,index,filter)
        if unit~='target' then return nil end
        if denied then error('Restricted') end
        return data[filter][index]
    end
    C_UnitAuras={GetUnitAuras=function(unit,filter)
        if unit~='target' then return {} end
        return data[filter]
    end,GetAuraDataByIndex=indexed}
    events.scripts.OnEvent(events,'ADDON_LOADED','LH_AuraBars')
    assert(count()==3,TEST_CLASS..': target auras or secret spell ID missing')
    C_UnitAuras.GetUnitAuras=function() error('Batch unavailable') end
    events.scripts.OnEvent(events,'UNIT_AURA','target')
    assert(count()==3,TEST_CLASS..': indexed fallback failed')
    -- Keep known timers through denied queries, but never across target changes.
    UnitBuff=nil; UnitDebuff=nil; denied=true
    events.scripts.OnEvent(events,'UNIT_AURA','target')
    assert(count()==3,TEST_CLASS..': temporary restriction lost timers')
    events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
    assert(count()==0,TEST_CLASS..': old target leaked')
    denied=false
    events.scripts.OnUpdate(events,0.5)
    assert(count()==3,TEST_CLASS..': polling did not recover')
    -- Readable removal of one filter must not erase the unreadable other filter.
    data.HELPFUL={}
    C_UnitAuras.GetUnitAuras=function(unit,filter)
        if unit~='target' then return {} end
        if filter=='HELPFUL' then return {} end
        return {{name=secret,spellId=secret,duration=secret,expirationTime=secret}}
    end
    events.scripts.OnEvent(events,'UNIT_AURA','target')
    assert(count()==2,TEST_CLASS..': partial scan handling failed')
    C_UnitAuras=nil
    UnitBuff=function(unit,index)
        if unit=='target' and index==1 then return 'Legacy buff',123,nil,nil,30,130,nil,nil,nil,999 end
    end
    UnitDebuff=function(unit,index)
        if unit=='target' and index==1 then return 'Legacy dot',124,nil,nil,20,120,nil,nil,nil,DOT_ID end
    end
    events.scripts.OnEvent(events,'UNIT_AURA','target')
    assert(count()==2,TEST_CLASS..': legacy queries failed')
    C_UnitAuras={GetUnitAuras=function() error('Batch denied') end,
        GetAuraDataByIndex=function() error('Index denied') end}
    events.scripts.OnEvent(events,'UNIT_AURA','target')
    assert(count()==2,TEST_CLASS..': denied modern query prevented legacy fallback')
    local oldBuff,oldDebuff=UnitBuff,UnitDebuff
    UnitBuff=nil; UnitDebuff=nil
    UnitAura=function(unit,index,filter)
        return (filter=='HELPFUL' and oldBuff or oldDebuff)(unit,index)
    end
    events.scripts.OnEvent(events,'UNIT_AURA','target')
    assert(count()==2,TEST_CLASS..': filtered UnitAura fallback failed')
    targetAttackable=false
    events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
    assert(count()==2,TEST_CLASS..': friendly target missing')
    targetExists=false; events.scripts.OnEvent(events,'PLAYER_TARGET_CHANGED')
    assert(count()==0)
    print('PASS: '..TEST_CLASS..' target buffs/debuffs, batch/index/legacy, secret IDs, restricted scans, polling, removal and target changes')
    ''')
