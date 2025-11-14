local addonName = ...

local FONT_PATH = "Fonts\\FRIZQT__.TTF"
local MOVE_CURSOR = "Interface\\CURSOR\\UI-Cursor-Move"
local GCD_SPELL_ID = 61304
local SCAN_INTERVAL = 0.1

local bindingRanges = {
    { 61, 72, "MULTIACTIONBAR1BUTTON" }, -- Bottom Left
    { 49, 60, "MULTIACTIONBAR2BUTTON" }, -- Bottom Right
    { 37, 48, "MULTIACTIONBAR3BUTTON" }, -- Right 1
    { 25, 36, "MULTIACTIONBAR4BUTTON" }, -- Right 2
}

local function GetBindingNameForSlot(slot)
    if not slot then return nil end

    local button = ((slot - 1) % 12) + 1
    for _, range in ipairs(bindingRanges) do
        local minSlot, maxSlot, prefix = range[1], range[2], range[3]
        if slot >= minSlot and slot <= maxSlot then
            return prefix .. button
        end
    end

    return "ACTIONBUTTON" .. button
end

local function SelectBinding(binding1, binding2)
    if not binding1 then return binding2 end
    if not binding2 then return binding1 end

    if binding1:find("-") then
        return binding1
    elseif binding2:find("-") then
        return binding2
    end

    return binding1
end

local function FormatBinding(binding)
    if not binding then return "" end
    return binding:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M")
end

-- Initialize saved variables
KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }

-- Create main frame
local frame = CreateFrame("Frame", "KnackFrame", UIParent)
frame:SetSize(64, 64)
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
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not frameX or not parentX then return end

    KnackDB.point, KnackDB.relativePoint = "CENTER", "CENTER"
    KnackDB.xOfs, KnackDB.yOfs = frameX - parentX, frameY - parentY
end

-- Create background
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)
bg:SetColorTexture(0, 0, 0, 0.5)

-- Create spell icon
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetPoint("CENTER")
icon:SetSize(60, 60)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

-- Create hotkey text
local hotkeyText = frame:CreateFontString(nil, "OVERLAY")
hotkeyText:SetFont(FONT_PATH, KnackDB.settings.hotkeySize or 14, "OUTLINE")
hotkeyText:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 2, 2)
hotkeyText:SetTextColor(1, 1, 1, 1)

-- Create GCD overlay (Cooldown frame)
local gcdOverlay = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
gcdOverlay:SetAllPoints(icon)
gcdOverlay:SetDrawEdge(false)
gcdOverlay:SetDrawSwipe(true)
gcdOverlay:SetReverse(false)
gcdOverlay:SetHideCountdownNumbers(true)
if gcdOverlay.SetSwipeColor then
    gcdOverlay:SetSwipeColor(0, 0, 0, 1) -- Black swipe, we'll control alpha separately
end
gcdOverlay:Hide()

-- Dragging
frame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
    ApplyPosition()
end)

local function UpdateCursor()
    if IsShiftKeyDown() and MouseIsOver(frame) then
        SetCursor(MOVE_CURSOR)
    else
        ResetCursor()
    end
end

frame:SetScript("OnUpdate", UpdateCursor)

local function ShouldDisplay()
    if not KnackDB.settings.enabled then
        return false
    end

    if KnackDB.settings.onlyWithEnemyTarget and (not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target")) then
        return false
    end

    return C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
end

local function GetHotkeyInfo(spellID)
    local slots = C_ActionBar.FindSpellActionButtons(spellID)
    if not slots or not slots[1] then
        return "", true
    end

    local bindingName = GetBindingNameForSlot(slots[1])
    local bindingPrimary, bindingSecondary
    if bindingName then
        bindingPrimary, bindingSecondary = GetBindingKey(bindingName)
    end
    local binding = SelectBinding(bindingPrimary, bindingSecondary)
    local formatted = FormatBinding(binding)
    local inRange = C_Spell.IsSpellInRange(spellID, "target") ~= false

    return formatted, inRange
end

-- Update the display
local function UpdateDisplay()
    if not ShouldDisplay() then
        frame:Hide()
        return
    end

    local success, spellID = pcall(C_AssistedCombat.GetNextCastSpell, true)
    if not success or not spellID or spellID == 0 then
        frame:Hide()
        return
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then
        frame:Hide()
        return
    end

    icon:SetTexture(spellInfo.iconID)

    local hotkey, inRange = GetHotkeyInfo(spellID)
    hotkeyText:SetText(hotkey)
    hotkeyText:SetTextColor(inRange and 1 or 0.8, inRange and 1 or 0.1, inRange and 1 or 0.1, 1)

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
        -- Apply saved hotkey size
        hotkeyText:SetFont(FONT_PATH, KnackDB.settings.hotkeySize or 14, "OUTLINE")
        print("|cff00ff00[knack]|r loaded. Hold SHIFT to move the icon.")
    elseif event == "PLAYER_LOGIN" then
        ApplyPosition()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateDisplay()
    end
end)

-- Global functions for settings panel
function KnackUpdateVisibility()
    if KnackDB.settings.enabled then UpdateDisplay() else frame:Hide() end
end

function KnackUpdateGCDOverlay()
    if KnackDB.settings.showGCD then gcdOverlay:Show() else gcdOverlay:Hide() end
end

function KnackUpdateHotkeySize()
    hotkeyText:SetFont(FONT_PATH, KnackDB.settings.hotkeySize, "OUTLINE")
end

function KnackResetPosition()
    KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = "CENTER", "CENTER", 0, 0
    ApplyPosition()
end

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
