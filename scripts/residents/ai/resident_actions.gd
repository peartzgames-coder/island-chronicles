class_name ResidentActions
extends RefCounted
## Executes the action chosen by ResidentBrain as a small state machine:
##   MOVE (walk to target) -> PERFORM (do the activity) -> DELIVER (carry goods to camp)
## update() returns true when the action is finished and a new decision is needed.

const ARRIVE_DISTANCE := 3.0
const SOCIAL_DISTANCE := 16.0
const EXPLORE_MIN_DISTANCE := 180.0
const DISCOVERIES := [
	[Stockpile.FRUIT, "semak buah liar"],
	[Stockpile.WOOD, "tumpukan kayu apung"],
	[Stockpile.FISH, "kolam ikan kecil di pesisir"],
]


# --- Starting actions --------------------------------------------------------

static func start(r: Resident, action: int, ctx: ResidentManager) -> void:
	r.action = action
	r.phase = Resident.Phase.MOVE
	r.timer = 0.0
	r.site_kind = ""
	r.site_index = -1
	r.partner_id = -1
	match action:
		Resident.Action.EAT:
			_start_eat(r, ctx)
		Resident.Action.DRINK:
			_start_drink(r, ctx)
		Resident.Action.SLEEP:
			r.target = ctx.map.sleep_point(ctx.rng)
			r.status_text = "Menuju kamp untuk tidur"
		Resident.Action.WORK:
			_start_work(r, ctx)
		Resident.Action.SOCIALIZE:
			_start_socialize(r, ctx)
		Resident.Action.WANDER:
			_start_wander(r, ctx, "Berjalan-jalan")
		_:
			r.action = Resident.Action.IDLE
			r.phase = Resident.Phase.PERFORM
			r.timer = ctx.rng.randf_range(0.8, 2.0)
			r.status_text = "Beristirahat sejenak"


static func _start_wander(r: Resident, ctx: ResidentManager, text: String) -> void:
	r.action = Resident.Action.WANDER
	r.phase = Resident.Phase.MOVE
	r.target = ctx.map.random_land_point(ctx.rng)
	r.timer = ctx.rng.randf_range(2.0, 7.0)
	r.status_text = text


static func _start_eat(r: Resident, ctx: ResidentManager) -> void:
	if ctx.stockpile.food_total() >= 1.0:
		r.site_kind = "camp"
		r.target = ctx.map.camp_point(ctx.rng)
		r.status_text = "Menuju kamp untuk makan"
		return
	var tree := ctx.map.nearest_tree_with_fruit(r.pos)
	if tree >= 0:
		r.site_kind = "tree"
		r.site_index = tree
		r.target = ctx.map.tree_work_point(tree)
		r.status_text = "Mencari buah liar untuk dimakan"
		return
	_start_wander(r, ctx, "Mencari makanan, tetapi tidak menemukan apa pun")


static func _start_drink(r: Resident, ctx: ResidentManager) -> void:
	var pond := ctx.map.pond_drink_point(r.pos)
	var camp_closer := r.pos.distance_to(IslandMap.CAMP_DROP_POINT) < r.pos.distance_to(pond)
	if camp_closer and ctx.stockpile.has(Stockpile.WATER, 1.0):
		r.site_kind = "camp"
		r.target = ctx.map.camp_point(ctx.rng)
		r.status_text = "Menuju kamp untuk minum"
	else:
		r.site_kind = "pond"
		r.target = pond
		r.status_text = "Menuju kolam untuk minum"


static func _start_work(r: Resident, ctx: ResidentManager) -> void:
	if r.job == JobDefinitions.FISHER:
		r.site_kind = Stockpile.FISH
		r.site_index = ctx.map.pick_fishing_spot(r.pos, ctx.rng)
		r.target = ctx.map.fishing_spots[r.site_index]
		r.status_text = "Pergi memancing"
	elif r.job == JobDefinitions.GATHERER:
		var wanted := JobDefinitions.gatherer_resource(ctx.stockpile)
		var tree := ctx.map.pick_tree(r.pos, ctx.rng, true) if wanted == Stockpile.FRUIT else -1
		if tree >= 0:
			r.site_kind = Stockpile.FRUIT
			r.site_index = tree
			r.target = ctx.map.tree_work_point(tree)
			r.status_text = "Pergi memetik buah"
		else:
			r.site_kind = Stockpile.WATER
			r.target = ctx.map.pond_drink_point(r.pos)
			r.status_text = "Pergi mengambil air"
	elif r.job == JobDefinitions.WOODCUTTER:
		r.site_kind = Stockpile.WOOD
		r.site_index = ctx.map.pick_tree(r.pos, ctx.rng, false)
		r.target = ctx.map.tree_work_point(r.site_index)
		r.status_text = "Pergi menebang kayu"
	else:
		r.site_kind = "explore"
		r.target = ctx.map.random_far_point(ctx.rng, IslandMap.CAMP_DROP_POINT, EXPLORE_MIN_DISTANCE)
		r.status_text = "Berangkat menjelajah"


