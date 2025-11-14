-- Knack: Assisted Highlight Spell Display
local addonName, addon = ...

-- Initialize saved variables
KnackDB = KnackDB or {
    point = "CENTER",
    relativePoint = "CENTER",
    xOfs = 0,
    yOfs = 0,
    settings = {
        enabled = true,
        onlyWithEnemyTarget = false,
        showGCD = true,
        gcdOpacity = 0.7,
        hotkeySize = 14,
    }
}

-- Create main frame
local frame = CreateFrame("Frame", "KnackFrame", UIParent)
frame:SetSize(64, 64)
frame:SetPoint(KnackDB.point, UIParent, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:Hide()

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
hotkeyText:SetFont("Fonts\\FRIZQT__.TTF", KnackDB.settings.hotkeySize or 14, "OUTLINE")
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

-- Dragging (only when SHIFT is held)
frame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    KnackDB.point = point
    KnackDB.relativePoint = relativePoint
    KnackDB.xOfs = xOfs
    KnackDB.yOfs = yOfs
end)

-- Update cursor when shift is held
frame:SetScript("OnUpdate", function(self)
    if IsShiftKeyDown() and MouseIsOver(self) then
        SetCursor("Interface\\CURSOR\\UI-Cursor-Move")
    else
        ResetCursor()
    end
end)

-- Update the display based on assisted combat
local function UpdateDisplay()
    -- Check if addon is enabled
    if not KnackDB.settings.enabled then
        frame:Hide()
        return
    end
    
    -- Check enemy target requirement
    if KnackDB.settings.onlyWithEnemyTarget then
        if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target") then
            frame:Hide()
            return
        end
    end
    
    if not C_AssistedCombat or not C_AssistedCombat.GetNextCastSpell then
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
    
    -- Find keybind
    local hotkey = ""
    local slots = C_ActionBar.FindSpellActionButtons(spellID)
    if slots and #slots > 0 then
        local slot = slots[1]
        if slot <= 12 then
            hotkey = GetBindingKey("ACTIONBUTTON" .. slot)
        elseif slot <= 24 then
            hotkey = GetBindingKey("MULTIACTIONBAR1BUTTON" .. (slot - 12))
        elseif slot <= 36 then
            hotkey = GetBindingKey("MULTIACTIONBAR2BUTTON" .. (slot - 24))
        elseif slot <= 48 then
            hotkey = GetBindingKey("MULTIACTIONBAR3BUTTON" .. (slot - 36))
        elseif slot <= 60 then
            hotkey = GetBindingKey("MULTIACTIONBAR4BUTTON" .. (slot - 48))
        end
    end
    
    -- Format hotkey
    if hotkey then
        hotkey = hotkey:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M")
    end
    
    hotkeyText:SetText(hotkey or "")
    
    -- Update GCD overlay - Cooldown frame handles its own visibility
    if KnackDB.settings.showGCD then
        local spellCooldown = C_Spell.GetSpellCooldown(61304) -- GCD spell ID
        if spellCooldown and spellCooldown.startTime and spellCooldown.duration then
            gcdOverlay:SetCooldown(spellCooldown.startTime, spellCooldown.duration)
            -- Control opacity through the swipe color
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
scanFrame:SetScript("OnUpdate", function(self, elapsed)
    lastScan = lastScan + elapsed
    if lastScan >= 0.1 then
        lastScan = 0
        UpdateDisplay()
    end
end)

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        print("|cff00ff00Knack|r loaded. Hold SHIFT to move the icon.")
    elseif event == "PLAYER_LOGIN" then
        frame:ClearAllPoints()
        frame:SetPoint(KnackDB.point, UIParent, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs)
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateDisplay()
    end
end)

-- Global functions for settings panel
function KnackUpdateVisibility()
    if KnackDB.settings.enabled then
        UpdateDisplay()
    else
        frame:Hide()
    end
end

function KnackUpdateGCDOverlay()
    if KnackDB.settings.showGCD then
        gcdOverlay:Show()
    else
        gcdOverlay:Hide()
    end
end

function KnackUpdateHotkeySize()
    hotkeyText:SetFont("Fonts\\FRIZQT__.TTF", KnackDB.settings.hotkeySize, "OUTLINE")
end

function KnackResetPosition()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- Slash command
SLASH_KNACK1 = "/knack"
SlashCmdList["KNACK"] = function(msg)
    if msg == "reset" then
        KnackDB.point = "CENTER"
        KnackDB.relativePoint = "CENTER"
        KnackDB.xOfs = 0
        KnackDB.yOfs = 0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("|cff00ff00Knack|r position reset to center.")
    else
        print("|cff00ff00Knack|r - Displays assisted highlight spells")
        print("  /knack reset - Reset position to center")
        print("  Hold SHIFT and drag to move the icon")
    end
end
