class_name IslandMap
extends Node2D
## Draws the procedural island (unchanged prototype art) and exposes the
## points of interest residents use: camp, fire, pond, fishing spots and trees.

const WATER_COLOR := Color("#263e58")
const SAND_COLOR := Color("#d9bd82")
const GRASS_COLOR := Color("#557c4c")

const ISLAND_CENTER := Vector2(650, 370)
const POND_CENTER := Vector2(610, 390)
const POND_RADIUS := 52.0
const POND_BANK_RADIUS := 66.0
const CAMP_RECT := Rect2(730, 300, 80, 48)
const CAMP_DROP_POINT := Vector2(770, 362)
const FIRE_POS := Vector2(830, 330)

const TREE_SLOTS := 30
const TREE_FRUIT_MAX := 8.0
const TREE_FRUIT_REGEN := 0.04
const SPOT_FISH_MAX := 14.0
const SPOT_FISH_REGEN := 0.07

var shore_polygon := PackedVector2Array([Vector2(300,370),Vector2(350,220),Vector2(480,145),Vector2(700,130),Vector2(900,190),Vector2(1000,320),Vector2(980,500),Vector2(850,610),Vector2(590,635),Vector2(390,560),Vector2(285,455)])
var sand_polygon := PackedVector2Array([Vector2(320,365),Vector2(375,230),Vector2(495,165),Vector2(700,150),Vector2(885,205),Vector2(975,325),Vector2(955,485),Vector2(830,590),Vector2(600,615),Vector2(410,545),Vector2(310,450)])
var grass_polygon := PackedVector2Array([Vector2(405,340),Vector2(455,235),Vector2(570,190),Vector2(755,190),Vector2(875,255),Vector2(910,370),Vector2(865,500),Vector2(720,560),Vector2(535,555),Vector2(415,475),Vector2(375,400)])

var tree_positions: Array[Vector2] = []
var tree_shades: Array[int] = []
var tree_fruit: Array[float] = []
var fishing_spots: Array[Vector2] = []
var spot_fish: Array[float] = []
var fire_lit := true

var _is_setup := false


func _ready() -> void:
	setup()


## Builds the site lists. Safe to call more than once.
func setup() -> void:
	if _is_setup:
		return
	_is_setup = true
	# Same placement formula as the prototype so the island looks identical.
	for i in range(TREE_SLOTS):
		var a := float(i) * 2.399
		var radius := _seed_radius(i)
		var pos := ISLAND_CENTER + Vector2(cos(a) * radius, sin(a) * radius * 0.62)
		if pos.x > 410 and pos.x < 900 and pos.y > 205 and pos.y < 545:
			tree_positions.append(pos)
			tree_shades.append(i % 3)
			tree_fruit.append(TREE_FRUIT_MAX * 0.75)
	# Fishing spots sit on the beach just inside each shoreline vertex.
	for v in sand_polygon:
		fishing_spots.append(v.lerp(ISLAND_CENTER, 0.05))
		spot_fish.append(SPOT_FISH_MAX)


func update_sites(delta: float) -> void:
	for i in range(tree_fruit.size()):
		tree_fruit[i] = minf(TREE_FRUIT_MAX, tree_fruit[i] + TREE_FRUIT_REGEN * delta)
	for i in range(spot_fish.size()):
		spot_fish[i] = minf(SPOT_FISH_MAX, spot_fish[i] + SPOT_FISH_REGEN * delta)


# --- Queries -----------------------------------------------------------------

func is_on_land(point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point, sand_polygon):
		return false
	if point.distance_to(POND_CENTER) < POND_BANK_RADIUS:
		return false
	return not CAMP_RECT.grow(4.0).has_point(point)


func random_land_point(rng: RandomNumberGenerator) -> Vector2:
	for _attempt in range(24):
		var p := Vector2(rng.randf_range(330, 970), rng.randf_range(165, 590))
		if is_on_land(p):
			return p
	return Vector2(700, 470)


func random_far_point(rng: RandomNumberGenerator, from: Vector2, min_distance: float) -> Vector2:
	var best := random_land_point(rng)
	for _attempt in range(8):
		if best.distance_to(from) >= min_distance:
			break
		best = random_land_point(rng)
	return best


func camp_point(rng: RandomNumberGenerator) -> Vector2:
	return CAMP_DROP_POINT + Vector2(rng.randf_range(-26, 26), rng.randf_range(-3, 10))


func sleep_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(705, 875), rng.randf_range(356, 425))


func pond_drink_point(from: Vector2) -> Vector2:
	var dir := from - POND_CENTER
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	return POND_CENTER + dir.normalized() * (POND_BANK_RADIUS + 4.0)


func tree_work_point(index: int) -> Vector2:
	return tree_positions[index] + Vector2(0, 22)


