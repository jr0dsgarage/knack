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
    FONT = {
        DEFAULT_PATH = "Fonts\\FRIZQT__.TTF",
        OFFSET = 0,
        COLOR_IN_RANGE = {r = 1, g = 1, b = 1, a = 1},
        COLOR_OUT_OF_RANGE = {r = 0.8, g = 0.1, b = 0.1, a = 1}
    },
    ICON = {
        MIN_SIZE = 10,
        MAX_SIZE = 128,
        PADDING = 4,
        STEP = 4,
        TEXTURE_INSET = 0.07,
        TEXTURE_OUTER = 0.93,
        BG_OPACITY = 0.5
    },
    GCD = {
        SPELL_ID = 61304,
        SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 1}
    },
    CAST = {
        SWIPE_COLOR = {r = 0, g = 1, b = 0, a = 0.5}
    },
    CHANNEL = {
        SWIPE_COLOR = {r = 0, g = 1, b = 0, a = 0.5}
    },
    SCAN_INTERVAL = 0.1,
    MOVE_CURSOR = "Interface\\CURSOR\\UI-Cursor-Move",
    ACTION_BAR = {
        BUTTONS_PER_BAR = 12,
        MAX_BINDINGS = 3,
        SLOTS = {
            {start = 169, binding = "MULTIACTIONBAR7BUTTON"}, -- Bar 8
            {start = 157, binding = "MULTIACTIONBAR6BUTTON"}, -- Bar 7
            {start = 145, binding = "MULTIACTIONBAR5BUTTON"}, -- Bar 6
            {start = 61, binding = "MULTIACTIONBAR1BUTTON"},  -- Bar 2
            {start = 49, binding = "MULTIACTIONBAR2BUTTON"},  -- Bar 3
            {start = 37, binding = "MULTIACTIONBAR4BUTTON"},  -- Bar 5
            {start = 25, binding = "MULTIACTIONBAR3BUTTON"}   -- Bar 4
        }
    }
}

-- Binding Utilities
local BindingUtils = {}

function BindingUtils.GetBindingNameForSlot(slot)
    if not slot then return nil end
    local button = ((slot - 1) % CONSTANTS.ACTION_BAR.BUTTONS_PER_BAR) + 1
    for _, bar in ipairs(CONSTANTS.ACTION_BAR.SLOTS) do
        if slot >= bar.start and slot < bar.start + CONSTANTS.ACTION_BAR.BUTTONS_PER_BAR then
            return bar.binding .. button
        end
    end
    
    -- Check if the slot is on the current main action bar page
    local currentPage = GetActionBarPage and GetActionBarPage() or 1
    local offset = GetBonusBarOffset and GetBonusBarOffset() or 0

    if offset > 0 then
        currentPage = 6 + offset
    end

    local startSlot = (currentPage - 1) * CONSTANTS.ACTION_BAR.BUTTONS_PER_BAR + 1
    local endSlot = startSlot + CONSTANTS.ACTION_BAR.BUTTONS_PER_BAR - 1

    if slot >= startSlot and slot <= endSlot then
        return "ACTIONBUTTON" .. button
    end
    
    return nil
end

function BindingUtils.SelectBinding(b1, b2)
    return b1 and b1:find("-") and b1 or b2 and b2:find("-") and b2 or b1 or b2
end