static func _start_socialize(r: Resident, ctx: ResidentManager) -> void:
	var partner := ctx.find_social_partner(r)
	if partner == null:
		_start_wander(r, ctx, "Mencari teman mengobrol")
		return
	r.partner_id = partner.id
	r.target = partner.pos
	r.timer = SimConfig.SOCIAL_CHASE_TIME
	r.status_text = "Menghampiri " + partner.short_name()


# --- Per-frame update --------------------------------------------------------

static func update(r: Resident, delta: float, ctx: ResidentManager) -> bool:
	match r.phase:
		Resident.Phase.MOVE:
			return _update_move(r, delta, ctx)
		Resident.Phase.PERFORM:
			return _perform(r, delta, ctx)
		_:
			if _move_towards(r, delta, ARRIVE_DISTANCE):
				_deliver(r, ctx)
				return true
			return false


static func _update_move(r: Resident, delta: float, ctx: ResidentManager) -> bool:
	if r.action == Resident.Action.SOCIALIZE:
		var partner := ctx.get_resident(r.partner_id)
		if partner == null or not partner.alive or partner.is_sleeping():
			return true
		r.target = partner.pos
		r.timer -= delta
		if r.timer <= 0.0:
			r.status_text = partner.short_name() + " terlalu sibuk"
			return true
		if _move_towards(r, delta, SOCIAL_DISTANCE):
			return _begin_perform(r, ctx)
		return false
	if r.action == Resident.Action.WANDER:
		r.timer -= delta
		return _move_towards(r, delta, ARRIVE_DISTANCE) or r.timer <= 0.0
	if _move_towards(r, delta, ARRIVE_DISTANCE):
		return _begin_perform(r, ctx)
	return false


## Called on arrival. Returns true if the action had to be abandoned.
static func _begin_perform(r: Resident, ctx: ResidentManager) -> bool:
	r.phase = Resident.Phase.PERFORM
	match r.action:
		Resident.Action.EAT:
			if r.site_kind == "camp":
				var eaten := ctx.stockpile.take_food(1.0)
				if eaten == "":
					start(r, Resident.Action.EAT, ctx)  # stock ran out on the way: forage instead
					return false
				r.status_text = "Makan " + Stockpile.label(eaten).to_lower()
			else:
				if ctx.map.take_fruit(r.site_index, 1.0) < 0.5:
					r.status_text = "Pohonnya sudah kosong"
					return true
				r.status_text = "Makan buah liar"
			r.timer = SimConfig.EAT_DURATION
		Resident.Action.DRINK:
			if r.site_kind == "camp" and ctx.stockpile.take(Stockpile.WATER, 1.0) < 1.0:
				r.site_kind = "pond"
				r.phase = Resident.Phase.MOVE
				r.target = ctx.map.pond_drink_point(r.pos)
				r.status_text = "Air kamp habis, menuju kolam"
				return false
			r.status_text = "Minum air" if r.site_kind == "camp" else "Minum di kolam"
			r.timer = SimConfig.DRINK_DURATION
		Resident.Action.SLEEP:
			r.status_text = "Tidur"
			r.timer = SimConfig.SLEEP_MAX_DURATION
		Resident.Action.WORK:
			r.status_text = JobDefinitions.work_status(r.job, r.site_kind)
			r.timer = JobDefinitions.work_duration(r.job)
		Resident.Action.SOCIALIZE:
			var partner := ctx.get_resident(r.partner_id)
			if partner == null:
				return true
			r.status_text = "Mengobrol dengan " + partner.short_name()
			r.timer = SimConfig.SOCIAL_DURATION
			_invite_partner(r, partner)
		_:
			r.timer = 1.0
	return false


