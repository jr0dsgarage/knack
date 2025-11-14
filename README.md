# Knack

A World of Warcraft addon that displays the next spell highlighted by the Assisted Combat feature with hotkey bindings.

## Features

- **Assisted Combat Integration**: Displays the spell icon recommended by WoW's Assisted Combat system
- **Hotkey Display**: Shows the keybinding for the recommended spell in the upper right corner
- **Draggable**: Hold SHIFT and drag to reposition the icon anywhere on screen
- **GCD Overlay**: Optional visual indicator showing when spells are on global cooldown
- **Customizable Settings**:
  - Enable/disable the addon
  - Show only when targeting an enemy
  - Toggle GCD overlay with adjustable opacity
  - Adjustable hotkey text size
  - Position reset button

## Installation

1. Download the addon
2. Extract to `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or reload UI with `/reload`

## Usage

- The spell icon appears automatically when Assisted Combat recommends a spell
- Hold **SHIFT** and drag the icon to reposition it
- Access settings via the WoW interface options: **ESC > Interface > AddOns > Knack**
- Use `/knack reset` to reset the icon position to screen center

## Commands

- `/knack reset` - Reset icon position to center of screen

## Requirements

- World of Warcraft 12.0.0 or later
- Assisted Combat mode enabled (automatically enabled by the addon)

## Settings

Access the settings panel through the WoW interface options menu:

- **Enable Knack**: Toggle the addon on/off
- **Only show with enemy target**: Only display when you have a valid enemy targeted
- **Show Global Cooldown overlay**: Display a darkening effect during GCD
- **GCD Overlay Opacity**: Adjust the darkness of the GCD overlay (0-100%)
- **Hotkey Size**: Adjust the size of the hotkey text (14-34)
- **Reset Position**: Move the icon back to the center of the screen

## Credits

Created for WoW 12.0.0 using the C_AssistedCombat API.
