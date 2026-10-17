local ADDON_NAME = ...
local HEIGHT, INSET, GAP = 20, 3, 0
local ICON_GAP = 3
local spellIcons = {}
local function SpellIcon(id)
    if not id then return nil end
    if spellIcons[id] then return spellIcons[id] end
    local query = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
    if not query then return nil end
    local ok, icon = pcall(query, id)
    if ok and not (issecretvalue and issecretvalue(icon)) and icon then
        spellIcons[id] = icon
        return icon
    end
end
local MAX_BUFF_REMAINING = 180
local TEXTURE = "Interface\\AddOns\\MiniAuraBars\\Media\\Smooth.tga"
local active = {}
local playerDebuffs = {}
local playerGroup = {rows = {}, visibleCount = 0}
local targetGroup = {rows = {}, visibleCount = 0}
local groups = {playerGroup, targetGroup}
local targetAuras = {}
local untimedTargetAuras, seenUntimedTargetAuras = {}, {}
local warlockDebuffDurations = {}
local nativeTarget, nativeTargetError
local nativePlayerAuras, nativePlayerError
local UpdateNativeTargetSize
local initialized, preview = false, false
local names, spells = {}, {}
local playerClass
local function SupportsClass(class)
    return class == "PALADIN" or class == "ROGUE" or class == "WARRIOR" or class == "WARLOCK" or class == "PRIEST" or class == "HUNTER"
end
local sealNames, estimatedSeal = {}, nil
local estimatedBloodfury
local bloodfuryIDs = {[20572] = true, [33697] = true, [33702] = true}
local cooldownSpells, cooldowns = {}, {}
local sealSeeds = {21084,20154,21082,20375,20164,20165,20166,20163}
-- Resolve names in the client's language; names cover every rank of a spell.
local seeds = {20271,19740,19742,20217,19977,20911,1022,1044,6940,1038,
    25782,25894,25898,25890,25899,25909,642,498,633,10278,
    20165,20166,21084,20375,20164,20925,20216,20050,31884,
    1310897}
local function AddSpell(id)
    if not id then return end
    local name
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id)
    elseif GetSpellInfo then name = GetSpellInfo(id) end
    if name then names[name], spells[id] = true, true end
    return name
end
local function AddCooldownSpell(id)
    local name = AddSpell(id)
    if name then cooldownSpells[id] = name end
end
local function RefreshSpells()
    local _, class = UnitClass("player")
    playerClass = class
    names, spells, sealNames = {}, {}, {}
    cooldownSpells = {}
    warlockDebuffDurations = {}
    if class == "WARLOCK" then
        -- Localized names also cover the other ranks of these Classic spells.
        for id, duration in pairs({[172] = 18, [980] = 24, [348] = 15,
            [18265] = 30, [603] = 60}) do
            local name = AddSpell(id)
            if name then warlockDebuffDurations[name] = duration end
        end
    end
    if class == "PALADIN" then
        for _, id in ipairs(seeds) do AddSpell(id) end
        for _, id in ipairs(sealSeeds) do
            local name = AddSpell(id)
            if name then sealNames[name] = true end
        end
    end
    if not SupportsClass(class) then return end
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsSpellKnown
    if known then
        for id in pairs(spells) do
            local ok, learned = pcall(known, id)
            if ok and learned == true then AddCooldownSpell(id) end
        end
    end
    -- Include General for racial abilities such as Bloodfury, and discover beta abilities.
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank.Player
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info then
                for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                    if item and item.spellID then
                        AddSpell(item.spellID)
                        if not item.isPassive and not item.isOffSpec then AddCooldownSpell(item.spellID) end
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for index = offset + 1, offset + count do
                local kind, id = GetSpellBookItemInfo(index, "spell")
                if kind == "SPELL" then AddCooldownSpell(id) end
            end
        end
    end
end
local function SavePosition(group)
    local x, y = group.anchor:GetCenter()
    if not x or not y then return end
    local scale = group.anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    group.db.position = {x = x * scale, y = y * scale}
    group.anchor:ClearAllPoints()
    group.anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * scale, y * scale)
end
local function StopMoving(group)
    group.anchor:StopMovingOrSizing()
    SavePosition(group)
end
local function StandardWidth(group)
    local reference = MiniExpBarFrame or Minimap
    return reference and reference:GetWidth() * reference:GetEffectiveScale() / group.anchor:GetEffectiveScale() or 140
end
local function PositionRow(group, row, index, count)
    row:ClearAllPoints()
    row:SetPoint("BOTTOMLEFT", group.anchor, "BOTTOMLEFT", 0,
        (count - index) * (HEIGHT * group.db.heightFactor + GAP))
end
local function UpdateWidth(group)
    local width = StandardWidth(group)
    if width <= INSET * 2 then return end
    local widthFactor, heightFactor = group.db.widthFactor, group.db.heightFactor
    local height = HEIGHT * heightFactor
    group.anchor:SetSize(width * widthFactor, height)
    for index, row in ipairs(group.rows) do
        row:SetSize(width * widthFactor, height)
        row.icon:SetSize(height, height)
        PositionRow(group, row, index, group.visibleCount)
        for _, label in ipairs({row.name, row.time, row.measure}) do
            label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        end
        row.time:SetWidth(42)
    end
    if group == targetGroup and nativeTarget then UpdateNativeTargetSize() end
    if group == playerGroup and nativePlayerAuras then UpdateNativeTargetSize(nativePlayerAuras, playerGroup) end
end
local function FinishResize(group)
    if not group.resizing then return end
    group.resizing = nil
    SavePosition(group)
