local addonName = ...

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
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
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

function KnackDisplay:CreateElements()
    -- Icon
    self.icon = self.frame:CreateTexture(nil, "ARTWORK")
    self.icon:SetPoint("CENTER")
    self.icon:SetTexCoord(CONSTANTS.ICON.TEXTURE_INSET, CONSTANTS.ICON.TEXTURE_OUTER, CONSTANTS.ICON.TEXTURE_INSET, CONSTANTS.ICON.TEXTURE_OUTER)
    
    -- Hotkey Text
    self.hotkeyText = self.frame:CreateFontString(nil, "OVERLAY")
    self.hotkeyText:SetPoint("TOPRIGHT", self.icon, "TOPRIGHT", CONSTANTS.FONT.OFFSET, CONSTANTS.FONT.OFFSET)
    
    -- GCD Overlay
    self.gcdOverlay = CreateFrame("Cooldown", nil, self.frame, "CooldownFrameTemplate")
    self.gcdOverlay:SetAllPoints(self.icon)
    self.gcdOverlay:SetDrawEdge(false)
    self.gcdOverlay:SetDrawSwipe(true)
    self.gcdOverlay:SetReverse(false)
    self.gcdOverlay:SetHideCountdownNumbers(true)
    if self.gcdOverlay.SetSwipeColor then
        local c = CONSTANTS.GCD.SWIPE_COLOR
        self.gcdOverlay:SetSwipeColor(c.r, c.g, c.b, c.a)
    end
    self.gcdOverlay:Hide()

    -- Helper to create sweep frames (StatusBar)
    local function CreateSweepFrame(parent, anchor, color, atlas, glowAtlas)
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

    -- Cast Overlay
    self.castOverlay = CreateSweepFrame(self.frame, self.icon, CONSTANTS.CAST.SWIPE_COLOR, "UI-HUD-ActionBar-Cast-Fill", "UI-HUD-ActionBar-Casting-InnerGlow")
    self.castOverlay:SetReverseFill(false)

    -- Channel Overlay
    self.channelOverlay = CreateSweepFrame(self.frame, self.icon, CONSTANTS.CHANNEL.SWIPE_COLOR, "UI-HUD-ActionBar-Channel-Fill", "UI-HUD-ActionBar-Channel-InnerGlow")
    self.channelOverlay:SetReverseFill(true)

    -- Border
    self.border = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    self.border:SetFrameLevel(self.frame:GetFrameLevel() + 1)
    self.border:Hide()

    -- Nameplate Frame (Copy)
    self.nameplateFrame = CreateFrame("Frame", "KnackNameplateFrame", UIParent)
    self.nameplateFrame:SetSize(CONSTANTS.ICON.MIN_SIZE, CONSTANTS.ICON.MIN_SIZE)
    self.nameplateFrame:Hide()
    
    self.nameplateFrame.icon = self.nameplateFrame:CreateTexture(nil, "ARTWORK")
    self.nameplateFrame.icon:SetAllPoints(self.nameplateFrame)
    self.nameplateFrame.icon:SetTexCoord(CONSTANTS.ICON.TEXTURE_INSET, CONSTANTS.ICON.TEXTURE_OUTER, CONSTANTS.ICON.TEXTURE_INSET, CONSTANTS.ICON.TEXTURE_OUTER)

    self.nameplateFrame.gcdOverlay = CreateFrame("Cooldown", nil, self.nameplateFrame, "CooldownFrameTemplate")
    self.nameplateFrame.gcdOverlay:SetAllPoints(self.nameplateFrame.icon)
    self.nameplateFrame.gcdOverlay:SetDrawEdge(false)
    self.nameplateFrame.gcdOverlay:SetDrawSwipe(true)
    self.nameplateFrame.gcdOverlay:SetReverse(false)
    self.nameplateFrame.gcdOverlay:SetHideCountdownNumbers(true)
    if self.nameplateFrame.gcdOverlay.SetSwipeColor then
        local c = CONSTANTS.GCD.SWIPE_COLOR
        self.nameplateFrame.gcdOverlay:SetSwipeColor(c.r, c.g, c.b, c.a)
    end
    self.nameplateFrame.gcdOverlay:Hide()

    -- Nameplate Cast Overlay
    self.nameplateFrame.castOverlay = CreateSweepFrame(self.nameplateFrame, self.nameplateFrame.icon, CONSTANTS.CAST.SWIPE_COLOR, "UI-HUD-ActionBar-Cast-Fill", "UI-HUD-ActionBar-Casting-InnerGlow")
    self.nameplateFrame.castOverlay:SetReverseFill(false)

    -- Nameplate Channel Overlay
    self.nameplateFrame.channelOverlay = CreateSweepFrame(self.nameplateFrame, self.nameplateFrame.icon, CONSTANTS.CHANNEL.SWIPE_COLOR, "UI-HUD-ActionBar-Channel-Fill", "UI-HUD-ActionBar-Channel-InnerGlow")
    self.nameplateFrame.channelOverlay:SetReverseFill(true)

    -- Nameplate Hotkey Text
    self.nameplateFrame.hotkeyText = self.nameplateFrame:CreateFontString(nil, "OVERLAY")
    self.nameplateFrame.hotkeyText:SetPoint("TOPRIGHT", self.nameplateFrame.icon, "TOPRIGHT", CONSTANTS.FONT.OFFSET, CONSTANTS.FONT.OFFSET)

    -- Nameplate Border
    self.nameplateFrame.border = CreateFrame("Frame", nil, self.nameplateFrame, "BackdropTemplate")
    self.nameplateFrame.border:SetFrameLevel(self.nameplateFrame:GetFrameLevel() + 1)
    self.nameplateFrame.border:Hide()
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
end

