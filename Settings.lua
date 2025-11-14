-- Knack Settings Panel
local addonName = ...

-- Default settings
local defaults = {
    enabled = true,
    onlyWithEnemyTarget = false,
    showGCD = true,
    gcdOpacity = 0.7,
    hotkeySize = 14,
}

-- Initialize settings
function KnackInitializeSettings()
    KnackDB = KnackDB or {}
    KnackDB.settings = KnackDB.settings or {}
    
    -- Apply defaults for any missing settings
    for key, value in pairs(defaults) do
        if KnackDB.settings[key] == nil then
            KnackDB.settings[key] = value
        end
    end
end

-- Create the settings panel
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "KnackSettingsPanel", UIParent)
    panel.name = "Knack"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Knack - Assisted Highlight Display")
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure the assisted combat spell display")
    
    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", "KnackEnableCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    enableCheck.Text:SetText("Enable Knack")
    enableCheck.tooltipText = "Show/hide the assisted combat spell icon"
    enableCheck:SetChecked(KnackDB.settings.enabled)
    enableCheck:SetScript("OnClick", function(self)
        KnackDB.settings.enabled = self:GetChecked()
        KnackUpdateVisibility()
    end)
    
    -- Enemy target only checkbox
    local enemyTargetCheck = CreateFrame("CheckButton", "KnackEnemyTargetCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    enemyTargetCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -8)
    enemyTargetCheck.Text:SetText("Only show with enemy target")
    enemyTargetCheck.tooltipText = "Only display the spell icon when you have an enemy targeted"
    enemyTargetCheck:SetChecked(KnackDB.settings.onlyWithEnemyTarget)
    enemyTargetCheck:SetScript("OnClick", function(self)
        KnackDB.settings.onlyWithEnemyTarget = self:GetChecked()
    end)
    
    -- GCD overlay checkbox
    local gcdCheck = CreateFrame("CheckButton", "KnackGCDCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    gcdCheck:SetPoint("TOPLEFT", enemyTargetCheck, "BOTTOMLEFT", 0, -8)
    gcdCheck.Text:SetText("Show Global Cooldown overlay")
    gcdCheck.tooltipText = "Display a darkening overlay on the icon during global cooldown"
    gcdCheck:SetChecked(KnackDB.settings.showGCD)
    gcdCheck:SetScript("OnClick", function(self)
        KnackDB.settings.showGCD = self:GetChecked()
        KnackUpdateGCDOverlay()
    end)
    
    -- GCD opacity slider
    local gcdSlider = CreateFrame("Slider", "KnackGCDOpacitySlider", panel, "OptionsSliderTemplate")
    gcdSlider:SetPoint("TOPLEFT", gcdCheck, "BOTTOMLEFT", 16, -24)
    gcdSlider:SetMinMaxValues(0, 1)
    gcdSlider:SetValue(KnackDB.settings.gcdOpacity)
    gcdSlider:SetValueStep(0.05)
    gcdSlider:SetObeyStepOnDrag(true)
    gcdSlider:SetWidth(200)
    KnackGCDOpacitySliderLow:SetText("0%")
    KnackGCDOpacitySliderHigh:SetText("100%")
    KnackGCDOpacitySliderText:SetText("GCD Overlay Opacity: " .. math.floor(KnackDB.settings.gcdOpacity * 100) .. "%")
    gcdSlider:SetScript("OnValueChanged", function(self, value)
        KnackDB.settings.gcdOpacity = value
        KnackGCDOpacitySliderText:SetText("GCD Overlay Opacity: " .. math.floor(value * 100) .. "%")
        KnackUpdateGCDOverlay()
    end)
    
    -- Hotkey size slider
    local hotkeySlider = CreateFrame("Slider", "KnackHotkeySizeSlider", panel, "OptionsSliderTemplate")
    hotkeySlider:SetPoint("TOPLEFT", gcdSlider, "BOTTOMLEFT", 0, -32)
    hotkeySlider:SetMinMaxValues(14, 34)
    hotkeySlider:SetValue(KnackDB.settings.hotkeySize)
    hotkeySlider:SetValueStep(1)
    hotkeySlider:SetObeyStepOnDrag(true)
    hotkeySlider:SetWidth(200)
    KnackHotkeySizeSliderLow:SetText("14")
    KnackHotkeySizeSliderHigh:SetText("34")
    KnackHotkeySizeSliderText:SetText("Hotkey Size: " .. KnackDB.settings.hotkeySize)
    hotkeySlider:SetScript("OnValueChanged", function(self, value)
        KnackDB.settings.hotkeySize = value
        KnackHotkeySizeSliderText:SetText("Hotkey Size: " .. value)
        KnackUpdateHotkeySize()
    end)
    
    -- Position reset button
    local resetButton = CreateFrame("Button", "KnackResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", hotkeySlider, "BOTTOMLEFT", -16, -24)
    resetButton:SetSize(150, 22)
    resetButton:SetText("Reset Position")
    resetButton:SetScript("OnClick", function()
        KnackDB.point = "CENTER"
        KnackDB.relativePoint = "CENTER"
        KnackDB.xOfs = 0
        KnackDB.yOfs = 0
        KnackResetPosition()
        print("|cff00ff00Knack|r position reset to center.")
    end)
    
    -- Instructions
    local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -24)
    instructions:SetText("Hold SHIFT and drag the spell icon to reposition it.")
    instructions:SetTextColor(0.7, 0.7, 0.7)
    
    return panel
end

-- Register settings panel
local function RegisterSettings()
    local panel = CreateSettingsPanel()
    
    -- Try new Settings API first (10.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    -- Fall back to old Interface Options (pre-10.0)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Initialize on load
local settingsFrame = CreateFrame("Frame")
settingsFrame:RegisterEvent("ADDON_LOADED")
settingsFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        KnackInitializeSettings()
        RegisterSettings()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
