class_name Puff
extends Node2D
## Soft dust: a few pale discs that swell, drift and fade. Used for footfalls,
## take-offs, landings and the dodge.

var _dots: Array = []
var _t := 0.0
var _life := 0.5


static func burst(near: Node, at: Vector2, count: int, drift: Vector2 = Vector2.ZERO, size: float = 1.0) -> void:
	if Sfx.muted or not near.is_inside_tree():
		return
	var p := Puff.new()
	p.z_index = 9
	p._life = 0.34 + 0.2 * size
	for i in count:
		var spread := (float(i) / maxf(count - 1, 1) - 0.5) * 2.0
		p._dots.append({
			"p": Vector2(spread * 18.0 * size, randf_range(-4.0, 0.0)),
			"v": drift + Vector2(spread * 130.0 * size + randf_range(-20.0, 20.0), randf_range(-46.0, -8.0) * size),
			"r": randf_range(5.0, 11.0) * size,
		})
	near.get_tree().current_scene.add_child(p)
	p.global_position = at


func _process(delta: float) -> void:
	_t += delta
	for d: Dictionary in _dots:
		d["p"] += d["v"] * delta
		d["v"] *= 1.0 - 4.0 * delta
	if _t >= _life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / _life
	for d: Dictionary in _dots:
		var r: float = d["r"]
		draw_circle(d["p"], r * (0.6 + 1.1 * k), Color(0.62, 0.58, 0.82, 0.3 * (1.0 - k)))