function KnackDisplay:UpdateBorder()
    if not KnackDB.settings.showBorder then
        self.border:Hide()
        return
    end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local texture = (LSM and KnackDB.settings.borderTexture) and LSM:Fetch("border", KnackDB.settings.borderTexture) or "Interface\\Tooltips\\UI-Tooltip-Border"
    
    local edgeSize = KnackDB.settings.borderWidth or KnackDefaultSettings.borderWidth
    local offset = KnackDB.settings.borderOffset or KnackDefaultSettings.borderOffset
    
    self.border:SetBackdrop({
        edgeFile = texture,
        edgeSize = edgeSize,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    self.border:ClearAllPoints()
    self.border:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -(offset + edgeSize), (offset + edgeSize))
    self.border:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", (offset + edgeSize), -(offset + edgeSize))
    
    local color = KnackDB.settings.borderColor or KnackDefaultSettings.borderColor
    self.border:SetBackdropBorderColor(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4])
    self.border:Show()
end

function KnackDisplay:UpdateFont()
    local fontPath = BindingUtils.GetFontPath(KnackDB.settings.hotkeyFont)
    local size = KnackDB.settings.hotkeySize or KnackDefaultSettings.hotkeySize
    self.hotkeyText:SetFont(fontPath, size, "OUTLINE")
    
    if self.nameplateFrame and self.nameplateFrame.hotkeyText then
        local npFontPath = BindingUtils.GetFontPath(KnackDB.settings.nameplateHotkeyFont)
        local npSize = KnackDB.settings.nameplateHotkeySize or KnackDefaultSettings.nameplateHotkeySize
        self.nameplateFrame.hotkeyText:SetFont(npFontPath, npSize, "OUTLINE")
    end
end

function KnackDisplay:UpdateGCD()
    if not KnackDB.settings.showGCD then
        self.gcdOverlay:Hide()
        return
    end

    local gcd = C_Spell.GetSpellCooldown(CONSTANTS.GCD.SPELL_ID)
    
    if gcd then
        self.gcdOverlay:Show()
        if self.gcdOverlay.SetSwipeColor then
            self.gcdOverlay:SetSwipeColor(0, 0, 0, KnackDB.settings.gcdOpacity or KnackDefaultSettings.gcdOpacity)
        end
        
        -- Blindly pass values to SetCooldown. 
        -- We cannot check them or compare them if they are secrets.
        -- We rely on SetCooldown to handle secret values and '0' duration.
        pcall(self.gcdOverlay.SetCooldown, self.gcdOverlay, gcd.startTime, gcd.duration)

        -- Update Nameplate GCD
        if self.nameplateFrame and self.nameplateFrame.gcdOverlay then
            if KnackDB.settings.nameplateShowGCD then
                self.nameplateFrame.gcdOverlay:Show()
                if self.nameplateFrame.gcdOverlay.SetSwipeColor then
                    self.nameplateFrame.gcdOverlay:SetSwipeColor(0, 0, 0, KnackDB.settings.nameplateGCDOpacity or KnackDefaultSettings.nameplateGCDOpacity)
                end
                pcall(self.nameplateFrame.gcdOverlay.SetCooldown, self.nameplateFrame.gcdOverlay, gcd.startTime, gcd.duration)
            else
                self.nameplateFrame.gcdOverlay:Hide()
            end
        end
    else
        self.gcdOverlay:Hide()
        if self.nameplateFrame and self.nameplateFrame.gcdOverlay then
            self.nameplateFrame.gcdOverlay:Hide()
        end
    end
