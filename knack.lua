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
        MIN_SIZE = 32,
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
    return "ACTIONBUTTON" .. button -- Bar 1 (slots 1-12)
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

    -- Border
    self.border = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    self.border:SetFrameLevel(self.frame:GetFrameLevel() + 1)
    self.border:Hide()
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
    self.border:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -offset, offset)
    self.border:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", offset, -offset)
    
    local color = KnackDB.settings.borderColor or KnackDefaultSettings.borderColor
    self.border:SetBackdropBorderColor(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4])
    self.border:Show()
end

function KnackDisplay:UpdateFont()
    local fontPath = BindingUtils.GetFontPath(KnackDB.settings.hotkeyFont)
    local size = KnackDB.settings.hotkeySize or KnackDefaultSettings.hotkeySize
    self.hotkeyText:SetFont(fontPath, size, "OUTLINE")
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
    else
        self.gcdOverlay:Hide()
    end
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
    
    -- Update Tooltip if needed
    if spellChanged and GameTooltip:IsOwned(self.frame) and GameTooltip:IsShown() then
        self:ShowTooltip()
    end

    -- Update Hotkey
    local hotkey, inRange = BindingUtils.GetHotkeyInfo(spellID)
    self.hotkeyText:SetText(hotkey)
    
    local color = inRange and CONSTANTS.FONT.COLOR_IN_RANGE or CONSTANTS.FONT.COLOR_OUT_OF_RANGE
    self.hotkeyText:SetTextColor(color.r, color.g, color.b, color.a)

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
    
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            self:OnLoad()
        elseif event == "PLAYER_LOGIN" then
            self.display:ApplyPosition()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self:Update()
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            self.display:UpdateGCD()
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
