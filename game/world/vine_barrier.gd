extends StaticBody2D
## Overgrowth across a way through. It stops Cowl until he has something to
## cut with; one good swing of the butcher knife parts it.

var w := 64.0
var h := 256.0
var _strands: Array = []
var _sway := 0.0
var _shake := 0.0
var _cut := false
var _fall := 0.0
var _hurt: Hurtbox


func configure(spec: Dictionary) -> void:
	w = float(spec.get("w", 1)) * Game.TILE
	h = float(spec.get("h", 4)) * Game.TILE


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 12
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(w * 0.5, -h * 0.5)
	add_child(cs)
	_hurt = Hurtbox.new()
	_hurt.owner_node = self
	var hs := RectangleShape2D.new()
	hs.size = Vector2(w + 40.0, h)
	var hcs := CollisionShape2D.new()
	hcs.shape = hs
	hcs.position = cs.position
	_hurt.add_child(hcs)
	_hurt.position = Vector2.ZERO
	add_child(_hurt)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7.0 + global_position.y)
	for i in 9:
		_strands.append({
			"x": rng.randf_range(-0.25, 1.25) * w, "amp": rng.randf_range(8.0, 26.0),
			"freq": rng.randf_range(1.2, 2.6), "ph": rng.randf_range(0.0, TAU),
			"thick": rng.randf_range(7.0, 20.0), "leaves": rng.randi_range(2, 5),
			"seed": rng.randi(),
		})


func take_hit(info: Dictionary) -> bool:
	if _cut:
		return false
	_cut = true
	collision_layer = 0
	_hurt.collision_layer = 0
	Sfx.play(&"vine_cut")
	HitFx.spawn(self, info["at"], info["direction"], Color(0.6, 0.95, 0.75))
	Puff.burst(self, global_position + Vector2(w * 0.5, -h * 0.5), 10, Vector2(float(info["direction"]) * 160.0, -60.0), 1.4)
	Game.shake(0.25)
	return true


func _process(delta: float) -> void:
	_sway += delta
	_shake = maxf(_shake - delta * 4.0, 0.0)
	if _cut:
		_fall += delta
		if _fall > 0.7:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var drop := _fall * _fall * 1500.0
	var alpha := clampf(1.0 - _fall / 0.7, 0.0, 1.0)
	for s: Dictionary in _strands:
		var pts := PackedVector2Array()
		var n := 14
		var rng := RandomNumberGenerator.new()
		rng.seed = s["seed"]
		for i in n + 1:
			var f := float(i) / n
			var x: float = s["x"] + sin(f * TAU * s["freq"] + s["ph"] + _sway * 0.7) * s["amp"] * (0.3 + f)
			var y := -h + f * (h + 8.0)
			if _cut:
				# Severed about a third of the way down: the top stays, the rest falls.
				if f > 0.3:
					y += drop * (0.6 + rng.randf() * 0.6)
					x += float(s["amp"]) * _fall * 3.0 * (rng.randf() - 0.5)
			pts.append(Vector2(x, y))
		var col := Pal.INK_SOFT
		col.a = alpha if _cut else 1.0
		draw_polyline(pts, col, s["thick"], true)
		var hi := Pal.LEAF
		hi.a = 0.8 * col.a
		draw_polyline(pts, hi, 2.0, true)
		for j in int(s["leaves"]):
			var p: Vector2 = pts[rng.randi_range(2, n - 1)]
			var a := rng.randf_range(-1.2, 1.2)
			var leaf := PackedVector2Array([p, p + Vector2(18, -6).rotated(a), p + Vector2(34, 2).rotated(a), p + Vector2(16, 9).rotated(a)])
			draw_colored_polygon(leaf, Color(Pal.LEAF.r, Pal.LEAF.g, Pal.LEAF.b, col.a))