function BindingUtils.FormatBinding(binding)
    if not binding then return "" end
    return (binding:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M"))
end

function BindingUtils.GetHotkeyInfo(spellID)
    local slots = C_ActionBar.FindSpellActionButtons(spellID)
    if not slots or not slots[1] then return "", true end
    
    local bindings = {}
    for i = 1, math.min(CONSTANTS.ACTION_BAR.MAX_BINDINGS, #slots) do
        local bindingName = BindingUtils.GetBindingNameForSlot(slots[i])
        local binding = bindingName and BindingUtils.SelectBinding(GetBindingKey(bindingName))
        if binding then
            table.insert(bindings, BindingUtils.FormatBinding(binding))
        end
    end
    
    return table.concat(bindings, "\n"), C_Spell.IsSpellInRange(spellID, "target") ~= false
end

function BindingUtils.GetFontPath(fontName)
    if LSM and fontName then
        return LSM:Fetch("font", fontName) or CONSTANTS.FONT.DEFAULT_PATH
    end
    return CONSTANTS.FONT.DEFAULT_PATH
end

-- Main Display Object
local KnackDisplay = {}
KnackDisplay.__index = KnackDisplay

function KnackDisplay:New()
    local self = setmetatable({
        lastGCDStart = 0,
        lastGCDDuration = 0
    }, KnackDisplay)
    self:CreateFrame()
    self:CreateElements()
    self:SetupScripts()
    return self
end

function KnackDisplay:CreateFrame()
    self.frame = CreateFrame("Frame", "KnackFrame", UIParent)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetClampedToScreen(true)
    self.frame:Hide()
    
    -- Background
    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints(self.frame)
    self.bg:SetColorTexture(0, 0, 0, CONSTANTS.ICON.BG_OPACITY)
end

function KnackDisplay:CreateSweepFrame(parent, anchor, color, atlas, glowAtlas)
    local f = CreateFrame("StatusBar", nil, parent)
    f:SetAllPoints(anchor)
    
    if atlas then
        f:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        f:GetStatusBarTexture():SetAtlas(atlas)
        f:SetStatusBarColor(1, 1, 1, 1)
    else
        f:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        f:SetStatusBarColor(color.r, color.g, color.b, color.a)
    end
    
    f:SetMinMaxValues(0, 1)
    f:SetValue(0)
    f:Hide()
    
    -- Add Spark
    local spark = f:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetWidth(20)
    spark:SetHeight(anchor:GetHeight() * 2)
    spark:SetPoint("CENTER", f:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:Show()
    f.spark = spark
    
    -- Add Inner Glow
    if glowAtlas then
        local glow = f:CreateTexture(nil, "ARTWORK")
        glow:SetAllPoints(anchor)
        glow:SetAtlas(glowAtlas)
        glow:SetBlendMode("ADD")
        glow:Show()
        f.glow = glow
    end
    
    f:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        if now > self.endTime then
            self:Hide()
            return
        end
        
        local progress = (now - self.startTime) / self.duration
        if self.reverse then
            -- Channel: Right to Left (ReverseFill)
            self:SetValue(progress)
            self.spark:ClearAllPoints()
            self.spark:SetPoint("CENTER", self:GetStatusBarTexture(), "LEFT", 0, 0)
        else
            -- Cast: Left to Right
            self:SetValue(progress)
            self.spark:ClearAllPoints()
            self.spark:SetPoint("CENTER", self:GetStatusBarTexture(), "RIGHT", 0, 0)
        end
    end)
    return f
end

function KnackDisplay:PopulateIconFrame(frame)
    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    if frame == self.frame then
        self.icon = frame.icon
        frame.icon:SetPoint("CENTER")
    else
        frame.icon:SetAllPoints(frame)
    end
    frame.icon:SetTexCoord(CONSTANTS.ICON.TEXTURE_INSET, CONSTANTS.ICON.TEXTURE_OUTER, CONSTANTS.ICON.TEXTURE_INSET, CONSTANTS.ICON.TEXTURE_OUTER)
    
    -- Hotkey Text
    frame.hotkeyText = frame:CreateFontString(nil, "OVERLAY")
    if frame == self.frame then
        self.hotkeyText = frame.hotkeyText
    end
    frame.hotkeyText:SetPoint("TOPRIGHT", frame.icon, "TOPRIGHT", CONSTANTS.FONT.OFFSET, CONSTANTS.FONT.OFFSET)
    
    -- GCD Overlay
    frame.gcdOverlay = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.gcdOverlay:SetAllPoints(frame.icon)
    frame.gcdOverlay:SetDrawEdge(false)
    frame.gcdOverlay:SetDrawSwipe(true)
    frame.gcdOverlay:SetReverse(false)
    frame.gcdOverlay:SetHideCountdownNumbers(true)
    if frame.gcdOverlay.SetSwipeColor then
        local c = CONSTANTS.GCD.SWIPE_COLOR
        frame.gcdOverlay:SetSwipeColor(c.r, c.g, c.b, c.a)
    end
    frame.gcdOverlay:Hide()

    -- Cast Overlay
    frame.castOverlay = self:CreateSweepFrame(frame, frame.icon, CONSTANTS.CAST.SWIPE_COLOR, "UI-HUD-ActionBar-Cast-Fill", "UI-HUD-ActionBar-Casting-InnerGlow")
    frame.castOverlay:SetReverseFill(false)

    -- Channel Overlay
    frame.channelOverlay = self:CreateSweepFrame(frame, frame.icon, CONSTANTS.CHANNEL.SWIPE_COLOR, "UI-HUD-ActionBar-Channel-Fill", "UI-HUD-ActionBar-Channel-InnerGlow")
    frame.channelOverlay:SetReverseFill(true)

    -- Border
    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetFrameLevel(frame:GetFrameLevel() + 1)
    frame.border:Hide()
end

function KnackDisplay:CreateElements()
    self:PopulateIconFrame(self.frame)

    -- Nameplate Frame (Copy)
    self.nameplateFrame = CreateFrame("Frame", "KnackNameplateFrame", UIParent)
    self.nameplateFrame:SetSize(CONSTANTS.ICON.MIN_SIZE, CONSTANTS.ICON.MIN_SIZE)
    self.nameplateFrame:Hide()
    
    self:PopulateIconFrame(self.nameplateFrame)
end

function KnackDisplay:SetupScripts()
    -- Dragging
    self.frame:SetScript("OnDragStart", function() 
        if IsShiftKeyDown() and not InCombatLockdown() then 
            self.frame:StartMoving() 
        end 
    end)
    
    self.frame:SetScript("OnDragStop", function() 
        self.frame:StopMovingOrSizing() 
        self:SavePosition() 
    end)

    -- Cursor change on hover
    self.frame:SetScript("OnUpdate", function() 
        if IsShiftKeyDown() and not InCombatLockdown() and MouseIsOver(self.frame) then
            SetCursor(CONSTANTS.MOVE_CURSOR)
        else
            ResetCursor()
        end
    end)

    -- Mouse wheel scaling
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown() and not InCombatLockdown() then
            local currentSize = KnackDB.settings.iconSize or KnackDefaultSettings.iconSize
            local newSize = math.max(CONSTANTS.ICON.MIN_SIZE, math.min(CONSTANTS.ICON.MAX_SIZE, currentSize + (delta * CONSTANTS.ICON.STEP)))
            KnackDB.settings.iconSize = newSize
            self:UpdateSize()
        end
    end)
    self.frame:EnableMouseWheel(true)

    -- Tooltip
    self.frame:SetScript("OnEnter", function() self:ShowTooltip() end)
    self.frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Nameplate Tooltip
    self.nameplateFrame:SetScript("OnEnter", function() self:ShowNameplateTooltip() end)
    self.nameplateFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function KnackDisplay:ShowTooltip()
    if KnackDB.settings.showTooltip and self.currentSpellID then
        if not KnackDB.settings.hideTooltipInCombat or not InCombatLockdown() then
            GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.currentSpellID)
            GameTooltip:Show()
        end
    end
