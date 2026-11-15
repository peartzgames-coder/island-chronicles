extends Node2D
## Island Chronicles — composition root.
## Wires the world, the Resident AI and the HUD together and owns
## the global pause / simulation speed controls.

const SPEEDS := [1.0, 2.0, 4.0]

@onready var island_map: IslandMap = $IslandMap
@onready var resident_manager: ResidentManager = $ResidentManager
@onready var night_overlay: NightOverlay = $NightOverlay
@onready var hud: Hud = $Hud

var rng := RandomNumberGenerator.new()
var clock := GameClock.new()
var stockpile := Stockpile.new()
var event_log := EventLog.new()
var sim_speed := 1.0
var paused := false


func _ready() -> void:
	rng.randomize()
	resident_manager.setup(island_map, stockpile, clock, event_log, rng)
	resident_manager.spawn_population(SimConfig.POPULATION)
	night_overlay.setup(clock, island_map)
	clock.day_changed.connect(_on_day_changed)
	hud.pause_pressed.connect(_toggle_pause)
	hud.speed_pressed.connect(_cycle_speed)
	event_log.add("%d orang terdampar di Pulau Harapan." % SimConfig.POPULATION)
	event_log.add("Persediaan awal ditemukan di sekitar pantai.")


func _process(delta: float) -> void:
	if not paused:
		_simulate(delta * sim_speed)
	hud.refresh(clock, stockpile, resident_manager, event_log)


## Runs the simulation in fixed-size sub-steps so 4x speed stays stable.
func _simulate(delta: float) -> void:
	var steps := maxi(1, int(ceil(delta / SimConfig.MAX_STEP)))
	var dt := delta / steps
	for i in range(steps):
		clock.advance(dt)
		island_map.update_sites(dt)
		resident_manager.simulate(dt)


func _on_day_changed(day: int) -> void:
	resident_manager.on_day_changed(day)
	if day % 3 == 0:
		event_log.add("Hari %d: kelompok penduduk mulai menjelajahi bagian pulau." % day)
	if day % 5 == 0:
		event_log.add("Hari %d: persediaan makanan perlu diperhatikan." % day)


func _toggle_pause() -> void:
	paused = not paused
	hud.set_paused(paused)


func _cycle_speed() -> void:
	var index := SPEEDS.find(sim_speed)
	sim_speed = SPEEDS[(index + 1) % SPEEDS.size()]
	hud.set_speed(sim_speed)


## _unhandled_input so clicks on HUD buttons/panels don't change the selection.
func _unhandled_input(event: InputEvent) -> void:
	var pressed_at := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_at = make_input_local(event).position
	elif event is InputEventScreenTouch and event.pressed:
		pressed_at = make_input_local(event).position
	if pressed_at != Vector2.INF:
		resident_manager.selected_id = resident_manager.pick_at(pressed_at)
