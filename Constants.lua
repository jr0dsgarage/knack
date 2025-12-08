local addonName, ns = ...

-- LibSharedMedia Fallback
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
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
ns.LSM = LSM

-- Constants
ns.CONSTANTS = {
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
