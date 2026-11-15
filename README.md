# Island Chronicles — Godot 4 Prototype

A small, playable autonomous island-survival simulation inspired by the uploaded reference video.

## Requirements
- Godot Engine 4.3 or newer
- Renderer: Compatibility / OpenGL (configured for Android friendliness)

## Run
1. Extract this ZIP.
2. Open the `project.godot` file in Godot 4.
3. Press **F6** or **F5** to run.

## Current prototype features
- Tropical top-down island drawn procedurally (no external assets required).
- 50 autonomous residents with names, ages, jobs, health, hunger, thirst, energy and social need.
- Residents wander around the island automatically.
- Basic survival pressure: hunger and thirst rise; health deteriorates when needs become critical.
- Day/night clock and day counter.
- Resource counters for fish, fruit, wood and water.
- Select a resident by clicking/tapping them to inspect their status.
- Pause/resume and simulation speed controls (1x, 2x, 4x).
- Event log and population/death counters.
- Mouse and touchscreen selection input.

## Controls
- Click/tap a resident: inspect that resident.
- JEDA / LANJUT: pause or resume.
- 1x / 2x / 4x: change simulation speed.

## Prototype limitations
This is the first playable vertical slice, not the full game. Social relationships, real harvesting/building, reproduction, advanced pathfinding, weather, save/load and Android export configuration are planned next. Resource counters currently demonstrate the survival economy loop and are not yet tied to individual job actions.

## Suggested next milestones
1. Give each resident a needs-driven AI state machine (eat, drink, rest, work, socialize).
2. Make resource gathering and consumption physically affect stockpiles.
3. Add shelters, camp upgrades and group/faction formation.
4. Add relationship scores, family trees, birth and aging.
5. Add random events: storms, injury, disease, discovery and conflict.
6. Add save/load, touch-friendly zoom/pan and Android export presets.
