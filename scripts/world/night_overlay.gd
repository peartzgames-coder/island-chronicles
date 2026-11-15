class_name NightOverlay
extends Node2D
## Darkens the world at night and adds a warm glow around the camp fire.

var clock: GameClock
var map: IslandMap


func setup(p_clock: GameClock, p_map: IslandMap) -> void:
	clock = p_clock
	map = p_map


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if clock == null:
		return
	var dark := clock.darkness()
	if dark <= 0.01:
		return
	draw_rect(Rect2(Vector2.ZERO, SimConfig.WORLD_SIZE), Color(0.03, 0.05, 0.16, 0.5 * dark))
	if map != null and map.fire_lit:
		for i in range(3):
			draw_circle(IslandMap.FIRE_POS, 30.0 + i * 22.0, Color(1.0, 0.6, 0.25, 0.07 * dark))
