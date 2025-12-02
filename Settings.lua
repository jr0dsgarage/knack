-- Knack Settings Panel
local addonName = ...
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Fallback for LSM if not present
if not LSM then
    LSM = {
        Fetch = function(self, mediaType, name)
            if mediaType == "font" then
                local fonts = {
                    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
                    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
                    ["Skurri"] = "Fonts\\SKURRI.TTF",
                    ["Morpheus"] = "Fonts\\MORPHEUS.TTF"
                }
                return fonts[name]
            elseif mediaType == "border" then
                local borders = {
                    ["Blizzard Tooltip"] = "Interface\\Tooltips\\UI-Tooltip-Border",
                    ["Blizzard Dialog"] = "Interface\\DialogFrame\\UI-DialogBox-Border"
                }
                return borders[name]
            end
            return nil
        end,
        List = function(self, mediaType)
            if mediaType == "font" then
                return {"Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus"}
            elseif mediaType == "border" then
                return {"Blizzard Tooltip", "Blizzard Dialog"}
            end
            return {}
        end
    }
end

-- Constants
local CONSTANTS = {
    PADDING_LARGE = 16,
    PADDING_SMALL = 8,
    GRAY_TEXT = {0.7, 0.7, 0.7},
    
    SLIDER = {
        WIDTH = 200,
        HEIGHT = 48,
        ICON_MIN = 10,
        ICON_MAX = 64,
        HOTKEY_MIN = 4,
        HOTKEY_MAX = 32,
        GCD_MIN = 0,
        GCD_MAX = 1,
        GCD_STEP = 0.05
    },
    
    BUTTON_HEIGHT = 22,
    DROPDOWN_WIDTH = 220,
    DROPDOWN_HEIGHT = 50,
    
    ALPHA = {
        DISABLED = 0.5,
        ENABLED = 1.0
    },
    
}

-- Global Defaults
KnackDefaultSettings = {
    enabled = true, 
    onlyWithEnemyTarget = false, 
    attachToNameplate = false,
    nameplateAnchor = "TOP",
    nameplateIconSize = 32,
    nameplateOffset = 1,
    nameplateOffsetX = 0,
    nameplateOffsetY = 0,
    nameplateShowBorder = false,
    nameplateBorderTexture = "Blizzard Tooltip",
    nameplateBorderWidth = 16,
    nameplateBorderOffset = 2,
    nameplateBorderColor = {1, 1, 1, 1},
    nameplateHotkeyFont = "Friz Quadrata TT",
    nameplateHotkeySize = 10,
    nameplateShowTooltip = false,
    nameplateHideTooltipInCombat = false,
    nameplateShowGCD = true,
    nameplateGCDOpacity = 0.7,
    showGCD = true, 
    gcdOpacity = 0.7, 
    showCastSweep = true,
    showCastGlow = true,
    showChannelSweep = true,
    showChannelGlow = true,
    
    -- Nameplate Defaults
    nameplateShowCastSweep = true,
    nameplateShowCastGlow = true,
    nameplateShowChannelSweep = true,
    nameplateShowChannelGlow = true,
    
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

-- Initialize settings with defaults
function KnackInitializeSettings()
    KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }
    for key, value in pairs(KnackDefaultSettings) do
        if KnackDB.settings[key] == nil then KnackDB.settings[key] = value end
    end
end

-- Profile Management
local currentProfile = "Main Icon"
local profiles = {
    { name = "Main Icon", prefix = "" },
    { name = "Nameplate Icon", prefix = "nameplate" }
}

local globalKeys = {
    ["enabled"] = true,
    ["onlyWithEnemyTarget"] = true,
    ["attachToNameplate"] = true
}

local function GetSettingKey(baseKey)
    if globalKeys[baseKey] then return baseKey end

    local profile = nil
    for _, p in ipairs(profiles) do
        if p.name == currentProfile then profile = p break end
    end
    
    if not profile then return baseKey end
    
    if profile.prefix == "" then
        -- Lowercase first letter for main profile (e.g. "IconSize" -> "iconSize")
        return baseKey:gsub("^%u", string.lower)
    else
        -- Prefix + Uppercase first letter (e.g. "IconSize" -> "nameplateIconSize")
        return profile.prefix .. baseKey:gsub("^%l", string.upper)
    end
end

local function GetSetting(baseKey)
    local key = GetSettingKey(baseKey)
    return KnackDB.settings[key]
end

local function SetSetting(baseKey, value)
    local key = GetSettingKey(baseKey)
    KnackDB.settings[key] = value
end

-- UI Builder Class
local SettingsBuilder = {}
SettingsBuilder.__index = SettingsBuilder

function SettingsBuilder:New(name, parent)
    local panel = CreateFrame("Frame", "KnackSettingsPanel", parent)
    panel:SetSize(600, 600) -- Ensure panel has a default size
    panel.name = name
    
    -- Removed global ScrollFrame to allow for fixed headers and scrolling content area
    local container = panel
    
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
        },
        controls = {} -- Store controls for updates
    }, SettingsBuilder)
    
    return self
end

