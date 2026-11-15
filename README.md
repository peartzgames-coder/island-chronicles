# Island Chronicles — Godot 4 Prototype

A small, playable autonomous island-survival simulation inspired by the uploaded reference video.

## Requirements
- Godot Engine 4.3 or newer
- Renderer: Compatibility / OpenGL (configured for Android friendliness)

## Run
1. Open the `project.godot` file (repository root) in Godot 4.3+.
2. Press **F5** to run (main scene: `scenes/main.tscn`).

## Project structure
```
project.godot
scenes/main.tscn                 Main scene: IslandMap, ResidentManager, NightOverlay, Hud
scripts/
  main.gd                        Composition root: wiring, pause, speed, input
  core/                          SimConfig (tuning), GameClock, EventLog
  economy/stockpile.gd           Camp storage for fish, fruit, wood, water
  world/island_map.gd            Island drawing + points of interest (camp, pond, trees, fishing spots)
  world/night_overlay.gd         Night darkness and camp-fire glow
  residents/resident.gd          Resident data (needs, personality, skills, relationships)
  residents/resident_needs.gd    Need decay and health
  residents/resident_manager.gd  Runs all residents, colony upkeep, drawing, selection
  residents/ai/                  ResidentBrain (utility AI) + ResidentActions (state machine)
  residents/jobs/                JobDefinitions
  ui/hud.gd                      HUD
assets/                          Placeholder folders for future sprites, audio, fonts
docs/                            Game design + Resident AI documentation
tests/test_resident_ai.gd        Headless smoke test
```
The original `IslandChronicles_Godot4_Prototype.zip` is kept for reference.

## Current prototype features
- Tropical top-down island drawn procedurally (no external assets required).
- 50 autonomous residents with names, ages, jobs, health, hunger, thirst, energy and social need.
- **Resident AI**: every resident decides on their own to eat, drink, sleep, work, socialize or wander (see `docs/RESIDENT_AI.md`).
- Jobs produce real resources: fishers catch fish, gatherers pick fruit or fetch water, woodcutters chop wood, explorers make discoveries. Goods are carried back to the camp stockpile.
- Eating and drinking consume the stockpile; residents forage wild fruit or drink at the pond when the camp is empty.
- Personality traits, skills that improve with work, and friendships formed by chatting.
- Day/night rhythm: residents sleep at the camp at night; the camp fire burns wood; night overlay.
- Basic survival pressure: hunger and thirst rise; health deteriorates when needs become critical.
- Day/night clock and day counter.
- Resource counters for fish, fruit, wood and water.
- Select a resident by clicking/tapping them to inspect their status, current action, goal, carried goods, traits and best friend.
- Pause/resume and simulation speed controls (1x, 2x, 4x).
- Event log and population/death counters.
- Mouse and touchscreen selection input.

## Controls
- Click/tap a resident: inspect that resident.
- JEDA / LANJUT: pause or resume.
- 1x / 2x / 4x: change simulation speed.

## Prototype limitations
This is a playable vertical slice, not the full game. Building, reproduction, advanced pathfinding (residents walk in straight lines), weather, save/load and Android export configuration are planned next.

Changes from the original prototype: the two parse errors that stopped `main.gd` from loading were fixed; the automatic daily refill of hunger/thirst/energy was replaced by residents actually eating, drinking and sleeping; one in-game day now lasts 40 s at 1x (was 20 s) so residents have time to travel.

## Suggested next milestones
1. ~~Needs-driven AI state machine (eat, drink, rest, work, socialize).~~ Done.
2. ~~Resource gathering and consumption affect stockpiles.~~ Done.
3. Add shelters, camp upgrades and group/faction formation.
4. Add relationship scores, family trees, birth and aging.
5. Add random events: storms, injury, disease, discovery and conflict.
6. Add save/load, touch-friendly zoom/pan and Android export presets.
