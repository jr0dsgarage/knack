-- Knack Settings Panel
local addonName = ...

-- UI Layout Constants
local SETTINGS_PADDING_LARGE = 16
local SETTINGS_PADDING_SMALL = 8
local GRAY_TEXT_COLOR = 0.7

-- Slider Range Constants
local ICON_SIZE_MIN = 24
local ICON_SIZE_MAX = 128
local HOTKEY_SIZE_MIN = 8
local HOTKEY_SIZE_MAX = 34
local OPACITY_MIN = 0
local OPACITY_MAX = 1
local OPACITY_STEP = 0.05
local PERCENTAGE_MULTIPLIER = 100

-- UI Element Size Constants
local BUTTON_HEIGHT = 22
local SLIDER_WIDTH = 200
local DROPDOWN_WIDTH = 200

-- Alpha Constants
local DISABLED_ALPHA = 0.5
local ENABLED_ALPHA = 1.0

-- Spacing Constants
local SLIDER_TOTAL_HEIGHT = 48
local DROPDOWN_TOTAL_HEIGHT = 50

-- Initialize settings with defaults
function KnackInitializeSettings()
    KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }
    local defaults = {enabled = true, onlyWithEnemyTarget = false, showGCD = true, gcdOpacity = 0.7, hotkeySize = 14, hotkeyFont = "Friz Quadrata TT", iconSize = 64, showTooltip = true, hideTooltipInCombat = false}
    for key, value in pairs(defaults) do
        if KnackDB.settings[key] == nil then KnackDB.settings[key] = value end
    end
end

