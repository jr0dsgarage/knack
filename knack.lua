-- Knack: Assisted Highlight Spell Display
local addonName = ...

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

-- Dragging
frame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = point, relativePoint, xOfs, yOfs
end)

frame:SetScript("OnUpdate", function(self)
    if IsShiftKeyDown() and MouseIsOver(self) then
        SetCursor("Interface\\CURSOR\\UI-Cursor-Move")
    else
        ResetCursor()
    end
end)

-- Update the display
local function UpdateDisplay()
    if not KnackDB.settings.enabled then
        frame:Hide()
        return
    end
    
    if KnackDB.settings.onlyWithEnemyTarget and (not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target")) then
        frame:Hide()
        return
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
    
    -- Find keybind and check range
    local hotkey = ""
    local inRange = true
    local slots = C_ActionBar.FindSpellActionButtons(spellID)
    if slots and #slots > 0 then
        local slot = slots[1]
        local actionBar = slot <= 12 and "ACTIONBUTTON" or slot <= 24 and "MULTIACTIONBAR1BUTTON" or slot <= 36 and "MULTIACTIONBAR2BUTTON" or slot <= 48 and "MULTIACTIONBAR3BUTTON" or "MULTIACTIONBAR4BUTTON"
        local buttonNum = slot <= 12 and slot or (slot - 12) % 12
        if buttonNum == 0 then buttonNum = 12 end
        hotkey = GetBindingKey(actionBar .. buttonNum) or ""
        hotkey = hotkey:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("BUTTON", "M")
        
        -- Check if spell is in range
        inRange = C_Spell.IsSpellInRange(spellID, "target") ~= false
    end
    
    hotkeyText:SetText(hotkey)
    hotkeyText:SetTextColor(inRange and 1 or 0.8, inRange and 1 or 0.1, inRange and 1 or 0.1, 1)
    
    -- Update GCD overlay
    if KnackDB.settings.showGCD then
        local spellCooldown = C_Spell.GetSpellCooldown(61304)
        if spellCooldown and spellCooldown.startTime and spellCooldown.duration then
            gcdOverlay:SetCooldown(spellCooldown.startTime, spellCooldown.duration)
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

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Apply saved hotkey size
        hotkeyText:SetFont("Fonts\\FRIZQT__.TTF", KnackDB.settings.hotkeySize or 14, "OUTLINE")
        print("|cff00ff00[knack]|r loaded. Hold SHIFT to move the icon.")
    elseif event == "PLAYER_LOGIN" then
        frame:ClearAllPoints()
        frame:SetPoint(KnackDB.point, UIParent, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs)
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
    hotkeyText:SetFont("Fonts\\FRIZQT__.TTF", KnackDB.settings.hotkeySize, "OUTLINE")
end

function KnackResetPosition()
    KnackDB.point, KnackDB.relativePoint, KnackDB.xOfs, KnackDB.yOfs = "CENTER", "CENTER", 0, 0
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
