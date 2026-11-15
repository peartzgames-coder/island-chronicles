class_name SearchingWaterState
extends ResidentState
## SEARCHING_WATER: walk to the camp water store (if it is closer and not
## empty) or to the pond, which never runs dry. Then hands over to DRINKING.


func enter(r: Resident, ctx: ResidentManager, _params: Dictionary) -> void:
	var pond := ctx.map.pond_drink_point(r.pos)
	var camp_closer := r.pos.distance_to(IslandMap.CAMP_DROP_POINT) < r.pos.distance_to(pond)
	if camp_closer and ctx.stockpile.has(Stockpile.WATER, 1.0):
		r.site_kind = "camp"
		r.target = ctx.map.camp_point(ctx.rng)
		r.status_text = "Mencari air di kamp"
	else:
		_go_to_pond(r, ctx)


func update(r: Resident, delta: float, ctx: ResidentManager) -> int:
	if not ResidentMovement.move_towards(r, delta, ResidentMovement.walk_speed(r)):
		return STAY
	if r.site_kind == "pond":
		r.consumed_label = "air kolam"
		return Resident.State.DRINKING
	if ctx.stockpile.take(Stockpile.WATER, 1.0) >= 1.0:
		r.consumed_label = "air dari kamp"
		return Resident.State.DRINKING
	_go_to_pond(r, ctx)  # camp store ran dry while walking
	r.status_text = "Air kamp habis, menuju kolam"
	return STAY


func _go_to_pond(r: Resident, ctx: ResidentManager) -> void:
	r.site_kind = "pond"
	r.target = ctx.map.pond_drink_point(r.pos)
	r.status_text = "Mencari air di kolam"
