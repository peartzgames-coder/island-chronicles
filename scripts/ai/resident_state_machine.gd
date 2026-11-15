class_name ResidentStateMachine
extends RefCounted
## Runs the Resident AI states: one shared instance per state, per-resident
## data on the Resident. Handles enter/exit, direct transitions and redirects.

signal state_changed(resident: Resident, from_state: int, to_state: int)

var states := {}  ## Resident.State -> ResidentState


func _init() -> void:
	states[Resident.State.IDLE] = IdleState.new()
	states[Resident.State.WORKING] = WorkingState.new()
	states[Resident.State.SEARCHING_FOOD] = SearchingFoodState.new()
	states[Resident.State.SEARCHING_WATER] = SearchingWaterState.new()
	states[Resident.State.EATING] = EatingState.new()
	states[Resident.State.DRINKING] = DrinkingState.new()
	states[Resident.State.SLEEPING] = SleepingState.new()
	states[Resident.State.SOCIALIZING] = SocializingState.new()


func get_state(state: int) -> ResidentState:
	return states.get(state)


func change_state(r: Resident, new_state: int, ctx: ResidentManager, params: Dictionary = {}) -> void:
	var old_state := r.state
	var current := get_state(old_state)
	if current != null:
		current.exit(r, ctx)
	r.state = new_state
	r.step = Resident.Step.MOVE
	r.timer = 0.0
	r.site_kind = ""
	r.site_index = -1
	r.partner_id = -1
	r.attempts = 0
	r.redirect_state = -1
	get_state(new_state).enter(r, ctx, params)
	state_changed.emit(r, old_state, new_state)


## Advances the resident's current state.
## Returns true when the state finished and the brain must choose a new one.
func update(r: Resident, delta: float, ctx: ResidentManager) -> bool:
	if r.redirect_state >= 0:
		change_state(r, r.redirect_state, ctx, {"redirected": true})
		return false
	var result := get_state(r.state).update(r, delta, ctx)
	if result == ResidentState.STAY:
		return false
	if result == ResidentState.DECIDE:
		return true
	change_state(r, result, ctx)
	return false
