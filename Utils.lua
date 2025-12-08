local addonName, ns = ...
local CONSTANTS = ns.CONSTANTS
local LSM = ns.LSM

local BindingUtils = {}
ns.BindingUtils = BindingUtils

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