function SettingsBuilder:BeginScrollingGroup()
    local outer = CreateFrame("Frame", nil, self.container, "BackdropTemplate")
    
    -- Anchor to the last element (tabs) and fill down to the bottom of the panel
    outer:SetPoint("TOPLEFT", self.lastAnchor, "BOTTOMLEFT", 0, 10) -- Small gap
    outer:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", -CONSTANTS.PADDING_LARGE, CONSTANTS.PADDING_LARGE)
    
    outer:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    outer:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, outer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(600, 100) -- Initial size, width matches panel roughly
    scrollFrame:SetScrollChild(content)
    
    content.elements = {}
    content.currentY = -self.spacing.groupTop
    content.outer = outer
    
    return content
end

function SettingsBuilder:EndScrollingGroup(group)
    local totalHeight = math.abs(group.currentY) + self.spacing.groupBottom
    group:SetHeight(totalHeight)
    
    self.lastAnchor = group.outer
    self.yOffset = -self.spacing.group
    return group
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
    group:SetPoint("RIGHT", self.container, "RIGHT", -CONSTANTS.PADDING_LARGE, 0)
    group.elements = {}
    group.currentY = -self.spacing.groupTop
    return group
end

function SettingsBuilder:EndGroup(group)
    local totalHeight = math.abs(group.currentY) + self.spacing.groupBottom
    group:SetHeight(totalHeight)
    
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
    local check
    if _G["SettingsCheckBoxControlTemplate"] then
        check = CreateFrame("Frame", nil, group, "SettingsCheckBoxControlTemplate")
        check:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft + (indent or 0), group.currentY)
        check:SetSize(300, 26)
        
        check.CheckBox:SetScript("OnClick", function(self)
            if callback then callback(self) end
        end)
        
        if check.CheckBox.SetLabel then
            check.CheckBox:SetLabel(label)
        else
            -- Fallback if SetLabel isn't available on the CheckBox
            local fontString = check.Label or check.CheckBox.Label or check.CheckBox.Text
            if fontString then fontString:SetText(label) end
        end
        
        check.CheckBox.tooltipText = tooltip
        
        if setting then
            check.settingKey = setting
            check.SetChecked = function(self, val) self.CheckBox:SetChecked(val) end
            check.GetChecked = function(self) return self.CheckBox:GetChecked() end
            table.insert(self.controls, check)
        end
        
        group.currentY = group.currentY - (check:GetHeight() + self.spacing.item)
        table.insert(group.elements, check)
        return check
    else
        check = CreateFrame("CheckButton", nil, group, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft + (indent or 0), group.currentY)
        check.Text:SetText(label)
        check.tooltipText = tooltip
        check:SetScript("OnClick", callback)
        check:SetFrameLevel(group:GetFrameLevel() + 1)
        
        if setting then
            check.settingKey = setting
            table.insert(self.controls, check)
        end
        
        group.currentY = group.currentY - (check:GetHeight() + self.spacing.item)
        table.insert(group.elements, check)
        return check
    end
end

