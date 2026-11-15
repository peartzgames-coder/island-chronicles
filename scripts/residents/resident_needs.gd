class_name ResidentNeeds
extends RefCounted
## Advances a resident's needs and health each simulation step.


## Returns the cause of death ("kelaparan", "dehidrasi", "kelelahan")
## when health reaches zero, otherwise "".
static func update(r: Resident, delta: float) -> String:
	var sleeping := r.is_sleeping()
	var need_mult := SimConfig.SLEEP_NEED_MULT if sleeping else 1.0
	r.hunger = minf(100.0, r.hunger + SimConfig.HUNGER_RATE * delta * need_mult)
	r.thirst = minf(100.0, r.thirst + SimConfig.THIRST_RATE * delta * need_mult)

	if not sleeping:
		var drain := SimConfig.ENERGY_DRAIN
		if r.is_working():
			drain += SimConfig.ENERGY_DRAIN_WORK
		r.energy = maxf(0.0, r.energy - drain * delta)

	var chatting := r.action == Resident.Action.SOCIALIZE and r.phase == Resident.Phase.PERFORM
	if not chatting:
		r.social = maxf(0.0, r.social - SimConfig.SOCIAL_DECAY * delta)

	var starving := r.hunger > SimConfig.HUNGER_CRITICAL
	var dehydrated := r.thirst > SimConfig.THIRST_CRITICAL
	if starving or dehydrated:
		r.health -= SimConfig.HEALTH_LOSS * delta
	elif r.hunger < SimConfig.HEALTHY_NEED_LIMIT and r.thirst < SimConfig.HEALTHY_NEED_LIMIT:
		var regen := SimConfig.HEALTH_REGEN_SLEEP if sleeping else SimConfig.HEALTH_REGEN
		r.health = minf(100.0, r.health + regen * delta)
	if r.energy <= 0.0:
		r.health -= SimConfig.EXHAUSTION_DAMAGE * delta

	if r.health > 0.0:
		return ""
	r.health = 0.0
	if dehydrated and (not starving or r.thirst - SimConfig.THIRST_CRITICAL >= r.hunger - SimConfig.HUNGER_CRITICAL):
		return "dehidrasi"
	if starving:
		return "kelaparan"
	return "kelelahan"