-- Create the settings panel
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "KnackSettingsPanel", UIParent)
    panel.name = "knack"
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", SETTINGS_PADDING_LARGE, -SETTINGS_PADDING_LARGE)
    title:SetText("knack - Next Assisted Combat")
    
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SETTINGS_PADDING_SMALL)
    subtitle:SetText("Configure the next assisted combat spell icon display")
    
    local GROUP_SPACING = 2         -- Spacing between groups
    local GROUP_TOP_PADDING = SETTINGS_PADDING_SMALL     -- Padding at top of group
    local GROUP_BOTTOM_PADDING = 6  -- Padding at bottom of group
    local GROUP_LEFT_PADDING = 10   -- Padding at left side of group
    local ITEM_SPACING = 4          -- Spacing between items within a group
    
    local lastAnchor = subtitle
    local yOffset = -SETTINGS_PADDING_LARGE
    
    -- Helper to create a group container
    local function BeginGroup()
        local group = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        group:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, yOffset)
        group.elements = {}
        group.currentY = -GROUP_TOP_PADDING
        return group
    end
    
    -- Helper to add backdrop and finalize group
    local function EndGroup(group)
        -- Calculate total height needed (current position + bottom padding)
        local totalHeight = math.abs(group.currentY) + GROUP_BOTTOM_PADDING
        group:SetSize(420, totalHeight)
        
        -- Add backdrop
        group:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        group:SetBackdropColor(0.1, 0.1, 0.1, 0.4)
        group:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        
        lastAnchor = group
        yOffset = -GROUP_SPACING
        return group
    end
    
    -- Helper to create checkbox within a group
    local function AddCheckbox(group, label, tooltip, setting, callback, indent)
        local check = CreateFrame("CheckButton", "Knack" .. setting:gsub("^%l", string.upper):gsub("%a+", function(w) return w:gsub("^%l", string.upper) end) .. "Check", panel, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", group, "TOPLEFT", GROUP_LEFT_PADDING + (indent or 0), group.currentY)
        check.Text:SetText(label)
        check.tooltipText = tooltip
        check:SetChecked(KnackDB.settings[setting])
        check:SetScript("OnClick", callback)
        group.currentY = group.currentY - (check:GetHeight() + ITEM_SPACING)
        table.insert(group.elements, check)
        return check
    end
    
    -- Helper to add slider within a group
    local function AddSlider(group, name, min, max, value, lowText, highText, labelFormat, callback)
        local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
        -- Sliders have their label above, so we need to offset down for the label space
        slider:SetPoint("TOPLEFT", group, "TOPLEFT", GROUP_LEFT_PADDING + SETTINGS_PADDING_SMALL, group.currentY - SETTINGS_PADDING_LARGE)
        slider:SetMinMaxValues(min, max)
        slider:SetValue(value)
        slider:SetValueStep(min == OPACITY_MIN and OPACITY_STEP or 1) 
        slider:SetObeyStepOnDrag(true)
        slider:SetWidth(SLIDER_WIDTH)
        _G[name .. "Low"]:SetText(lowText)
        _G[name .. "High"]:SetText(highText)
        _G[name .. "Text"]:SetText(labelFormat(value))
        slider:SetScript("OnValueChanged", function(self, v) _G[name .. "Text"]:SetText(labelFormat(v)) callback(v) end)
        -- Total height: 16 (label space) + 17 (slider) + 15 (low/high text) + ITEM_SPACING
        group.currentY = group.currentY - (SLIDER_TOTAL_HEIGHT + ITEM_SPACING)
        table.insert(group.elements, slider)
        return slider
    end
    
    -- Helper to create button within a group
    local function AddButton(group, text, width, callback)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", group, "TOPLEFT", GROUP_LEFT_PADDING, group.currentY)
        button:SetSize(width, BUTTON_HEIGHT)
        button:SetText(text)
        button:SetScript("OnClick", callback)
        group.currentY = group.currentY - (button:GetHeight() + ITEM_SPACING)
        table.insert(group.elements, button)
        return button
    end
    
    -- Helper to create text within a group
    local function AddText(group, text, r, g, b)
        local fontString = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fontString:SetPoint("TOPLEFT", group, "TOPLEFT", GROUP_LEFT_PADDING, group.currentY)
        fontString:SetText(text)
        if r and g and b then
            fontString:SetTextColor(r, g, b)
        end
        group.currentY = group.currentY - (fontString:GetHeight() + ITEM_SPACING)
        table.insert(group.elements, fontString)
        return fontString
    end
    
    -- Helper to create dropdown within a group
    local function AddDropdown(group, labelText, items, currentValue, callback)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", group, "TOPLEFT", GROUP_LEFT_PADDING, group.currentY)
        label:SetText(labelText)
        
        local dropdown = CreateFrame("Frame", "KnackFontDropdown", panel, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", group, "TOPLEFT", GROUP_LEFT_PADDING - SETTINGS_PADDING_LARGE, group.currentY - 20)
        UIDropDownMenu_SetWidth(dropdown, DROPDOWN_WIDTH)
        UIDropDownMenu_SetText(dropdown, currentValue)
        
        -- Store LSM reference for font rendering
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, item in ipairs(items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = item
                info.func = function()
                    UIDropDownMenu_SetText(dropdown, item)
                    callback(item)
                end
                info.checked = (item == currentValue)
                
                -- Render the dropdown item text in its own font
                if LSM then
                    local fontPath = LSM:Fetch("font", item)
                    if fontPath then
                        info.fontObject = CreateFont("KnackDropdownFont_" .. item:gsub("[^%w]", ""))
                        info.fontObject:SetFont(fontPath, 12, "OUTLINE")
                    end
                end
                
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        group.currentY = group.currentY - DROPDOWN_TOTAL_HEIGHT  -- Dropdowns need space for label + dropdown
        table.insert(group.elements, label)
        table.insert(group.elements, dropdown)
        return dropdown
    end
    
    -- GROUP 1: Enable & Enemy Target
    local enableGroup = BeginGroup()
    AddCheckbox(enableGroup, "Enable knack", "Show/hide the assisted combat spell icon", "enabled", function(self)
        KnackDB.settings.enabled = self:GetChecked()
        KnackUpdateVisibility()
    end)
    AddCheckbox(enableGroup, "Only show with enemy target", "Only display the spell icon when you have an enemy targeted", "onlyWithEnemyTarget", function(self)
        KnackDB.settings.onlyWithEnemyTarget = self:GetChecked()
    end)
    EndGroup(enableGroup)
    
    -- GROUP 2: Icon Size, Reset Position & Instructions
    local iconGroup = BeginGroup()
    AddText(iconGroup, "Hold SHIFT and use the scrollwheel to resize the spell icon", GRAY_TEXT_COLOR, GRAY_TEXT_COLOR, GRAY_TEXT_COLOR)
    AddSlider(iconGroup, "KnackIconSizeSlider", ICON_SIZE_MIN, ICON_SIZE_MAX, KnackDB.settings.iconSize, tostring(ICON_SIZE_MIN), tostring(ICON_SIZE_MAX),
        function(v) return "Icon Size: " .. v end,
        function(v)
            KnackDB.settings.iconSize = v
            KnackUpdateIconSize()
        end)
    AddText(iconGroup, "Hold SHIFT and drag the spell icon to reposition it.", 0.7, 0.7, 0.7)
    AddButton(iconGroup, "Reset Position", 150, function()
        KnackResetPosition()
        print("|cff00ff00[knack]|r position reset to center.")
    end)
    EndGroup(iconGroup)
    
    -- GROUP 3: Hotkey Font & Size
    local hotkeyGroup = BeginGroup()
    
    -- Get available fonts
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontList = {}
    if LSM then
        for _, fontName in pairs(LSM:List("font")) do
            table.insert(fontList, fontName)
        end
        table.sort(fontList)
    else
        -- Fallback to default WoW fonts if LSM not available
        fontList = {"Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus"}
    end
    
    AddDropdown(hotkeyGroup, "Hotkey Font:", fontList, KnackDB.settings.hotkeyFont or "Friz Quadrata TT", function(fontName)
        KnackDB.settings.hotkeyFont = fontName
        if KnackUpdateHotkeyFont then
            KnackUpdateHotkeyFont()
        end
    end)
    
    AddSlider(hotkeyGroup, "KnackHotkeySizeSlider", HOTKEY_SIZE_MIN, HOTKEY_SIZE_MAX, KnackDB.settings.hotkeySize, tostring(HOTKEY_SIZE_MIN), tostring(HOTKEY_SIZE_MAX),
        function(v) return "Hotkey Font Size: " .. v end,
        function(v) KnackDB.settings.hotkeySize = v KnackUpdateHotkeySize() end)
    EndGroup(hotkeyGroup)
    
    -- GROUP 4: Tooltip Settings
    local tooltipGroup = BeginGroup()
    local tooltipCheck = AddCheckbox(tooltipGroup, "Show spell tooltip on mouseover", "Display the spell tooltip when hovering over the icon", "showTooltip", function(self)
        KnackDB.settings.showTooltip = self:GetChecked()
        local hideCheck = _G["KnackHideTooltipInCombatCheck"]
        if hideCheck then 
            hideCheck:SetEnabled(self:GetChecked())
            if not self:GetChecked() then
                hideCheck:SetAlpha(DISABLED_ALPHA)
            else
                hideCheck:SetAlpha(ENABLED_ALPHA)
            end
        end
    end)
    local hideCheck = AddCheckbox(tooltipGroup, "Hide tooltip in combat", "Only show tooltip when out of combat", "hideTooltipInCombat", function(self)
        KnackDB.settings.hideTooltipInCombat = self:GetChecked()
    end, 20)
    hideCheck:SetEnabled(KnackDB.settings.showTooltip)
    if not KnackDB.settings.showTooltip then
        hideCheck:SetAlpha(DISABLED_ALPHA)
    end
    EndGroup(tooltipGroup)
    
    -- GROUP 5: GCD Overlay & Opacity
    local gcdGroup = BeginGroup()
    AddCheckbox(gcdGroup, "Show Global Cooldown overlay", "Display a darkening overlay on the icon during global cooldown", "showGCD", function(self)
        KnackDB.settings.showGCD = self:GetChecked()
        KnackUpdateGCDOverlay()
    end)
    AddSlider(gcdGroup, "KnackGCDOpacitySlider", OPACITY_MIN, OPACITY_MAX, KnackDB.settings.gcdOpacity, tostring(OPACITY_MIN) .. "%", tostring(OPACITY_MAX * PERCENTAGE_MULTIPLIER) .. "%",
        function(v) return "GCD Overlay Opacity: " .. math.floor(v * PERCENTAGE_MULTIPLIER) .. "%" end,
        function(v) KnackDB.settings.gcdOpacity = v KnackUpdateGCDOverlay() end)
    EndGroup(gcdGroup)
    
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
