class_name Camp
extends Node2D
## The survivors' beach camp: shelter hut and camp fire (prototype art).
## Node position = top-left corner of the hut; drawing is in local space.

const HUT_SIZE := Vector2(80, 48)
const FIRE_OFFSET := Vector2(100, 30)

var fire_lit := true:
	set(value):
		if fire_lit != value:
			fire_lit = value
			queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, HUT_SIZE), Color("#8a6042"))
	draw_rect(Rect2(8, 7, 64, 34), Color("#d6b27a"))
	draw_line(Vector2(5, 0), Vector2(40, -25), Color("#594331"), 5)
	draw_line(Vector2(40, -25), Vector2(82, 0), Color("#594331"), 5)
	if fire_lit:
		draw_circle(FIRE_OFFSET, 12, Color("#d77b40"))
		draw_circle(FIRE_OFFSET, 6, Color("#f3c46b"))
	else:
		draw_circle(FIRE_OFFSET, 10, Color("#5a4a40"))
		draw_circle(FIRE_OFFSET, 4, Color("#7a5a44"))
