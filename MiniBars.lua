local ADDON_NAME = ...
local HEIGHT, INSET, GAP = 20, 3, 3
local MAX_BUFF_REMAINING = 180
local TEXTURE = "Interface\\AddOns\\MiniBars\\Media\\Smooth.tga"
local anchor, rows, active = nil, {}, {}
local initialized, preview = false, false
local resizeHandle, resizing
local visibleCount = 0
local names, spells = {}, {}
local playerClass
local function SupportsClass(class)
    return class == "PALADIN" or class == "ROGUE" or class == "WARRIOR" or class == "WARLOCK"
end
local function TracksAllTimedBuffs()
    return playerClass == "ROGUE" or playerClass == "WARRIOR" or playerClass == "WARLOCK"
end
local sealNames, estimatedSeal = {}, nil
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
local function SavePosition()
    local x, y = anchor:GetCenter()
    if not x or not y then return end
    local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    MiniBarsDB.position = {x = x * scale, y = y * scale}
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * scale, y * scale)
end
local function StopMoving()
    anchor:StopMovingOrSizing()
    SavePosition()
end
local function StandardWidth()
    local reference = MiniExpBarFrame or Minimap
    return reference and reference:GetWidth() * reference:GetEffectiveScale() / anchor:GetEffectiveScale() or 140
end
local function PositionRow(row, index, count)
    row:ClearAllPoints()
    row:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0,
        (count - index) * (HEIGHT * MiniBarsDB.heightFactor + GAP))
end
local function UpdateWidth()
    local width = StandardWidth()
    if width <= INSET * 2 then return end
    local widthFactor, heightFactor = MiniBarsDB.widthFactor, MiniBarsDB.heightFactor
    local height = HEIGHT * heightFactor
    anchor:SetSize(width * widthFactor, height)
    for index, row in ipairs(rows) do
        row:SetSize(width * widthFactor, height)
        PositionRow(row, index, visibleCount)
        for _, label in ipairs({row.name, row.time, row.measure}) do
            label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12 * heightFactor, "OUTLINE")
        end
        row.time:SetWidth(42 * heightFactor)
    end
end
local function FinishResize()
    if not resizing then return end
    resizing = nil
    SavePosition()
end
local function CreateResizeHandle()
    resizeHandle = CreateFrame("Button", "MiniBarsResizeHandle", anchor)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetFrameLevel(anchor:GetFrameLevel() + 10)
    resizeHandle:EnableMouse(true)
    local circle = resizeHandle:CreateTexture(nil, "ARTWORK")
    circle:SetAllPoints()
    circle:SetTexture("Interface\\Buttons\\UI-RadioButton")
    circle:SetTexCoord(0.25, 0.5, 0, 1)
    resizeHandle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or MiniBarsDB.locked then return end
        StopMoving()
        local x, y = GetCursorPosition()
        local scale = anchor:GetEffectiveScale()
        local left, top = anchor:GetLeft(), anchor:GetTop()
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        resizing = {x = x / scale, y = y / scale, widthFactor = MiniBarsDB.widthFactor, heightFactor = MiniBarsDB.heightFactor,
            width = StandardWidth(), height = math.max(visibleCount, 3) * HEIGHT}
    end)
    resizeHandle:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then FinishResize() end
    end)
    resizeHandle:SetScript("OnHide", FinishResize)
    resizeHandle:Hide()
end
local function UpdateResize()
    if not resizing then return end
    if not IsMouseButtonDown("LeftButton") then FinishResize(); return end
    local x, y = GetCursorPosition()
    local scale = anchor:GetEffectiveScale()
    local dx, dy = x / scale - resizing.x, resizing.y - y / scale
    -- Change each dimension independently; fixed gaps are excluded from height.
    MiniBarsDB.widthFactor = math.max(0.5, math.min(2, resizing.widthFactor + dx / resizing.width))
    MiniBarsDB.heightFactor = math.max(0.5, math.min(2, resizing.heightFactor + dy / resizing.height))
    UpdateWidth()
end
local function CreateRow(index)
    local row = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    row:SetSize(anchor:GetWidth(), HEIGHT * MiniBarsDB.heightFactor)
    row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}})
    row:SetBackdropColor(0, 0, 0, 1)
    row:SetBackdropBorderColor(0.65, 0.59, 0.45, 1)
    row:EnableMouse(not MiniBarsDB.locked)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() if not MiniBarsDB.locked then anchor:StartMoving() end end)
    row:SetScript("OnDragStop", StopMoving)
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
    row.time:SetWidth(42 * MiniBarsDB.heightFactor)
    row.time:SetJustifyH("RIGHT")
    row.name = overlay:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWordWrap(false)
    row.name:SetJustifyH("LEFT")
    row.measure = overlay:CreateFontString(nil, "OVERLAY")
    row.measure:Hide()
    for _, label in ipairs({row.name, row.time, row.measure}) do
        label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12 * MiniBarsDB.heightFactor, "OUTLINE")
        label:SetTextColor(1, 1, 1, 1)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
    end
    rows[index] = row
    return row
