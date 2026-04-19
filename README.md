# Nah Ad Propaganda

A 2D Metroidvania/platformer set in a post-dystopian world where an authoritarian government controls the population through propaganda. Play as an ordinary citizen rising up against the regime, armed with nothing but a sword, determination, and a Clarity Shield that cuts through the lies.

## Game Overview

- **Genre:** 2D Metroidvania/Platformer
- **Engine:** Godot 4.2
- **Art Style:** Pixel art (Blasphemous-inspired)
- **Status:** Demo (Tutorial + Level 01 + Boss Fight)

## Features

- **Sanity System** — Instead of health, your character has sanity. Propaganda attacks drain your sanity. Lose it all, and you lose your mind.
- **Propaganda Mechanics** — Destroy propaganda machines, deprogram brainwashed citizens, and resist government brainwashing.
- **Clarity Shield** — Your primary defense against propaganda. Block propaganda bombs, absorb their power, and upgrade your shield.
- **Skill Tree** — Three upgrade paths: Combat, Sanity, and Shield. Earn skill points from bosses and special objectives.
- **Satirical Tone** — Over-the-top propaganda posters, absurd news broadcasts, NPCs spouting ridiculous government slogans.
- **Boss Fights** — Face propaganda lieutenants, media moguls, and enforcers on your way to confront the Supreme Leader.

## Controls

| Action | Keyboard | Mouse |
|--------|----------|-------|
| Move | A/D or Arrow Keys | — |
| Jump | Space / W / Up | — |
| Melee Attack | J | Left Click |
| Ranged Attack | K | Right Click |
| Clarity Shield | Shift | — |
| Interact | E | — |
| Pause | Escape | — |

## Demo Content

- **Tutorial** — Learn movement, combat, and propaganda mechanics
- **Level 01: The Broadcast Quarter** — Navigate through propaganda-filled streets
- **Boss: The Propaganda Lieutenant** — Your first real test against the regime

## Project Structure

```
Nah Ad Propaganda/
├── project.godot
├── export_presets.cfg
├── .gitignore
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   ├── fonts/
│   ├── shaders/
│   │   └── sanity_distortion.gdshader
│   └── sprites/
│       ├── enemies/
│       ├── objects/
│       ├── player/
│       ├── tiles/
│       └── ui/
├── docs/
│   └── .gdignore
├── scenes/
│   ├── effects/
│   │   ├── damage_number.tscn
│   │   ├── death_effect.tscn
│   │   ├── hit_spark.tscn
│   │   └── shield_effect.tscn
│   ├── enemies/
│   │   ├── boss_lieutenant.tscn
│   │   ├── propaganda_bomb.tscn
│   │   ├── propaganda_drone.tscn
│   │   ├── propaganda_soldier.tscn
│   │   └── shockwave.tscn
│   ├── levels/
│   │   ├── level_01.tscn
│   │   ├── parallax_city.tscn
│   │   └── tutorial.tscn
│   ├── objects/
│   │   ├── checkpoint.tscn
│   │   ├── npc.tscn
│   │   ├── propaganda_machine.tscn
│   │   └── sanity_pickup.tscn
│   ├── player/
│   │   ├── player.tscn
│   │   └── projectile.tscn
│   └── ui/
│       ├── credits.tscn
│       ├── dialogue_box.tscn
│       ├── game_over.tscn
│       ├── hud.tscn
│       ├── main_menu.tscn
│       ├── pause_menu.tscn
│       ├── settings_menu.tscn
│       ├── skill_tree.tscn
│       └── victory_screen.tscn
└── scripts/
    ├── autoload/
    │   ├── audio_manager.gd
    │   ├── effects_manager.gd
    │   ├── game_manager.gd
    │   ├── sanity_manager.gd
    │   ├── save_manager.gd
    │   └── skill_tree_manager.gd
    ├── effects/
    │   ├── damage_number.gd
    │   ├── death_effect.gd
    │   ├── hit_spark.gd
    │   └── shield_effect.gd
    ├── enemies/
    │   ├── boss_base.gd
    │   ├── boss_lieutenant.gd
    │   ├── enemy_base.gd
    │   ├── propaganda_bomb.gd
    │   ├── propaganda_drone.gd
    │   ├── propaganda_soldier.gd
    │   └── shockwave.gd
    ├── levels/
    │   ├── level_01.gd
    │   ├── level_base.gd
    │   ├── parallax_city.gd
    │   └── tutorial.gd
    ├── objects/
    │   ├── checkpoint.gd
    │   ├── npc.gd
    │   ├── propaganda_machine.gd
    │   └── sanity_pickup.gd
    ├── player/
    │   ├── clarity_shield.gd
    │   ├── player.gd
    │   └── projectile.gd
    └── ui/
        ├── credits.gd
        ├── dialogue_box.gd
        ├── game_over.gd
        ├── hud.gd
        ├── main_menu.gd
        ├── pause_menu.gd
        ├── settings_menu.gd
        ├── skill_tree.gd
        └── victory_screen.gd
```

## Getting Started

1. Install [Godot 4.2+](https://godotengine.org/download)
2. Clone this repository
3. Open the project in Godot (Project > Import > select the `project.godot` file)
4. Press F5 to run

## Technical Details

- **Base Resolution:** 480x270 (pixel-perfect, scales to 1080p/4K)
- **Target Hardware:** GTX 1060 or equivalent (very lightweight)
- **Platforms:** Windows (primary), with planned mobile support

## Future Plans

- Additional levels and city districts
- More boss fights (media moguls, enforcers, the Supreme Leader)
- Expanded skill tree
- Story/dialogue system
- Co-op multiplayer (far future)
- Mobile port

## License

All rights reserved.