end

function KnackDisplay:UpdateCast(startTime, duration)
    local showSweep = KnackDB.settings.showCastSweep
    local showGlow = KnackDB.settings.showCastGlow
    
    if not showSweep then
        self.castOverlay:Hide()
    else
        if startTime and duration and duration > 0 then
            self.castOverlay.startTime = startTime
            self.castOverlay.duration = duration
            self.castOverlay.endTime = startTime + duration
            self.castOverlay.reverse = false
            self.castOverlay:Show()
            if self.castOverlay.glow then
                if showGlow then self.castOverlay.glow:Show() else self.castOverlay.glow:Hide() end
            end
        else
            self.castOverlay:Hide()
        end
    end

    if self.nameplateFrame and self.nameplateFrame.castOverlay then
        local npShowSweep = KnackDB.settings.nameplateShowCastSweep
        local npShowGlow = KnackDB.settings.nameplateShowCastGlow
        
        if not npShowSweep then
            self.nameplateFrame.castOverlay:Hide()
        else
            if startTime and duration and duration > 0 then
                self.nameplateFrame.castOverlay.startTime = startTime
                self.nameplateFrame.castOverlay.duration = duration
                self.nameplateFrame.castOverlay.endTime = startTime + duration
                self.nameplateFrame.castOverlay.reverse = false
                self.nameplateFrame.castOverlay:Show()
                if self.nameplateFrame.castOverlay.glow then
                    if npShowGlow then self.nameplateFrame.castOverlay.glow:Show() else self.nameplateFrame.castOverlay.glow:Hide() end
                end
            else
                self.nameplateFrame.castOverlay:Hide()
            end
        end
    end
end

function KnackDisplay:UpdateChannel(startTime, duration)
    local showSweep = KnackDB.settings.showChannelSweep
    local showGlow = KnackDB.settings.showChannelGlow
    
    if not showSweep then
        self.channelOverlay:Hide()
    else
        if startTime and duration and duration > 0 then
            self.channelOverlay.startTime = startTime
            self.channelOverlay.duration = duration
            self.channelOverlay.endTime = startTime + duration
            self.channelOverlay.reverse = true
            self.channelOverlay:Show()
            if self.channelOverlay.glow then
                if showGlow then self.channelOverlay.glow:Show() else self.channelOverlay.glow:Hide() end
            end
        else
            self.channelOverlay:Hide()
        end
    end

    if self.nameplateFrame and self.nameplateFrame.channelOverlay then
        local npShowSweep = KnackDB.settings.nameplateShowChannelSweep
        local npShowGlow = KnackDB.settings.nameplateShowChannelGlow
        
        if not npShowSweep then
            self.nameplateFrame.channelOverlay:Hide()
        else
            if startTime and duration and duration > 0 then
                self.nameplateFrame.channelOverlay.startTime = startTime
                self.nameplateFrame.channelOverlay.duration = duration
                self.nameplateFrame.channelOverlay.endTime = startTime + duration
                self.nameplateFrame.channelOverlay.reverse = true
                self.nameplateFrame.channelOverlay:Show()
                if self.nameplateFrame.channelOverlay.glow then
                    if npShowGlow then self.nameplateFrame.channelOverlay.glow:Show() else self.nameplateFrame.channelOverlay.glow:Hide() end
                end
            else
                self.nameplateFrame.channelOverlay:Hide()
            end
        end
    end
end