func nearest_tree_with_fruit(from: Vector2, min_fruit: float = 1.0) -> int:
	var best := -1
	var best_dist := INF
	for i in range(tree_positions.size()):
		if tree_fruit[i] < min_fruit:
			continue
		var d := from.distance_squared_to(tree_positions[i])
		if d < best_dist:
			best_dist = d
			best = i
	return best


## Picks one of the closest few trees so workers spread out.
func pick_tree(from: Vector2, rng: RandomNumberGenerator, need_fruit: bool) -> int:
	var candidates: Array[Vector2i] = []  # x = index, y = squared distance (int)
	for i in range(tree_positions.size()):
		if need_fruit and tree_fruit[i] < 2.0:
			continue
		candidates.append(Vector2i(i, int(from.distance_squared_to(tree_positions[i]))))
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	return candidates[rng.randi_range(0, mini(3, candidates.size() - 1))].x


func pick_fishing_spot(from: Vector2, rng: RandomNumberGenerator) -> int:
	var best := 0
	var best_score := -INF
	for i in range(fishing_spots.size()):
		var score := spot_fish[i] - from.distance_to(fishing_spots[i]) * 0.02 + rng.randf() * 3.0
		if score > best_score:
			best_score = score
			best = i
	return best


func take_fruit(index: int, amount: float) -> float:
	if index < 0 or index >= tree_fruit.size():
		return 0.0
	var taken := minf(amount, tree_fruit[index])
	tree_fruit[index] -= taken
	return taken


func take_fish(index: int, amount: float) -> float:
	if index < 0 or index >= spot_fish.size():
		return 0.0
	var taken := minf(amount, spot_fish[index])
	spot_fish[index] -= taken
	return taken


# --- Drawing -----------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Water background and subtle wave bands
	draw_rect(Rect2(Vector2.ZERO, SimConfig.WORLD_SIZE), WATER_COLOR)
	for y in range(0, 720, 34):
		draw_line(Vector2(0, y), Vector2(1280, y + 8), Color("#45627a", 0.24), 2)
	# Island layers
	draw_colored_polygon(shore_polygon, Color("#9a865d"))
	draw_colored_polygon(sand_polygon, SAND_COLOR)
	draw_colored_polygon(grass_polygon, GRASS_COLOR)
	# Inland pond and river
	draw_circle(POND_CENTER, POND_BANK_RADIUS, Color("#477b91"))
	draw_circle(POND_CENTER, POND_RADIUS, Color("#6098a6"))
	draw_line(POND_CENTER, Vector2(560, 505), Color("#6098a6"), 18)
	# Trees and bushes
	for i in range(tree_positions.size()):
		_draw_tree(tree_positions[i], tree_shades[i], tree_fruit[i])
	# Beach camp
	draw_rect(CAMP_RECT, Color("#8a6042"))
	draw_rect(Rect2(738, 307, 64, 34), Color("#d6b27a"))
	draw_line(Vector2(735, 300), Vector2(770, 275), Color("#594331"), 5)
	draw_line(Vector2(770, 275), Vector2(812, 300), Color("#594331"), 5)
	if fire_lit:
		draw_circle(FIRE_POS, 12, Color("#d77b40"))
		draw_circle(FIRE_POS, 6, Color("#f3c46b"))
	else:
		draw_circle(FIRE_POS, 10, Color("#5a4a40"))
		draw_circle(FIRE_POS, 4, Color("#7a5a44"))
	# Boat
	draw_colored_polygon(PackedVector2Array([Vector2(180,360),Vector2(250,350),Vector2(230,380),Vector2(195,383)]), Color("#78543d"))
	draw_line(Vector2(215, 350), Vector2(215, 300), Color("#e4d5ad"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(218,303),Vector2(245,340),Vector2(218,340)]), Color("#eee2c5"))


func _seed_radius(i: int) -> float:
	return 75.0 + float((i * 37) % 150)


func _draw_tree(pos: Vector2, shade: int, fruit: float) -> void:
	draw_rect(Rect2(pos.x - 3, pos.y + 7, 6, 13), Color("#654b32"))
	var palette: Array[Color] = [Color("#315b3b"), Color("#3e7043"), Color("#6e8747")]
	var c: Color = palette[shade % palette.size()]
	draw_circle(pos, 15, c)
	draw_circle(pos + Vector2(-7, -5), 8, c.lightened(0.12))
	draw_circle(pos + Vector2(7, -3), 7, c.darkened(0.08))
	# Ripe fruit indicator (new): up to three dots depending on remaining fruit.
	var dots := int(fruit / (TREE_FRUIT_MAX / 3.0))
	for d in range(dots):
		draw_circle(pos + Vector2(-6 + d * 6, 4), 2.2, Color("#f0a040"))
