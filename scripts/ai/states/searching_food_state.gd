class_name SearchingFoodState
extends ResidentState
## SEARCHING_FOOD: walk to the nearest food source — the camp stockpile if it
## has food, otherwise a fruit tree. Tries other sources if one turns out
## empty, then hands over to EATING.

const MAX_ATTEMPTS := 3


func enter(r: Resident, ctx: ResidentManager, _params: Dictionary) -> void:
	_find_source(r, ctx)


func update(r: Resident, delta: float, ctx: ResidentManager) -> int:
	if not ResidentMovement.move_towards(r, delta, ResidentMovement.walk_speed(r)):
		return STAY
	# Arrived: try to take one portion.
	if r.site_kind == "camp":
		var eaten := ctx.stockpile.take_food(1.0)
		if eaten != "":
			r.consumed_label = Stockpile.label(eaten).to_lower()
			return Resident.State.EATING
	elif ctx.map.take_fruit(r.site_index, 1.0) >= 0.5:
		r.consumed_label = "buah liar"
		return Resident.State.EATING
	# The source was empty when we got there.
	r.attempts += 1
	if r.attempts >= MAX_ATTEMPTS:
		r.status_text = "Tidak menemukan makanan"
		return DECIDE
	_find_source(r, ctx)  # if nothing is left, this redirects to Idle
	return STAY


## Picks a food source. Returns false (and redirects to Idle) if none exists.
func _find_source(r: Resident, ctx: ResidentManager) -> bool:
	r.step = Resident.Step.MOVE
	if ctx.stockpile.food_total() >= 1.0:
		r.site_kind = "camp"
		r.target = ctx.map.camp_point(ctx.rng)
		r.status_text = "Mencari makanan di kamp"
		return true
	var tree := ctx.map.nearest_tree_with_fruit(r.pos)
	if tree >= 0:
		r.site_kind = "tree"
		r.site_index = tree
		r.target = ctx.map.tree_work_point(tree)
		r.status_text = "Mencari buah liar"
		return true
	redirect(r, Resident.State.IDLE, "Tidak ada makanan di mana pun")
	return false
