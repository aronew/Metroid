extends Area2D
## Stalagmites. Touching them hurts and puts Cowl back on his last sound footing.

var w := 256.0
var h := 64.0


func configure(spec: Dictionary) -> void:
	w = float(spec.get("w", 1)) * Game.TILE
	h = float(spec.get("h", 1)) * Game.TILE


func _ready() -> void:
	collision_layer = 64
	collision_mask = 0
	monitoring = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w - 12.0, h * 0.7)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(w * 0.5, -h * 0.35)
	add_child(cs)
	z_index = 6


func is_spikes() -> bool:
	return true


## Kit art (W34): stalagmites in their trench, fitted to the hazard's width.
func _draw() -> void:
	var t := Kit.tex("props/stalagmites")
	if t == null:
		return
	var s := (w + 20.0) / t.get_width()
	var size := t.get_size() * s
	draw_texture_rect(t, Rect2(-10.0, -size.y + 6.0, size.x, size.y), false)
