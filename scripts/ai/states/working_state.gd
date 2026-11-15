class_name WorkingState
extends ResidentState
## WORKING: do the resident's job.
##   MOVE    search for and walk to a work site with resources left
##   PERFORM work a shift (catch fish / pick fruit / chop wood / explore)
##   DELIVER carry the yield to the camp stockpile
##
## Fishers look for a fishing spot that still has fish and move on if it is
## fished out; gatherers look for a tree with fruit (or fetch water when the
## camp needs that more); woodcutters go to a tree; explorers roam far away.

const MAX_ATTEMPTS := 3
const EXPLORE_MIN_DISTANCE := 180.0
const DISCOVERIES := [
	[Stockpile.FRUIT, "semak buah liar"],
	[Stockpile.WOOD, "tumpukan kayu apung"],
	[Stockpile.FISH, "kolam ikan kecil di pesisir"],
]


func enter(r: Resident, ctx: ResidentManager, _params: Dictionary) -> void:
	_search_site(r, ctx)


func exit(r: Resident, _ctx: ResidentManager) -> void:
	if r.carry_amount > 0.0:
		r.clear_carry()  # interrupted by an emergency: the load is dropped


func update(r: Resident, delta: float, ctx: ResidentManager) -> int:
	match r.step:
		Resident.Step.MOVE:
			if not ResidentMovement.move_towards(r, delta, ResidentMovement.walk_speed(r)):
				return STAY
			if not _site_has_resources(r, ctx):
				r.attempts += 1
				if r.attempts >= MAX_ATTEMPTS or not _search_site(r, ctx):
					r.status_text = "Tidak menemukan " + Stockpile.label(r.site_kind).to_lower()
					return DECIDE
				return STAY
			r.step = Resident.Step.PERFORM
			r.timer = JobDefinitions.work_duration(r.job)
			r.status_text = JobDefinitions.work_status(r.job, r.site_kind)
			return STAY
		Resident.Step.PERFORM:
			r.timer -= delta
			if r.timer > 0.0:
				return STAY
			return _finish_shift(r, ctx)
		_:
			if not ResidentMovement.move_towards(r, delta, ResidentMovement.walk_speed(r)):
				return STAY
			var stored := ctx.stockpile.add(r.carry_type, r.carry_amount)
			ctx.record_delivery(r.carry_type, stored)
			r.status_text = "Menyetor %d %s ke kamp" % [int(round(stored)), Stockpile.label(r.carry_type).to_lower()]
			r.clear_carry()
			return DECIDE


## Chooses a work site for the job. Returns false if none is available.
func _search_site(r: Resident, ctx: ResidentManager) -> bool:
	r.step = Resident.Step.MOVE
	if r.job == JobDefinitions.FISHER:
		r.site_kind = Stockpile.FISH
		r.site_index = ctx.map.pick_fishing_spot(r.pos, ctx.rng, 1.0)
		if r.site_index < 0:
			redirect(r, Resident.State.IDLE, "Ikan di pantai sedang habis")
			return false
		r.target = ctx.map.fishing_spots[r.site_index]
		r.status_text = "Mencari ikan di pantai"
	elif r.job == JobDefinitions.GATHERER:
		var wanted := JobDefinitions.gatherer_resource(ctx.stockpile)
		var tree := ctx.map.pick_tree(r.pos, ctx.rng, true) if wanted == Stockpile.FRUIT else -1
		if tree >= 0:
			r.site_kind = Stockpile.FRUIT
			r.site_index = tree
			r.target = ctx.map.tree_work_point(tree)
			r.status_text = "Mencari pohon berbuah"
		else:
			r.site_kind = Stockpile.WATER
			r.target = ctx.map.pond_drink_point(r.pos)
			r.status_text = "Pergi mengambil air"
	elif r.job == JobDefinitions.WOODCUTTER:
		r.site_kind = Stockpile.WOOD
		r.site_index = ctx.map.pick_tree(r.pos, ctx.rng, false)
		r.target = ctx.map.tree_work_point(r.site_index)
		r.status_text = "Menuju pohon untuk ditebang"
	else:
		r.site_kind = "explore"
		r.target = ctx.map.random_far_point(ctx.rng, IslandMap.CAMP_DROP_POINT, EXPLORE_MIN_DISTANCE)
		r.status_text = "Berangkat menjelajah"
	return true


func _site_has_resources(r: Resident, ctx: ResidentManager) -> bool:
	if r.site_kind == Stockpile.FISH:
		return ctx.map.spot_fish[r.site_index] >= 1.0
	if r.site_kind == Stockpile.FRUIT:
		return ctx.map.tree_fruit[r.site_index] >= 1.0
	return true


func _finish_shift(r: Resident, ctx: ResidentManager) -> int:
	var skill := r.get_skill(r.job)
	r.improve_skill(r.job, SimConfig.SKILL_GAIN)
	if r.site_kind == "explore":
		return _finish_explore(r, ctx, skill)
	var range_ := JobDefinitions.yield_range(r.site_kind)
	var amount := ctx.rng.randf_range(range_.x, range_.y) * (0.6 + 0.8 * skill)
	if r.site_kind == Stockpile.FISH:
		amount = ctx.map.take_fish(r.site_index, amount)
	elif r.site_kind == Stockpile.FRUIT:
		amount = ctx.map.take_fruit(r.site_index, amount)
	if amount < 0.5:
		r.status_text = "Tidak mendapat hasil"
		return DECIDE
	_begin_delivery(r, ctx, r.site_kind, amount)
	return STAY


func _finish_explore(r: Resident, ctx: ResidentManager, skill: float) -> int:
	if ctx.rng.randf() > 0.3 + 0.25 * r.curiosity:
		r.status_text = "Tidak menemukan apa pun"
		return DECIDE
	var find: Array = DISCOVERIES[ctx.rng.randi_range(0, DISCOVERIES.size() - 1)]
	ctx.report_discovery(r, find[1])
	_begin_delivery(r, ctx, find[0], ctx.rng.randf_range(4.0, 9.0) * (0.6 + 0.8 * skill))
	return STAY


func _begin_delivery(r: Resident, ctx: ResidentManager, resource: String, amount: float) -> void:
	r.carry_type = resource
	r.carry_amount = amount
	r.step = Resident.Step.DELIVER
	r.target = ctx.map.camp_point(ctx.rng)
	r.status_text = "Membawa %d %s ke kamp" % [int(round(amount)), Stockpile.label(resource).to_lower()]