end

function KnackDisplay:ShowNameplateTooltip()
    if KnackDB.settings.nameplateShowTooltip and self.currentSpellID then
        if not KnackDB.settings.nameplateHideTooltipInCombat or not InCombatLockdown() then
            GameTooltip:SetOwner(self.nameplateFrame, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.currentSpellID)
            GameTooltip:Show()
        end
    end
end

function KnackDisplay:SavePosition()
    local fx, fy = self.frame:GetCenter()
    local px, py = UIParent:GetCenter()
    if fx and fy and px and py then
        KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = "CENTER", "CENTER", fx - px, fy - py
    end
    self:ApplyPosition()
end

function KnackDisplay:ApplyPosition()
    self.frame:ClearAllPoints()
    self.frame:SetPoint(KnackDB.point, UIParent, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs)
end

function KnackDisplay:UpdateSize()
    local size = KnackDB.settings.iconSize or KnackDefaultSettings.iconSize
    self.frame:SetSize(size, size)
    self.icon:SetSize(size - CONSTANTS.ICON.PADDING, size - CONSTANTS.ICON.PADDING)
    self:UpdateBorder()
    
    local npSize = KnackDB.settings.nameplateIconSize or KnackDefaultSettings.nameplateIconSize
    self.nameplateFrame:SetSize(npSize, npSize)
    self:UpdateNameplateBorder()