function KnackDisplay:UpdateNameplateAttachment()
    if not KnackDB.settings.attachToNameplate then
        self.nameplateFrame:Hide()
        return
    end

    if not UnitExists("target") then
        self.nameplateFrame:Hide()
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit("target")
    if nameplate then
        self.nameplateFrame:SetParent(nameplate)
        self.nameplateFrame:ClearAllPoints()
        
        local anchor = KnackDB.settings.nameplateAnchor or "TOP"
        local offset = (KnackDB.settings.nameplateOffset or 0) - 13
        local offsetX = KnackDB.settings.nameplateOffsetX or 0
        local offsetY = KnackDB.settings.nameplateOffsetY or 0
        
        local p, rP, x, y = anchor, anchor, 0, 0
        
        if anchor == "TOP" then p = "BOTTOM"; rP = "TOP"; y = offset
        elseif anchor == "BOTTOM" then p = "TOP"; rP = "BOTTOM"; y = -offset
        elseif anchor == "LEFT" then p = "RIGHT"; rP = "LEFT"; x = -2 - offset
        elseif anchor == "RIGHT" then p = "LEFT"; rP = "RIGHT"; x = 2 + offset
        elseif anchor == "TOPLEFT" then p = "BOTTOMRIGHT"; rP = "TOPLEFT"; x = -offset; y = offset
        elseif anchor == "TOPRIGHT" then p = "BOTTOMLEFT"; rP = "TOPRIGHT"; x = offset; y = offset
        elseif anchor == "BOTTOMLEFT" then p = "TOPRIGHT"; rP = "BOTTOMLEFT"; x = -offset; y = -offset
        elseif anchor == "BOTTOMRIGHT" then p = "TOPLEFT"; rP = "BOTTOMRIGHT"; x = offset; y = -offset
        end
        
        self.nameplateFrame:SetPoint(p, nameplate, rP, x + offsetX, y + offsetY)
        self.nameplateFrame:Show()
        
        local size = KnackDB.settings.nameplateIconSize or 32
        self.nameplateFrame:SetSize(size, size)
        self.nameplateFrame.icon:SetSize(size - CONSTANTS.ICON.PADDING, size - CONSTANTS.ICON.PADDING)
        
        -- Update font size when nameplate icon size changes
        self:UpdateFont()
    else
        self.nameplateFrame:Hide()
    end
end

function KnackDisplay:UpdateNameplateBorder()
    if not self.nameplateFrame or not self.nameplateFrame.border then return end

    if not KnackDB.settings.nameplateShowBorder then
        self.nameplateFrame.border:Hide()
        return
    end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local texture = (LSM and KnackDB.settings.nameplateBorderTexture) and LSM:Fetch("border", KnackDB.settings.nameplateBorderTexture) or "Interface\\Tooltips\\UI-Tooltip-Border"
    
    local edgeSize = KnackDB.settings.nameplateBorderWidth or KnackDefaultSettings.nameplateBorderWidth
    local offset = KnackDB.settings.nameplateBorderOffset or KnackDefaultSettings.nameplateBorderOffset
    
    self.nameplateFrame.border:SetBackdrop({
        edgeFile = texture,
        edgeSize = edgeSize,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    self.nameplateFrame.border:ClearAllPoints()
    self.nameplateFrame.border:SetPoint("TOPLEFT", self.nameplateFrame, "TOPLEFT", -(offset + edgeSize), (offset + edgeSize))
    self.nameplateFrame.border:SetPoint("BOTTOMRIGHT", self.nameplateFrame, "BOTTOMRIGHT", (offset + edgeSize), -(offset + edgeSize))
    
    local color = KnackDB.settings.nameplateBorderColor or KnackDefaultSettings.nameplateBorderColor
    self.nameplateFrame.border:SetBackdropBorderColor(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4])
    self.nameplateFrame.border:Show()
end

function KnackDisplay:Update(spellID)
    if not spellID then
        self.frame:Hide()
        self.currentSpellID = nil
        return
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then
        self.frame:Hide()
        self.currentSpellID = nil
        return
    end

    -- Update Icon
    local spellChanged = (self.currentSpellID ~= spellID)
    self.currentSpellID = spellID
    self.icon:SetTexture(spellInfo.iconID)
    
    -- Update Nameplate Copy
    if self.nameplateFrame then
        self.nameplateFrame.icon:SetTexture(spellInfo.iconID)
        self:UpdateNameplateAttachment()
        self:UpdateNameplateBorder()
    end
    
    -- Update Tooltip if needed
    if spellChanged and GameTooltip:IsOwned(self.frame) and GameTooltip:IsShown() then
        self:ShowTooltip()
    end

    -- Update Hotkey
    local hotkey, inRange = BindingUtils.GetHotkeyInfo(spellID)
    self.hotkeyText:SetText(hotkey)
    
    local color = inRange and CONSTANTS.FONT.COLOR_IN_RANGE or CONSTANTS.FONT.COLOR_OUT_OF_RANGE
    self.hotkeyText:SetTextColor(color.r, color.g, color.b, color.a)

    -- Update Nameplate Hotkey
    if self.nameplateFrame and self.nameplateFrame.hotkeyText then
        self.nameplateFrame.hotkeyText:SetText(hotkey)
        self.nameplateFrame.hotkeyText:SetTextColor(color.r, color.g, color.b, color.a)
    end

    -- Update GCD
    -- self:UpdateGCD()

    self.frame:Show()
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
    self.display:UpdateGCD()
    print("|cff00ff00[knack]|r loaded. Hold SHIFT to move the icon.")
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
