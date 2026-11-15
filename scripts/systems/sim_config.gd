class_name SimConfig
extends RefCounted
## Central tuning values for the simulation.
## Keep gameplay numbers here so balancing never requires touching AI code.
## Per-resource and per-job values live as .tres files under res://data/.

const WORLD_SIZE := Vector2(1280, 720)
const POPULATION := 50

# Time: one in-game hour per (1 / HOURS_PER_SECOND) real seconds at 1x speed.
const HOURS_PER_SECOND := 0.6  # prototype used 1.2 (20 s days); 40 s days give residents time to travel
const NIGHT_START_HOUR := 20.0
const NIGHT_END_HOUR := 6.0
const WORK_START_HOUR := 7.0
const WORK_END_HOUR := 18.0
# Largest simulation step; bigger frames (e.g. 4x speed) are split into sub-steps.
const MAX_STEP := 0.1

# Needs, per simulated second. 0 = satisfied for hunger/thirst, 100 = satisfied for energy/social/health.
const HUNGER_RATE := 0.55
const THIRST_RATE := 0.72
const ENERGY_DRAIN := 0.8
const ENERGY_DRAIN_WORK := 1.0
const SOCIAL_DECAY := 0.2
const SLEEP_NEED_MULT := 0.5
const HUNGER_CRITICAL := 75.0
const THIRST_CRITICAL := 80.0
const ENERGY_CRITICAL := 8.0
const HEALTH_LOSS := 0.8
const EXHAUSTION_DAMAGE := 0.3
const HEALTH_REGEN := 0.1
const HEALTH_REGEN_SLEEP := 0.35
const HEALTHY_NEED_LIMIT := 60.0

# Movement (pixels per second).
const WALK_SPEED := 55.0
const WANDER_SPEED := 16.0  # prototype wander speed

# Action tuning.
const EAT_DURATION := 3.0
const EAT_RATE := 18.0
const DRINK_DURATION := 2.5
const DRINK_RATE := 22.0
const SLEEP_RATE := 4.5
const SLEEP_FIRE_BONUS := 1.5
const SLEEP_MAX_DURATION := 30.0
const WAKE_ENERGY := 60.0
const SOCIAL_DURATION := 4.0
const SOCIAL_RATE := 9.0
const SOCIAL_RANGE := 260.0
const SOCIAL_CHASE_TIME := 8.0
const AFFINITY_RATE := 5.0
const FRIEND_THRESHOLD := 30.0
const SKILL_GAIN := 0.01

# Colony.
const FIRE_WOOD_PER_SECOND := 0.35
const FOOD_WARNING_LEVEL := 20.0
const DISCOVERY_LOG_COOLDOWN := 12.0