end

function KnackDisplay:UpdateFrameBorder(frame, prefix)
    if not frame or not frame.border then return end

    local key = (prefix == "" and "showBorder" or prefix .. "ShowBorder")
    if not KnackDB.settings[key] then
        frame.border:Hide()
        return
    end

    local textureKey = (prefix == "" and "borderTexture" or prefix .. "BorderTexture")
    local textureName = KnackDB.settings[textureKey]
    local texture = (LSM and textureName) and LSM:Fetch("border", textureName) or "Interface\\Tooltips\\UI-Tooltip-Border"
    
    local widthKey = (prefix == "" and "borderWidth" or prefix .. "BorderWidth")
    local edgeSize = KnackDB.settings[widthKey] or KnackDefaultSettings[widthKey]
    
    local offsetKey = (prefix == "" and "borderOffset" or prefix .. "BorderOffset")
    local offset = KnackDB.settings[offsetKey] or KnackDefaultSettings[offsetKey]
    
    frame.border:SetBackdrop({
        edgeFile = texture,
        edgeSize = edgeSize,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    frame.border:ClearAllPoints()
    frame.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -(offset + edgeSize), (offset + edgeSize))
    frame.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", (offset + edgeSize), -(offset + edgeSize))
    
    local colorKey = (prefix == "" and "borderColor" or prefix .. "BorderColor")
    local color = KnackDB.settings[colorKey] or KnackDefaultSettings[colorKey]
    frame.border:SetBackdropBorderColor(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4])
    frame.border:Show()
end

function KnackDisplay:UpdateBorder()
    self:UpdateFrameBorder(self.frame, "")
end

function KnackDisplay:UpdateNameplateBorder()
    self:UpdateFrameBorder(self.nameplateFrame, "nameplate")
end

function KnackDisplay:UpdateFrameFont(frame, prefix)
    if not frame or not frame.hotkeyText then return end
    
    local fontKey = (prefix == "" and "hotkeyFont" or prefix .. "HotkeyFont")
    local sizeKey = (prefix == "" and "hotkeySize" or prefix .. "HotkeySize")
    
    local fontPath = BindingUtils.GetFontPath(KnackDB.settings[fontKey])
    local size = KnackDB.settings[sizeKey] or KnackDefaultSettings[sizeKey]
    
    frame.hotkeyText:SetFont(fontPath, size, "OUTLINE")
end

function KnackDisplay:UpdateFrameHotkeyPosition(frame, prefix)
    if not frame or not frame.hotkeyText then return end
    
    local anchorKey = (prefix == "" and "hotkeyAnchor" or prefix .. "HotkeyAnchor")
    local anchor = KnackDB.settings[anchorKey] or "TOPRIGHT"
    
    frame.hotkeyText:ClearAllPoints()
    frame.hotkeyText:SetPoint(anchor, frame.icon, anchor, CONSTANTS.FONT.OFFSET, CONSTANTS.FONT.OFFSET)
    
    if anchor:find("LEFT") then
        frame.hotkeyText:SetJustifyH("LEFT")
    elseif anchor:find("RIGHT") then
        frame.hotkeyText:SetJustifyH("RIGHT")
    else
        frame.hotkeyText:SetJustifyH("CENTER")
    end
