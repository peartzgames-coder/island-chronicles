class_name IdleState
extends ResidentState
## IDLE: nothing pressing. Wanders around the island like the original
## prototype, or rests on the spot for a moment.


func enter(r: Resident, ctx: ResidentManager, params: Dictionary) -> void:
	var keep_status: bool = params.get("redirected", false)
	if ctx.rng.randf() < 0.7:
		r.step = Resident.Step.MOVE
		r.target = ctx.map.random_land_point(ctx.rng)
		r.timer = ctx.rng.randf_range(2.0, 7.0)
		if not keep_status:
			r.status_text = "Berjalan-jalan"
	else:
		r.step = Resident.Step.PERFORM
		r.timer = ctx.rng.randf_range(1.0, 2.5)
		if not keep_status:
			r.status_text = "Beristirahat sejenak"


func update(r: Resident, delta: float, _ctx: ResidentManager) -> int:
	r.timer -= delta
	if r.step == Resident.Step.MOVE:
		if ResidentMovement.move_towards(r, delta, SimConfig.WANDER_SPEED):
			return DECIDE
	return DECIDE if r.timer <= 0.0 else STAY