## A free partner stops what they are doing and joins the conversation.
static func _invite_partner(r: Resident, partner: Resident) -> void:
	var already := partner.action == Resident.Action.SOCIALIZE and partner.partner_id == r.id
	var free := partner.action == Resident.Action.IDLE or partner.action == Resident.Action.WANDER
	if already or not free:
		return
	partner.action = Resident.Action.SOCIALIZE
	partner.phase = Resident.Phase.PERFORM
	partner.partner_id = r.id
	partner.site_kind = ""
	partner.timer = SimConfig.SOCIAL_DURATION
	partner.status_text = "Mengobrol dengan " + r.short_name()


static func _perform(r: Resident, delta: float, ctx: ResidentManager) -> bool:
	r.timer -= delta
	match r.action:
		Resident.Action.EAT:
			r.hunger = maxf(0.0, r.hunger - SimConfig.EAT_RATE * delta)
			return r.timer <= 0.0 or r.hunger <= 0.0
		Resident.Action.DRINK:
			r.thirst = maxf(0.0, r.thirst - SimConfig.DRINK_RATE * delta)
			return r.timer <= 0.0 or r.thirst <= 0.0
		Resident.Action.SLEEP:
			var rate := SimConfig.SLEEP_RATE + (SimConfig.SLEEP_FIRE_BONUS if ctx.map.fire_lit else 0.0)
			r.energy = minf(100.0, r.energy + rate * delta)
			var morning := not ctx.clock.is_night() and r.energy >= SimConfig.WAKE_ENERGY
			return morning or r.timer <= 0.0
		Resident.Action.WORK:
			if r.timer <= 0.0:
				return _finish_work(r, ctx)
			return false
		Resident.Action.SOCIALIZE:
			var partner := ctx.get_resident(r.partner_id)
			if partner == null or not partner.alive:
				return true
			var engaged := partner.action == Resident.Action.SOCIALIZE and partner.partner_id == r.id
			var factor := 1.0 if engaged else 0.4
			r.social = minf(100.0, r.social + SimConfig.SOCIAL_RATE * factor * delta)
			ctx.change_affinity(r, partner, SimConfig.AFFINITY_RATE * factor * delta)
			return r.timer <= 0.0 or r.social >= 100.0
		_:
			return r.timer <= 0.0


# --- Work results ------------------------------------------------------------

static func _finish_work(r: Resident, ctx: ResidentManager) -> bool:
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
		return true
	r.carry_type = r.site_kind
	r.carry_amount = amount
	_begin_deliver(r, ctx)
	return false


static func _finish_explore(r: Resident, ctx: ResidentManager, skill: float) -> bool:
	if ctx.rng.randf() > 0.3 + 0.25 * r.curiosity:
		r.status_text = "Tidak menemukan apa pun"
		return true
	var find: Array = DISCOVERIES[ctx.rng.randi_range(0, DISCOVERIES.size() - 1)]
	r.carry_type = find[0]
	r.carry_amount = ctx.rng.randf_range(4.0, 9.0) * (0.6 + 0.8 * skill)
	ctx.report_discovery(r, find[1])
	_begin_deliver(r, ctx)
	return false


static func _begin_deliver(r: Resident, ctx: ResidentManager) -> void:
	r.phase = Resident.Phase.DELIVER
	r.target = ctx.map.camp_point(ctx.rng)
	r.status_text = "Membawa %d %s ke kamp" % [int(round(r.carry_amount)), Stockpile.label(r.carry_type).to_lower()]


static func _deliver(r: Resident, ctx: ResidentManager) -> void:
	if r.carry_amount > 0.0:
		ctx.record_delivery(r.carry_type, ctx.stockpile.add(r.carry_type, r.carry_amount))
	r.status_text = "Menyetor hasil ke kamp"
	r.clear_carry()


# --- Movement ----------------------------------------------------------------

## Moves toward r.target. Returns true once within `arrive_distance`.
static func _move_towards(r: Resident, delta: float, arrive_distance: float) -> bool:
	var to_target := r.target - r.pos
	var dist := to_target.length()
	if dist <= arrive_distance:
		return true
	var speed := SimConfig.WANDER_SPEED if r.action == Resident.Action.WANDER else SimConfig.WALK_SPEED
	speed *= 0.55 + 0.45 * clampf(r.energy / 60.0, 0.0, 1.0)
	if r.carry_amount > 0.0:
		speed *= 0.85
	var step := speed * delta
	if step >= dist:
		r.pos = r.target
		return true
	r.pos += to_target / dist * step
	return false
