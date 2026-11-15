class_name SleepingState
extends ResidentState
## SLEEPING: walk to the camp, then sleep. Restores energy (faster next to a
## lit camp fire) and health. Wakes up in the morning once rested and healthy.


func enter(r: Resident, ctx: ResidentManager, _params: Dictionary) -> void:
	r.step = Resident.Step.MOVE
	r.target = ctx.map.sleep_point(ctx.rng)
	r.status_text = "Menuju kamp untuk tidur"


func update(r: Resident, delta: float, ctx: ResidentManager) -> int:
	if r.step == Resident.Step.MOVE:
		if ResidentMovement.move_towards(r, delta, ResidentMovement.walk_speed(r)):
			r.step = Resident.Step.PERFORM
			r.timer = SimConfig.SLEEP_MAX_DURATION
			r.status_text = "Tidur"
		return STAY
	r.timer -= delta
	var rate := SimConfig.SLEEP_RATE + (SimConfig.SLEEP_FIRE_BONUS if ctx.map.fire_lit else 0.0)
	r.energy = minf(100.0, r.energy + rate * delta)
	var rested := r.energy >= SimConfig.WAKE_ENERGY and r.health >= SimConfig.WAKE_HEALTH
	if (not ctx.clock.is_night() and rested) or r.timer <= 0.0:
		return DECIDE
	return STAY
