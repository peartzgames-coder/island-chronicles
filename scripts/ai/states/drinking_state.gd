class_name DrinkingState
extends ResidentState
## DRINKING: drink the water found by SEARCHING_WATER; thirst drops quickly.


func enter(r: Resident, _ctx: ResidentManager, _params: Dictionary) -> void:
	r.step = Resident.Step.PERFORM
	r.timer = SimConfig.DRINK_DURATION
	r.status_text = "Minum " + r.consumed_label


func update(r: Resident, delta: float, _ctx: ResidentManager) -> int:
	r.timer -= delta
	r.thirst = maxf(0.0, r.thirst - SimConfig.DRINK_RATE * delta)
	return DECIDE if r.timer <= 0.0 or r.thirst <= 0.0 else STAY
