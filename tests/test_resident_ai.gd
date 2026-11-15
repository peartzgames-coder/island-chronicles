extends SceneTree
## Headless tests for the Resident AI (v0.2 state machine).
## Run from the project root:
##   godot --headless --import            (first time only, builds the class cache)
##   godot --headless -s res://tests/test_resident_ai.gd

const SIM_DAYS := 12
const STEP := 0.1

var failures := 0
var checks := 0


func _initialize() -> void:
	_test_data_and_scenes()
	_test_highest_need_decides()
	_test_state_transitions()
	_test_fisher_finds_fish()
	_test_death()
	_test_long_simulation()
	_test_food_crisis()
	print("RESULT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures > 0 else 0)


# --- Helpers -----------------------------------------------------------------

class World:
	var rng := RandomNumberGenerator.new()
	var clock := GameClock.new()
	var stockpile := Stockpile.new()
	var event_log := EventLog.new()
	var map: IslandMap
	var manager: ResidentManager

	func tick(seconds: float) -> void:
		var t := 0.0
		while t < seconds:
			clock.advance(STEP)
			map.update_sites(STEP)
			manager.simulate(STEP)
			t += STEP

	func free_nodes() -> void:
		map.queue_free()
		manager.queue_free()


func _make_world(population: int, seed_value: int) -> World:
	var w := World.new()
	w.rng.seed = seed_value
	w.map = load("res://scenes/world/island.tscn").instantiate()
	w.manager = load("res://scenes/residents/resident_manager.tscn").instantiate()
	root.add_child(w.map)
	root.add_child(w.manager)
	w.manager.setup(w.map, w.stockpile, w.clock, w.event_log, w.rng)
	w.manager.spawn_population(population)
	w.clock.day_changed.connect(w.manager.on_day_changed)
	return w


## Puts a resident in a calm, fully satisfied state.
func _calm(r: Resident) -> void:
	r.hunger = 0.0
	r.thirst = 0.0
	r.energy = 100.0
	r.health = 100.0
	r.social = 100.0


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL: " + label)


func _state_names(counts: Dictionary) -> Dictionary:
	var named := {}
	for key in counts:
		named[Resident.STATE_NAMES[key]] = counts[key]
	return named


# --- Tests -------------------------------------------------------------------

func _test_data_and_scenes() -> void:
	var w := _make_world(4, 1)
	_check(w.map.tree_positions.size() > 0, "island has trees")
	_check(w.map.camp != null, "island scene contains the camp building")
	_check(w.manager.profile != null and w.manager.profile.first_names.size() == 20, "resident profile data loaded")
	for resource in Stockpile.ids():
		_check(ResourceCatalog.get_type(resource) != null, "resource data for %s loaded" % resource)
	for job in JobDefinitions.ALL:
		_check(JobDefinitions.get_job(job) != null, "job data for %s loaded" % job)
	_check(w.stockpile.get_amount(Stockpile.FISH) == 120.0, "stockpile starts from data")
	for state in Resident.State.values():
		_check(w.manager.state_machine.get_state(state) != null, "state %s is registered" % Resident.STATE_NAMES[state])
	for spot in w.map.fishing_spots:
		_check(Geometry2D.is_point_in_polygon(spot, w.map.sand_polygon), "fishing spot %s is on the beach" % spot)
	w.free_nodes()


func _test_highest_need_decides() -> void:
	var w := _make_world(1, 2)
	var brain := w.manager.brain
	var r: Resident = w.manager.residents[0]
	w.clock.hour = 10.0
	w.stockpile.amounts[Stockpile.FISH] = 10.0  # low stock -> work is wanted

	_calm(r)
	r.hunger = 80.0
	r.thirst = 60.0
	_check(brain.choose_state(r, w.manager) == Resident.State.SEARCHING_FOOD, "hungriest need wins -> Searching Food")
	_calm(r)
	r.hunger = 60.0
	r.thirst = 85.0
	_check(brain.choose_state(r, w.manager) == Resident.State.SEARCHING_WATER, "thirst highest -> Searching Water")
	_calm(r)
	r.energy = 10.0
	_check(brain.choose_state(r, w.manager) == Resident.State.SLEEPING, "exhausted -> Sleeping")
	_calm(r)
	r.health = 30.0
	_check(brain.choose_state(r, w.manager) == Resident.State.SLEEPING, "low health -> Sleeping to recover")
	_calm(r)
	r.social = 0.0
	r.sociability = 1.0
	_check(brain.choose_state(r, w.manager) == Resident.State.SOCIALIZING, "lonely -> Socializing")
	_calm(r)
	r.job = JobDefinitions.FISHER
	r.diligence = 1.0
	_check(brain.choose_state(r, w.manager) == Resident.State.WORKING, "no pressing need + low fish stock -> Working")
	w.clock.hour = 23.0
	r.energy = 70.0
	_check(brain.choose_state(r, w.manager) == Resident.State.SLEEPING, "night -> Sleeping")
	w.clock.hour = 10.0
	_calm(r)
	w.stockpile.amounts[Stockpile.FISH] = 300.0
	w.stockpile.amounts[Stockpile.FRUIT] = 300.0
	r.diligence = 0.0
	r.curiosity = 1.0
	_check(brain.choose_state(r, w.manager) == Resident.State.IDLE, "nothing needed -> Idle")
	w.free_nodes()


func _test_state_transitions() -> void:
	var w := _make_world(1, 3)
	var sm := w.manager.state_machine
	var r: Resident = w.manager.residents[0]
	w.clock.hour = 10.0

	# Searching Food -> Eating, food really leaves the stockpile.
	_calm(r)
	r.hunger = 70.0
	var food_before := w.stockpile.food_total()
	sm.change_state(r, Resident.State.SEARCHING_FOOD, w.manager)
	var start := r.pos
	var saw_eating := false
	for i in range(400):
		w.tick(STEP)
		saw_eating = saw_eating or r.state == Resident.State.EATING
		if saw_eating and r.state != Resident.State.EATING:
			break
	_check(r.pos.distance_to(start) > 1.0 or start.distance_to(IslandMap.CAMP_DROP_POINT) < 40.0, "resident walked to the food source")
	_check(saw_eating, "Searching Food -> Eating")
	_check(w.stockpile.food_total() <= food_before - 0.99, "eating removed one portion from the stockpile")
	_check(r.hunger < 30.0, "eating reduced hunger")

	# Searching Water -> Drinking.
	_calm(r)
	r.thirst = 70.0
	sm.change_state(r, Resident.State.SEARCHING_WATER, w.manager)
	var saw_drinking := false
	for i in range(400):
		w.tick(STEP)
		saw_drinking = saw_drinking or r.state == Resident.State.DRINKING
		if saw_drinking and r.state != Resident.State.DRINKING:
			break
	_check(saw_drinking, "Searching Water -> Drinking")
	_check(r.thirst < 30.0, "drinking reduced thirst")

	# Searching Food with no food anywhere -> Idle.
	for resource in [Stockpile.FISH, Stockpile.FRUIT]:
		w.stockpile.amounts[resource] = 0.0
	for i in range(w.map.tree_fruit.size()):
		w.map.tree_fruit[i] = 0.0
	sm.change_state(r, Resident.State.SEARCHING_FOOD, w.manager)
	w.manager.state_machine.update(r, STEP, w.manager)
	_check(r.state == Resident.State.IDLE, "no food anywhere -> Idle")

	# Sleeping walks to camp, then restores energy.
	_calm(r)
	r.energy = 30.0
	w.clock.hour = 22.0
	sm.change_state(r, Resident.State.SLEEPING, w.manager)
	for i in range(300):
		w.manager.state_machine.update(r, STEP, w.manager)
	_check(r.is_sleeping(), "Sleeping: arrived at camp and fell asleep")
	_check(r.energy > 30.0, "sleeping restored energy")
	w.free_nodes()


func _test_fisher_finds_fish() -> void:
	var w := _make_world(1, 4)
	var r: Resident = w.manager.residents[0]
	r.job = JobDefinitions.FISHER
	_calm(r)
	# Empty every spot but one: the fisher must search for that one.
	for i in range(w.map.spot_fish.size()):
		w.map.spot_fish[i] = 0.0
	var stocked := 3
	w.map.spot_fish[stocked] = 14.0
	var fish_before := w.stockpile.get_amount(Stockpile.FISH)
	w.manager.state_machine.change_state(r, Resident.State.WORKING, w.manager)
	_check(r.site_index == stocked, "fisher searched for the only spot with fish")
	var delivered := false
	for i in range(1500):
		if w.manager.state_machine.update(r, STEP, w.manager):
			delivered = true
			break
	_check(delivered, "fisher finished the work cycle")
	_check(w.map.spot_fish[stocked] < 14.0, "catching took fish from the spot")
	_check(w.stockpile.get_amount(Stockpile.FISH) > fish_before, "caught fish were added to the stockpile")
	_check(r.carry_amount == 0.0, "fisher delivered the whole catch")
	# Every spot empty: fisher gives up instead of walking forever.
	w.map.spot_fish[stocked] = 0.0
	w.manager.state_machine.change_state(r, Resident.State.WORKING, w.manager)
	w.manager.state_machine.update(r, STEP, w.manager)
	_check(r.state == Resident.State.IDLE, "no fish anywhere -> Idle")
	w.free_nodes()


func _test_death() -> void:
	var w := _make_world(2, 5)
	var r: Resident = w.manager.residents[0]
	r.hunger = 20.0
	r.thirst = 100.0
	r.health = 1.0
	w.tick(3.0)
	_check(not r.alive, "resident dies when needs are not met")
	_check(w.manager.deaths == 1, "death is counted")
	_check(r.cause_of_death == "dehidrasi", "cause of death (dehidrasi) recorded")
	_check(w.event_log.entries[0].contains("meninggal"), "death is logged")
	var pos := r.pos
	w.tick(2.0)
	_check(r.pos == pos, "dead residents stay still")
	_check(w.manager.living_count() == 1, "living count updated")
	w.free_nodes()


func _test_long_simulation() -> void:
	var w := _make_world(SimConfig.POPULATION, 1234)
	for r in w.manager.residents:
		_check(w.map.is_on_land(r.pos), "%s spawned on land" % r.full_name)
	var night_sleep_ratio := 0.0
	var night_samples := 0
	var max_working := 0
	var seconds := SIM_DAYS * 24.0 / SimConfig.HOURS_PER_SECOND
	var t := 0.0
	while t < seconds:
		w.tick(STEP)
		t += STEP
		var summary := w.manager.activity_summary()
		max_working = maxi(max_working, int(summary.get(Resident.State.WORKING, 0)))
		if w.clock.hour >= 23.0 and w.clock.hour < 23.2:
			night_samples += 1
			night_sleep_ratio += float(summary.get(Resident.State.SLEEPING, 0)) / maxf(1.0, w.manager.living_count())
	night_sleep_ratio /= maxf(1.0, night_samples)

	print("--- Long simulation (%d days, %d residents) ---" % [SIM_DAYS, SimConfig.POPULATION])
	print("Alive: %d, deaths: %d, friendships: %d" % [w.manager.living_count(), w.manager.deaths, w.manager.friendship_count()])
	print("Stock: ", w.stockpile.amounts)
	print("Delivered: ", w.manager.delivered)
	print("States entered: ", _state_names(w.manager.state_counts))
	print("Night sleep ratio: %.2f, peak workers: %d" % [night_sleep_ratio, max_working])

	_check(w.manager.living_count() >= int(SimConfig.POPULATION * 0.9), "most residents survive %d days" % SIM_DAYS)
	for resource in Stockpile.ids():
		_check(float(w.manager.delivered.get(resource, 0.0)) > 0.0, "%s was delivered to camp" % resource)
	for state in Resident.State.values():
		_check(int(w.manager.state_counts.get(state, 0)) > 0, "state %s was used" % Resident.STATE_NAMES[state])
	_check(night_sleep_ratio > 0.6, "most residents sleep at night")
	_check(max_working >= 10, "many residents work during the day")
	for r in w.manager.residents:
		if r.alive:
			_check(r.hunger <= 100.0 and r.thirst <= 100.0 and r.energy >= 0.0 and r.health <= 100.0, "%s needs in range" % r.full_name)
	_check(w.manager.describe(0).contains("State:"), "describe() shows the state")
	w.free_nodes()


## Empty camp: residents must forage wild fruit and workers must restock food.
func _test_food_crisis() -> void:
	var w := _make_world(20, 99)
	for resource in Stockpile.ids():
		w.stockpile.amounts[resource] = 0.0
	for r in w.manager.residents:
		r.hunger = 60.0
		r.thirst = 60.0
	w.tick(3.0 * 24.0 / SimConfig.HOURS_PER_SECOND)
	var meals := int(w.manager.state_counts.get(Resident.State.EATING, 0))
	print("Food crisis: alive %d/20, food stock %.1f, meals %d" % [w.manager.living_count(), w.stockpile.food_total(), meals])
	_check(w.manager.living_count() >= 18, "residents survive an empty camp")
	_check(meals >= 20, "residents still find food in a crisis")
	_check(w.stockpile.food_total() > 0.0, "workers restock the empty camp")
	w.free_nodes()
