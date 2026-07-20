# Stickman Gate

A tiny 2D platformer where you run a single hand-crafted level, fight off patrolling stickmen, and finish with a multi-phase boss fight before a gate crumbles open to the exit flag.

## What this is

This is a first-attempt platformer built to explore core game-feel mechanics (coyote time, jump buffering, dashing, hitstop, screen shake) and a scripted boss encounter. One continuous level: fight through patrolling enemies, grab a weapon upgrade, then trigger an arena gate that seals behind you and wakes "THE AMALGAM" — a boss with six telegraphed attack patterns and an enrage phase. Defeating it crumbles the exit gate to the level's flag.

## Features

- Platformer movement: run/jump with acceleration & friction curves, coyote time, jump buffering, variable jump height (cut on release), and a short invincible dash with an afterimage trail
- Shooting: swappable weapon stats (starts with a pistol; a pickup crate upgrades to a triple-shot rifle), with muzzle flash, recoil, and pooled bullets
- Patrolling enemies that turn at walls/ledges, with knockback and death effects
- Boss fight: "THE AMALGAM" — six attack patterns (ground slam, arm whip, thrown skulls, minion summon, wall-crashing charge with a stun punish window, radial orb burst), phase-2 enrage below 50% HP, and an arena that seals/reopens via gate tiles
- HUD with hearts, kill counter, boss health bar, toast messages, and start/death/win screens
- Juice: hit-flash shader, hitstop on big hits, camera shake, particle effects (dust, debris, death bursts)

## Controls

| Action | Keys |
|---|---|
| Move | A/D or Arrow Left/Right |
| Jump | Space, W, or Arrow Up |
| Shoot | J or Left Mouse Button |
| Dash | Shift |
| Confirm/Restart (start, death, win screens) | Jump or Shoot key |

## Tech

- Godot 4.7, mobile rendering method, 480x270 base viewport (canvas_items stretch)
- GDScript, organized as `scripts/` (player, enemy, boss, components), `scenes/`, `shaders/` (hit-flash), `assets/` (sprite sheets, sfx), `resources/` (tileset, weapon stat resources)
- Composition-based actors: `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `WeaponComponent` are shared child nodes reused across Player/Enemy/Boss
- `addons/godot_ai/` is an internal AI-assisted-development helper used during building the project; it has no gameplay role

## Running it

Open the project folder in Godot 4.7 (or later) and press Run — the main scene (`scenes/main.tscn`) launches directly into the level.
