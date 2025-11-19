-- Knack Settings Panel
local addonName = ...

-- Constants
local CONSTANTS = {
    PADDING_LARGE = 16,
    PADDING_SMALL = 8,
    GRAY_TEXT = {0.7, 0.7, 0.7},
    
    SLIDER = {
        WIDTH = 200,
        HEIGHT = 48,
        ICON_MIN = 24,
        ICON_MAX = 128,
        HOTKEY_MIN = 8,
        HOTKEY_MAX = 32,
        GCD_MIN = 0,
        GCD_MAX = 1,
        GCD_STEP = 0.05
    },
    
    BUTTON_HEIGHT = 22,
    DROPDOWN_WIDTH = 200,
    DROPDOWN_HEIGHT = 50,
    
    ALPHA = {
        DISABLED = 0.5,
        ENABLED = 1.0
    },
    
    OPACITY_TO_PERCENTAGE = 100
}

-- Initialize settings with defaults
function KnackInitializeSettings()
    KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }
    local defaults = {
        enabled = true, 
        onlyWithEnemyTarget = false, 
        showGCD = true, 
        gcdOpacity = 0.7, 
        hotkeySize = 14, 
        hotkeyFont = "Friz Quadrata TT", 
        iconSize = 64, 
        showTooltip = true, 
        hideTooltipInCombat = false,
        showBorder = false,
        borderTexture = "Blizzard Tooltip",
        borderWidth = 16,
        borderOffset = 2,
        borderColor = {1, 1, 1, 1}
    }
    for key, value in pairs(defaults) do
        if KnackDB.settings[key] == nil then KnackDB.settings[key] = value end
    end
end

-- UI Builder Class
local SettingsBuilder = {}
SettingsBuilder.__index = SettingsBuilder

function SettingsBuilder:New(name, parent)
    local panel = CreateFrame("Frame", "KnackSettingsPanel", parent)
    panel.name = name
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -CONSTANTS.PADDING_LARGE)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, CONSTANTS.PADDING_LARGE)
    
    local container = CreateFrame("Frame", nil, scrollFrame)
    container:SetSize(600, 1000)
    scrollFrame:SetScrollChild(container)
    
    local self = setmetatable({
        panel = panel,
        container = container,
        lastAnchor = nil,
        yOffset = -CONSTANTS.PADDING_LARGE,
        spacing = {
            group = 2,
            groupTop = CONSTANTS.PADDING_SMALL,
            groupBottom = 6,
            groupLeft = 10,
            item = 4
        }
    }, SettingsBuilder)
    
    return self
end

function SettingsBuilder:AddTitle(titleText, subtitleText)
    local title = self.container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", CONSTANTS.PADDING_LARGE, -CONSTANTS.PADDING_LARGE)
    title:SetText(titleText)
    
    local subtitle = self.container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -CONSTANTS.PADDING_SMALL)
    subtitle:SetText(subtitleText)
    
    self.lastAnchor = subtitle
    return self
end

function SettingsBuilder:BeginGroup()
    local group = CreateFrame("Frame", nil, self.container, "BackdropTemplate")
    group:SetPoint("TOPLEFT", self.lastAnchor, "BOTTOMLEFT", 0, self.yOffset)
    group.elements = {}
    group.currentY = -self.spacing.groupTop
    return group
end

function SettingsBuilder:EndGroup(group)
    local totalHeight = math.abs(group.currentY) + self.spacing.groupBottom
    group:SetSize(580, totalHeight)
    
    group:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    group:SetBackdropColor(0.1, 0.1, 0.1, 0.4)
    group:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    
    self.lastAnchor = group
    self.yOffset = -self.spacing.group
    return group
end

function SettingsBuilder:AddCheckbox(group, label, tooltip, setting, callback, indent)
    local check = CreateFrame("CheckButton", "Knack" .. setting:gsub("^%l", string.upper):gsub("%a+", function(w) return w:gsub("^%l", string.upper) end) .. "Check", self.container, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft + (indent or 0), group.currentY)
    check.Text:SetText(label)
    check.tooltipText = tooltip
    check:SetChecked(KnackDB.settings[setting])
    check:SetScript("OnClick", callback)
    
    group.currentY = group.currentY - (check:GetHeight() + self.spacing.item)
    table.insert(group.elements, check)
    return check