end
local function ReadAura(index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        return C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
    elseif UnitBuff then
        local name, _, _, _, duration, expiration, source, _, _, id = UnitBuff("player", index)
        if name then return {name = name, duration = duration, expirationTime = expiration, sourceUnit = source, spellId = id} end
    end
end
local scanPending = false
local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end
local function CollectAuras()
    -- Prefer the list API: by-index queries can be denied while auras are secret.
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        return C_UnitAuras.GetUnitAuras("player", "HELPFUL")
    end
    local result = {}
    for index = 1, 255 do
        local aura = ReadAura(index)
        if IsSecret(aura) then return nil end
        if not aura then break end
        result[#result + 1] = aura
    end
    return result
end
local function BuildSnapshot()
    local auras = CollectAuras()
    if IsSecret(auras) or type(auras) ~= "table" or
        (issecrettable and issecrettable(auras)) then return nil end
    local snapshot, now, incomplete = {}, GetTime(), false
    for index, aura in ipairs(auras) do
        -- Check before using secret fields as table keys, conditions or numbers.
        if not IsSecret(aura) and type(aura) == "table" and
            not (issecrettable and issecrettable(aura)) then
            local id, name = aura.spellId, aura.name
            local duration, expiration = aura.duration, aura.expirationTime
            if not IsSecret(id) and not IsSecret(name) and
                not IsSecret(duration) and not IsSecret(expiration) and
                (TracksAllTimedBuffs() or spells[id] or names[name]) and type(name) == "string" and
                type(duration) == "number" and duration > 0 and
                type(expiration) == "number" and expiration > now then
                -- The scan index is always plain and only serves as a sort tie-breaker.
                snapshot[#snapshot + 1] = {name = name, duration = duration, expires = expiration, key = index}
            elseif IsSecret(id) or IsSecret(name) or IsSecret(duration) or IsSecret(expiration) then
                incomplete = true
            end
        else
            incomplete = true
        end
    end
    return snapshot, incomplete
end
local function Scan()
    local ok, snapshot, incomplete = pcall(BuildSnapshot)
    scanPending = not ok or snapshot == nil or incomplete
    if ok and snapshot then
        local present = {}
        for _, buff in ipairs(snapshot) do
            present[buff.name] = true
            if sealNames[buff.name] then
                MiniBarsDB.sealDurations[buff.name] = buff.duration
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
    end
end
local function TrackSealCast(unit, spellID)
    if IsSecret(unit) or unit ~= "player" or IsSecret(spellID) or type(spellID) ~= "number" then return end
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return end
    local name = AddSpell(spellID)
    if not name or not sealNames[name] then return end
    local duration = MiniBarsDB.sealDurations[name]
    -- Baseline for a seal not yet observed; readable auras teach rank/gear changes.
    if type(duration) ~= "number" or duration <= 0 then duration = 30 end
    local now = GetTime()
    estimatedSeal = {name = name, duration = duration, expires = now + duration, started = now, key = -1000}
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
    if ok and PlainNumber(ms) and ms > 0 then return ms / 1000 end
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
                    found[name] = timer
                end
                MiniBarsDB.cooldownDurations[name] = timer.duration
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
    if not ok or not timer then
        local duration = MiniBarsDB.cooldownDurations[name] or BaseCooldown(id)
        if not PlainNumber(duration) or duration <= 0 then return end
        local now = GetTime()
        timer = {duration = duration, expires = now + duration, started = now}
    else MiniBarsDB.cooldownDurations[name] = timer.duration end
    timer.name, timer.kind, timer.key = name, "cooldown", 1000000 + id
    cooldowns[name] = timer
end
local function SetBuffName(row, name)
    -- Left padding is included so the name ends no farther than the midpoint.
    local limit = math.max(0, row:GetWidth() / 2 - 6)
    local heightFactor = MiniBarsDB.heightFactor
    if row.lastName == name and row.nameLimit == limit and row.nameHeightFactor == heightFactor then return end
    row.lastName, row.nameLimit, row.nameHeightFactor = name, limit, heightFactor
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
local function Render()
    local now, display = GetTime(), {}
    local ok, attackable = pcall(HasAttackableTarget)
    if ok and attackable then
        for _, buff in ipairs(active) do
            if buff.expires - now < MAX_BUFF_REMAINING and buff.expires > now and
                (not estimatedSeal or not sealNames[buff.name]) then
                display[#display + 1] = buff
            end
        end
    end
    if ok and attackable and estimatedSeal and estimatedSeal.expires - now < MAX_BUFF_REMAINING and
        estimatedSeal.expires > now then
        display[#display + 1] = estimatedSeal
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
    table.sort(display, function(a, b)
        if a.expires == b.expires then return a.key < b.key end
        return a.expires > b.expires
    end)
    for index, buff in ipairs(display) do
        local row = rows[index] or CreateRow(index)
        PositionRow(row, index, #display)
        local remaining = math.max(0, buff.expires - now)
        row.fill:SetMinMaxValues(0, buff.duration)
        row.fill:SetValue(math.min(remaining, buff.duration))
        if buff.kind == "cooldown" then
            row:SetBackdropColor(0.55, 0.82, 1, 0.3)
            row.fill:SetStatusBarColor(0.55, 0.82, 1, 1)
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
    for index = #display + 1, #rows do rows[index]:Hide() end
    visibleCount = #display
    if resizeHandle then
        resizeHandle:ClearAllPoints()
        if preview and visibleCount > 0 then
            resizeHandle:SetPoint("TOPRIGHT", rows[visibleCount], "BOTTOMRIGHT", 0, -4)
            resizeHandle:Show()
        else resizeHandle:Hide() end
    end
end
local function Initialize()
    MiniBarsDB = type(MiniBarsDB) == "table" and MiniBarsDB or {}
    MiniBarsDB.cooldownDurations = type(MiniBarsDB.cooldownDurations) == "table" and MiniBarsDB.cooldownDurations or {}
    MiniBarsDB.sealDurations = type(MiniBarsDB.sealDurations) == "table" and MiniBarsDB.sealDurations or {}
    if MiniBarsDB.locked == nil then MiniBarsDB.locked = true end
    -- Migrate the earlier uniform setting without changing the saved appearance.
    local previous = type(MiniBarsDB.sizeFactor) == "number" and MiniBarsDB.sizeFactor or 1
    MiniBarsDB.widthFactor = type(MiniBarsDB.widthFactor) == "number" and MiniBarsDB.widthFactor or previous
    MiniBarsDB.heightFactor = type(MiniBarsDB.heightFactor) == "number" and MiniBarsDB.heightFactor or previous
    MiniBarsDB.widthFactor = math.max(0.5, math.min(2, MiniBarsDB.widthFactor))
    MiniBarsDB.heightFactor = math.max(0.5, math.min(2, MiniBarsDB.heightFactor))
    MiniBarsDB.sizeFactor = nil
    preview = not MiniBarsDB.locked
    anchor = CreateFrame("Frame", "MiniBarsFrame", UIParent)
    anchor:SetSize(140, HEIGHT)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    local p = MiniBarsDB.position
    if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
        anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
    else anchor:SetPoint("CENTER", UIParent, "CENTER", 180, 0) end
    CreateResizeHandle()
    initialized = true
    RefreshSpells()
    UpdateWidth()
    Scan()
    ScanCooldowns()
    Render()
end
local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_COOLDOWN", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME and not initialized then Initialize() end
        return
    end
    if not initialized or (event == "UNIT_AURA" and (IsSecret(unit) or unit ~= "player")) then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        pcall(TrackSealCast, unit, spellID)
        pcall(TrackCooldownCast, unit, spellID)
        Render()
        return
    end
    if event == "SPELL_UPDATE_COOLDOWN" then ScanCooldowns(); Render(); return end
    if event == "PLAYER_TARGET_CHANGED" then Render(); return end
    if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then RefreshSpells() end
    UpdateWidth()
    Scan()
    ScanCooldowns()
    Render()
end)
local elapsedSinceWidth = 0
events:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    UpdateResize()
    elapsedSinceWidth = elapsedSinceWidth + elapsed
    if elapsedSinceWidth >= 0.5 then
        elapsedSinceWidth = 0
        UpdateWidth()
        if scanPending then Scan() end
        ScanCooldowns()
    end
    Render()
end)
SLASH_MINIBARS1 = "/minibars"
SlashCmdList.MINIBARS = function(message)
    if not initialized then return end
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "lock" or command == "unlock" then
        FinishResize()
        StopMoving()
        MiniBarsDB.locked = command == "lock"
        preview = not MiniBarsDB.locked
        for _, row in ipairs(rows) do row:EnableMouse(preview) end
        Scan()
        Render()
        print(preview and "MiniBars: Entsperrt. Testbalken mit linker Maustaste verschieben." or "MiniBars: Position fixiert.")
    elseif command == "reset" then
        FinishResize()
        anchor:StopMovingOrSizing()
        MiniBarsDB.position = nil
        MiniBarsDB.widthFactor, MiniBarsDB.heightFactor = 1, 1
        MiniBarsDB.sizeFactor = nil
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
        UpdateWidth()
        Scan()
        Render()
        print("MiniBars: Standardgröße und Standardposition wiederhergestellt.")
    else print("MiniBars: /minibars lock | /minibars unlock | /minibars reset") end
end