function SettingsBuilder:AddSlider(group, name, min, max, value, lowText, highText, labelFormat, callback, step, xOffset, yOverride, setting)
    local slider
    local isModern = (_G["MinimalSliderWithSteppersTemplate"] ~= nil)
    
    local yPos = yOverride or (group.currentY - CONSTANTS.PADDING_LARGE)
    local xPos = self.spacing.groupLeft + CONSTANTS.PADDING_SMALL + (xOffset or 0)
    
    if isModern then
        slider = CreateFrame("Frame", name, group, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("TOPLEFT", group, "TOPLEFT", xPos, yPos)
        slider:SetWidth(CONSTANTS.SLIDER.WIDTH)
        slider:SetFrameLevel(group:GetFrameLevel() + 1)
        
        local steps = (max - min) / (step or 1)
        slider:Init(value or min, min, max, steps, { Format = function() return "" end })
        
        slider.Label = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        slider.Label:SetPoint("BOTTOM", slider, "TOP", 0, 0)
        slider.Label:SetText(labelFormat(value or min))
        
        slider:RegisterCallback("OnValueChanged", function(_, v)
            slider.Label:SetText(labelFormat(v))
            callback(v)
        end)
        
        slider.IsModernSlider = true
    else
        slider = CreateFrame("Slider", name, group, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", group, "TOPLEFT", xPos, yPos)
        slider:SetMinMaxValues(min, max)
        slider:SetValue(value or min)
        slider:SetValueStep(step or 1)
        slider:SetObeyStepOnDrag(true)
        slider:SetWidth(CONSTANTS.SLIDER.WIDTH)
        slider:SetFrameLevel(group:GetFrameLevel() + 1)
        
        _G[name .. "Low"]:SetText(lowText)
        _G[name .. "High"]:SetText(highText)
        _G[name .. "Text"]:SetText(labelFormat(value or min))
        
        slider:SetScript("OnValueChanged", function(self, v) 
            _G[name .. "Text"]:SetText(labelFormat(v)) 
            callback(v) 
        end)
    end
    
    if setting then
        slider.settingKey = setting
        slider.labelFormat = labelFormat
        slider.name = name
        table.insert(self.controls, slider)
    end
    
    if not yOverride then
        group.currentY = group.currentY - (CONSTANTS.SLIDER.HEIGHT + self.spacing.item)
    end
    table.insert(group.elements, slider)
    return slider
end

function SettingsBuilder:AddButton(group, text, width, callback)
    local template = "UIPanelButtonTemplate"
    local button = CreateFrame("Button", nil, group, template)
    button:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
    button:SetSize(width, CONSTANTS.BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    button:SetFrameLevel(group:GetFrameLevel() + 1)
    
    group.currentY = group.currentY - (button:GetHeight() + self.spacing.item)
    table.insert(group.elements, button)
    return button
end

function SettingsBuilder:AddText(group, text, color)
    local fontString = group:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fontString:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
    fontString:SetText(text)
    if color then
        fontString:SetTextColor(unpack(color))
    end
    
    group.currentY = group.currentY - (fontString:GetHeight() + self.spacing.item)
    table.insert(group.elements, fontString)
    return fontString
end

function SettingsBuilder:AddHeader(group, text)
    group.currentY = group.currentY - 8
    local fontString = group:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontString:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
    fontString:SetText(text)
    
    group.currentY = group.currentY - (fontString:GetHeight() + self.spacing.item)
    table.insert(group.elements, fontString)
    return fontString
end

function SettingsBuilder:AddTabs(group, items, currentValue, callback)
    local container = CreateFrame("Frame", nil, group)
    container:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
    container:SetSize(1, 30)
    
    local buttons = {}
    local xOffset = 0
    
    for i, item in ipairs(items) do
        -- Unique name is required for PanelTemplates to find textures via _G in some versions
        local btnName = "KnackTab" .. math.random(1000000)
        local btn = CreateFrame("Button", btnName, container, "PanelTopTabButtonTemplate")
        
        btn:SetID(i)
        btn:SetText(item)
        btn:SetPoint("LEFT", container, "LEFT", xOffset, 0)
        
        -- Auto-resize tab to fit text
        if PanelTemplates_TabResize then
            PanelTemplates_TabResize(btn, 10)
        else
            local textWidth = btn:GetFontString():GetStringWidth()
            btn:SetWidth(textWidth + 20)
        end
        
        btn:SetScript("OnClick", function(self)
            for _, b in ipairs(buttons) do 
                if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(b) else b:Enable() end
            end
            if PanelTemplates_SelectTab then PanelTemplates_SelectTab(self) else self:Disable() end
            callback(item)
        end)
        
        if item == currentValue then
            if PanelTemplates_SelectTab then PanelTemplates_SelectTab(btn) else btn:Disable() end
        else
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(btn) else btn:Enable() end
        end
        
        table.insert(buttons, btn)
        xOffset = xOffset + btn:GetWidth() - 4 -- Slight overlap for connected look
    end
    
    group.currentY = group.currentY - (30 + self.spacing.item)
    table.insert(group.elements, container)
    return container
end

function SettingsBuilder:AddDropdown(group, labelText, items, currentValue, callback, setting)
    local dropdown
    
    if _G["SettingsDropdownControlTemplate"] then
        local control = CreateFrame("Frame", nil, group, "SettingsDropdownControlTemplate")
        control:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
        control:SetSize(550, 26)
        
        if control.Label then
            control.Label:SetText(labelText)
            control.Label:SetJustifyH("LEFT")
            -- Ensure label doesn't overlap dropdown
            control.Label:SetPoint("RIGHT", control.Dropdown, "LEFT", -10, 0)
        end
        
        dropdown = control.Dropdown
        dropdown:SetWidth(CONSTANTS.DROPDOWN_WIDTH)
        
        local function SetDropdownText(text)
            dropdown:SetText(text)
        end
        
        SetDropdownText(currentValue)
        
        dropdown:SetupMenu(function(dropdown, rootDescription)
            rootDescription:SetTag("KnackDropdown")
            
            local selectedValue = currentValue
            if setting then
                selectedValue = GetSetting(setting)
            end
            
            for _, item in ipairs(items) do
                local button = rootDescription:CreateButton(item, function()
                    SetDropdownText(item)
                    callback(item)
                end)
                
                button:SetIsSelected(function() return item == selectedValue end)
                
                if LSM then
                    local fontPath = LSM:Fetch("font", item)
                    if fontPath then
                        button:AddInitializer(function(btn, description, menu)
                            local fontString = btn.fontString or btn.Text or (btn.GetFontString and btn:GetFontString())
                            if fontString then
                                local _, height, flags = fontString:GetFont()
                                fontString:SetFont(fontPath, height, flags)
                            end
                        end)
                    end
                end
            end
        end)
        
        if setting then
            control.settingKey = setting
            control.UpdateValue = function(self, val)
                SetDropdownText(val)
            end
            table.insert(self.controls, control)
        end
        
        group.currentY = group.currentY - (control:GetHeight() + self.spacing.item)
        table.insert(group.elements, control)
        return control
        
    else
        local label = group:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
        label:SetText(labelText)
        
        if _G["WowStyle1DropdownTemplate"] then
            dropdown = CreateFrame("DropdownButton", nil, group, "WowStyle1DropdownTemplate")
            dropdown:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY - 20)
            dropdown:SetWidth(CONSTANTS.DROPDOWN_WIDTH)
            
            local function SetDropdownText(text)
                dropdown:SetText(text)
            end
            
            SetDropdownText(currentValue)
            
            dropdown:SetupMenu(function(dropdown, rootDescription)
                rootDescription:SetTag("KnackDropdown")
                
                local selectedValue = currentValue
                if setting then
                    selectedValue = GetSetting(setting)
                end
                
                for _, item in ipairs(items) do
                    local button = rootDescription:CreateButton(item, function()
                        SetDropdownText(item)
                        callback(item)
                    end)
                    
                    button:SetIsSelected(function() return item == selectedValue end)
                    
                    if LSM then
                        local fontPath = LSM:Fetch("font", item)
                        if fontPath then
                            button:AddInitializer(function(btn, description, menu)
                                local fontString = btn.fontString or btn.Text or (btn.GetFontString and btn:GetFontString())
                                if fontString then
                                    local _, height, flags = fontString:GetFont()
                                    fontString:SetFont(fontPath, height, flags)
                                end
                            end)
                        end
                    end
                end
            end)
            
            if setting then
                dropdown.settingKey = setting
                dropdown.UpdateValue = function(self, val)
                    SetDropdownText(val)
                end
                table.insert(self.controls, dropdown)
            end
        else
            dropdown = CreateFrame("Frame", "KnackDropdown" .. (setting or math.random(1000)), group, "UIDropDownMenuTemplate")
            dropdown:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft - CONSTANTS.PADDING_LARGE, group.currentY - 20)
            UIDropDownMenu_SetWidth(dropdown, CONSTANTS.DROPDOWN_WIDTH)
            UIDropDownMenu_SetText(dropdown, currentValue)
            dropdown:SetFrameLevel(group:GetFrameLevel() + 1)
            
            local function InitializeDropdown(self, level)
                local selectedValue = currentValue
                if setting then
                    selectedValue = GetSetting(setting)
                end

                for _, item in ipairs(items) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = item
                    info.func = function()
                        UIDropDownMenu_SetText(dropdown, item)
                        callback(item)
                    end
                    info.checked = (item == selectedValue)
                    
                    if LSM then
                        local fontPath = LSM:Fetch("font", item)
                        if fontPath then
                            info.fontObject = CreateFont("KnackDropdownFont_" .. item:gsub("[^%w]", ""))
                            info.fontObject:SetFont(fontPath, 12, "OUTLINE")
                        end
                    end
                    
                    UIDropDownMenu_AddButton(info)
                end
            end
            
            UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
            
            if setting then
                dropdown.settingKey = setting
                dropdown.items = items
                dropdown.InitializeDropdown = InitializeDropdown
                table.insert(self.controls, dropdown)
            end
        end
        
        dropdown.label = label
        
        group.currentY = group.currentY - CONSTANTS.DROPDOWN_HEIGHT
        table.insert(group.elements, label)
        table.insert(group.elements, dropdown)
        return dropdown
    end
end

function SettingsBuilder:AddColorPicker(group, label, setting, callback, relativeTo)
    local button = CreateFrame("Button", nil, group)
    button:SetSize(20, 20)
    button:SetFrameLevel(group:GetFrameLevel() + 1)
    
    if relativeTo then
        button:SetPoint("LEFT", relativeTo, "RIGHT", 10, 2)
    else
        button:SetPoint("TOPLEFT", group, "TOPLEFT", self.spacing.groupLeft, group.currentY)
        group.currentY = group.currentY - (20 + self.spacing.item)
    end
    
    button.swatch = button:CreateTexture(nil, "OVERLAY")
    button.swatch:SetAllPoints(button)
    local r, g, b, a = unpack(GetSetting(setting) or {1, 1, 1, 1})
    button.swatch:SetColorTexture(r, g, b, a)
    
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button.border:SetColorTexture(0.5, 0.5, 0.5)
    
    button:SetScript("OnClick", function()
        local r, g, b, a = unpack(GetSetting(setting) or {1, 1, 1, 1})
        
        local function OnColorSelect()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newA = a
            if ColorPickerFrame.GetColorAlpha then
                newA = ColorPickerFrame:GetColorAlpha()
            elseif OpacitySliderFrame then
                newA = OpacitySliderFrame:GetValue()
            end
            
            SetSetting(setting, {newR, newG, newB, newA})
            button.swatch:SetColorTexture(newR, newG, newB, newA)
            callback(newR, newG, newB, newA)
        end
        
        local function OnCancel()
            SetSetting(setting, {r, g, b, a})
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
    
    if setting then
        button.settingKey = setting
        table.insert(self.controls, button)
    end
    
    table.insert(group.elements, button)
    return button
end

function SettingsBuilder:BeginCollapsibleSubGroup(parentGroup, title, reflowCallback)
    local container = CreateFrame("Frame", nil, parentGroup, "BackdropTemplate")
    local width = 580 - (self.spacing.groupLeft * 2)
    container:SetWidth(width)
    
    -- Header Button
    local header = CreateFrame("Button", nil, container)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(24)
    
    -- Twistie Texture
    header.arrow = header:CreateTexture(nil, "ARTWORK")
    header.arrow:SetPoint("LEFT", 4, 0)
    header.arrow:SetSize(14, 14)
    
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Options-List-Expand") then
        header.arrow:SetAtlas("Options-List-Expand")
        header.collapsedAtlas = "Options-List-Expand"
        header.expandedAtlas = "Options-List-Collapse"
    else
        header.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        header.collapsedTexture = "Interface\\Buttons\\UI-PlusButton-Up"
        header.expandedTexture = "Interface\\Buttons\\UI-MinusButton-Up"
    end
    
    -- Title
    header.text = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header.text:SetPoint("LEFT", header.arrow, "RIGHT", 4, 0)
    header.text:SetText(title)
    
    -- Content Frame
    local content = CreateFrame("Frame", nil, container, "BackdropTemplate")
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    content.elements = {}
    content.currentY = -self.spacing.groupTop
    
    -- State
    container.expandedStates = {}
    
    container.IsExpanded = function(self)
        return self.expandedStates[currentProfile] == true
    end
    
    container.SetExpanded = function(self, expanded)
        self.expandedStates[currentProfile] = expanded
    end
    
    content:Hide()
    
    container.RefreshState = function(self)
        local expanded = self:IsExpanded()
        if expanded then
            content:Show()
            if header.expandedAtlas then
                header.arrow:SetAtlas(header.expandedAtlas)
            else
                header.arrow:SetTexture(header.expandedTexture)
            end
        else
            content:Hide()
            if header.collapsedAtlas then
                header.arrow:SetAtlas(header.collapsedAtlas)
            else
                header.arrow:SetTexture(header.collapsedTexture)
            end
        end
        if self.UpdateHeight then self:UpdateHeight() end
    end
    
    header:SetScript("OnClick", function()
        local newState = not container:IsExpanded()
        container:SetExpanded(newState)
        container:RefreshState()
        
        -- Trigger Reflow
        if reflowCallback then reflowCallback() end
    end)
    
    container.header = header
    container.content = content
    
    -- We return content so items are added to it, but we attach container ref to it
    content.container = container
    
    return content
end

function SettingsBuilder:EndCollapsibleSubGroup(content)
    local container = content.container
    local totalHeight = math.abs(content.currentY) + self.spacing.groupBottom
    content:SetHeight(totalHeight)
    content.originalHeight = totalHeight
    
    content:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    content:SetBackdropColor(0.15, 0.15, 0.15, 0.5)
    content:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    container.UpdateHeight = function(self)
        if self:IsExpanded() then
            self:SetHeight(self.header:GetHeight() + self.content:GetHeight())
        else
            self:SetHeight(self.header:GetHeight())
        end
    end
    
    container:UpdateHeight()
    
    return container
end

local function UpdatePanelValues(builder)
    for _, control in ipairs(builder.controls) do
        local key = GetSettingKey(control.settingKey)
        local value = KnackDB.settings[key]
        
        if control.UpdateValue then -- Modern Dropdown or Custom Control
            control:UpdateValue(value)
        elseif control.SetChecked then -- Checkbox (Modern wrapper or Old)
            control:SetChecked(value)
        elseif control.IsModernSlider then
            control:SetValue(value or 0)
            if control.Label then control.Label:SetText(control.labelFormat(value or 0)) end
        elseif control:GetObjectType() == "Slider" then
            control:SetValue(value or 0)
            _G[control.name .. "Text"]:SetText(control.labelFormat(value or 0))
        elseif control:GetObjectType() == "Button" and control.swatch then -- ColorPicker
            local r, g, b, a = unpack(value or {1, 1, 1, 1})
            control.swatch:SetColorTexture(r, g, b, a)
        elseif control:GetObjectType() == "Frame" and control.InitializeDropdown then -- Old Dropdown
            UIDropDownMenu_SetText(control, value)
        end
    end
    
    -- Handle visibility of profile-specific controls
    if builder.profileSpecificControls then
        for profileName, controls in pairs(builder.profileSpecificControls) do
            for _, control in ipairs(controls) do
                if profileName == currentProfile then
                    control:Show()
                else
                    control:Hide()
                end
            end
        end
    end
end

-- Create the settings panel
local function CreateSettingsPanel()
    local builder = SettingsBuilder:New("knack", UIParent)
    builder:AddTitle("knack - Next Assisted Combat", "Configure the next assisted combat spell icon display")
    builder.profileSpecificControls = { ["Main Icon"] = {}, ["Nameplate Icon"] = {} }
    
    -- Forward declaration for reflow function
    local ReflowConfigGroup
    
    -- GROUP 1: General Settings (Global)
    local globalGroup = builder:BeginGroup()
    builder:AddHeader(globalGroup, "General Settings")
    builder:AddCheckbox(globalGroup, "Enable knack", "Show/hide the assisted combat spell icon", "enabled", function(self)
        KnackDB.settings.enabled = self:GetChecked()
        KnackUpdateVisibility()
    end)
    builder:EndGroup(globalGroup)

    -- TABS (Outside of Configuration Group)
    local tabsGroup = builder:BeginGroup()
    local availableProfiles = {}
    for _, p in ipairs(profiles) do
        if not p.condition or p.condition() then
            table.insert(availableProfiles, p.name)
        end
    end
    
    builder:AddTabs(tabsGroup, availableProfiles, currentProfile, function(val)
        currentProfile = val
        UpdatePanelValues(builder)
        if ReflowConfigGroup then ReflowConfigGroup() end
    end)
    builder:EndGroup(tabsGroup)
    tabsGroup:SetBackdrop(nil) -- Make tabs group transparent

    -- GROUP 2: Configuration Table (Main Container)
    local configGroup = builder:BeginScrollingGroup()
    configGroup.rows = {} 
    
    -- Profile Specific Options (Overlapping)
    local startY = configGroup.currentY
    
    -- Main Icon Option: Only show when an Enemy is targeted
    local cbMain = builder:AddCheckbox(configGroup, "Only show when an Enemy is targeted", "Only display the spell icon when you have an enemy targeted", "onlyWithEnemyTarget", function(self)
        KnackDB.settings.onlyWithEnemyTarget = self:GetChecked()
    end)
    table.insert(builder.profileSpecificControls["Main Icon"], cbMain)
    
    local afterMainY = configGroup.currentY
    
    -- Reset Y for Nameplate option
    configGroup.currentY = startY
    
    -- Nameplate Icon Option: Attach copy to Nameplate
    local cbNameplate = builder:AddCheckbox(configGroup, "Attach copy to Current Target's Nameplate", "Attach a copy of the icon to the current target's nameplate", "attachToNameplate", function(self)
        KnackDB.settings.attachToNameplate = self:GetChecked()
        if KnackUpdateNameplateAttachment then KnackUpdateNameplateAttachment() end
    end)
    table.insert(builder.profileSpecificControls["Nameplate Icon"], cbNameplate)
    
    -- Continue from the lower Y
    configGroup.currentY = math.min(afterMainY, configGroup.currentY)
    
    local initialRowY = configGroup.currentY

    -- Row 1: Size & Position
    local sizeContent = builder:BeginCollapsibleSubGroup(configGroup, "Size & Position", function() if ReflowConfigGroup then ReflowConfigGroup() end end)
    
    -- Generic Size Slider
    builder:AddSlider(sizeContent, "KnackGenericIconSizeSlider", CONSTANTS.SLIDER.ICON_MIN, CONSTANTS.SLIDER.ICON_MAX, 64, 
        tostring(CONSTANTS.SLIDER.ICON_MIN), tostring(CONSTANTS.SLIDER.ICON_MAX),
        function(v) return "Icon Size: " .. v end,
        function(v)
            SetSetting("IconSize", v)
            KnackUpdateIconSize()
            if currentProfile ~= "Main Icon" then KnackUpdateNameplateAttachment() end
        end, nil, 0, nil, "IconSize")

    local startY = sizeContent.currentY
    
    -- Main Profile Controls
    local mainResetBtn = builder:AddButton(sizeContent, "Reset Position", 150, function()
        KnackResetPosition()
        print("|cff00ff00[knack]|r position reset to center.")
    end)
    table.insert(builder.profileSpecificControls["Main Icon"], mainResetBtn)
    
    local mainText1 = builder:AddText(sizeContent, "Hold SHIFT and use the scrollwheel to resize the spell icon", CONSTANTS.GRAY_TEXT)
    table.insert(builder.profileSpecificControls["Main Icon"], mainText1)
    
    local mainText2 = builder:AddText(sizeContent, "Hold SHIFT and drag the spell icon to reposition it.", CONSTANTS.GRAY_TEXT)
    table.insert(builder.profileSpecificControls["Main Icon"], mainText2)
    
    local mainY = sizeContent.currentY
    
    -- Nameplate Profile Controls
    sizeContent.currentY = startY -- Reset Y for overlap
    
    local anchorPoints = {"TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"}
    local npAnchorDropdown = builder:AddDropdown(sizeContent, "Anchor Point:", anchorPoints, KnackDB.settings.nameplateAnchor or "TOP", function(val)
        KnackDB.settings.nameplateAnchor = val
        if KnackUpdateNameplateAttachment then KnackUpdateNameplateAttachment() end
    end)
    table.insert(builder.profileSpecificControls["Nameplate Icon"], npAnchorDropdown)
    table.insert(builder.profileSpecificControls["Nameplate Icon"], npAnchorDropdown.label)

    local rowY = sizeContent.currentY

    local npOffsetSlider = builder:AddSlider(sizeContent, "KnackNameplateOffsetSlider", 0, 13, KnackDB.settings.nameplateOffset or 1, 
        "0", "13",
        function(v) return "Anchor Distance: " .. v end,
        function(v) 
            KnackDB.settings.nameplateOffset = v 
            if KnackUpdateNameplateAttachment then KnackUpdateNameplateAttachment() end
        end,
        nil, 220, startY - 20)
    table.insert(builder.profileSpecificControls["Nameplate Icon"], npOffsetSlider)

    -- X Offset Slider
    local npOffsetXSlider = builder:AddSlider(sizeContent, "KnackNameplateOffsetXSlider", -100, 100, KnackDB.settings.nameplateOffsetX or 0, 
        "-100%", "100%",
        function(v) return "X Offset: " .. v .. "%" end,
        function(v) 
            KnackDB.settings.nameplateOffsetX = v 
            if KnackUpdateNameplateAttachment then KnackUpdateNameplateAttachment() end
        end,
        nil, 0, startY - 80)
    table.insert(builder.profileSpecificControls["Nameplate Icon"], npOffsetXSlider)
    
    -- Y Offset Slider
    local npOffsetYSlider = builder:AddSlider(sizeContent, "KnackNameplateOffsetYSlider", -100, 100, KnackDB.settings.nameplateOffsetY or 0, 
        "-100%", "100%",
        function(v) return "Y Offset: " .. v .. "%" end,
        function(v) 
            KnackDB.settings.nameplateOffsetY = v 
            if KnackUpdateNameplateAttachment then KnackUpdateNameplateAttachment() end
        end,
        nil, 220, startY - 80)
    table.insert(builder.profileSpecificControls["Nameplate Icon"], npOffsetYSlider)
    
    sizeContent.currentY = startY - 80 - CONSTANTS.SLIDER.HEIGHT - CONSTANTS.PADDING_SMALL

    local npY = sizeContent.currentY
    
    -- Store heights for dynamic resizing
    sizeContent.profileHeights = {
        ["Main Icon"] = math.abs(mainY) + builder.spacing.groupBottom,
        ["Nameplate Icon"] = math.abs(npY) + builder.spacing.groupBottom
    }
    
    -- Set initial height based on current profile
    sizeContent.currentY = -(sizeContent.profileHeights[currentProfile] - builder.spacing.groupBottom)
        
    local sizeContainer = builder:EndCollapsibleSubGroup(sizeContent)
    table.insert(configGroup.rows, sizeContainer)
        
    -- Row 2: Border Settings
    local borderContent = builder:BeginCollapsibleSubGroup(configGroup, "Border Settings", function() if ReflowConfigGroup then ReflowConfigGroup() end end)
    
    builder:AddCheckbox(borderContent, "Show Border", "Show a border around the icon", "ShowBorder", function(self)
        SetSetting("ShowBorder", self:GetChecked())
        if currentProfile == "Main Icon" then KnackUpdateBorder() else KnackUpdateNameplateBorder() end
    end, 0)
    
    local borderList = {}
    if LSM then
        for _, borderName in pairs(LSM:List("border")) do
            table.insert(borderList, borderName)
        end
        table.sort(borderList)
    else
        borderList = {"Blizzard Tooltip", "Blizzard Dialog"}
    end
    
    local borderDropdown = builder:AddDropdown(borderContent, "Border Texture:", borderList, "Blizzard Tooltip", function(val)
        SetSetting("BorderTexture", val)
        if currentProfile == "Main Icon" then KnackUpdateBorder() else KnackUpdateNameplateBorder() end
    end, "BorderTexture")
    
    -- Color Picker
    builder:AddColorPicker(borderContent, "Border Color", "BorderColor", function(r, g, b, a)
        if currentProfile == "Main Icon" then KnackUpdateBorder() else KnackUpdateNameplateBorder() end
    end, borderDropdown)
    
    local rowY = borderContent.currentY
    
    builder:AddSlider(borderContent, "KnackGenericBorderWidthSlider", 1, 64, 16, 
        "1", "64",
        function(v) return "Border Thickness: " .. v end,
        function(v) 
            SetSetting("BorderWidth", v) 
            if currentProfile == "Main Icon" then KnackUpdateBorder() else KnackUpdateNameplateBorder() end
        end,
        nil, 0, rowY - CONSTANTS.PADDING_LARGE, "BorderWidth")
        
    builder:AddSlider(borderContent, "KnackGenericBorderOffsetSlider", -20, 20, 2, 
        "-20", "20",
        function(v) return "Border Offset: " .. v end,
        function(v) 
            SetSetting("BorderOffset", v) 
            if currentProfile == "Main Icon" then KnackUpdateBorder() else KnackUpdateNameplateBorder() end
        end,
        nil, 220, rowY - CONSTANTS.PADDING_LARGE, "BorderOffset")
        
    borderContent.currentY = rowY - (CONSTANTS.SLIDER.HEIGHT + builder.spacing.item)
    local borderContainer = builder:EndCollapsibleSubGroup(borderContent)
    table.insert(configGroup.rows, borderContainer)
    
    -- Row 3: Hotkey Settings
    local hotkeyContent = builder:BeginCollapsibleSubGroup(configGroup, "Hotkey Settings", function() if ReflowConfigGroup then ReflowConfigGroup() end end)
    
    local fontList = {}
    if LSM then
        for _, fontName in pairs(LSM:List("font")) do
            table.insert(fontList, fontName)
        end
        table.sort(fontList)
    else
        fontList = {"Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus"}
    end
    
    builder:AddDropdown(hotkeyContent, "Hotkey Font:", fontList, "Friz Quadrata TT", function(fontName)
        SetSetting("HotkeyFont", fontName)
        KnackUpdateHotkeyFont()
    end, "HotkeyFont")
    
    builder:AddSlider(hotkeyContent, "KnackGenericHotkeySizeSlider", CONSTANTS.SLIDER.HOTKEY_MIN, CONSTANTS.SLIDER.HOTKEY_MAX, 10, 
        tostring(CONSTANTS.SLIDER.HOTKEY_MIN), tostring(CONSTANTS.SLIDER.HOTKEY_MAX),
        function(v) return "Hotkey Font Size: " .. v end,
        function(v) SetSetting("HotkeySize", v) KnackUpdateHotkeySize() end, nil, nil, nil, "HotkeySize")
    local hotkeyContainer = builder:EndCollapsibleSubGroup(hotkeyContent)
    table.insert(configGroup.rows, hotkeyContainer)
    
    -- Row 4: Tooltip Settings
    local tooltipContent = builder:BeginCollapsibleSubGroup(configGroup, "Tooltip Settings", function() if ReflowConfigGroup then ReflowConfigGroup() end end)
    
    builder:AddCheckbox(tooltipContent, "Show spell tooltip on mouseover", "Display the spell tooltip when hovering over the icon", "ShowTooltip", function(self)
        SetSetting("ShowTooltip", self:GetChecked())
        UpdatePanelValues(builder)
    end, 0)
    
    builder:AddCheckbox(tooltipContent, "Hide tooltip in combat", "Only show tooltip when out of combat", "HideTooltipInCombat", function(self)
        SetSetting("HideTooltipInCombat", self:GetChecked())
    end, 20)
    local tooltipContainer = builder:EndCollapsibleSubGroup(tooltipContent)
    table.insert(configGroup.rows, tooltipContainer)
    
    -- Row 5: Timers & Overlays
    local timersContent = builder:BeginCollapsibleSubGroup(configGroup, "Timers & Overlays", function() if ReflowConfigGroup then ReflowConfigGroup() end end)
    
    builder:AddCheckbox(timersContent, "Show Global Cooldown overlay", "Display a darkening overlay on the icon during global cooldown", "ShowGCD", function(self)
        SetSetting("ShowGCD", self:GetChecked())
        KnackUpdateGCDOverlay()
    end, 0)
    
    builder:AddSlider(timersContent, "KnackGenericGCDOpacitySlider", CONSTANTS.SLIDER.GCD_MIN, CONSTANTS.SLIDER.GCD_MAX, 0.7, 
        tostring(CONSTANTS.SLIDER.GCD_MIN) .. "%", tostring(CONSTANTS.SLIDER.GCD_MAX * 100) .. "%",
        function(v) return "GCD Overlay Opacity: " .. math.floor(v * 100) .. "%" end,
        function(v) SetSetting("GCDOpacity", v) KnackUpdateGCDOverlay() end,
        CONSTANTS.SLIDER.GCD_STEP, nil, nil, "GCDOpacity")

    builder:AddCheckbox(timersContent, "Show Cast Timer sweep", "Display a sweep animation on the icon during spell casting", "ShowCastSweep", function(self)
        SetSetting("ShowCastSweep", self:GetChecked())
        UpdatePanelValues(builder)
    end, 0)

    builder:AddCheckbox(timersContent, "Show Cast Glow", "Display the inner glow effect during cast sweep", "ShowCastGlow", function(self)
        SetSetting("ShowCastGlow", self:GetChecked())
    end, 20)
    
    builder:AddCheckbox(timersContent, "Show Channel Timer sweep", "Display a sweep animation on the icon during spell channeling", "ShowChannelSweep", function(self)
        SetSetting("ShowChannelSweep", self:GetChecked())
        UpdatePanelValues(builder)
    end, 0)

    builder:AddCheckbox(timersContent, "Show Channel Glow", "Display the inner glow effect during channel sweep", "ShowChannelGlow", function(self)
        SetSetting("ShowChannelGlow", self:GetChecked())
    end, 20)

    local timersContainer = builder:EndCollapsibleSubGroup(timersContent)
    table.insert(configGroup.rows, timersContainer)
    
    builder:EndScrollingGroup(configGroup)
    
    -- Define Reflow function
    ReflowConfigGroup = function()
        local currentY = initialRowY
        
        -- Handle Size Row special case
        if sizeContent and sizeContainer then
             local h = sizeContent.profileHeights[currentProfile] or sizeContent.originalHeight
             sizeContent:SetHeight(h)
             -- sizeContainer:UpdateHeight() -- RefreshState will handle this
        end
        
        for _, row in ipairs(configGroup.rows) do
            if row.RefreshState then row:RefreshState() end
            row:SetPoint("TOPLEFT", configGroup, "TOPLEFT", builder.spacing.groupLeft, currentY)
            currentY = currentY - row:GetHeight() - builder.spacing.item
        end
        
        local totalHeight = math.abs(currentY) + builder.spacing.groupBottom
        configGroup:SetHeight(totalHeight)
    end
    
    -- Initial Update
    UpdatePanelValues(builder)
    ReflowConfigGroup()
    
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
