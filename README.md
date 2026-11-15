# Island Chronicles — Godot 4 Prototype

A small, playable autonomous island-survival simulation inspired by the uploaded reference video.

## Requirements
- Godot Engine 4.3 or newer
- Renderer: Compatibility / OpenGL (configured for Android friendliness)

## Run
1. Open the `project.godot` file (repository root) in Godot 4.3+.
2. Press **F5** to run (main scene: `scenes/world/main.tscn`).

## Project structure
```
project.godot
scenes/
  world/main.tscn                 Main scene (instances the scenes below + NightOverlay)
  world/island.tscn               IslandMap with the Camp building
  residents/resident_manager.tscn All residents (data-driven, drawn in one node)
  buildings/camp.tscn             Shelter hut + camp fire
  ui/hud.tscn                     HUD
scripts/
  ai/                             ResidentBrain (utility AI), ResidentActions (state machine)
  residents/                      Resident, ResidentNeeds, ResidentManager, JobDefinitions,
                                  JobData + ResidentProfile (data classes)
  systems/                        SimConfig, GameClock, EventLog, Stockpile, ResourceCatalog,
                                  ResourceTypeData, Hud
  world/                          main.gd (composition root), IslandMap, Camp, NightOverlay
assets/characters|environment|ui  Placeholders for future art
data/
  residents/                      job_*.tres (colour, shift length) + resident_profile.tres (names, start ranges)
  resources/                      fish/fruit/wood/water.tres (start amount, capacity, spoilage, yield, colour)
docs/                             Game design + Resident AI documentation
tests/test_resident_ai.gd         Headless smoke test
```
Balancing values for jobs, resources and new residents are `.tres` files in `data/`:
open them in the Godot Inspector to edit. Global AI/needs tuning is in `scripts/systems/sim_config.gd`.
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
