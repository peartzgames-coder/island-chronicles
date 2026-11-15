extends Node2D

# Island Chronicles - playable autonomous survival prototype
# Built for Godot 4.x. All visuals are drawn procedurally, so no external assets are required.

const WORLD_SIZE := Vector2(1280, 720)
const POPULATION := 50
const WATER_COLOR := Color("#263e58")
const SAND_COLOR := Color("#d9bd82")
const GRASS_COLOR := Color("#557c4c")

var rng := RandomNumberGenerator.new()
var people: Array[Dictionary] = []
var day := 1
var hour := 7.0
var sim_speed := 1.0
var paused := false
var selected_id := -1
var event_log: Array[String] = []
var fish_stock := 120.0
var fruit_stock := 160.0
var wood_stock := 80.0
var water_stock := 180.0
var births := 0
var deaths := 0
var ui_layer: CanvasLayer
var stats_label: Label
var day_label: Label
var log_label: Label
var selected_label: Label
var resource_labels: Dictionary = {}
var pause_button: Button
var speed_button: Button
var island_center := Vector2(650, 370)

func _ready() -> void:
	rng.randomize()
	_create_population()
	_create_ui()
	_add_event("50 orang terdampar di Pulau Harapan.")
	_add_event("Persediaan awal ditemukan di sekitar pantai.")
	queue_redraw()

func _create_population() -> void:
	var names := ["Ari","Bima","Citra","Dara","Eko","Fajar","Gita","Hana","Indra","Joko","Kirana","Laras","Made","Nadia","Oki","Putri","Raka","Sari","Tono","Wulan"]
	for i in POPULATION:
		var p := {
			"id": i,
			"name": names[i % names.size()] + (" %02d" % (i + 1)),
			"pos": Vector2(rng.randf_range(360, 940), rng.randf_range(170, 590)),
			"target": Vector2.ZERO,
			"age": rng.randi_range(18, 55),
			"health": 100.0,
			"hunger": rng.randf_range(8, 35),
			"thirst": rng.randf_range(5, 30),
			"energy": rng.randf_range(60, 100),
			"job": ["Nelayan","Pengumpul","Penebang","Penjelajah"][i % 4],
			"alive": true,
			"color": [Color("#e8b65d"),Color("#d77e65"),Color("#7db2a1"),Color("#a68ac7")][i % 4],
			"social": rng.randf_range(35, 85),
			"wander": rng.randf_range(0.5, 3.0)
		}
		p.target = p.pos
		people.append(p)

