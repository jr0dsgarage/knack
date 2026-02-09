# knack - Assisted Combat Spell Display

## Architecture Overview

World of Warcraft addon that displays the spell icon recommended by WoW's Assisted Combat system with hotkey bindings overlaid. Shows next spell, range status, GCD overlay, and tooltips.

**Core Components:**
- [`knack.lua`](../knack.lua): Main logic, event handling, cooldown manager integration
- [`Display.lua`](../Display.lua): Icon rendering, positioning, GCD/cast overlays, tooltip handling
- [`Constants.lua`](../Constants.lua): All constants including font paths, icon sizes, action bar slot mappings
- [`Utils.lua`](../Utils.lua): Binding resolution (action bar → keybind), font path resolution via LSM
- [`Settings.lua`](../Settings.lua): UI settings panel with organized sections

**Load Order:** [`knack.toc`](../knack.toc) - Constants → Utils → Settings → Display → knack.lua

## WoW API Integration Points

**Assisted Combat System:**
```lua
-- Core API calls in knack.lua
C_SpellBook.GetCurrentAssistSpell()  -- Returns spellID of recommended spell
C_Spell.IsSpellInRange(spellID, "target")  -- Range checking (false = out of range)
```

**Action Bar Slot Resolution:**
- Use `C_ActionBar.FindSpellActionButtons(spellID)` to get all slots containing the spell
- Map slot numbers to binding names via `CONSTANTS.ACTION_BAR.SLOTS` table
- Binding resolution order: Bar 8→7→6→2→3→5→4, then current action bar page
- See [`Utils.lua:9-30`](../Utils.lua#L9-L30) for slot→binding logic

**Cooldown Managers (Optional Integration):**
- Hooks `EssentialCooldownViewer` and `UtilityCooldownViewer` frames if present
- Uses `hooksecurefunc(frame, "Update", ...)` to inject hotkey text without breaking functionality
- Must handle restricted table access with pcall safety (see [`knack.lua:17-89`](../knack.lua#L17-L89))

## Critical Development Patterns

**Safe Table Access (Restricted Tables):**
```lua
-- Action bar slots API returns restricted tables - must use pcall
local isSafe, firstSlot = pcall(function() return slots and slots[1] end)
if not isSafe or not firstSlot then return "", true end
```

**Namespace Structure:**
```lua
local addonName, ns = ...
ns.CONSTANTS = {...}  -- Define in Constants.lua
ns.BindingUtils = {...}  -- Define in Utils.lua
local CONSTANTS = ns.CONSTANTS  -- Import in other files
```

**SavedVariables:**
- `KnackDB` persists settings (declared in .toc)
- Default values provided through fallback logic
- Settings organized: Enable, Icon Size/Position, Hotkey Font/Size, Tooltips, GCD Overlay

## Icon Display Logic

**Frame Structure:**
```lua
-- Display.lua creates overlay icon frame
frame = CreateFrame("Frame", "KnackIconFrame", UIParent)
frame.texture = frame:CreateTexture(nil, "BACKGROUND")  -- Spell icon
frame.border = frame:CreateTexture(nil, "BORDER")  -- Icon border
frame.hotkeyText = frame:CreateFontString(nil, "OVERLAY")  -- Keybind text
frame.gcdOverlay = frame:CreateTexture(nil, "OVERLAY")  -- GCD darkening effect
```

**Position/Size Persistence:**
- SHIFT + drag to reposition (uses `:StartMoving()` API)
- SHIFT + scrollwheel to resize (adjusts both frame and texture)
- Position saved to `KnackDB.position` as `{point, relativeTo, relativePoint, x, y}`
- Size saved to `KnackDB.iconSize` (range: 24-128)

**GCD Overlay Pattern:**
- Full-frame black texture with adjustable opacity
- Shows/hides based on `C_Spell.GetSpellCooldown(CONSTANTS.GCD.SPELL_ID)`
- Cooldown check runs on ticker, not on every frame
- GCD spell ID: 61304 (standard global cooldown tracker)

## Binding Display Formatting

**Hotkey Text Transformation:**
```lua
-- Utils.lua:FormatBinding compresses modifier names
"SHIFT-1" → "S-1"
"CTRL-ALT-2" → "C-A-2"  
"BUTTON3" → "M3"  -- Mouse buttons
```

**Multi-Binding Display:**
- Shows up to 3 bindings max (`CONSTANTS.ACTION_BAR.MAX_BINDINGS`)
- Separated by newlines if multiple bindings found
- Color: White when in range, Red (#CC1919) when out of range

**Binding Selection Priority:**
- Prefer modified bindings (with SHIFT/CTRL/ALT) over unmodified
- Logic: `b1 and b1:find("-") and b1 or b2 and b2:find("-") and b2 or b1 or b2`

## LibSharedMedia-3.0 Integration

**Optional Dependency:**
```lua
-- Constants.lua provides LSM fallback if library not loaded
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if not LSM then
    LSM = { Fetch = function(...) end, List = function(...) end }  -- Stub implementation
end
```

**Font Resolution:**
- `LSM:Fetch("font", fontName)` returns full path to font file
- Fallback fonts: "Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus"
- Default: `Fonts\\FRIZQT__.TTF`

## Testing Workflows

**In-Game Commands:**
- `/knack` - Open settings panel
- `/knack reset` - Reset icon position to center

**Verification Steps:**
1. Enable Assisted Combat (addon auto-enables via CVar)
2. Target an enemy NPC
3. Watch for spell icon to appear
4. Verify hotkey text shows correct binding
5. Test range indicator: Move out of spell range → text turns red
6. Test GCD overlay: Cast spell → icon darkens briefly
7. SHIFT + drag/scroll to test positioning/sizing

**Common Issues:**
- No icon showing: Check if Assisted Combat disabled in WoW settings, check if `KnackDB.enabled == false`
- Wrong hotkey: Verify spell is on action bars, check action bar slot mapping in Constants.lua
- Blank hotkey: No keybind set for that spell's action bar button

## Constants Reference

Key values in [`Constants.lua`](../Constants.lua):
- `FONT.COLOR_IN_RANGE`: `{r=1, g=1, b=1, a=1}` (white)
- `FONT.COLOR_OUT_OF_RANGE`: `{r=0.8, g=0.1, b=0.1, a=1}` (red)
- `ICON.MIN_SIZE`: 10, `ICON.MAX_SIZE`: 128
- `GCD.SPELL_ID`: 61304 (used to query GCD status)
- `ACTION_BAR.SLOTS`: Maps slot ranges (169-180, 157-168, etc.) to binding prefixes