end

function KnackDisplay:UpdateHotkeyPosition()
    self:UpdateFrameHotkeyPosition(self.frame, "")
    self:UpdateFrameHotkeyPosition(self.nameplateFrame, "nameplate")
end

function KnackDisplay:UpdateFont()
    self:UpdateFrameFont(self.frame, "")
    self:UpdateFrameFont(self.nameplateFrame, "nameplate")
end

function KnackDisplay:UpdateFrameGCD(frame, gcd, prefix)
    if not frame or not frame.gcdOverlay then return end
    
    local showKey = (prefix == "" and "showGCD" or prefix .. "ShowGCD")
    if not KnackDB.settings[showKey] then
        frame.gcdOverlay:Hide()
        return
    end
    
    if gcd then
        frame.gcdOverlay:Show()
        if frame.gcdOverlay.SetSwipeColor then
            local opacityKey = (prefix == "" and "gcdOpacity" or prefix .. "GCDOpacity")
            frame.gcdOverlay:SetSwipeColor(0, 0, 0, KnackDB.settings[opacityKey] or KnackDefaultSettings[opacityKey])
        end
        pcall(frame.gcdOverlay.SetCooldown, frame.gcdOverlay, gcd.startTime, gcd.duration)
    else
        frame.gcdOverlay:Hide()
    end
end

function KnackDisplay:UpdateGCD()
    local gcd = C_Spell.GetSpellCooldown(CONSTANTS.GCD.SPELL_ID)
    self:UpdateFrameGCD(self.frame, gcd, "")
    self:UpdateFrameGCD(self.nameplateFrame, gcd, "nameplate")
end

function KnackDisplay:UpdateFrameSweep(frame, startTime, duration, isChannel, prefix)
    local overlay = isChannel and frame.channelOverlay or frame.castOverlay
    if not overlay then return end
    
    local typeStr = isChannel and "Channel" or "Cast"
    local showKey = (prefix == "" and "show" .. typeStr .. "Sweep" or prefix .. "Show" .. typeStr .. "Sweep")
    local glowKey = (prefix == "" and "show" .. typeStr .. "Glow" or prefix .. "Show" .. typeStr .. "Glow")
    
    local showSweep = KnackDB.settings[showKey]
    local showGlow = KnackDB.settings[glowKey]
    
    if not showSweep then
        overlay:Hide()
    else
        if startTime and duration and duration > 0 then
            overlay.startTime = startTime
            overlay.duration = duration
            overlay.endTime = startTime + duration
            overlay.reverse = isChannel
            overlay:Show()
            if overlay.glow then
                if showGlow then overlay.glow:Show() else overlay.glow:Hide() end
            end
        else
            overlay:Hide()
        end
    end
end

function KnackDisplay:UpdateCast(startTime, duration)
    self:UpdateFrameSweep(self.frame, startTime, duration, false, "")
    self:UpdateFrameSweep(self.nameplateFrame, startTime, duration, false, "nameplate")
end

function KnackDisplay:UpdateChannel(startTime, duration)
    self:UpdateFrameSweep(self.frame, startTime, duration, true, "")
    self:UpdateFrameSweep(self.nameplateFrame, startTime, duration, true, "nameplate")
end