func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var top := PanelContainer.new()
	top.position = Vector2(18, 16)
	top.size = Vector2(1244, 62)
	top.add_theme_stylebox_override("panel", _panel_style(Color("#182333"), 0.92))
	ui_layer.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 22)
	top.add_child(top_row)

	day_label = Label.new()
	day_label.text = "HARI 01  •  07:00"
	day_label.add_theme_font_size_override("font_size", 21)
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(day_label)

	stats_label = Label.new()
	stats_label.text = "50 HIDUP  |  0 MENINGGAL"
	stats_label.add_theme_font_size_override("font_size", 17)
	top_row.add_child(stats_label)

	pause_button = Button.new()
	pause_button.text = "JEDA"
	pause_button.custom_minimum_size = Vector2(90, 38)
	pause_button.pressed.connect(_toggle_pause)
	top_row.add_child(pause_button)

	speed_button = Button.new()
	speed_button.text = "1x"
	speed_button.custom_minimum_size = Vector2(70, 38)
	speed_button.pressed.connect(_cycle_speed)
	top_row.add_child(speed_button)

	var left := PanelContainer.new()
	left.position = Vector2(18, 94)
	left.size = Vector2(250, 220)
	left.add_theme_stylebox_override("panel", _panel_style(Color("#182333"), 0.90))
	ui_layer.add_child(left)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 7)
	left.add_child(left_box)
	var title := Label.new()
	title.text = "PULAU HARAPAN"
	title.add_theme_font_size_override("font_size", 19)
	left_box.add_child(title)
	var sub := Label.new()
	sub.text = "KONDISI SUMBER DAYA"
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color("#b8c6d8")
	left_box.add_child(sub)
	for text in ["Ikan","Buah","Kayu","Air"]:
		var l := Label.new()
		l.name = text + "Value"
		l.text = text + ": --"
		l.add_theme_font_size_override("font_size", 16)
		left_box.add_child(l)
		resource_labels[text] = l

	var bottom := PanelContainer.new()
	bottom.position = Vector2(18, 570)
	bottom.size = Vector2(770, 130)
	bottom.add_theme_stylebox_override("panel", _panel_style(Color("#182333"), 0.92))
	ui_layer.add_child(bottom)
	var bottom_box := VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 5)
	bottom.add_child(bottom_box)
	var log_title := Label.new()
	log_title.text = "CATATAN PULAU"
	log_title.add_theme_font_size_override("font_size", 14)
	bottom_box.add_child(log_title)
	log_label = Label.new()
	log_label.text = "Menunggu aktivitas penduduk..."
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_box.add_child(log_label)

	var right := PanelContainer.new()
	right.position = Vector2(1010, 94)
	right.size = Vector2(252, 240)
	right.add_theme_stylebox_override("panel", _panel_style(Color("#182333"), 0.90))
	ui_layer.add_child(right)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 7)
	right.add_child(right_box)
	var sel_title := Label.new()
	sel_title.text = "PENDUDUK TERPILIH"
	sel_title.add_theme_font_size_override("font_size", 17)
	right_box.add_child(sel_title)
	selected_label = Label.new()
	selected_label.text = "Ketuk seseorang di pulau untuk melihat statusnya."
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_font_size_override("font_size", 14)
	right_box.add_child(selected_label)

	var hint := Label.new()
	hint.text = "KLIK / KETUK PENDUDUK UNTUK MEMILIH"
	hint.position = Vector2(820, 655)
	hint.size = Vector2(440, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color("#e6e3d9")
	ui_layer.add_child(hint)

func _panel_style(color: Color, alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, alpha)
	s.border_color = Color("#8294a9", 0.45)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _process(delta: float) -> void:
	if not paused:
		_simulate(delta * sim_speed)
	_update_ui()
	queue_redraw()

func _simulate(delta: float) -> void:
	hour += delta * 1.2
	if hour >= 24.0:
		hour -= 24.0
		_next_day()
	for i in range(people.size()):
		var p: Dictionary = people[i]
		if not p.alive:
			continue
		p.hunger = minf(100.0, p.hunger + delta * 0.55)
		p.thirst = minf(100.0, p.thirst + delta * 0.72)
		p.energy = maxf(0.0, p.energy - delta * 0.18)
		p.social = maxf(0.0, p.social - delta * 0.06)
		if p.target.distance_to(p.pos) < 5.0 or p.wander <= 0.0:
			p.target = _random_land_point()
			p.wander = rng.randf_range(2.0, 7.0)
		else:
			var direction: Vector2 = (p.target - p.pos).normalized()
			p.pos += direction * delta * 16.0
			p.wander -= delta
		if p.hunger > 75.0 or p.thirst > 80.0:
			p.health -= delta * 0.8
		if p.energy < 12.0:
			p.energy = minf(100.0, p.energy + delta * 0.7)
		if p.health <= 0.0:
			p.alive = false
			deaths += 1
			_add_event(p.name + " meninggal karena kondisi tubuh memburuk.")
		people[i] = p
	# Small autonomous resource loop: workers replenish/consume island stores.
	if rng.randf() < delta * 0.35:
		var worker := _living_count()
		if worker > 0:
			fish_stock = maxf(0, fish_stock - rng.randf_range(0.2, 1.0))
			fruit_stock = maxf(0, fruit_stock - rng.randf_range(0.1, 0.7))
			wood_stock = minf(250, wood_stock + rng.randf_range(0.1, 0.8))
			water_stock = maxf(0, water_stock - rng.randf_range(0.1, 0.5))

func _next_day() -> void:
	day += 1
	for i in range(people.size()):
		var p := people[i]
		if not p.alive:
			continue
		p.age += 1 if day % 365 == 0 else 0
		p.hunger = maxf(0, p.hunger - rng.randf_range(8, 20))
		p.thirst = maxf(0, p.thirst - rng.randf_range(10, 22))
		p.energy = minf(100, p.energy + rng.randf_range(20, 40))
		p.social = minf(100, p.social + rng.randf_range(3, 12))
		people[i] = p
	if day % 3 == 0:
		_add_event("Hari %d: kelompok penduduk mulai menjelajahi bagian pulau." % day)
	if day % 5 == 0:
		_add_event("Hari %d: persediaan makanan perlu diperhatikan." % day)

func _random_land_point() -> Vector2:
	return Vector2(rng.randf_range(330, 970), rng.randf_range(165, 590))

func _living_count() -> int:
	var n := 0
	for p in people:
		if p.alive:
			n += 1
	return n

func _add_event(message: String) -> void:
	event_log.push_front("• " + message)
	if event_log.size() > 4:
		event_log.pop_back()

func _update_ui() -> void:
	day_label.text = "HARI %02d  •  %02d:%02d" % [day, int(hour), int((hour - floor(hour)) * 60)]
	stats_label.text = "%d HIDUP  |  %d MENINGGAL" % [_living_count(), deaths]
	for key in ["Ikan","Buah","Kayu","Air"]:
		var value := {"Ikan":fish_stock,"Buah":fruit_stock,"Kayu":wood_stock,"Air":water_stock}[key]
		var l: Label = resource_labels.get(key)
		if l != null:
			l.text = key + ": " + str(int(value))
	log_label.text = "\n".join(event_log)
	if selected_id >= 0 and selected_id < people.size():
		var p: Dictionary = people[selected_id]
		if p.alive:
			selected_label.text = "%s\nUsia: %d tahun\nPekerjaan: %s\nKesehatan: %d%%\nLapar: %d%%\nHaus: %d%%\nEnergi: %d%%" % [p.name,p.age,p.job,int(p.health),int(p.hunger),int(p.thirst),int(p.energy)]
		else:
			selected_label.text = p.name + "\nStatus: Meninggal"

func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "LANJUT" if paused else "JEDA"

func _cycle_speed() -> void:
	if sim_speed == 1.0:
		sim_speed = 2.0
	elif sim_speed == 2.0:
		sim_speed = 4.0
	else:
		sim_speed = 1.0
	speed_button.text = str(int(sim_speed)) + "x"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_person(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_select_person(event.position)

func _select_person(point: Vector2) -> void:
	var nearest := -1
	var best := 24.0
	for i in range(people.size()):
		var p: Dictionary = people[i]
		if not p.alive:
			continue
		var d: float = point.distance_to(p.pos)
		if d < best:
			best = d
			nearest = i
	selected_id = nearest

func _draw() -> void:
	# Water background and subtle wave bands
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), WATER_COLOR)
	for y in range(0, 720, 34):
		draw_line(Vector2(0,y), Vector2(1280,y+8), Color("#45627a",0.24), 2)
	# Island layers
	var shore := PackedVector2Array([Vector2(300,370),Vector2(350,220),Vector2(480,145),Vector2(700,130),Vector2(900,190),Vector2(1000,320),Vector2(980,500),Vector2(850,610),Vector2(590,635),Vector2(390,560),Vector2(285,455)])
	draw_colored_polygon(shore, Color("#9a865d"))
	var sand := PackedVector2Array([Vector2(320,365),Vector2(375,230),Vector2(495,165),Vector2(700,150),Vector2(885,205),Vector2(975,325),Vector2(955,485),Vector2(830,590),Vector2(600,615),Vector2(410,545),Vector2(310,450)])
	draw_colored_polygon(sand, SAND_COLOR)
	var grass := PackedVector2Array([Vector2(405,340),Vector2(455,235),Vector2(570,190),Vector2(755,190),Vector2(875,255),Vector2(910,370),Vector2(865,500),Vector2(720,560),Vector2(535,555),Vector2(415,475),Vector2(375,400)])
	draw_colored_polygon(grass, GRASS_COLOR)
	# Inland pond and river
	draw_circle(Vector2(610,390), 66, Color("#477b91"))
	draw_circle(Vector2(610,390), 52, Color("#6098a6"))
	draw_line(Vector2(610,390), Vector2(560,505), Color("#6098a6"), 18)
	# Trees and bushes
	for i in range(30):
		var a := float(i) * 2.399
		var pos := Vector2(650,370) + Vector2(cos(a)*rng_seed_radius(i), sin(a)*rng_seed_radius(i)*0.62)
		if pos.x > 410 and pos.x < 900 and pos.y > 205 and pos.y < 545:
			_draw_tree(pos, i)
	# Beach camp
	draw_rect(Rect2(730,300,80,48), Color("#8a6042"))
	draw_rect(Rect2(738,307,64,34), Color("#d6b27a"))
	draw_line(Vector2(735,300), Vector2(770,275), Color("#594331"), 5)
	draw_line(Vector2(770,275), Vector2(812,300), Color("#594331"), 5)
	draw_circle(Vector2(830,330), 12, Color("#d77b40"))
	draw_circle(Vector2(830,330), 6, Color("#f3c46b"))
	# Boat
	draw_colored_polygon(PackedVector2Array([Vector2(180,360),Vector2(250,350),Vector2(230,380),Vector2(195,383)]), Color("#78543d"))
	draw_line(Vector2(215,350), Vector2(215,300), Color("#e4d5ad"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(218,303),Vector2(245,340),Vector2(218,340)]), Color("#eee2c5"))
	# People
	for i in range(people.size()):
		var p: Dictionary = people[i]
		if p.alive:
			_draw_person(p, i == selected_id)

