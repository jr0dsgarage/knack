local addonName = ...

local FONT_PATH = "Fonts\\FRIZQT__.TTF"
local MOVE_CURSOR = "Interface\\CURSOR\\UI-Cursor-Move"
local GCD_SPELL_ID = 61304
local SCAN_INTERVAL = 0.1

local function GetBindingNameForSlot(slot)
    if not slot then return nil end
    local button = ((slot - 1) % 12) + 1
    local ranges = {{61, "MULTIACTIONBAR1BUTTON"}, {49, "MULTIACTIONBAR2BUTTON"}, {37, "MULTIACTIONBAR3BUTTON"}, {25, "MULTIACTIONBAR4BUTTON"}}
    for _, r in ipairs(ranges) do
        if slot >= r[1] and slot < r[1] + 12 then return r[2] .. button end
    end
    return "ACTIONBUTTON" .. button
end

local function SelectBinding(b1, b2)
    return b1 and b1:find("-") and b1 or b2 and b2:find("-") and b2 or b1 or b2
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
    local fx, fy, px, py = frame:GetCenter(), UIParent:GetCenter()
    if fx and px then
        KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = "CENTER", "CENTER", fx - px, fy - py
    end
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
frame:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePosition() ApplyPosition() end)

frame:SetScript("OnUpdate", function() (IsShiftKeyDown() and MouseIsOver(frame) and SetCursor or ResetCursor)(MOVE_CURSOR) end)

local function ShouldDisplay()
    return KnackDB.settings.enabled and (not KnackDB.settings.onlyWithEnemyTarget or (UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target"))) and C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
end

local function GetHotkeyInfo(spellID)
    local slots = C_ActionBar.FindSpellActionButtons(spellID)
    if not slots or not slots[1] then return "", true end
    local bindingName = GetBindingNameForSlot(slots[1])
    local binding = bindingName and SelectBinding(GetBindingKey(bindingName))
    return FormatBinding(binding), C_Spell.IsSpellInRange(spellID, "target") ~= false
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
function KnackUpdateVisibility() if KnackDB.settings.enabled then UpdateDisplay() else frame:Hide() end end
function KnackUpdateGCDOverlay() (KnackDB.settings.showGCD and gcdOverlay.Show or gcdOverlay.Hide)(gcdOverlay) end
function KnackUpdateHotkeySize() hotkeyText:SetFont(FONT_PATH, KnackDB.settings.hotkeySize, "OUTLINE") end
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
