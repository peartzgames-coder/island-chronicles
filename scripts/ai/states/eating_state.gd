class_name EatingState
extends ResidentState
## EATING: consume the portion found by SEARCHING_FOOD; hunger drops quickly.


func enter(r: Resident, _ctx: ResidentManager, _params: Dictionary) -> void:
	r.step = Resident.Step.PERFORM
	r.timer = SimConfig.EAT_DURATION
	r.status_text = "Makan " + r.consumed_label


func update(r: Resident, delta: float, _ctx: ResidentManager) -> int:
	r.timer -= delta
	r.hunger = maxf(0.0, r.hunger - SimConfig.EAT_RATE * delta)
	return DECIDE if r.timer <= 0.0 or r.hunger <= 0.0 else STAY
