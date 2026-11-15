class_name Hud
extends CanvasLayer
## Prototype HUD (top bar, resources, event log, selected resident) built in code,
## extended with a live activity summary for the Resident AI.

signal pause_pressed
signal speed_pressed

var stats_label: Label
var day_label: Label
var log_label: Label
var selected_label: Label
var activity_label: Label
var resource_labels: Dictionary = {}
var pause_button: Button
var speed_button: Button


func _ready() -> void:
	_build()


func _build() -> void:
	var top := PanelContainer.new()
	top.position = Vector2(18, 16)
	top.size = Vector2(1244, 62)
	top.add_theme_stylebox_override("panel", _panel_style(Color("#182333"), 0.92))
	add_child(top)

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
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	top_row.add_child(pause_button)

	speed_button = Button.new()
	speed_button.text = "1x"
	speed_button.custom_minimum_size = Vector2(70, 38)
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	top_row.add_child(speed_button)

	var left := PanelContainer.new()
	left.position = Vector2(18, 94)
	left.size = Vector2(250, 220)
	left.add_theme_stylebox_override("panel", _panel_style(Color("#182333"), 0.90))
	add_child(left)
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
	for resource in Stockpile.ORDER:
		var text := Stockpile.label(resource)
		var l := Label.new()
		l.name = text + "Value"
		l.text = text + ": --"
		l.add_theme_font_size_override("font_size", 16)
		left_box.add_child(l)
		resource_labels[resource] = l
	var activity_title := Label.new()
	activity_title.text = "AKTIVITAS PENDUDUK"
	activity_title.add_theme_font_size_override("font_size", 12)
	activity_title.modulate = Color("#b8c6d8")
	left_box.add_child(activity_title)
	activity_label = Label.new()
	activity_label.add_theme_font_size_override("font_size", 13)
	left_box.add_child(activity_label)

	var bottom := PanelContainer.new()
	bottom.position = Vector2(18, 570)
	bottom.size = Vector2(770, 130)
	bottom.add_theme_stylebox_override("panel", _panel_style(Color("#182333"), 0.92))
	add_child(bottom)
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
	add_child(right)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 7)
	right.add_child(right_box)
	var sel_title := Label.new()
	sel_title.text = "PENDUDUK TERPILIH"
	sel_title.add_theme_font_size_override("font_size", 17)
	right_box.add_child(sel_title)
	selected_label = Label.new()
	selected_label.text = "Ketuk seseorang di pulau untuk melihat statusnya."
	selected_label.custom_minimum_size = Vector2(228, 0)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_font_size_override("font_size", 13)
	right_box.add_child(selected_label)

	var hint := Label.new()
	hint.text = "KLIK / KETUK PENDUDUK UNTUK MEMILIH"
	hint.position = Vector2(820, 655)
	hint.size = Vector2(440, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color("#e6e3d9")
	add_child(hint)


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


func set_paused(paused: bool) -> void:
	pause_button.text = "LANJUT" if paused else "JEDA"


func set_speed(speed: float) -> void:
	speed_button.text = str(int(speed)) + "x"


func refresh(clock: GameClock, stockpile: Stockpile, manager: ResidentManager, event_log: EventLog) -> void:
	day_label.text = clock.time_string()
	stats_label.text = "%d HIDUP  |  %d MENINGGAL" % [manager.living_count(), manager.deaths]
	for resource in Stockpile.ORDER:
		var l: Label = resource_labels.get(resource)
		if l != null:
			l.text = Stockpile.label(resource) + ": " + str(int(stockpile.get_amount(resource)))
	var a := manager.activity_summary()
	activity_label.text = "Kerja %d · Tidur %d\nMakan %d · Minum %d\nSosial %d · Santai %d" % [
		int(a.get(Resident.Action.WORK, 0)), int(a.get(Resident.Action.SLEEP, 0)),
		int(a.get(Resident.Action.EAT, 0)), int(a.get(Resident.Action.DRINK, 0)),
		int(a.get(Resident.Action.SOCIALIZE, 0)),
		int(a.get(Resident.Action.WANDER, 0)) + int(a.get(Resident.Action.IDLE, 0)),
	]
	if not event_log.entries.is_empty():
		log_label.text = event_log.as_text()
	if manager.selected_id >= 0:
		selected_label.text = manager.describe(manager.selected_id)
