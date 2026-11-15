class_name ResidentMovement
extends RefCounted
## Shared movement helpers for Resident AI states.

const ARRIVE_DISTANCE := 3.0


## Purposeful walking speed: slower when tired or carrying goods.
static func walk_speed(r: Resident) -> float:
	var speed := SimConfig.WALK_SPEED * (0.55 + 0.45 * clampf(r.energy / 60.0, 0.0, 1.0))
	if r.carry_amount > 0.0:
		speed *= 0.85
	return speed


## Moves toward r.target. Returns true once within `arrive_distance`.
static func move_towards(r: Resident, delta: float, speed: float, arrive_distance: float = ARRIVE_DISTANCE) -> bool:
	var to_target := r.target - r.pos
	var dist := to_target.length()
	if dist <= arrive_distance:
		return true
	var step := speed * delta
	if step >= dist:
		r.pos = r.target
		return true
	r.pos += to_target / dist * step
	return false
