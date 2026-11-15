# Resident AI System (v0.2)

Every islander is an autonomous agent driven by a **state machine**. A
**brain** chooses the next state from the resident's **most urgent need**.
Global tuning: `scripts/systems/sim_config.gd`. Per-job and per-resource values:
`.tres` files in `data/`.

## Architecture
```
ResidentManager (scripts/residents/resident_manager.gd)  — every simulation step, per resident:
  1. ResidentNeeds.update()          needs + health, death check
  2. ResidentStateMachine.update()   runs the current state
  3. ResidentBrain.choose_state()    when the state finishes (or an emergency interrupts)
```
| File | Role |
|---|---|
| `scripts/residents/resident.gd` | Resident data, `State` / `Step` enums |
| `scripts/residents/resident_needs.gd` | Need decay, health, cause of death |
| `scripts/ai/resident_brain.gd` | Highest-need decision + interrupts |
| `scripts/ai/resident_state_machine.gd` | enter / update / exit, transitions, redirects |
| `scripts/ai/resident_movement.gd` | Walking helpers |
| `scripts/ai/states/*.gd` | One script per state (base: `resident_state.gd`) |

States are stateless strategies: one instance per state serves all residents,
and per-resident data (target, timer, step…) lives on the `Resident`.
`update()` returns `STAY`, `DECIDE` (ask the brain) or the id of the next state.

## Needs
| Need | Scale | Changes |
|---|---|---|
| Hunger | 0 = full | +0.55/s (half while sleeping); Eating −18/s |
| Thirst | 0 = quenched | +0.72/s (half while sleeping); Drinking −22/s |
| Energy | 100 = rested | −0.8/s awake, −1.8/s working; Sleeping +4.5/s (+1.5 if camp fire lit) |
| Health | 100 = healthy | −0.8/s if hunger > 75 or thirst > 80; −0.3/s at 0 energy; regenerates when fed (faster asleep) |
| Social | 100 = content | −0.2/s; Socializing +9/s |

**Death:** health 0, logged with the cause — *kelaparan*, *dehidrasi* or *kelelahan*.

## Decision: highest need wins — `ResidentBrain`
Each need gets an urgency (0…1+). The most urgent need that reaches its
threshold (`SimConfig.NEED_THRESHOLDS`, 0.5–0.6) picks the state:

| Need | Urgency | → State |
|---|---|---|
| Hunger | hunger/100, +0.4 near critical | Searching Food |
| Thirst | thirst/100 × 1.05, +0.4 near critical | Searching Water |
| Energy | tiredness; ≥ 0.85 at night, ≥ 0.62 just before night | Sleeping |
| Health | 1 − health/100 | Sleeping (rest heals) |
| Social | loneliness × sociability (× 0.4 at night) | Socializing |

No pressing need → **Working** if `work_score` (diligence × colony demand for
the job × time of day × energy) beats `idle_score`, otherwise **Idle**.

**Interrupts** (checked ~1×/s): critical hunger/thirst/exhaustion abandons the
current state; nightfall cancels a work trip that has not started yet. Residents
carrying goods finish delivering first.

## States
```
           ┌──────────── Brain (highest need) ─────────────┐
           ▼              ▼              ▼          ▼       ▼
 Searching Food   Searching Water    Sleeping  Socializing  Working / Idle
        │                │
        ▼                ▼
     Eating           Drinking
```
| State | Behaviour |
|---|---|
| **Idle** | Prototype wandering, or a short rest |
| **Working** | MOVE: search for a site with resources (try another if empty) → PERFORM: work a shift → DELIVER: carry the yield to the camp stockpile |
| **Searching Food** | Walk to the camp stockpile, or the nearest fruit tree if the camp is empty; try up to 3 sources → Eating. Nothing anywhere → Idle |
| **Searching Water** | Walk to the camp water store (if closer and stocked) or the pond → Drinking |
| **Eating** | Consume the portion (1 fish/fruit already taken from the stockpile or tree) |
| **Drinking** | Drink (1 water taken from the camp, or free at the pond) |
| **Sleeping** | Walk to the camp, sleep until morning once energy ≥ 60 and health ≥ 50 |
| **Socializing** | Walk to a nearby resident (friends preferred); an idle partner joins; both gain social + affinity (friends at ≥ 30 both ways) |

## Jobs (Working)
| Job | Searches for | Stock change |
|---|---|---|
| Nelayan | Fishing spot with fish left (spots deplete and regenerate) | Spot −catch, camp Ikan +catch |
| Pengumpul | Tree with fruit (or the pond when the camp needs water more) | Tree −fruit, camp Buah / Air + |
| Penebang | A nearby tree | camp Kayu + |
| Penjelajah | A far corner of the island | random discovery → Buah / Kayu / Ikan + |

Yield = data range × (0.6 + 0.8 × skill); skill grows each shift.
Stock also changes through eating, drinking, spoilage (fish, fruit) and the
camp fire burning wood at night.

## Adding a state
1. Add an entry to `Resident.State` and `Resident.STATE_NAMES`.
2. Create `scripts/ai/states/<name>_state.gd` extending `ResidentState`.
3. Register it in `ResidentStateMachine._init()`.
4. Return it from `ResidentBrain.choose_state()` (or from another state's `update()`).

## Testing
```bash
godot --headless --import
godot --headless -s res://tests/test_resident_ai.gd
```
Covers: data and scenes, highest-need decisions, state transitions and stock
changes, the fisher searching for fish, death, a 12-day 50-resident run (all 8
states used, night sleep, deliveries) and a food crisis.
