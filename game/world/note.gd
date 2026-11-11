extends Node2D
## A small text marker (used by the movement lab's ruler).

var text := ""


func configure(spec: Dictionary) -> void:
	text = str(spec.get("text", ""))


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -24), Color(0.25, 0.2, 0.4), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(6, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.25, 0.2, 0.4))
