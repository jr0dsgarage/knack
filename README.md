# knack

A World of Warcraft addon that displays the next spell highlighted by the Assisted Combat feature with hotkey bindings.

## Features

- **Assisted Combat Integration**: Displays the spell icon recommended by WoW's Assisted Combat system
- **Hotkey Display**: Shows the keybinding for the recommended spell in the upper right corner
- **Range Indicator**: Hotkey text turns red when the target is out of range
- **Draggable**: Hold SHIFT and drag to reposition the icon anywhere on screen
- **Resizable**: Hold SHIFT and use the scrollwheel to resize the icon
- **GCD Overlay**: Optional visual indicator showing when spells are on global cooldown
- **Spell Tooltips**: Optional mouseover tooltips showing spell details
- **Customizable Settings**:
  - Enable/disable the addon
  - Show only when targeting an enemy
  - Adjustable icon size (24-128)
  - Customizable hotkey font with LibSharedMedia-3.0 support
  - Adjustable hotkey text size (8-34)
  - Toggle spell tooltips with combat visibility option
  - Toggle GCD overlay with adjustable opacity
  - Position reset button

## Installation

1. Download the addon
2. Extract to `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or reload UI with `/reload`

## Usage

- The spell icon appears automatically when Assisted Combat recommends a spell
- Hold **SHIFT** and drag the icon to reposition it
- Hold **SHIFT** and use the **scrollwheel** to resize the icon
- Access settings via `/knack` command or **ESC > Interface > AddOns > knack**
- The hotkey turns red when your target is out of range
- Hover over the icon to see the spell tooltip (if enabled)

## Commands

- `/knack` - Open the knack settings panel
- `/knack reset` - Reset icon position to center of screen

## Requirements

- World of Warcraft 12.0.0 or later
- Assisted Combat mode enabled (automatically enabled by the addon)

## Settings

Access the settings panel through `/knack` or the WoW interface options menu. Settings are organized into groups:

### Enable & Enemy Target

- **Enable knack**: Toggle the addon on/off
- **Only show with enemy target**: Only display when you have a valid enemy targeted

### Icon Size & Position

- **Icon Size**: Adjust the size of the spell icon (24-128)
- **Reset Position**: Move the icon back to the center of the screen

### Hotkey Font & Size

- **Hotkey Font**: Choose from available fonts (supports LibSharedMedia-3.0 fonts)
- **Hotkey Font Size**: Adjust the size of the hotkey text (8-34)

### Tooltips

- **Show spell tooltip on mouseover**: Display spell information when hovering over the icon
- **Hide tooltip in combat**: Only show tooltips when out of combat

### GCD Overlay

- **Show Global Cooldown overlay**: Display a darkening effect during GCD
- **GCD Overlay Opacity**: Adjust the darkness of the GCD overlay (0-100%)

## Credits

Created for WoW 12.0.0 using the C_AssistedCombat API.
