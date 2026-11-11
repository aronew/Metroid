extends Node2D
## Something in front of the play that hides a way through (here, the bank of
## pipes behind the boiler). It never collides. It thins out when Cowl is
## behind it, so finding the gap is a discovery, not a guess.

var w := 256.0
var h := 640.0
var _a := 1.0


func configure(spec: Dictionary) -> void:
	w = float(spec.get("w", 4)) * Game.TILE
	h = float(spec.get("h", 10)) * Game.TILE


func _ready() -> void:
	z_index = 40


func _process(delta: float) -> void:
	var cowl := get_tree().get_first_node_in_group(&"player") as Cowl
	var inside := false
	if cowl != null:
		inside = Rect2(global_position + Vector2(-20, -h - 40), Vector2(w + 40, h + 400)).has_point(cowl.global_position)
		if inside and not Game.get_flag("found_gap"):
			Game.set_flag("found_gap")
			Sfx.play(&"secret")
	_a = move_toward(_a, 0.18 if inside else 1.0, delta * 2.5)
	modulate.a = _a


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := 6.0
	while x < w - 6.0:
		var pw := rng.randf_range(16.0, 38.0)
		draw_rect(Rect2(x, -h, pw, h), Pal.INK)
		draw_line(Vector2(x + 3, -h), Vector2(x + 3, 0), Color(Pal.EDGE.r, Pal.EDGE.g, Pal.EDGE.b, 0.7), 2.0)
		for k in 3:
			var y := -rng.randf_range(0.1, 0.95) * h
			draw_rect(Rect2(x - 4, y, pw + 8, 12), Pal.INK)
		x += pw + rng.randf_range(4.0, 14.0)
	# A breath of cold light through the gaps: the tell.
	for i in 5:
		var y := -h * (0.15 + 0.17 * i)
		draw_circle(Vector2(w * 0.5, y), 60.0, Color(Pal.WATER.r, Pal.WATER.g, Pal.WATER.b, 0.05))
