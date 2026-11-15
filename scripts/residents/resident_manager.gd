class_name ResidentManager
extends Node2D
## Owns every Resident and runs, each simulation step: needs (ResidentNeeds),
## the state machine (ResidentStateMachine) and decisions (ResidentBrain).
## Also handles colony upkeep (camp fire, spoilage) and draws the residents.

signal resident_died(resident: Resident)

const SELECT_RADIUS := 24.0

@export var profile: ResidentProfile = preload("res://data/residents/resident_profile.tres")

var residents: Array[Resident] = []
var map: IslandMap
var stockpile: Stockpile
var clock: GameClock
var event_log: EventLog
var rng: RandomNumberGenerator
var brain := ResidentBrain.new()
var state_machine := ResidentStateMachine.new()

var selected_id := -1
var deaths := 0
var births := 0
var state_counts := {}   ## Resident.State -> number of times the state was entered
var delivered := {}      ## resource -> total amount delivered to camp

var _discovery_cooldown := 0.0
var _food_warning_shown := false
var _fire_warning_shown := false
var _friend_pairs := {}


func setup(p_map: IslandMap, p_stockpile: Stockpile, p_clock: GameClock, p_log: EventLog, p_rng: RandomNumberGenerator) -> void:
	map = p_map
	stockpile = p_stockpile
	clock = p_clock
	event_log = p_log
	rng = p_rng
	map.setup()


func spawn_population(count: int) -> void:
	for i in range(count):
		var r := Resident.new()
		r.id = residents.size()
		var names := profile.first_names
		r.full_name = names[i % names.size()] + (" %02d" % (i + 1))
		r.pos = map.random_land_point(rng)
		r.target = r.pos
		r.age = rng.randi_range(profile.age_range.x, profile.age_range.y)
		r.hunger = _roll(profile.hunger_range)
		r.thirst = _roll(profile.thirst_range)
		r.energy = _roll(profile.energy_range)
		r.social = _roll(profile.social_range)
		r.job = JobDefinitions.ALL[i % JobDefinitions.ALL.size()]
		r.color = JobDefinitions.color_for(r.job)
		r.diligence = _roll(profile.trait_range)
		r.sociability = _roll(profile.trait_range)
		r.curiosity = _roll(profile.trait_range)
		for job_name in JobDefinitions.ALL:
			r.skills[job_name] = _roll(profile.main_skill_range if job_name == r.job else profile.other_skill_range)
		r.timer = rng.randf_range(0.0, 1.0)  # stagger the first decisions
		residents.append(r)
	if not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.state_changed.connect(_on_state_changed)


func _roll(value_range: Vector2) -> float:
	return rng.randf_range(value_range.x, value_range.y)


# --- Simulation --------------------------------------------------------------

func simulate(delta: float) -> void:
	_discovery_cooldown = maxf(0.0, _discovery_cooldown - delta)
	_update_colony(delta)
	for r in residents:
		if not r.alive:
			continue
		var cause := ResidentNeeds.update(r, delta)
		if cause != "":
			_kill(r, cause)
			continue
		_update_ai(r, delta)
	queue_redraw()


func _update_ai(r: Resident, delta: float) -> void:
	if state_machine.update(r, delta, self):
		decide(r, -1)
		return
	r.think_cooldown -= delta
	if r.think_cooldown <= 0.0:
		r.think_cooldown = rng.randf_range(0.8, 1.6)
		if brain.should_interrupt(r, self):
			decide(r, r.state)


## Asks the brain for the next state. `current` (if >= 0) is the state being
## interrupted; if the brain picks the same need it keeps running.
func decide(r: Resident, current: int) -> void:
	var next := brain.choose_state(r, self, current)
	if current >= 0 and (next == current or ResidentBrain.handles_need(current, _need_of(next))):
		return
	state_machine.change_state(r, next, self)


func _need_of(state: int) -> String:
	for need in ResidentBrain.NEED_STATES:
		if ResidentBrain.NEED_STATES[need] == state:
			return need
	return ""


func _on_state_changed(_r: Resident, _from_state: int, to_state: int) -> void:
	state_counts[to_state] = int(state_counts.get(to_state, 0)) + 1


func _update_colony(delta: float) -> void:
	stockpile.apply_spoilage(delta)
	var wood := stockpile.get_amount(Stockpile.WOOD)
	if clock.is_night():
		if wood > 0.0:
			stockpile.take(Stockpile.WOOD, SimConfig.FIRE_WOOD_PER_SECOND * delta)
			map.fire_lit = true
			_fire_warning_shown = false
		else:
			map.fire_lit = false
			if not _fire_warning_shown:
				_fire_warning_shown = true
				event_log.add("Kayu habis — api unggun padam malam ini.")
	else:
		map.fire_lit = wood > 0.0

	var food := stockpile.food_total()
	if food < SimConfig.FOOD_WARNING_LEVEL and not _food_warning_shown:
		_food_warning_shown = true
		event_log.add("Persediaan makanan di kamp hampir habis!")
	elif food > SimConfig.FOOD_WARNING_LEVEL * 3.0:
		_food_warning_shown = false


func on_day_changed(day: int) -> void:
	if day % 365 == 0:
		for r in residents:
			if r.alive:
				r.age += 1


func _kill(r: Resident, cause: String) -> void:
	r.alive = false
	r.cause_of_death = cause
	r.clear_carry()
	r.state = Resident.State.IDLE
	r.status_text = "Meninggal"
	deaths += 1
	event_log.add("%s meninggal karena %s." % [r.full_name, cause])
	resident_died.emit(r)


# --- Services used by the AI states -----------------------------------------

func get_resident(id: int) -> Resident:
	if id < 0 or id >= residents.size():
		return null
	return residents[id]


