# Resident AI System

Every islander is an independent agent with needs, a job, a personality and
relationships. Nothing is scripted per resident; behaviour emerges from the
rules below. Global tuning lives in `scripts/systems/sim_config.gd`; per-job and per-resource values are `.tres` files in `data/`.

## Data — `scripts/residents/resident.gd`
| Group | Fields |
|---|---|
| Identity | name, age, job, colour, position |
| Needs (0–100) | hunger, thirst (0 = satisfied); energy, social, health (100 = satisfied) |
| Personality (0–1) | diligence (work), sociability (company), curiosity (wandering/discovery) |
| Skills (0–1) | one per job; main job starts at 0.5–0.85 and improves with each shift |
| Relationships | affinity per resident (-100…100); ≥ 30 both ways = friends |

## Needs — `scripts/residents/resident_needs.gd`
- Hunger and thirst rise every second (halved while sleeping).
- Energy drains while awake, faster while working. Sleeping restores it, faster when the camp fire is lit.
- Social need decays unless the resident is chatting.
- Health drops when hunger > 75 or thirst > 80 (prototype rule), or energy is 0.
  It slowly regenerates when needs are under control, faster during sleep.
- Health 0 → death, logged with the cause (kelaparan / dehidrasi / kelelahan).

## Decisions — `scripts/ai/resident_brain.gd` (utility AI)
Each action gets a score; the highest (plus a little noise) wins.

| Action | Score grows with |
|---|---|
| Makan / Minum | hunger² / thirst², big bonus near critical |
| Tidur | tiredness², bonus at night and just before nightfall |
| Bekerja | diligence × colony demand for the job's resource; reduced in the evening, mostly off at night |
| Bersosialisasi | loneliness × sociability; reduced at night |
| Jalan-jalan / Santai | small baseline (curiosity) — what residents do when nothing is pressing |

Decisions are made when an action finishes. Every ~1 s the brain also checks
for interrupts: critical hunger/thirst/exhaustion, or nightfall while still
walking to a job. Residents carrying goods finish delivering first.

## Actions — `scripts/ai/resident_actions.gd` (state machine)
`MOVE → PERFORM → (DELIVER)`

| Action | Behaviour |
|---|---|
| Eat | walk to camp, eat 1 fish/fruit from the stockpile; if empty, eat wild fruit from the nearest tree |
| Drink | camp water (if closer and available) or the pond (always free) |
| Sleep | walk to the camp, sleep until morning |
| Work | walk to a work site, work a shift, carry the yield back to the camp stockpile |
| Socialize | walk to a nearby resident (friends preferred); a free partner joins the chat; both gain social and affinity |
| Wander / Idle | prototype wandering |

## Jobs — `scripts/residents/job_definitions.gd` + `data/residents/job_*.tres`
| Job | Site | Produces |
|---|---|---|
| Nelayan | beach fishing spots (fish regenerate) | Ikan |
| Pengumpul | fruit trees or the pond — whichever the camp needs more | Buah / Air |
| Penebang | trees | Kayu |
| Penjelajah | far corners of the island | random discoveries (fruit, driftwood, fish) |

Yield = base range × (0.6 + 0.8 × skill). Work desire follows stockpile demand,
so production self-regulates: residents work hard when stores are low and enjoy
free time when they are full.

## Colony economy
- Start amounts, caps, spoilage and yields: `data/resources/*.tres` (caps: 300 fish/fruit/water, 250 wood).
- Fish and fruit slowly spoil; the camp fire burns wood at night.
- No wood → fire goes out (logged) → slower sleep recovery.
- Low food triggers a log warning.

## Testing
```bash
godot --headless --import
godot --headless -s res://tests/test_resident_ai.gd
```
The smoke test simulates 12 days with a fixed seed and checks survival, deliveries,
all action types, night-time sleeping and a food-crisis scenario (empty camp).
