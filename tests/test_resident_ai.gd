extends SceneTree
## Headless smoke test for the Resident AI.
## Run from the project root:
##   godot --headless --import            (first time only, builds the class cache)
##   godot --headless -s res://tests/test_resident_ai.gd

const SIM_DAYS := 12
const STEP := 0.1

var failures := 0


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var clock := GameClock.new()
	var stockpile := Stockpile.new()
	var event_log := EventLog.new()
	var map: IslandMap = load("res://scenes/world/island.tscn").instantiate()
	var manager: ResidentManager = load("res://scenes/residents/resident_manager.tscn").instantiate()
	root.add_child(map)
	root.add_child(manager)
	manager.setup(map, stockpile, clock, event_log, rng)
	manager.spawn_population(SimConfig.POPULATION)
	clock.day_changed.connect(manager.on_day_changed)

	_check(map.tree_positions.size() > 0, "island has trees")
	_check(map.camp != null, "island scene contains the camp building")
	_check(manager.profile != null and manager.profile.first_names.size() == 20, "resident profile data loaded")
	for resource in Stockpile.ids():
		_check(ResourceCatalog.get_type(resource) != null, "resource data for %s loaded" % resource)
	for job in JobDefinitions.ALL:
		_check(JobDefinitions.get_job(job) != null, "job data for %s loaded" % job)
	_check(Stockpile.ids().size() == 4 and stockpile.get_amount(Stockpile.FISH) == 120.0, "stockpile starts from data")
	for spot in map.fishing_spots:
		_check(Geometry2D.is_point_in_polygon(spot, map.sand_polygon), "fishing spot %s is on the beach" % spot)
	for r in manager.residents:
		_check(map.is_on_land(r.pos), "%s spawned on land" % r.full_name)

	var night_sleep_ratio := 0.0
	var night_samples := 0
	var max_working := 0
	var seconds := SIM_DAYS * 24.0 / SimConfig.HOURS_PER_SECOND
	var t := 0.0
	while t < seconds:
		clock.advance(STEP)
		map.update_sites(STEP)
		manager.simulate(STEP)
		t += STEP
		var summary := manager.activity_summary()
		max_working = maxi(max_working, int(summary.get(Resident.Action.WORK, 0)))
		if clock.hour >= 23.0 and clock.hour < 23.2:
			night_samples += 1
			night_sleep_ratio += float(summary.get(Resident.Action.SLEEP, 0)) / maxf(1.0, manager.living_count())

	night_sleep_ratio /= maxf(1.0, night_samples)
	print("--- Resident AI smoke test (%d days) ---" % SIM_DAYS)
	print("Alive: %d / %d, deaths: %d, friendships: %d" % [manager.living_count(), SimConfig.POPULATION, manager.deaths, manager.friendship_count()])
	print("Stock: ", stockpile.amounts)
	print("Delivered: ", manager.delivered)
	print("Finished actions: ", _named_counts(manager.action_counts))
	print("Night sleep ratio: %.2f, peak workers: %d" % [night_sleep_ratio, max_working])
	print("Log: ", event_log.entries)

	_check(manager.living_count() >= int(SimConfig.POPULATION * 0.9), "most residents survive %d days" % SIM_DAYS)
	for resource in Stockpile.ids():
		_check(float(manager.delivered.get(resource, 0.0)) > 0.0, "%s was delivered to camp" % resource)
	for action in [Resident.Action.EAT, Resident.Action.DRINK, Resident.Action.SLEEP, Resident.Action.WORK, Resident.Action.SOCIALIZE]:
		_check(int(manager.action_counts.get(action, 0)) > 0, "residents performed %s" % Resident.ACTION_NAMES[action])
	_check(night_sleep_ratio > 0.6, "most residents sleep at night")
	_check(max_working >= 10, "many residents work during the day")
	for r in manager.residents:
		if r.alive:
			_check(r.hunger <= 100.0 and r.thirst <= 100.0 and r.energy >= 0.0, "%s needs in range" % r.full_name)
	_check(manager.pick_at(manager.residents[0].pos) >= 0 or not manager.residents[0].alive, "selection picks a resident")
	_check(manager.describe(0).length() > 0, "describe() returns text")

	_test_food_crisis()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	map.queue_free()
	manager.queue_free()
	quit(1 if failures > 0 else 0)


## Empty camp: residents must forage wild fruit and workers must restock food.
func _test_food_crisis() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var clock := GameClock.new()
	var stockpile := Stockpile.new()
	for resource in Stockpile.ids():
		stockpile.amounts[resource] = 0.0
	var map := IslandMap.new()  # bare map without its scene must also work
	var manager: ResidentManager = load("res://scenes/residents/resident_manager.tscn").instantiate()
	root.add_child(map)
	root.add_child(manager)
	manager.setup(map, stockpile, clock, EventLog.new(), rng)
	manager.spawn_population(20)
	for r in manager.residents:
		r.hunger = 60.0
		r.thirst = 60.0
	var t := 0.0
	while t < 3.0 * 24.0 / SimConfig.HOURS_PER_SECOND:
		clock.advance(STEP)
		map.update_sites(STEP)
		manager.simulate(STEP)
		t += STEP
	print("Food crisis: alive %d/20, food stock %.1f, meals %d" % [manager.living_count(), stockpile.food_total(), int(manager.action_counts.get(Resident.Action.EAT, 0))])
	_check(manager.living_count() >= 18, "residents survive an empty camp")
	_check(int(manager.action_counts.get(Resident.Action.EAT, 0)) >= 20, "residents still find food in a crisis")
	_check(stockpile.food_total() > 0.0, "workers restock the empty camp")
	map.queue_free()
	manager.queue_free()


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("  FAIL: " + label)


func _named_counts(counts: Dictionary) -> Dictionary:
	var named := {}
	for key in counts:
		named[Resident.ACTION_NAMES[key]] = counts[key]
	return named
