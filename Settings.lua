-- Knack Settings Panel
local addonName = ...

-- Initialize settings with defaults
function KnackInitializeSettings()
    KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }
    local defaults = {enabled = true, onlyWithEnemyTarget = false, showGCD = true, gcdOpacity = 0.7, hotkeySize = 14, iconSize = 64}
    for key, value in pairs(defaults) do
        if KnackDB.settings[key] == nil then KnackDB.settings[key] = value end
    end
end

-- Create the settings panel
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "KnackSettingsPanel", UIParent)
    panel.name = "knack"
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("knack - Assisted Highlight Display")
    
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure the assisted combat spell display")
    
    local function CreateCheck(name, anchor, offset, label, tooltip, setting, callback)
        local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offset)
        check.Text:SetText(label)
        check.tooltipText = tooltip
        check:SetChecked(KnackDB.settings[setting])
        check:SetScript("OnClick", callback)
        return check
    end
    
    local enableCheck = CreateCheck("KnackEnableCheck", subtitle, -16, "Enable knack", "Show/hide the assisted combat spell icon", "enabled", function(self)
        KnackDB.settings.enabled = self:GetChecked()
        KnackUpdateVisibility()
    end)
    
    local enemyTargetCheck = CreateCheck("KnackEnemyTargetCheck", enableCheck, -8, "Only show with enemy target", "Only display the spell icon when you have an enemy targeted", "onlyWithEnemyTarget", function(self)
        KnackDB.settings.onlyWithEnemyTarget = self:GetChecked()
    end)
    
    local gcdCheck = CreateCheck("KnackGCDCheck", enemyTargetCheck, -8, "Show Global Cooldown overlay", "Display a darkening overlay on the icon during global cooldown", "showGCD", function(self)
        KnackDB.settings.showGCD = self:GetChecked()
        KnackUpdateGCDOverlay()
    end)
    
    local function CreateSlider(name, anchor, offset, min, max, value, lowText, highText, labelFormat, callback)
        local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offset > -20 and 16 or 0, offset)
        slider:SetMinMaxValues(min, max)
        slider:SetValue(value)
        slider:SetValueStep(min == 0 and 0.05 or 1)
        slider:SetObeyStepOnDrag(true)
        slider:SetWidth(200)
        _G[name .. "Low"]:SetText(lowText)
        _G[name .. "High"]:SetText(highText)
        _G[name .. "Text"]:SetText(labelFormat(value))
        slider:SetScript("OnValueChanged", function(self, v) _G[name .. "Text"]:SetText(labelFormat(v)) callback(v) end)
        return slider
    end
    
    local gcdSlider = CreateSlider("KnackGCDOpacitySlider", gcdCheck, -24, 0, 1, KnackDB.settings.gcdOpacity, "0%", "100%", 
        function(v) return "GCD Overlay Opacity: " .. math.floor(v * 100) .. "%" end,
        function(v) KnackDB.settings.gcdOpacity = v KnackUpdateGCDOverlay() end)
    
    local hotkeySlider = CreateSlider("KnackHotkeySizeSlider", gcdSlider, -32, 14, 34, KnackDB.settings.hotkeySize, "14", "34",
        function(v) return "Hotkey Size: " .. v end,
        function(v) KnackDB.settings.hotkeySize = v KnackUpdateHotkeySize() end)
    
    local iconSizeSlider = CreateSlider("KnackIconSizeSlider", hotkeySlider, -32, 32, 128, KnackDB.settings.iconSize, "32", "128",
        function(v) return "Icon Size: " .. v end,
        function(v) KnackDB.settings.iconSize = v KnackUpdateIconSize() end)
    
    local resetButton = CreateFrame("Button", "KnackResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", iconSizeSlider, "BOTTOMLEFT", -16, -24)
    resetButton:SetSize(150, 22)
    resetButton:SetText("Reset Position")
    resetButton:SetScript("OnClick", function() KnackResetPosition() print("|cff00ff00[knack]|r position reset to center.") end)
    
    local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -24)
    instructions:SetText("Hold SHIFT and drag the spell icon to reposition it.")
    instructions:SetTextColor(0.7, 0.7, 0.7)
    
    return panel
end


-- Register settings panel
local settingsCategory
local function RegisterSettings()
    local panel = CreateSettingsPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(settingsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Global function to open settings
function KnackOpenSettings()
    if settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("KnackSettingsPanel")
        InterfaceOptionsFrame_OpenToCategory("KnackSettingsPanel")
    end
end

-- Initialize on load
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, addon) if addon == addonName then KnackInitializeSettings() RegisterSettings() self:UnregisterEvent("ADDON_LOADED") end end)