end
local function SyncSize(source)
    for _, group in ipairs(groups) do
        if group ~= source then
            group.db.widthFactor, group.db.heightFactor = source.db.widthFactor, source.db.heightFactor
        end
        UpdateWidth(group)
    end
end
local function CreateResizeHandle(group)
    group.resizeHandle = CreateFrame("Button", group.handleName, group.anchor)
    group.resizeHandle:SetSize(16, 16)
    group.resizeHandle:SetFrameLevel(group.anchor:GetFrameLevel() + 10)
    group.resizeHandle:EnableMouse(true)
    local circle = group.resizeHandle:CreateTexture(nil, "ARTWORK")
    circle:SetAllPoints()
    circle:SetTexture("Interface\\Buttons\\UI-RadioButton")
    circle:SetTexCoord(0.25, 0.5, 0, 1)
    group.resizeHandle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or MiniAuraBarsDB.locked then return end
        StopMoving(group)
        local x, y = GetCursorPosition()
        local scale = group.anchor:GetEffectiveScale()
        local left, top = group.anchor:GetLeft(), group.anchor:GetTop()
        group.anchor:ClearAllPoints()
        group.anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        group.resizing = {x = x / scale, y = y / scale, widthFactor = group.db.widthFactor, heightFactor = group.db.heightFactor,
            width = StandardWidth(group), height = math.max(group.visibleCount, 3) * HEIGHT}
    end)
    group.resizeHandle:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then FinishResize(group) end
    end)
    group.resizeHandle:SetScript("OnHide", function() FinishResize(group) end)
    group.resizeHandle:Hide()
end
local function UpdateResize(group)
    if not group.resizing then return end
    if not IsMouseButtonDown("LeftButton") then FinishResize(group); return end
    local x, y = GetCursorPosition()
    local scale = group.anchor:GetEffectiveScale()
    local dx, dy = x / scale - group.resizing.x, group.resizing.y - y / scale
    -- Change each dimension independently; fixed gaps are excluded from height.
    group.db.widthFactor = math.max(0.5, math.min(2, group.resizing.widthFactor + dx / group.resizing.width))
    group.db.heightFactor = math.max(0.5, math.min(2, group.resizing.heightFactor + dy / group.resizing.height))
    if MiniAuraBarsDB.synch then SyncSize(group) else UpdateWidth(group) end
end
local function CreateRow(group, index, native)
    local row = CreateFrame("Frame", nil, group.anchor,
        native and "BackdropTemplate,DisableUntrustedLayoutScriptsTemplate" or "BackdropTemplate")
    row:SetSize(group.anchor:GetWidth(), HEIGHT * group.db.heightFactor)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("RIGHT", row, "LEFT", -ICON_GAP, 0)
    row.icon:SetSize(HEIGHT * group.db.heightFactor, HEIGHT * group.db.heightFactor)
    row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}})
    row:SetBackdropColor(0, 0, 0, 1)
    row:SetBackdropBorderColor(0.65, 0.59, 0.45, 1)
    row:EnableMouse(not MiniAuraBarsDB.locked)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() if not MiniAuraBarsDB.locked then group.anchor:StartMoving() end end)
    row:SetScript("OnDragStop", function() StopMoving(group) end)
    row.fill = CreateFrame("StatusBar", nil, row)
    row.fill:SetPoint("TOPLEFT", INSET, -INSET)
    row.fill:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    row.fill:SetStatusBarTexture(TEXTURE)
    row.fill:SetStatusBarColor(1, 0.75, 0.15, 1)
    row.fill:EnableMouse(false)
    local overlay = CreateFrame("Frame", nil, row)
    overlay:SetAllPoints(row)
    overlay:SetFrameLevel(row.fill:GetFrameLevel() + 1)
    overlay:EnableMouse(false)
    row.time = overlay:CreateFontString(nil, "OVERLAY")
    row.time:SetPoint("RIGHT", -6, 0)
    row.time:SetWidth(42)
    row.time:SetJustifyH("RIGHT")
    row.name = overlay:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWordWrap(false)
    row.name:SetJustifyH("LEFT")
    row.measure = overlay:CreateFontString(nil, "OVERLAY")
    row.measure:Hide()
    for _, label in ipairs({row.name, row.time, row.measure}) do
        label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        label:SetTextColor(1, 1, 1, 1)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
    end
    group.rows[index] = row
    return row
