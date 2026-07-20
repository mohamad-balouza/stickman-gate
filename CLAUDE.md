# Godot Stickman Platformer

Build a 2D pixel-art stickman platformer in this Godot project. Use the **godot-ai MCP** (connected via localhost:8000/mcp) to create scenes, scripts, run the game, and test.

## Requirements

### Visual & Assets
- Player and enemies are **stickmen/stickfigures** with pixel art animations (idle, run, jump, shoot, death)
- Pixel art rendering (nearest filtering, small viewport)
- Generate textures procedurally via the godot-ai MCP tools

### Player Movement (polished)
- Acceleration/deceleration with max run speed
- Variable jump height (release early = short hop)
- Coyote time (~0.1s grace when walking off edges)
- Jump buffering (~0.1s before landing)
- Good air control
- Sprite flip direction based on movement

### Combat
- Enemies that patrol and/or chase the player
- Player can shoot bullets
- Optimized bullets with good fire rate and speed
- Hit feedback (flash, knockback, particles)
- Score +100 per kill

### 1 Weapon Upgrade (Composition Architecture)
- One pickup in the level that upgrades the weapon
- Use **composition architecture** - WeaponComponent with swappable WeaponConfig Resource
- Base: single shot, moderate fire rate
- Upgrade: spread shot (3 bullets) + faster fire
- Different bullet color/icon for upgrade

### UI (Polished)
- Health bar (pixel hearts)
- Weapon indicator (icon + name)
- Score counter
- Game Over and Win screens

### Level
- One well-crafted level ~120 tiles wide
- Platforms, gaps, spike pits, enemy encounters
- The upgrade pickup placed on a high ledge
- Goal flag at the end
- Camera2D with smoothing + limits
- Kill zone below the map

### Architecture
- CharacterBody2D for player and enemies
- Composition components: HealthComponent, WeaponComponent, HitboxComponent/HurtboxComponent
- Bullet pooling for performance
- State machine for animations (idle, run, jump, fall, shoot, death)

### Testing
- After creating scenes/scripts, run the game via godot-ai MCP
- Verify everything works
- Take screenshots
- Fix any errors from game logs

Make reasonable decisions on your own about details not specified here.