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


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x)
	var x := 0.0
	while x < w:
		var bw := rng.randf_range(22.0, 44.0)
		var bh := rng.randf_range(0.7, 1.35) * h
		var tip := Vector2(x + bw * rng.randf_range(0.35, 0.65), -bh)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 4), tip, Vector2(x + bw + 4, 4)]), Pal.INK)
		draw_line(Vector2(x - 2, 0), tip, Pal.EDGE, 2.0, true)
		x += bw * 0.8