end
-- Like EllesmereUI's AuraKit, register display regions once and let Blizzard's
-- AuraContainer assign, sort and update the auras inside its secure execution.
-- No aura fields or secret frame geometry are read back into addon Lua.
local function CreateNativeTarget(owner, unit, filters)
    -- Buffs use readable timers: native candidate filters only support total duration.
    owner, unit, filters = owner or targetGroup, unit or "target", filters or {"HARMFUL"}
    if not C_AddOns or not C_AddOns.LoadAddOn then return end
    C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    if not AuraContainerSortMethod then
        nativeTargetError = "Blizzard_AuraContainer stellt keine native AuraContainer-API bereit."
        return
    end
    local container = CreateFrame("AuraContainer", nil, owner.anchor, "CustomAuraContainerTemplate")
    local state = {container = container, rows = {}, filters = filters, unit = unit}
    if unit == "player" then nativePlayerAuras = state else nativeTarget = state end
    container:SetPoint("BOTTOMLEFT", owner.anchor, "BOTTOMLEFT")
    container:SetSize(1, 1)
    local setAnchor = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    local setGrowth = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
    local setLine = container.SetFlowLayoutMaximumLineSize or container.SetAuraLayoutRowWidth
    setAnchor(container, "BOTTOMLEFT")
    setGrowth(container, AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    setLine(container, owner.anchor:GetWidth())
    for _, filter in ipairs(filters) do
        local harmful = filter == "HARMFUL"
        container:AddAuraGroup(filter, filter, {
            maxFrameCount = 255,
            candidateFilters = {maxDuration = math.huge},
            sortMethod = AuraContainerSortMethod.ExpirationOnly,
            sortDirection = AuraContainerSortDirection.Normal,
            layout = {elementWidth = owner.anchor:GetWidth(),
                elementHeight = HEIGHT * owner.db.heightFactor,
                elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0},
            initializeFrame = function(button)
                local width, height = owner.anchor:GetWidth(), HEIGHT * owner.db.heightFactor
                button:SetSize(width, height)
                button:EnableMouse(false)
                local group = {anchor = button, rows = {}, db = owner.db}
                local row = CreateRow(group, 1, true)
                row:SetAllPoints(button)
                row:EnableMouse(false)
                row:SetScript("OnDragStart", nil)
                row:SetScript("OnDragStop", nil)
                row.name:SetWidth(math.max(0, width / 2 - 6))
                row.fill:SetStatusBarColor(harmful and 0.9 or 1, harmful and 0.25 or 0.75, harmful and 0.2 or 0.15, 1)
                state.rows[#state.rows + 1] = row
                button:SetIcon(row.icon)
                button:SetSpellName(row.name)
                button:SetDurationBar(row.fill, {direction = Enum.StatusBarTimerDirection.RemainingTime})
                button:SetDurationText(row.time, {})
            end,
        })
    end
    container:SetUnit(unit)
    container:UpdateAllAuras()
end
UpdateNativeTargetSize = function(state, owner)
    state, owner = state or nativeTarget, owner or targetGroup
    local width, height = owner.anchor:GetWidth(), HEIGHT * owner.db.heightFactor
    if state.width == width and state.height == height then return end
    local container = state.container
    local setLine = container.SetFlowLayoutMaximumLineSize or container.SetAuraLayoutRowWidth
    setLine(container, width)
    for _, filter in ipairs(state.filters) do
        container:SetAuraGroupLayout(filter, {elementWidth = width, elementHeight = height,
            elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0})
    end
    for _, row in ipairs(state.rows) do
        row.icon:SetSize(height, height)
        row.name:SetWidth(math.max(0, width / 2 - 6))
    end
    state.width, state.height = width, height
end
local function ReadAura(index, unit, filter)
    local query
    if filter == "HARMFUL" then query = UnitDebuff
    elseif filter == "HELPFUL" then query = UnitBuff end
    query = query or UnitAura
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and aura then return aura end
        if not query then
            if ok then return nil end
            error("Aura query unavailable")
        end
    end
    if query then
        local name, icon, _, _, duration, expiration, source, _, _, id = query(unit, index, filter)
        if name then return {name = name, icon = icon, duration = duration, expirationTime = expiration, sourceUnit = source, spellId = id} end
    else
        error("Aura query unavailable")
    end
end
local scanPending = false
local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end
local function CollectAuras(unit, filter)
    local batchFailed = false
    -- Prefer the list API: by-index queries can be denied while auras are secret.
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok, result = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
        if ok and not IsSecret(result) and type(result) == "table" and
            not (issecrettable and issecrettable(result)) and #result > 0 then return result end
        -- Empty/restricted batch results need not mean the indexed API is empty.
        if ok and not IsSecret(result) and type(result) == "table" and
            not (issecrettable and issecrettable(result)) and #result == 0 then
            local fallback = {}
            for index = 1, 255 do
                local readable, aura = pcall(ReadAura, index, unit, filter)
                if not readable or IsSecret(aura) then return fallback, #fallback > 0 end
                if not aura then break end
                fallback[#fallback + 1] = aura
            end
            return fallback
        end
        batchFailed = true
    end
    local result = {}
    for index = 1, 255 do
        local ok, aura = pcall(ReadAura, index, unit, filter)
        if not ok or IsSecret(aura) then return result, true end
        if not aura then break end
        result[#result + 1] = aura
    end
    return result, batchFailed and #result == 0
end
local function BuildSnapshot(unit, filter)
    unit, filter = unit or "player", filter or "HELPFUL"
    local auras, collectionIncomplete = CollectAuras(unit, filter)
    if IsSecret(auras) or type(auras) ~= "table" or
        (issecrettable and issecrettable(auras)) then return nil end
    local snapshot, now, incomplete = {}, GetTime(), collectionIncomplete or false
    for index, aura in ipairs(auras) do
        -- Check before using secret fields as table keys, conditions or numbers.
        if not IsSecret(aura) and type(aura) == "table" and
            not (issecrettable and issecrettable(aura)) then
            local id, name = aura.spellId, aura.name
            local duration, expiration = aura.duration, aura.expirationTime
            -- Classic can expose a player's DoT but omit both timer fields.
            -- Estimate only confirmed, visible own DoTs; never invent an aura on cast.
            if unit == "target" and filter == "HARMFUL" and not IsSecret(name) and
                type(name) == "string" and warlockDebuffDurations[name] and
                not IsSecret(aura.sourceUnit) and aura.sourceUnit == "player" and
                not IsSecret(duration) and not IsSecret(expiration) and
                (duration == nil or duration == 0) and (expiration == nil or expiration == 0) then
                local key = name
                if not IsSecret(aura.auraInstanceID) and type(aura.auraInstanceID) == "number" then
                    key = name .. ":" .. aura.auraInstanceID
                end
                local timer = untimedTargetAuras[key]
                if not timer then
                    local total = warlockDebuffDurations[name]
                    if not IsSecret(id) then
                        if id == 172 then total = 12 elseif id == 6222 then total = 15 end
                    end
                    timer = {duration = total, expires = now + total}
                    untimedTargetAuras[key] = timer
                end
                seenUntimedTargetAuras[key] = true
                duration, expiration = timer.duration, timer.expires
            end
            local readableID = not IsSecret(id)
            if not IsSecret(name) and
                not IsSecret(duration) and not IsSecret(expiration) and
                type(name) == "string" and
                type(duration) == "number" and duration > 0 and
                type(expiration) == "number" and expiration > now then
                -- The scan index is always plain and only serves as a sort tie-breaker.
                local icon = not IsSecret(aura.icon) and aura.icon or nil
                snapshot[#snapshot + 1] = {name = name, duration = duration, expires = expiration, key = index,
                    icon = icon, spellID = readableID and id or nil}
            elseif IsSecret(id) or IsSecret(name) or IsSecret(duration) or IsSecret(expiration) then
                incomplete = true
            end
        else
            incomplete = true
        end
    end
    return snapshot, incomplete
end
local function ScanPlayerDebuffs()
    if nativePlayerAuras then return end
    local ok, snapshot, incomplete = pcall(BuildSnapshot, "player", "HARMFUL")
    if not ok or not snapshot then return end
    local present = {}
    for _, aura in ipairs(snapshot) do
        aura.kind, aura.key = "debuff", aura.key + 2000
        present[aura.name] = true
    end
    if incomplete then
        for _, aura in ipairs(playerDebuffs) do
            if not present[aura.name] and aura.expires > GetTime() then snapshot[#snapshot + 1] = aura end
        end
    end
    playerDebuffs = snapshot
end
local function Scan()
    ScanPlayerDebuffs()
    local ok, snapshot, incomplete = pcall(BuildSnapshot)
    scanPending = not ok or snapshot == nil or incomplete
    if ok and snapshot then
        local present = {}
        for _, buff in ipairs(snapshot) do
            present[buff.name] = true
            if estimatedBloodfury and estimatedBloodfury.name == buff.name then
                MiniAuraBarsDB.bloodfuryDuration = buff.duration
                estimatedBloodfury = nil
            end
            if sealNames[buff.name] then
                MiniAuraBarsDB.sealDurations[buff.name] = buff.duration
                if estimatedSeal and estimatedSeal.name == buff.name then estimatedSeal = nil end
            end
        end
        -- A partial secret snapshot is not proof that a known buff disappeared.
        if incomplete then
            for _, buff in ipairs(active) do
                if not present[buff.name] and buff.expires > GetTime() then
                    snapshot[#snapshot + 1] = buff
                end
            end
        elseif estimatedSeal then
            -- Allow the aura event to catch up with the instant cast event.
            if GetTime() - estimatedSeal.started >= 0.5 then estimatedSeal = nil
            else scanPending = true end
        end
        active = snapshot
        if estimatedBloodfury and not incomplete and GetTime() - estimatedBloodfury.started >= 0.5 then
            estimatedBloodfury = nil
        end
    end
end
local function TrackBloodfuryCast(unit, id)
    if IsSecret(unit) or unit ~= "player" or IsSecret(id) or not bloodfuryIDs[id] then return end
    if not SupportsClass(playerClass) then return end
    local name = AddSpell(id)
    if not name then return end
    local duration = MiniAuraBarsDB.bloodfuryDuration
    if type(duration) ~= "number" or duration <= 0 then duration = 15 end
    local now = GetTime()
    estimatedBloodfury = {name = name, spellID = id, duration = duration, expires = now + duration, started = now, key = -999}
    for index = #active, 1, -1 do
        if active[index].name == name then table.remove(active, index) end
    end
    scanPending = true
end
local function TrackSealCast(unit, spellID)
    if IsSecret(unit) or unit ~= "player" or IsSecret(spellID) or type(spellID) ~= "number" then return end
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return end
    local name = AddSpell(spellID)
    if not name or not sealNames[name] then return end
    local duration = MiniAuraBarsDB.sealDurations[name]
    -- Baseline for a seal not yet observed; readable auras teach rank/gear changes.
    if type(duration) ~= "number" or duration <= 0 then duration = 30 end
    local now = GetTime()
    estimatedSeal = {name = name, spellID = spellID, duration = duration, expires = now + duration, started = now, key = -1000}
    -- Casting another seal replaces the old one, even if aura removal is hidden.
    for index = #active, 1, -1 do
        if sealNames[active[index].name] then table.remove(active, index) end
    end
    scanPending = true
end
local function PlainNumber(value)
    return not IsSecret(value) and type(value) == "number"
end
local function BaseCooldown(id)
    if not GetSpellBaseCooldown then return nil end
    local ok, ms = pcall(GetSpellBaseCooldown, id)
    if ok and PlainNumber(ms) and ms >= 0 then return ms / 1000 end
end
local function ReadCooldown(id)
    local info
    if C_Spell and C_Spell.GetSpellCooldown then
        info = C_Spell.GetSpellCooldown(id)
    elseif GetSpellCooldown then
        local start, duration, enabled, rate = GetSpellCooldown(id)
        info = {startTime = start, duration = duration, isEnabled = enabled, modRate = rate}
    end
    if IsSecret(info) or type(info) ~= "table" or
        (issecrettable and issecrettable(info)) then return nil end
    local start, duration, enabled, rate = info.startTime, info.duration, info.isEnabled, info.modRate
    if not PlainNumber(start) or not PlainNumber(duration) or IsSecret(enabled) or IsSecret(rate) or IsSecret(info.isOnGCD) then return nil end
    if enabled == false or enabled == 0 then return false end
    if info.isOnGCD == true then return false end
    if start <= 0 or duration <= 0 then return false end
    -- Compare against the actual global cooldown, rather than showing every spell.
    local gcd
    if C_Spell and C_Spell.GetSpellCooldown then gcd = C_Spell.GetSpellCooldown(61304)
    elseif GetSpellCooldown then
        local s, d = GetSpellCooldown(61304)
        gcd = {startTime = s, duration = d}
    end
    if not IsSecret(gcd) and type(gcd) == "table" and not (issecrettable and issecrettable(gcd)) and
        PlainNumber(gcd.startTime) and PlainNumber(gcd.duration) and gcd.duration > 0 and
        math.abs(start - gcd.startTime) < 0.01 and math.abs(duration - gcd.duration) < 0.01 then return false end
    -- Covers beta APIs that omit the isOnGCD flag or the GCD spell itself.
    if info.isOnGCD == nil and duration <= 1.5 then return false end
    if not PlainNumber(rate) or rate <= 0 then rate = 1 end
    local total = duration / rate
    if start + total <= GetTime() then return false end
    return {duration = total, expires = start + total}
end
local function ScanCooldowns()
    local found, readable, unknown, available = {}, {}, {}, {}
    for id, name in pairs(cooldownSpells) do
        available[name] = true
        local ok, timer = pcall(ReadCooldown, id)
        if not ok or timer == nil then unknown[name] = true
        else
            readable[name] = true
            if timer then
                if not found[name] or timer.expires > found[name].expires then
                    timer.name, timer.kind, timer.key = name, "cooldown", 1000000 + id
                    timer.spellID = id
                    found[name] = timer
                end
                MiniAuraBarsDB.cooldownDurations[name] = timer.duration
            end
        end
    end
    local now = GetTime()
    for name, old in pairs(cooldowns) do
        if available[name] and old.expires > now and not found[name] and
            (unknown[name] or not readable[name] or (old.started and now - old.started < 0.5)) then
            found[name] = old
        end
    end
    cooldowns = found
end
local function TrackCooldownCast(unit, id)
    if IsSecret(unit) or unit ~= "player" or not PlainNumber(id) then return end
    local _, class = UnitClass("player")
    if not SupportsClass(class) then return end
    local name = cooldownSpells[id]
    if not name and spells[id] then
        name = AddSpell(id)
        if name then cooldownSpells[id] = name end
    end
    if not name then return end
    local ok, timer = pcall(ReadCooldown, id)
    -- A readable ready/GCD result is authoritative; only hidden data permits an estimate.
    if ok and timer == false then
        cooldowns[name] = nil
        return
    end
    if not ok or timer == nil then
        local base = BaseCooldown(id)
        -- An explicit zero also overrides stale durations learned by older versions.
        if base == 0 then
            MiniAuraBarsDB.cooldownDurations[name], cooldowns[name] = nil, nil
            return
        end
        local duration = MiniAuraBarsDB.cooldownDurations[name] or base
        if not PlainNumber(duration) or duration <= 0 then return end
        local now = GetTime()
        timer = {duration = duration, expires = now + duration, started = now}
    else MiniAuraBarsDB.cooldownDurations[name] = timer.duration end
    timer.name, timer.kind, timer.key = name, "cooldown", 1000000 + id
    timer.spellID = id
    cooldowns[name] = timer
end
local function SetBuffName(row, name)
    -- Left padding is included so the name ends no farther than the midpoint.
    local limit = math.max(0, row:GetWidth() / 2 - 6)
    if row.lastName == name and row.nameLimit == limit then return end
    row.lastName, row.nameLimit = name, limit
    row.name:SetWidth(limit)
    row.measure:SetText(name)
    if row.measure:GetStringWidth() <= limit then row.name:SetText(name); return end
    -- Prefix boundaries preserve multibyte characters such as German umlauts.
    local ends = {0}
    for start, character in name:gmatch("()([%z\1-\127\194-\244][\128-\191]*)") do
        ends[#ends + 1] = start + #character - 1
    end
    local low, high, best = 1, #ends, "..."
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = name:sub(1, ends[mid]) .. "..."
        row.measure:SetText(candidate)
        if row.measure:GetStringWidth() <= limit then
            best, low = candidate, mid + 1
        else high = mid - 1 end
    end
    row.name:SetText(best)
end
local function HasAttackableTarget()
    local exists = UnitExists("target")
    if IsSecret(exists) or not exists then return false end
    local attackable = UnitCanAttack("player", "target")
    if IsSecret(attackable) or not attackable then return false end
    local dead = UnitIsDeadOrGhost("target")
    return not IsSecret(dead) and not dead
end
local function ScanTarget(clear)
    if clear then untimedTargetAuras = {} end
    seenUntimedTargetAuras = {}
    local previous = clear and {} or targetAuras
    targetAuras = {}
    local ok, exists = pcall(UnitExists, "target")
    if not ok or IsSecret(exists) or not exists then return end
    for _, filter in ipairs(nativeTarget and {"HELPFUL"} or {"HELPFUL", "HARMFUL"}) do
        local readable, snapshot, incomplete = pcall(BuildSnapshot, "target", filter)
        local present = {}
        if readable and snapshot then
            for _, aura in ipairs(snapshot) do
                if filter == "HARMFUL" then aura.kind, aura.key = "debuff", aura.key + 1000 end
                present[aura.name .. "\031" .. aura.expires] = true
                targetAuras[#targetAuras + 1] = aura
            end
        end
        -- Preserve known timers only for this target and the unreadable filter.
        if not readable or not snapshot or incomplete then
            for _, aura in ipairs(previous) do
                if (filter == "HARMFUL") == (aura.kind == "debuff") and aura.expires > GetTime() and
                    not present[aura.name .. "\031" .. aura.expires] then
                    targetAuras[#targetAuras + 1] = aura
                end
            end
        end
    end
    for key in pairs(untimedTargetAuras) do
        if not seenUntimedTargetAuras[key] then untimedTargetAuras[key] = nil end
    end
end
local function RenderGroup(group, display, now)
    table.sort(display, function(a, b)
        if a.expires == b.expires then return a.key < b.key end
        return a.expires > b.expires
    end)
    for index, buff in ipairs(display) do
        local row = group.rows[index] or CreateRow(group, index)
        local icon = buff.icon or SpellIcon(buff.spellID) or "Interface\\Icons\\INV_Misc_QuestionMark"
        if row.lastIcon ~= icon then row.icon:SetTexture(icon); row.lastIcon = icon end
        PositionRow(group, row, index, #display)
        local remaining = math.max(0, buff.expires - now)
        row.fill:SetMinMaxValues(0, buff.duration)
        row.fill:SetValue(math.min(remaining, buff.duration))
        if buff.kind == "cooldown" then
            row:SetBackdropColor(0.55, 0.82, 1, 0.3)
            row.fill:SetStatusBarColor(0.55, 0.82, 1, 1)
        elseif buff.kind == "debuff" then
            row:SetBackdropColor(0, 0, 0, 1)
            row.fill:SetStatusBarColor(0.9, 0.25, 0.2, 1)
        elseif remaining <= buff.duration * 0.3 then
            row:SetBackdropColor(0, 0, 0, 1)
            row.fill:SetStatusBarColor(1, 0.4, 0, 1)
        else
            row:SetBackdropColor(0, 0, 0, 1)
            row.fill:SetStatusBarColor(1, 0.75, 0.15, 1)
        end
        SetBuffName(row, buff.name)
        if remaining >= 60 then
            local seconds = math.ceil(remaining)
            row.time:SetText(string.format("%d:%02d", math.floor(seconds / 60), seconds % 60))
        else row.time:SetText(string.format("%.1f", remaining)) end
        row:SetAlpha(remaining <= 3 and (0.35 + 0.65 * (0.5 + 0.5 * math.cos(remaining * math.pi * 4))) or 1)
        row:Show()
    end
    for index = #display + 1, #group.rows do group.rows[index]:Hide() end
    group.visibleCount = #display
    if preview and group.visibleCount > 0 then
        group.header:ClearAllPoints()
        group.header:SetPoint("BOTTOM", group.rows[1], "TOP", 0, 8)
        group.header:Show()
    else group.header:Hide() end
    if group.resizeHandle then
        group.resizeHandle:ClearAllPoints()
        if preview and group.visibleCount > 0 then
            group.resizeHandle:SetPoint("TOPRIGHT", group.rows[group.visibleCount], "BOTTOMRIGHT", 0, -4)
            group.resizeHandle:Show()
        else group.resizeHandle:Hide() end
    end
end
local function Render()
    local now, display = GetTime(), {}
    local ok, attackable = pcall(HasAttackableTarget)
    if ok and attackable then
        for _, aura in ipairs(playerDebuffs) do
            if aura.expires > now and aura.expires - now < MAX_BUFF_REMAINING then
                display[#display + 1] = aura
            end
        end
        for _, buff in ipairs(active) do
            if buff.expires - now <= MAX_BUFF_REMAINING and buff.expires > now and
                (not estimatedBloodfury or estimatedBloodfury.name ~= buff.name) and
                (not estimatedSeal or not sealNames[buff.name]) then
                display[#display + 1] = buff
            end
        end
    end
    if ok and attackable and estimatedSeal and estimatedSeal.expires - now <= MAX_BUFF_REMAINING and
        estimatedSeal.expires > now then
        display[#display + 1] = estimatedSeal
    end
    if ok and attackable and estimatedBloodfury and estimatedBloodfury.expires > now and
        estimatedBloodfury.expires - now <= MAX_BUFF_REMAINING then
        display[#display + 1] = estimatedBloodfury
    end
    if ok and attackable then
        for _, timer in pairs(cooldowns) do
            if timer.expires > now then display[#display + 1] = timer end
        end
    end
    if preview then
        for index, duration in ipairs({8, 15, 30}) do
            display[#display + 1] = {name = "Test " .. index, duration = duration, expires = now + duration, key = -index, kind = index == 3 and "cooldown" or nil}
        end
    end
    RenderGroup(playerGroup, display, now)
    -- Reassert the affected unit after visibility changes as well as while visible.
    -- Keep the binding independent of the current target and aura caster.
    if nativePlayerAuras then
        local state = nativePlayerAuras
        local offset = #display * HEIGHT * playerGroup.db.heightFactor
        if state.offset ~= offset then
            state.container:ClearAllPoints()
            state.container:SetPoint("BOTTOMLEFT", playerGroup.anchor, "BOTTOMLEFT", 0, offset)
            state.offset = offset
        end
        local shown = not preview and ok and attackable or false
        if state.shown ~= shown then
            state.container:SetShown(shown)
            state.shown = shown
            state.container:SetUnit(state.unit)
            if shown then state.container:UpdateAllAuras() end
        else state.container:SetUnit(state.unit) end
    end
    local targetDisplay = {}
    for _, aura in ipairs(targetAuras) do
        if aura.expires > now and aura.expires - now <= MAX_BUFF_REMAINING then
            targetDisplay[#targetDisplay + 1] = aura
        end
    end
    if preview then
        for index, duration in ipairs({8, 15, 30}) do
            targetDisplay[#targetDisplay + 1] = {name = "Target Test " .. index,
                duration = duration, expires = now + duration, key = -index,
                kind = index == 2 and "debuff" or nil}
        end
    end
    RenderGroup(targetGroup, targetDisplay, now)
    if nativeTarget then
        local offset = #targetDisplay * HEIGHT * targetGroup.db.heightFactor
        if nativeTarget.offset ~= offset then
            nativeTarget.container:ClearAllPoints()
            nativeTarget.container:SetPoint("BOTTOMLEFT", targetGroup.anchor, "BOTTOMLEFT", 0, offset)
            nativeTarget.offset = offset
        end
        local existsOK, exists = pcall(UnitExists, "target")
        local shown = not preview and existsOK and not IsSecret(exists) and exists == true
        if nativeTarget.shown ~= shown then
            nativeTarget.shown = shown
            nativeTarget.container:SetShown(shown)
            nativeTarget.container:SetUnit(nativeTarget.unit)
            if shown then nativeTarget.container:UpdateAllAuras() end
        else nativeTarget.container:SetUnit(nativeTarget.unit) end
    end
end
local function Initialize()
    MiniAuraBarsDB = type(MiniAuraBarsDB) == "table" and MiniAuraBarsDB or {}
    MiniAuraBarsDB.cooldownDurations = type(MiniAuraBarsDB.cooldownDurations) == "table" and MiniAuraBarsDB.cooldownDurations or {}
    MiniAuraBarsDB.sealDurations = type(MiniAuraBarsDB.sealDurations) == "table" and MiniAuraBarsDB.sealDurations or {}
    if MiniAuraBarsDB.locked == nil then MiniAuraBarsDB.locked = true end
    MiniAuraBarsDB.synch = MiniAuraBarsDB.synch == true
    -- Migrate the earlier uniform setting without changing the saved appearance.
    local previous = type(MiniAuraBarsDB.sizeFactor) == "number" and MiniAuraBarsDB.sizeFactor or 1
    MiniAuraBarsDB.widthFactor = type(MiniAuraBarsDB.widthFactor) == "number" and MiniAuraBarsDB.widthFactor or previous
    MiniAuraBarsDB.heightFactor = type(MiniAuraBarsDB.heightFactor) == "number" and MiniAuraBarsDB.heightFactor or previous
    MiniAuraBarsDB.widthFactor = math.max(0.5, math.min(2, MiniAuraBarsDB.widthFactor))
    MiniAuraBarsDB.heightFactor = math.max(0.5, math.min(2, MiniAuraBarsDB.heightFactor))
    MiniAuraBarsDB.sizeFactor = nil
    preview = not MiniAuraBarsDB.locked
    MiniAuraBarsDB.target = type(MiniAuraBarsDB.target) == "table" and MiniAuraBarsDB.target or {}
    playerGroup.db, targetGroup.db = MiniAuraBarsDB, MiniAuraBarsDB.target
    playerGroup.frameName, playerGroup.handleName = "MiniAuraBarsFrame", "MiniAuraBarsResizeHandle"
    targetGroup.frameName, targetGroup.handleName = "MiniAuraBarsTargetFrame", "MiniAuraBarsTargetResizeHandle"
    for index, group in ipairs(groups) do
        local db = group.db
        for _, dimension in ipairs({"widthFactor", "heightFactor"}) do
            db[dimension] = math.max(0.5, math.min(2, type(db[dimension]) == "number" and db[dimension] or 1))
        end
        group.anchor = CreateFrame("Frame", group.frameName, UIParent)
        group.anchor:SetSize(140, HEIGHT)
        group.anchor:SetFrameStrata("MEDIUM")
        group.anchor:SetMovable(true)
        group.anchor:SetClampedToScreen(true)
        group.header = group.anchor:CreateFontString(nil, "OVERLAY")
        group.header:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        group.header:SetText(index == 1 and "Player" or "Target")
        group.header:SetTextColor(1, 1, 1, 1)
        group.header:Hide()
        local p = db.position
        if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
            group.anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
        else group.anchor:SetPoint("CENTER", UIParent, "CENTER", index == 1 and 180 or -180, 0) end
        CreateResizeHandle(group)
    end
    initialized = true
    if MiniAuraBarsDB.synch then SyncSize(playerGroup) end
    RefreshSpells()
    for _, group in ipairs(groups) do UpdateWidth(group) end
    local nativeOK, nativeError = pcall(CreateNativeTarget)
    if not nativeOK then
        if nativeTarget then nativeTarget.container:Hide() end
        nativeTarget = nil
        nativeTargetError = nativeError
        print("MiniAuraBars: Could not initialize native target auras. Use /miniaurabars debug for details.")
    end
    local playerFilters = {"HARMFUL"}
    local playerOK, playerError = pcall(CreateNativeTarget, playerGroup, "player", playerFilters)
    if not playerOK then
        if nativePlayerAuras then nativePlayerAuras.container:Hide() end
        nativePlayerAuras = nil
        nativePlayerError = playerError
    end
    Scan()
    ScanCooldowns()
    ScanTarget()
    Render()
end
local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_COOLDOWN", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME and not initialized then Initialize() end
        return
    end
    if not initialized or (event == "UNIT_AURA" and (IsSecret(unit) or (unit ~= "player" and unit ~= "target"))) then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        pcall(TrackBloodfuryCast, unit, spellID)
        pcall(TrackSealCast, unit, spellID)
        pcall(TrackCooldownCast, unit, spellID)
        Render()
        return
    end
    if event == "SPELL_UPDATE_COOLDOWN" then ScanCooldowns(); Render(); return end
    if event == "PLAYER_TARGET_CHANGED" then
        ScanTarget(true)
        if nativeTarget then
            nativeTarget.container:SetUnit(nativeTarget.unit)
            nativeTarget.container:UpdateAllAuras()
        end
        Render()
        return
    end
    if event == "UNIT_AURA" and unit == "target" then ScanTarget(); Render(); return end
    if event == "UNIT_AURA" and unit == "player" and nativePlayerAuras then
        nativePlayerAuras.container:SetUnit("player")
        nativePlayerAuras.container:UpdateAllAuras()
    end
    if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then RefreshSpells() end
    for _, group in ipairs(groups) do UpdateWidth(group) end
    Scan()
    ScanCooldowns()
    ScanTarget()
    Render()
end)
local elapsedSinceWidth = 0
events:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    for _, group in ipairs(groups) do UpdateResize(group) end
    elapsedSinceWidth = elapsedSinceWidth + elapsed
    if elapsedSinceWidth >= 0.5 then
        elapsedSinceWidth = 0
        for _, group in ipairs(groups) do UpdateWidth(group) end
        if scanPending then Scan() else ScanPlayerDebuffs() end
        ScanCooldowns()
        ScanTarget()
    end
    Render()
end)
SLASH_MINIAURABARS1 = "/miniaurabars"
local function DebugTarget()
    local function describe(value)
        if IsSecret(value) then return "hidden" end
        if type(value) == "table" then
            if issecrettable and issecrettable(value) then return "hidden table" end
            return "table (" .. #value .. ")"
        end
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
            return tostring(value)
        end
        return type(value)
    end
    local function report(label, query, ...)
        if not query then print("MiniAuraBars: " .. label .. " unavailable"); return end
        local ok, value, extra = pcall(query, ...)
        print("MiniAuraBars: " .. label .. (ok and " = " or " ERROR: ") .. describe(value))
        if ok and not IsSecret(value) and type(value) == "table" and
            not (issecrettable and issecrettable(value)) then
            local sample = value
            if not IsSecret(value[1]) and type(value[1]) == "table" and
                not (issecrettable and issecrettable(value[1])) then sample = value[1] end
            if IsSecret(sample.name) or sample.name ~= nil then
                for _, field in ipairs({"name", "spellId", "sourceUnit", "duration", "expirationTime", "auraInstanceID"}) do
                    print("MiniAuraBars: " .. field .. " = " .. describe(sample[field]))
                end
            elseif type(extra) == "boolean" then
                print("MiniAuraBars: incomplete = " .. tostring(extra))
            end
        end
    end
    print("MiniAuraBars: Target diagnostics 1.5.4")
    print("MiniAuraBars: Native target auras = " .. (nativeTarget and "active" or "inactive"))
    print("MiniAuraBars: Native player auras = " .. (nativePlayerAuras and "active" or "inactive"))
    if nativePlayerError then print("MiniAuraBars: Player aura initialization: " .. describe(nativePlayerError)) end
    if nativeTargetError then print("MiniAuraBars: Native initialization: " .. describe(nativeTargetError)) end
    report("Target exists", UnitExists, "target")
    report("Batch HARMFUL", C_UnitAuras and C_UnitAuras.GetUnitAuras, "target", "HARMFUL")
    report("Index HARMFUL", C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, "target", 1, "HARMFUL")
    report("UnitDebuff", UnitDebuff, "target", 1)
    report("UnitAura", UnitAura, "target", 1, "HARMFUL")
    report("Collected HARMFUL", CollectAuras, "target", "HARMFUL")
    report("Usable HARMFUL", BuildSnapshot, "target", "HARMFUL")
    print("MiniAuraBars: Target bars = " .. targetGroup.visibleCount)
end
SlashCmdList.MINIAURABARS = function(message)
    if not initialized then return end
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    local synch = command:match("^synch%s+(%a+)$")
    if command == "debug" then
        DebugTarget()
    elseif synch == "on" or synch == "off" then
        for _, group in ipairs(groups) do FinishResize(group) end
        MiniAuraBarsDB.synch = synch == "on"
        if MiniAuraBarsDB.synch then SyncSize(playerGroup) end
        Render()
        print("MiniAuraBars: synch " .. synch)
    elseif command == "lock" or command == "unlock" then
        for _, group in ipairs(groups) do FinishResize(group); StopMoving(group) end
        MiniAuraBarsDB.locked = command == "lock"
        preview = not MiniAuraBarsDB.locked
        for _, group in ipairs(groups) do
            for _, row in ipairs(group.rows) do row:EnableMouse(preview) end
        end
        Scan()
        Render()
        print(preview and "MiniAuraBars: Unlocked. Left-drag the test bars to move them." or "MiniAuraBars: Position locked.")
    elseif command == "reset" then
        for index, group in ipairs(groups) do
            FinishResize(group)
            group.anchor:StopMovingOrSizing()
            group.db.position = nil
            group.db.widthFactor, group.db.heightFactor = 1, 1
            group.db.sizeFactor = nil
            group.anchor:ClearAllPoints()
            group.anchor:SetPoint("CENTER", UIParent, "CENTER", index == 1 and 180 or -180, 0)
            UpdateWidth(group)
        end
        Scan()
        Render()
        print("MiniAuraBars: Default size and position restored.")
    else print("MiniAuraBars: /miniaurabars lock | /miniaurabars unlock | /miniaurabars reset | /miniaurabars synch on|off") end
end
