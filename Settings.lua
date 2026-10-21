local addonName = ...
local variables = {}
local notifying = false

local function Refresh()
    if notifying or not Settings or not Settings.NotifyUpdate then return end
    notifying = true
    for _, variable in ipairs(variables) do Settings.NotifyUpdate(variable) end
    notifying = false
end

local originalCommand = SlashCmdList.LH_AURABARS
SlashCmdList.LH_AURABARS = function(message)
    originalCommand(message)
    Refresh()
end

local function Command(message) SlashCmdList.LH_AURABARS(message) end
local function Header(layout, title)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
end
local function Button(layout, label, text, callback, tooltip)
    layout:AddInitializer(CreateSettingsButtonInitializer(label, text, callback, tooltip, true))
end

local function RestoreDefaults()
    Command("lock")
    Command("synch off")
    Command("reset")
end

local function Build(category, layout)
    Header(layout, "Position and size")
    local options = {
        { key = "unlocked", label = "Unlock and preview both groups",
            get = function() return LH_AuraBarsDB and LH_AuraBarsDB.locked == false or false end,
            set = function(value) Command(value and "unlock" or "lock") end,
            tooltip = "Show three preview bars and a header for each group, even without a target. Left-drag the Player or Target bars to move that group. Drag the small circle below its right edge to change width and height independently from 50% to 200%. Disable to lock both groups and hide previews. Saved per character." },
        { key = "synch", label = "Synchronize group sizes",
            get = function() return LH_AuraBarsDB and LH_AuraBarsDB.synch == true or false end,
            set = function(value) Command(value and "synch on" or "synch off") end,
            tooltip = "Initially copy the Player group's width and height to the Target group. Resizing either group then changes both. Positions remain independent. Disable to resize groups separately. Saved per character." },
    }
    for _, option in ipairs(options) do
        local variable = "LH_AuraBars_" .. option.key
        variables[#variables + 1] = variable
        local setting = Settings.RegisterProxySetting(category, variable, "boolean", option.label, false,
            option.get, option.set)
        Settings.CreateCheckbox(category, setting, option.tooltip)
    end
    Button(layout, "Restore both groups' size and position", "Reset layout", function() Command("reset") end,
        "Restore default positions, width and height for Player and Target. Keep the current lock and synchronization settings.")

    Header(layout, "Aura diagnostics")
    Button(layout, "Inspect target aura APIs", "Print diagnostics", function() Command("debug") end,
        "Print native aura availability, target aura API results and collected target bars in chat for troubleshooting.")

    -- Native Defaults also restores layout; learned duration caches stay intact.
    EventRegistry:RegisterCallback("Settings.CategoryDefaulted", function(_, selected)
        if selected == category then RestoreDefaults() end
    end, variables)
    EventRegistry:RegisterCallback("Settings.Defaulted", RestoreDefaults, variables)
end

-- The required core queues this page until its root category is ready.
LH_Tweaks:RegisterModule(addonName, "LH AuraBars", Build)