func find_social_partner(r: Resident) -> Resident:
	var best: Resident = null
	var best_score := -INF
	for other in residents:
		if other == r or not other.alive or other.is_sleeping():
			continue
		var d := r.pos.distance_to(other.pos)
		if d > SimConfig.SOCIAL_RANGE:
			continue
		var score := 1.0 - d / SimConfig.SOCIAL_RANGE + r.get_affinity(other.id) / 40.0 + rng.randf() * 0.4
		if other.is_available():
			score += 0.3
		if score > best_score:
			best_score = score
			best = other
	return best


func change_affinity(r: Resident, other: Resident, amount: float) -> void:
	r.change_affinity(other.id, amount)
	if r.get_affinity(other.id) < SimConfig.FRIEND_THRESHOLD or other.get_affinity(r.id) < SimConfig.FRIEND_THRESHOLD:
		return
	var key := Vector2i(mini(r.id, other.id), maxi(r.id, other.id))
	if not _friend_pairs.has(key):
		_friend_pairs[key] = true
		event_log.add("%s dan %s kini bersahabat." % [r.short_name(), other.short_name()])


func friendship_count() -> int:
	return _friend_pairs.size()


func report_discovery(r: Resident, what: String) -> void:
	if _discovery_cooldown > 0.0:
		return
	_discovery_cooldown = SimConfig.DISCOVERY_LOG_COOLDOWN
	event_log.add("%s menemukan %s." % [r.full_name, what])


func record_delivery(resource: String, amount: float) -> void:
	delivered[resource] = float(delivered.get(resource, 0.0)) + amount


# --- Queries for UI ----------------------------------------------------------

func living_count() -> int:
	var n := 0
	for r in residents:
		if r.alive:
			n += 1
	return n


## Number of living residents currently doing each action.
func activity_summary() -> Dictionary:
	var counts := {}
	for r in residents:
		if r.alive:
			counts[r.state] = int(counts.get(r.state, 0)) + 1
	return counts


func pick_at(point: Vector2) -> int:
	var nearest := -1
	var best := SELECT_RADIUS
	for r in residents:
		if not r.alive:
			continue
		var d := point.distance_to(r.pos)
		if d < best:
			best = d
			nearest = r.id
	return nearest


func describe(id: int) -> String:
	var r := get_resident(id)
	if r == null:
		return "Ketuk seseorang di pulau untuk melihat statusnya."
	if not r.alive:
		return r.full_name + "\nStatus: Meninggal (" + r.cause_of_death + ")"
	var carry := "-"
	if r.carry_amount > 0.0:
		carry = "%d %s" % [int(round(r.carry_amount)), Stockpile.label(r.carry_type)]
	var friend := get_resident(r.best_friend_id())
	return "%s\nUsia: %d tahun\nPekerjaan: %s (%d%%)\nKesehatan: %d%%\nLapar: %d%%\nHaus: %d%%\nEnergi: %d%%\nSosial: %d%%\nState: %s\n> %s\n(%s)\nBawaan: %s\nSifat: Rajin %d · Ramah %d · Ingin tahu %d\nSahabat: %s" % [
		r.full_name, r.age, r.job, int(r.get_skill(r.job) * 100.0),
		int(r.health), int(r.hunger), int(r.thirst), int(r.energy), int(r.social),
		r.state_name(), r.status_text, r.decision_reason, carry,
		int(r.diligence * 100.0), int(r.sociability * 100.0), int(r.curiosity * 100.0),
		friend.short_name() if friend != null else "-",
	]


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var selected := get_resident(selected_id)
	if selected != null and selected.alive and selected.step != Resident.Step.PERFORM:
		draw_line(selected.pos, selected.target, Color(1.0, 0.94, 0.65, 0.45), 1.5)
		draw_circle(selected.target, 3.0, Color(1.0, 0.94, 0.65, 0.6))
	for r in residents:
		if r.alive:
			_draw_resident(r, r.id == selected_id)


func _draw_resident(r: Resident, is_selected: bool) -> void:
	var pos := r.pos
	if is_selected:
		draw_arc(pos, 13, 0, TAU, 20, Color("#fff0a6"), 2.5)
	if r.is_sleeping():
		# Lying down next to the camp.
		draw_rect(Rect2(pos.x - 6, pos.y + 2, 12, 5), r.color)
		draw_rect(Rect2(pos.x - 10, pos.y + 1, 5, 6), Color("#e6bd91"))
		draw_string(ThemeDB.fallback_font, pos + Vector2(2, -4), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))
	else:
		# Prototype figure.
		draw_rect(Rect2(pos.x - 4, pos.y - 2, 8, 10), r.color)
		draw_rect(Rect2(pos.x - 4, pos.y - 8, 8, 7), Color("#e6bd91"))
		draw_rect(Rect2(pos.x - 4, pos.y - 9, 8, 3), Color("#443b35"))
		draw_rect(Rect2(pos.x - 4, pos.y + 7, 3, 5), Color("#463f3a"))
		draw_rect(Rect2(pos.x + 1, pos.y + 7, 3, 5), Color("#463f3a"))
		if r.carry_amount > 0.0:
			var carried := ResourceCatalog.get_type(r.carry_type)
			draw_rect(Rect2(pos.x - 3, pos.y - 15, 6, 5), carried.carry_color if carried != null else Color.WHITE)
		elif r.is_chatting():
			for i in range(3):
				draw_circle(pos + Vector2(-4 + i * 4, -13), 1.2, Color(1, 1, 1, 0.85))
	if is_selected:
		draw_string(ThemeDB.fallback_font, pos + Vector2(-20, -17), r.short_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
