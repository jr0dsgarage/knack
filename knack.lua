local addonName = ...

-- Constants
local FONT_PATH = "Fonts\\FRIZQT__.TTF"
local MOVE_CURSOR = "Interface\\CURSOR\\UI-Cursor-Move"
local GCD_SPELL_ID = 61304
local SCAN_INTERVAL = 0.1

-- UI Constants
local DEFAULT_ICON_SIZE = 64
local ICON_PADDING = 4
local DEFAULT_HOTKEY_SIZE = 14
local HOTKEY_OFFSET = 2
local MIN_ICON_SIZE = 32
local MAX_ICON_SIZE = 128
local ICON_SIZE_STEP = 4

-- Color Constants
local BG_OPACITY = 0.5
local TEXTURE_COORD_INSET = 0.07
local TEXTURE_COORD_OUTER = 0.93
local GCD_SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 1}
local HOTKEY_COLOR_IN_RANGE = {r = 1, g = 1, b = 1, a = 1}
local HOTKEY_COLOR_OUT_OF_RANGE = {r = 0.8, g = 0.1, b = 0.1, a = 1}

-- Action Bar Constants
local BUTTONS_PER_BAR = 12
local MAX_HOTKEY_BINDINGS = 3
local ACTION_BAR_SLOTS = {
    {startSlot = 169, binding = "MULTIACTIONBAR7BUTTON"}, -- Bar 8
    {startSlot = 157, binding = "MULTIACTIONBAR6BUTTON"}, -- Bar 7
    {startSlot = 145, binding = "MULTIACTIONBAR5BUTTON"}, -- Bar 6
    {startSlot = 61, binding = "MULTIACTIONBAR1BUTTON"},  -- Bar 2
    {startSlot = 49, binding = "MULTIACTIONBAR2BUTTON"},  -- Bar 3
    {startSlot = 37, binding = "MULTIACTIONBAR4BUTTON"},  -- Bar 5
    {startSlot = 25, binding = "MULTIACTIONBAR3BUTTON"}   -- Bar 4
}

-- Helper to get font path from LibSharedMedia or fallback
local function GetFontPath(fontName)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and fontName then
        return LSM:Fetch("font", fontName) or FONT_PATH
    end
    return FONT_PATH
end

local function GetBindingNameForSlot(slot)
    if not slot then return nil end
    local button = ((slot - 1) % BUTTONS_PER_BAR) + 1
    for _, bar in ipairs(ACTION_BAR_SLOTS) do
        if slot >= bar.startSlot and slot < bar.startSlot + BUTTONS_PER_BAR then
            return bar.binding .. button
        end
    end
    return "ACTIONBUTTON" .. button -- Bar 1 (slots 1-12)
end

local function SelectBinding(b1, b2)
    return b1 and b1:find("-") and b1 or b2 and b2:find("-") and b2 or b1 or b2
end

local function FormatBinding(binding)
    if not binding then return "" end
    return (binding:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M"))
end

-- Initialize saved variables
KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }

-- Create main frame
local frame = CreateFrame("Frame", "KnackFrame", UIParent)
local frameSize = KnackDB.settings.iconSize or DEFAULT_ICON_SIZE
frame:SetSize(frameSize, frameSize)
frame:SetPoint(KnackDB.point, UIParent, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:Hide()

local function ApplyPosition()
    frame:ClearAllPoints()
    frame:SetPoint(KnackDB.point, UIParent, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs)
end

local function SavePosition()
    local fx, fy = frame:GetCenter()
    local px, py = UIParent:GetCenter()
    if fx and fy and px and py then
        KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = "CENTER", "CENTER", fx - px, fy - py
    end
end

-- Create background
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetColorTexture(0, 0, 0, BG_OPACITY)

-- Create spell icon
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetPoint("CENTER")
local iconSize = (KnackDB.settings.iconSize or DEFAULT_ICON_SIZE) - ICON_PADDING
icon:SetSize(iconSize, iconSize)
icon:SetTexCoord(TEXTURE_COORD_INSET, TEXTURE_COORD_OUTER, TEXTURE_COORD_INSET, TEXTURE_COORD_OUTER)

-- Create hotkey text
local hotkeyText = frame:CreateFontString(nil, "OVERLAY")
local fontPath = GetFontPath(KnackDB.settings.hotkeyFont)
hotkeyText:SetFont(fontPath, KnackDB.settings.hotkeySize or DEFAULT_HOTKEY_SIZE, "OUTLINE")
hotkeyText:SetPoint("TOPRIGHT", icon, "TOPRIGHT", HOTKEY_OFFSET, HOTKEY_OFFSET)
hotkeyText:SetTextColor(HOTKEY_COLOR_IN_RANGE.r, HOTKEY_COLOR_IN_RANGE.g, HOTKEY_COLOR_IN_RANGE.b, HOTKEY_COLOR_IN_RANGE.a)

-- Create GCD overlay (Cooldown frame)
local gcdOverlay = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
gcdOverlay:SetAllPoints(icon)
gcdOverlay:SetDrawEdge(false)
gcdOverlay:SetDrawSwipe(true)
gcdOverlay:SetReverse(false)
gcdOverlay:SetHideCountdownNumbers(true)
if gcdOverlay.SetSwipeColor then
    gcdOverlay:SetSwipeColor(GCD_SWIPE_COLOR.r, GCD_SWIPE_COLOR.g, GCD_SWIPE_COLOR.b, GCD_SWIPE_COLOR.a)
end
gcdOverlay:Hide()

-- Dragging
frame:SetScript("OnDragStart", function(self) if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePosition() ApplyPosition() end)

frame:SetScript("OnUpdate", function() (IsShiftKeyDown() and not InCombatLockdown() and MouseIsOver(frame) and SetCursor or ResetCursor)(MOVE_CURSOR) end)

-- Mouse wheel scaling
frame:SetScript("OnMouseWheel", function(self, delta)
    if IsShiftKeyDown() and not InCombatLockdown() then
        local newSize = math.max(MIN_ICON_SIZE, math.min(MAX_ICON_SIZE, KnackDB.settings.iconSize + (delta * ICON_SIZE_STEP)))
        KnackDB.settings.iconSize = newSize
        KnackUpdateIconSize()
    end
end)
frame:EnableMouseWheel(true)

-- Tooltip
local currentSpellID

frame:SetScript("OnEnter", function(self)
    if KnackDB.settings.showTooltip and currentSpellID then
        if not KnackDB.settings.hideTooltipInCombat or not InCombatLockdown() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(currentSpellID)
            GameTooltip:Show()
        end
    end
end)

frame:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

local function ShouldDisplay()
    return KnackDB.settings.enabled and (not KnackDB.settings.onlyWithEnemyTarget or (UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target"))) and C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
end

local function GetHotkeyInfo(spellID)
    local slots = C_ActionBar.FindSpellActionButtons(spellID)
    if not slots or not slots[1] then return "", true end
    
    -- Get bindings for up to MAX_HOTKEY_BINDINGS slots
    local bindings = {}
    for i = 1, math.min(MAX_HOTKEY_BINDINGS, #slots) do
        local bindingName = GetBindingNameForSlot(slots[i])
        local binding = bindingName and SelectBinding(GetBindingKey(bindingName))
        if binding then
            table.insert(bindings, FormatBinding(binding))
        end
    end
    
    local hotkeyText = table.concat(bindings, "\n")
    return hotkeyText, C_Spell.IsSpellInRange(spellID, "target") ~= false
end

-- Update the display
local function UpdateDisplay()
    if not ShouldDisplay() then
        frame:Hide()
        currentSpellID = nil
        return
    end

    local success, spellID = pcall(C_AssistedCombat.GetNextCastSpell, true)
    if not success or not spellID or spellID == 0 then
        frame:Hide()
        currentSpellID = nil
        return
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then
        frame:Hide()
        currentSpellID = nil
        return
    end

    local spellChanged = (currentSpellID ~= spellID)
    currentSpellID = spellID
    icon:SetTexture(spellInfo.iconID)
    
    -- Update tooltip if spell changed and tooltip is currently showing
    if spellChanged and GameTooltip:IsOwned(frame) and GameTooltip:IsShown() then
        if KnackDB.settings.showTooltip then
            if not KnackDB.settings.hideTooltipInCombat or not InCombatLockdown() then
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(currentSpellID)
                GameTooltip:Show()
            end
        end
    end

    local hotkey, inRange = GetHotkeyInfo(spellID)
    hotkeyText:SetText(hotkey)
    if inRange then
        hotkeyText:SetTextColor(HOTKEY_COLOR_IN_RANGE.r, HOTKEY_COLOR_IN_RANGE.g, HOTKEY_COLOR_IN_RANGE.b, HOTKEY_COLOR_IN_RANGE.a)
    else
        hotkeyText:SetTextColor(HOTKEY_COLOR_OUT_OF_RANGE.r, HOTKEY_COLOR_OUT_OF_RANGE.g, HOTKEY_COLOR_OUT_OF_RANGE.b, HOTKEY_COLOR_OUT_OF_RANGE.a)
    end

    if KnackDB.settings.showGCD then
        local gcd = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if gcd and gcd.startTime and gcd.duration then
            gcdOverlay:SetCooldown(gcd.startTime, gcd.duration)
            if gcdOverlay.SetSwipeColor then
                gcdOverlay:SetSwipeColor(0, 0, 0, KnackDB.settings.gcdOpacity)
            end
        end
    end

    frame:Show()
end

-- Periodic scanning
local lastScan = 0
local scanFrame = CreateFrame("Frame")
scanFrame:SetScript("OnUpdate", function(_, elapsed)
    lastScan = lastScan + elapsed
    if lastScan >= SCAN_INTERVAL then
        lastScan = 0
        UpdateDisplay()
    end
end)

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Apply saved settings
        local size = KnackDB.settings.iconSize or DEFAULT_ICON_SIZE
        frame:SetSize(size, size)
        icon:SetSize(size - ICON_PADDING, size - ICON_PADDING)
        local fontPath = GetFontPath(KnackDB.settings.hotkeyFont)
        hotkeyText:SetFont(fontPath, KnackDB.settings.hotkeySize or DEFAULT_HOTKEY_SIZE, "OUTLINE")
        print("|cff00ff00[knack]|r loaded. Hold SHIFT to move the icon.")
    elseif event == "PLAYER_LOGIN" then
        ApplyPosition()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateDisplay()
    end
end)

-- Global functions for settings panel
function KnackUpdateVisibility() if KnackDB.settings.enabled then UpdateDisplay() else frame:Hide() end end
function KnackUpdateGCDOverlay() (KnackDB.settings.showGCD and gcdOverlay.Show or gcdOverlay.Hide)(gcdOverlay) end
function KnackUpdateHotkeyFont() 
    local fontPath = GetFontPath(KnackDB.settings.hotkeyFont)
    hotkeyText:SetFont(fontPath, KnackDB.settings.hotkeySize, "OUTLINE") 
end
function KnackUpdateHotkeySize() 
    local fontPath = GetFontPath(KnackDB.settings.hotkeyFont)
    hotkeyText:SetFont(fontPath, KnackDB.settings.hotkeySize, "OUTLINE") 
end
function KnackUpdateIconSize() local size = KnackDB.settings.iconSize frame:SetSize(size, size) icon:SetSize(size - ICON_PADDING, size - ICON_PADDING) end
function KnackResetPosition() KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = "CENTER", "CENTER", 0, 0 ApplyPosition() end

-- Slash command
SLASH_KNACK1 = "/knack"
SlashCmdList["KNACK"] = function(msg)
    if msg == "reset" then
        KnackResetPosition()
        print("|cff00ff00[knack]|r position reset to center.")
    else
        KnackOpenSettings()
    end
end
