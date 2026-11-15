class_name ResidentState
extends RefCounted
## Base class for one Resident AI state.
## States are stateless strategies: every per-resident value lives on the
## Resident, so a single instance of each state serves the whole population.
##
## update() returns:
##   STAY        keep running this state
##   DECIDE      the state is finished, ask ResidentBrain what to do next
##   <State id>  switch directly to that state (e.g. SearchingFood -> Eating)

const STAY := -1
const DECIDE := -2


func enter(_r: Resident, _ctx: ResidentManager, _params: Dictionary) -> void:
	pass


func update(_r: Resident, _delta: float, _ctx: ResidentManager) -> int:
	return DECIDE


func exit(_r: Resident, _ctx: ResidentManager) -> void:
	pass


## Helper for enter(): hand over to another state on the next update
## (used when no target can be found, e.g. no food anywhere).
func redirect(r: Resident, state: int, status: String) -> void:
	r.redirect_state = state
	r.status_text = status
