extends Node2D
## Placeholder body for the movement laboratory (replaced in phase 3).

@onready var cowl: Cowl = get_parent()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := Color(0.16, 0.16, 0.18)
	draw_rect(Rect2(-20, -100, 40, 100), c)
	draw_rect(Rect2(-26, -112, 52, 40), Color(0.92, 0.9, 0.88))
	draw_rect(Rect2(-20, -42, 40, 22), Color(0.7, 0.2, 0.18))
	draw_rect(Rect2(4 * cowl.facing - 4 + 8 * cowl.facing, -70, 12, 4), Color(0.6, 0.9, 1.0))