function KnackDisplay:UpdateNameplateAttachment()
    if not self.nameplateFrame or not self.nameplateFrame.icon then return end

    if not KnackDB.settings.attachToNameplate then
        self.nameplateFrame:Hide()
        return
    end

    local unit = "target"
    if not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then
        self.nameplateFrame:Hide()
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then
        self.nameplateFrame:Hide()
        return
    end

    -- Try to find the health bar to anchor to
    local anchorFrame = nameplate
    if nameplate.UnitFrame and nameplate.UnitFrame.healthBar then
        anchorFrame = nameplate.UnitFrame.healthBar
    elseif nameplate.UnitFrame and nameplate.UnitFrame.HealthBar then
        anchorFrame = nameplate.UnitFrame.HealthBar
    elseif nameplate.UnitFrame then
        anchorFrame = nameplate.UnitFrame
    end

    local anchor = KnackDB.settings.nameplateAnchor or "TOP"
    local offset = KnackDB.settings.nameplateOffset or 0
    local xPercent = KnackDB.settings.nameplateOffsetX or 0
    local yPercent = KnackDB.settings.nameplateOffsetY or 0
    
    local npSize = KnackDB.settings.nameplateIconSize or KnackDefaultSettings.nameplateIconSize
    local xOfs = (xPercent / 100) * npSize
    local yOfs = (yPercent / 100) * npSize
    
    -- Smart Anchor Logic: Flip the anchor point for the icon to align edges
    local iconAnchor = anchor
    
    if iconAnchor:find("TOP") then
        iconAnchor = iconAnchor:gsub("TOP", "BOTTOM")
    elseif iconAnchor:find("BOTTOM") then
        iconAnchor = iconAnchor:gsub("BOTTOM", "TOP")
    end
    
    if iconAnchor:find("LEFT") then
        iconAnchor = iconAnchor:gsub("LEFT", "RIGHT")
    elseif iconAnchor:find("RIGHT") then
        iconAnchor = iconAnchor:gsub("RIGHT", "LEFT")
    end
    
    -- Adjust Y offset based on anchor and "distance" (offset)
    if anchor:find("TOP") then
        yOfs = yOfs + offset
    elseif anchor:find("BOTTOM") then
        yOfs = yOfs - offset
    end

    if anchor:find("LEFT") then
        xOfs = xOfs - offset
    elseif anchor:find("RIGHT") then
        xOfs = xOfs + offset
    end

    self.nameplateFrame:ClearAllPoints()
    self.nameplateFrame:SetPoint(iconAnchor, anchorFrame, anchor, xOfs, yOfs)
    self.nameplateFrame:Show()
end

function KnackDisplay:Update(spellID)
    self.currentSpellID = spellID
    
    if not spellID then
        self.frame:Hide()
        self.nameplateFrame:Hide()
        return
    end
    
    local icon = C_Spell.GetSpellTexture(spellID)
    if not icon then
        self.frame:Hide()
        self.nameplateFrame:Hide()
        return
    end
    
    -- Update Icon
    self.icon:SetTexture(icon)
    self.nameplateFrame.icon:SetTexture(icon)
    
    -- Update Hotkey
    local hotkeyText, inRange = BindingUtils.GetHotkeyInfo(spellID)
    self.hotkeyText:SetText(hotkeyText)
    self.nameplateFrame.hotkeyText:SetText(hotkeyText)
    
    local color = inRange and CONSTANTS.FONT.COLOR_IN_RANGE or CONSTANTS.FONT.COLOR_OUT_OF_RANGE
    self.hotkeyText:SetTextColor(color.r, color.g, color.b, color.a)
    self.nameplateFrame.hotkeyText:SetTextColor(color.r, color.g, color.b, color.a)
    
    self.frame:Show()
    self:UpdateNameplateAttachment()
end

-- Core Logic
local Knack = {
    display = nil,
    lastScan = 0
}

function Knack:Initialize()
    KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }
    self.display = KnackDisplay:New()
    
    self:SetupEvents()
    self:SetupSlashCommands()
    self:StartScanning()
end

