local addonName, ns = ...
local CONSTANTS = ns.CONSTANTS
local BindingUtils = ns.BindingUtils
local KnackDisplay = ns.KnackDisplay

-- Core Logic
local Knack = {
    display = nil,
    lastScan = 0
}

function Knack:UpdateCooldownManagerIcons(frame, managerName)
    if not frame then return end
    
    -- Determine settings based on managerName
    local isEssential = (managerName == "EssentialCooldownViewer")
    local isUtility = (managerName == "UtilityCooldownViewer")
    
    local enabled = false
    local fontName = "Friz Quadrata TT"
    local fontSize = 14
    local hotkeyAnchor = "TOPRIGHT"
    
    if KnackDB and KnackDB.settings then
        if isEssential then
            enabled = KnackDB.settings.cooldownEnableEssential
            fontName = KnackDB.settings.cooldownEssentialFont
            fontSize = KnackDB.settings.cooldownEssentialFontSize
            hotkeyAnchor = KnackDB.settings.cooldownEssentialHotkeyAnchor or "TOPRIGHT"
        elseif isUtility then
            enabled = KnackDB.settings.cooldownEnableUtility
            fontName = KnackDB.settings.cooldownUtilityFont
            fontSize = KnackDB.settings.cooldownUtilityFontSize
            hotkeyAnchor = KnackDB.settings.cooldownUtilityHotkeyAnchor or "TOPRIGHT"
        end
    end
    
    -- Default to enabled if settings not yet initialized (shouldn't happen but safe fallback)
    if KnackDB and not KnackDB.settings then enabled = true end

    local children = { frame:GetChildren() }

    for i, child in ipairs(children) do
        local spellID = child.spellID
        if not spellID and child.GetSpellID then
            spellID = child:GetSpellID()
        end

        if spellID then
            if not child.hotkeyText then
                child.hotkeyText = child:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                child.hotkeyText:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
                child.hotkeyText:SetShadowColor(0, 0, 0, 1)
                child.hotkeyText:SetShadowOffset(1, -1)
            end
            
            if enabled then
                local hotkey = BindingUtils.GetHotkeyInfo(spellID)
                child.hotkeyText:SetText(hotkey)
                
                local fontPath = BindingUtils.GetFontPath(fontName)
                local size = fontSize or KnackDefaultSettings.hotkeySize
                child.hotkeyText:SetFont(fontPath, size, "OUTLINE")
                
                local color = CONSTANTS.FONT.COLOR_IN_RANGE
                child.hotkeyText:SetTextColor(color.r, color.g, color.b, color.a)
                
                -- Update Anchor
                child.hotkeyText:ClearAllPoints()
                child.hotkeyText:SetPoint(hotkeyAnchor, child, hotkeyAnchor, CONSTANTS.FONT.OFFSET, CONSTANTS.FONT.OFFSET)
                
                if hotkeyAnchor:find("LEFT") then
                    child.hotkeyText:SetJustifyH("LEFT")
                elseif hotkeyAnchor:find("RIGHT") then
                    child.hotkeyText:SetJustifyH("RIGHT")
                else
                    child.hotkeyText:SetJustifyH("CENTER")
                end
                
                child.hotkeyText:Show()
            else
                child.hotkeyText:Hide()
            end
        end
    end
end

function Knack:SetupCooldownManagers()
    local managers = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
    
    for _, name in ipairs(managers) do
        local frame = _G[name]
        if frame then
            if frame.Update then
                hooksecurefunc(frame, "Update", function(self)
                    Knack:UpdateCooldownManagerIcons(self, name)
                end)
            end
            
            if frame.HookScript then
                frame:HookScript("OnShow", function(self)
                    Knack:UpdateCooldownManagerIcons(self, name)
                end)
            end
            
            Knack:UpdateCooldownManagerIcons(frame, name)
        end
    end
end

function Knack:Initialize()
    KnackDB = KnackDB or { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0, settings = {} }
    self.display = KnackDisplay:New()
    
    self:SetupEvents()
    self:SetupSlashCommands()
    self:SetupCooldownManagers()
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
            self:SetupCooldownManagers()
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

function KnackUpdateCooldownManagers()
    local managers = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
    for _, name in ipairs(managers) do
        local frame = _G[name]
        if frame then
            Knack:UpdateCooldownManagerIcons(frame, name)
        end
    end
end