func rng_seed_radius(i: int) -> float:
	return 75.0 + float((i * 37) % 150)

func _draw_tree(pos: Vector2, index: int) -> void:
	draw_rect(Rect2(pos.x-3,pos.y+7,6,13), Color("#654b32"))
	var c := [Color("#315b3b"),Color("#3e7043"),Color("#6e8747")][index % 3]
	draw_circle(pos, 15, c)
	draw_circle(pos + Vector2(-7,-5), 8, c.lightened(0.12))
	draw_circle(pos + Vector2(7,-3), 7, c.darkened(0.08))

func _draw_person(p: Dictionary, is_selected: bool) -> void:
	var pos: Vector2 = p.pos
	if is_selected:
		draw_arc(pos, 13, 0, TAU, 20, Color("#fff0a6"), 2.5)
	draw_rect(Rect2(pos.x-4,pos.y-2,8,10), p.color)
	draw_rect(Rect2(pos.x-4,pos.y-8,8,7), Color("#e6bd91"))
	draw_rect(Rect2(pos.x-4,pos.y-9,8,3), Color("#443b35"))
	draw_rect(Rect2(pos.x-4,pos.y+7,3,5), Color("#463f3a"))
	draw_rect(Rect2(pos.x+1,pos.y+7,3,5), Color("#463f3a"))
	if is_selected:
		draw_string(ThemeDB.fallback_font, pos + Vector2(-20,-17), p.name.split(" ")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