function Knack:SetupEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    
    -- Cast Events
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    
    -- Channel Events
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            self:OnLoad()
        elseif event == "PLAYER_LOGIN" then
            self.display:ApplyPosition()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self:Update()
            self.display:UpdateNameplateAttachment()
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            self.display:UpdateGCD()
        elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
            self.display:UpdateNameplateAttachment()
        
        -- Cast Handling
        elseif event == "UNIT_SPELLCAST_START" and arg1 == "player" then
            local _, _, _, startTime, endTime = UnitCastingInfo("player")
            if startTime and endTime then
                self.display:UpdateCast(startTime / 1000, (endTime - startTime) / 1000)
            end
        elseif event == "UNIT_SPELLCAST_DELAYED" and arg1 == "player" then
            local _, _, _, startTime, endTime = UnitCastingInfo("player")
            if startTime and endTime then
                self.display:UpdateCast(startTime / 1000, (endTime - startTime) / 1000)
            end
        elseif (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED") and arg1 == "player" then
            self.display:UpdateCast(nil, nil)
            
        -- Channel Handling
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" and arg1 == "player" then
            local _, _, _, startTime, endTime = UnitChannelInfo("player")
            if startTime and endTime then
                self.display:UpdateChannel(startTime / 1000, (endTime - startTime) / 1000)
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" and arg1 == "player" then
            local _, _, _, startTime, endTime = UnitChannelInfo("player")
            if startTime and endTime then
                self.display:UpdateChannel(startTime / 1000, (endTime - startTime) / 1000)
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and arg1 == "player" then
            self.display:UpdateChannel(nil, nil)
        end
    end)
end

function Knack:OnLoad()
    self.display:UpdateSize()
    self.display:UpdateFont()
    self.display:UpdateHotkeyPosition()
    self.display:UpdateGCD()
    print("|cff00ff00[knack]|r loaded. Hold SHIFT to move and resize the icon.")
end

function Knack:StartScanning()
    local scanFrame = CreateFrame("Frame")
    scanFrame:SetScript("OnUpdate", function(_, elapsed)
        self.lastScan = self.lastScan + elapsed
        if self.lastScan >= CONSTANTS.SCAN_INTERVAL then
            self.lastScan = 0
            self:Update()
        end
    end)
end

function Knack:ShouldDisplay()
    if not KnackDB.settings.enabled then return false end
    
    if KnackDB.settings.onlyWithEnemyTarget then
        if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target") then
            return false
        end
    end
    
    return C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
end

function Knack:Update()
    if not self:ShouldDisplay() then
        self.display:Update(nil)
        return
    end

    local success, spellID = pcall(C_AssistedCombat.GetNextCastSpell, true)
    if not success or not spellID or spellID == 0 then
        self.display:Update(nil)
        return
    end

    self.display:Update(spellID)
end

function Knack:SetupSlashCommands()
    SLASH_KNACK1 = "/knack"
    SlashCmdList["KNACK"] = function(msg)
        if msg == "reset" then
            KnackResetPosition()
            print("|cff00ff00[knack]|r position reset to center.")
        else
            KnackOpenSettings()
        end
    end
end

-- Initialize
Knack:Initialize()

-- Global API for Settings Panel
function KnackUpdateVisibility() Knack:Update() end
function KnackUpdateGCDOverlay() Knack.display:UpdateGCD() end
function KnackUpdateHotkeyFont() Knack.display:UpdateFont() end
function KnackUpdateHotkeySize() Knack.display:UpdateFont() end
function KnackUpdateHotkeyPosition() Knack.display:UpdateHotkeyPosition() end
function KnackUpdateIconSize() Knack.display:UpdateSize() end
function KnackUpdateBorder() Knack.display:UpdateBorder() end
function KnackResetPosition() 
    KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = "CENTER", "CENTER", 0, 0 
    Knack.display:ApplyPosition() 
end

function KnackUpdateNameplateAttachment()
    if Knack.display then
        Knack.display:UpdateNameplateAttachment()
    end
end

function KnackUpdateNameplateBorder()
    if Knack.display then
        Knack.display:UpdateNameplateBorder()
    end
end