end

function SettingsBuilder:AddSlider(group, name, min, max, value, lowText, highText, labelFormat, callback, step, xOffset, yOverride)
    local slider = CreateFrame("Slider", name, self.container, "OptionsSliderTemplate")
    
    local yPos = yOverride or (group.currentY - CONSTANTS.PADDING_LARGE)
    local xPos = self.spacing.groupLeft + CONSTANTS.PADDING_SMALL + (xOffset or 0)
    
    slider:SetPoint("TOPLEFT", group, "TOPLEFT", xPos, yPos)
    slider:SetMinMaxValues(min, max)
    slider:SetValue(value)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(CONSTANTS.SLIDER.WIDTH)
    
    _G[name .. "Low"]:SetText(lowText)
    _G[name .. "High"]:SetText(highText)
    _G[name .. "Text"]:SetText(labelFormat(value))
    
    slider:SetScript("OnValueChanged", function(self, v) 
        _G[name .. "Text"]:SetText(labelFormat(v)) 
        callback(v) 
    end)
    
    if not yOverride then
        group.currentY = group.currentY - (CONSTANTS.SLIDER.HEIGHT + self.spacing.item)
    end
    table.insert(group.elements, slider)
    return slider
end

function SettingsBuilder:AddButton(group, text, width, callback)
    local button = CreateFrame("Button", nil, self.container, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
    button:SetSize(width, CONSTANTS.BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    
    group.currentY = group.currentY - (button:GetHeight() + self.spacing.item)
    table.insert(group.elements, button)
    return button
end

function SettingsBuilder:AddText(group, text, color)
    local fontString = self.container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fontString:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
    fontString:SetText(text)
    if color then
        fontString:SetTextColor(unpack(color))
    end
    
    group.currentY = group.currentY - (fontString:GetHeight() + self.spacing.item)
    table.insert(group.elements, fontString)
    return fontString
end

function SettingsBuilder:AddDropdown(group, labelText, items, currentValue, callback)
    local label = self.container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
    label:SetText(labelText)
    
    local dropdown = CreateFrame("Frame", "KnackFontDropdown", self.container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft - CONSTANTS.PADDING_LARGE, group.currentY - 20)
    UIDropDownMenu_SetWidth(dropdown, CONSTANTS.DROPDOWN_WIDTH)
    UIDropDownMenu_SetText(dropdown, currentValue)
    
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
    
    group.currentY = group.currentY - CONSTANTS.DROPDOWN_HEIGHT
    table.insert(group.elements, label)
    table.insert(group.elements, dropdown)
    return dropdown
end

function SettingsBuilder:AddColorPicker(group, label, setting, callback, relativeTo)
    local button = CreateFrame("Button", nil, self.container)
    button:SetSize(20, 20)
    
    if relativeTo then
        button:SetPoint("LEFT", relativeTo, "RIGHT", 10, 2)
    else
        button:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
        group.currentY = group.currentY - (20 + self.spacing.item)
    end
    
    button.swatch = button:CreateTexture(nil, "OVERLAY")
    button.swatch:SetAllPoints(button)
    local r, g, b, a = unpack(KnackDB.settings[setting] or {1, 1, 1, 1})
    button.swatch:SetColorTexture(r, g, b, a)
    
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button.border:SetColorTexture(0.5, 0.5, 0.5)
    
    button:SetScript("OnClick", function()
        local r, g, b, a = unpack(KnackDB.settings[setting] or {1, 1, 1, 1})
        
        local function OnColorSelect()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newA = a
            if ColorPickerFrame.GetColorAlpha then
                newA = ColorPickerFrame:GetColorAlpha()
            elseif OpacitySliderFrame then
                newA = OpacitySliderFrame:GetValue()
            end
            
            KnackDB.settings[setting] = {newR, newG, newB, newA}
            button.swatch:SetColorTexture(newR, newG, newB, newA)
            callback(newR, newG, newB, newA)
        end
        
        local function OnCancel()
            KnackDB.settings[setting] = {r, g, b, a}
            button.swatch:SetColorTexture(r, g, b, a)
            callback(r, g, b, a)
        end
        
        if ColorPickerFrame.SetupColorPickerAndShow then
            local info = {
                swatchFunc = OnColorSelect,
                opacityFunc = OnColorSelect,
                cancelFunc = OnCancel,
                hasOpacity = true,
                opacity = a,
                r = r,
                g = g,
                b = b,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = OnColorSelect
            ColorPickerFrame.opacityFunc = OnColorSelect
            ColorPickerFrame.cancelFunc = OnCancel
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = a
            ColorPickerFrame:Show()
        end
    end)
    
    table.insert(group.elements, button)
    return button
end

-- Create the settings panel
local function CreateSettingsPanel()
    local builder = SettingsBuilder:New("knack", UIParent)
    builder:AddTitle("knack - Next Assisted Combat", "Configure the next assisted combat spell icon display")
    
    -- GROUP 1: Enable & Enemy Target
    local enableGroup = builder:BeginGroup()
    builder:AddCheckbox(enableGroup, "Enable knack", "Show/hide the assisted combat spell icon", "enabled", function(self)
        KnackDB.settings.enabled = self:GetChecked()
        KnackUpdateVisibility()
    end)
    builder:AddCheckbox(enableGroup, "Only show with enemy target", "Only display the spell icon when you have an enemy targeted", "onlyWithEnemyTarget", function(self)
        KnackDB.settings.onlyWithEnemyTarget = self:GetChecked()
    end)
    builder:EndGroup(enableGroup)
    
    -- GROUP 2: Icon Size, Reset Position & Instructions
    local iconGroup = builder:BeginGroup()
    builder:AddText(iconGroup, "Hold SHIFT and use the scrollwheel to resize the spell icon", CONSTANTS.GRAY_TEXT)
    builder:AddSlider(iconGroup, "KnackIconSizeSlider", CONSTANTS.SLIDER.ICON_MIN, CONSTANTS.SLIDER.ICON_MAX, KnackDB.settings.iconSize, 
        tostring(CONSTANTS.SLIDER.ICON_MIN), tostring(CONSTANTS.SLIDER.ICON_MAX),
        function(v) return "Icon Size: " .. v end,
        function(v)
            KnackDB.settings.iconSize = v
            KnackUpdateIconSize()
        end)
    builder:AddText(iconGroup, "Hold SHIFT and drag the spell icon to reposition it.", CONSTANTS.GRAY_TEXT)
    builder:AddButton(iconGroup, "Reset Position", 150, function()
        KnackResetPosition()
        print("|cff00ff00[knack]|r position reset to center.")
    end)
    builder:EndGroup(iconGroup)
    
    -- GROUP 2.5: Border Settings
    local borderGroup = builder:BeginGroup()
    builder:AddCheckbox(borderGroup, "Show Border", "Show a border around the icon", "showBorder", function(self)
        KnackDB.settings.showBorder = self:GetChecked()
        KnackUpdateBorder()
    end)
    
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local borderList = {}
    if LSM then
        for _, borderName in pairs(LSM:List("border")) do
            table.insert(borderList, borderName)
        end
        table.sort(borderList)
    else
        borderList = {"Blizzard Tooltip", "Blizzard Dialog"}
    end
    
    local dropdown = builder:AddDropdown(borderGroup, "Border Texture:", borderList, KnackDB.settings.borderTexture or "Blizzard Tooltip", function(val)
        KnackDB.settings.borderTexture = val
        KnackUpdateBorder()
    end)
    
    builder:AddColorPicker(borderGroup, "Border Color", "borderColor", function(r, g, b, a)
        KnackUpdateBorder()
    end, dropdown)
    
    local rowY = borderGroup.currentY
    
    builder:AddSlider(borderGroup, "KnackBorderWidthSlider", 1, 64, KnackDB.settings.borderWidth or 16, 
        "1", "64",
        function(v) return "Border Thickness: " .. v end,
        function(v) KnackDB.settings.borderWidth = v KnackUpdateBorder() end,
        nil, 0, rowY - CONSTANTS.PADDING_LARGE)
        
    builder:AddSlider(borderGroup, "KnackBorderOffsetSlider", -20, 20, KnackDB.settings.borderOffset or 2, 
        "-20", "20",
        function(v) return "Border Offset: " .. v end,
        function(v) KnackDB.settings.borderOffset = v KnackUpdateBorder() end,
        nil, 220, rowY - CONSTANTS.PADDING_LARGE)
        
    borderGroup.currentY = rowY - (CONSTANTS.SLIDER.HEIGHT + builder.spacing.item)
        
    builder:EndGroup(borderGroup)
    
    -- GROUP 3: Hotkey Font & Size
    local hotkeyGroup = builder:BeginGroup()
    
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontList = {}
    if LSM then
        for _, fontName in pairs(LSM:List("font")) do
            table.insert(fontList, fontName)
        end
        table.sort(fontList)
    else
        fontList = {"Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus"}
    end
    
    builder:AddDropdown(hotkeyGroup, "Hotkey Font:", fontList, KnackDB.settings.hotkeyFont or "Friz Quadrata TT", function(fontName)
        KnackDB.settings.hotkeyFont = fontName
        if KnackUpdateHotkeyFont then KnackUpdateHotkeyFont() end
    end)
    
    builder:AddSlider(hotkeyGroup, "KnackHotkeySizeSlider", CONSTANTS.SLIDER.HOTKEY_MIN, CONSTANTS.SLIDER.HOTKEY_MAX, KnackDB.settings.hotkeySize, 
        tostring(CONSTANTS.SLIDER.HOTKEY_MIN), tostring(CONSTANTS.SLIDER.HOTKEY_MAX),
        function(v) return "Hotkey Font Size: " .. v end,
        function(v) KnackDB.settings.hotkeySize = v KnackUpdateHotkeySize() end)
    builder:EndGroup(hotkeyGroup)
    
    -- GROUP 4: Tooltip Settings
    local tooltipGroup = builder:BeginGroup()
    local tooltipCheck = builder:AddCheckbox(tooltipGroup, "Show spell tooltip on mouseover", "Display the spell tooltip when hovering over the icon", "showTooltip", function(self)
        KnackDB.settings.showTooltip = self:GetChecked()
        local hideCheck = _G["KnackHideTooltipInCombatCheck"]
        if hideCheck then 
            hideCheck:SetEnabled(self:GetChecked())
            hideCheck:SetAlpha(self:GetChecked() and CONSTANTS.ALPHA.ENABLED or CONSTANTS.ALPHA.DISABLED)
        end
    end)
    
    local hideCheck = builder:AddCheckbox(tooltipGroup, "Hide tooltip in combat", "Only show tooltip when out of combat", "hideTooltipInCombat", function(self)
        KnackDB.settings.hideTooltipInCombat = self:GetChecked()
    end, 20)
    
    hideCheck:SetEnabled(KnackDB.settings.showTooltip)
    hideCheck:SetAlpha(KnackDB.settings.showTooltip and CONSTANTS.ALPHA.ENABLED or CONSTANTS.ALPHA.DISABLED)
    builder:EndGroup(tooltipGroup)
    
    -- GROUP 5: GCD Overlay & Opacity
    local gcdGroup = builder:BeginGroup()
    builder:AddCheckbox(gcdGroup, "Show Global Cooldown overlay", "Display a darkening overlay on the icon during global cooldown", "showGCD", function(self)
        KnackDB.settings.showGCD = self:GetChecked()
        KnackUpdateGCDOverlay()
    end)
    
    builder:AddSlider(gcdGroup, "KnackGCDOpacitySlider", CONSTANTS.SLIDER.GCD_MIN, CONSTANTS.SLIDER.GCD_MAX, KnackDB.settings.gcdOpacity, 
        tostring(CONSTANTS.SLIDER.GCD_MIN) .. "%", tostring(CONSTANTS.SLIDER.GCD_MAX * CONSTANTS.OPACITY_TO_PERCENTAGE) .. "%",
        function(v) return "GCD Overlay Opacity: " .. math.floor(v * 100) .. "%" end,
        function(v) KnackDB.settings.gcdOpacity = v KnackUpdateGCDOverlay() end,
        CONSTANTS.SLIDER.GCD_STEP)
    builder:EndGroup(gcdGroup)
    
    return builder.panel
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
f:SetScript("OnEvent", function(self, _, addon) 
    if addon == addonName then 
        KnackInitializeSettings() 
        RegisterSettings() 
        self:UnregisterEvent("ADDON_LOADED") 
    end 
end)
