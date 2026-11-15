# Island Chronicles — Game Design Document

## Vision
An emergent-life simulation in which 50 stranded people attempt to build a functioning society on a tropical island. The player is an observer and gentle world-shaper; residents make their own decisions.

## Design pillars
- Autonomous: the simulation continues without direct character control.
- Emergent: relationships, work and survival produce unscripted stories.
- Readable: population, needs, resources and events are visible at a glance.
- Scalable: the same simulation rules should work on Android and PC.

## Core loop
Observe residents → identify a survival or social pressure → optionally influence the island → watch residents adapt → review daily events and population trends.

## Resident model
Each resident has:
- Identity: name, age, personality seed, appearance.
- Needs: hunger, thirst, energy, health, social.
- Skills: fishing, gathering, crafting, building, medicine.
- Social graph: affinity, trust, family and group membership.
- Current goal: seek food, seek water, rest, work, socialize, explore or flee danger.

## Resource economy
- Food: fish, fruit and later cooked meals.
- Water: freshwater sources and rain collection.
- Materials: wood, stone, fiber.
- Buildings: shelter, fire pit, storage, fishing hut, rain collector and farm plot.

## Simulation cadence
- Real-time simulation with 1x / 2x / 4x speed.
- One in-game day is a configurable amount of real time.
- Daily summary reports births, deaths, resource changes, discoveries and conflicts.

## MVP scope
The included prototype implements the island scene, 50 autonomous wanderers, basic needs and health pressure, a day clock, resource indicators, selection panel, event log, pause and speed controls.

## Not yet implemented
Deep needs-driven behavior, actual harvesting/consumption, construction, social graph, romance, family/reproduction, weather, diseases, combat, save/load and final art/audio.
