class_name HitFx
extends Node2D
## A short burst where a blow lands: a bright slash and a few sparks.

var _t := 0.0
var _dir := 1
var _sparks: Array = []
var _color := Color(0.95, 0.93, 1.0)


static func spawn(near: Node, at: Vector2, direction: int, color: Color = Color(0.95, 0.93, 1.0)) -> void:
	var fx := HitFx.new()
	fx._dir = direction
	fx._color = color
	fx.z_index = 30
	near.get_tree().current_scene.add_child(fx)
	fx.global_position = at


func _ready() -> void:
	rotation = randf_range(-0.5, 0.5)
	for i in 7:
		var a := randf_range(-1.1, 1.1)
		_sparks.append({
			"v": Vector2(cos(a) * _dir, sin(a)) * randf_range(380.0, 900.0),
			"p": Vector2.ZERO, "l": randf_range(0.16, 0.3),
		})


func _process(delta: float) -> void:
	_t += delta
	for s: Dictionary in _sparks:
		s["p"] += s["v"] * delta
		s["v"] = s["v"] * (1.0 - 6.0 * delta) + Vector2(0, 900.0) * delta
	if _t > 0.32:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / 0.12, 0.0, 1.0)
	var fade := 1.0 - k
	if fade > 0.0:
		var half := lerpf(30.0, 130.0, k)
		var thick := lerpf(16.0, 2.0, k)
		var c := Color(_color.r, _color.g, _color.b, fade)
		draw_line(Vector2(-half, -half * 0.25), Vector2(half, half * 0.25), c, thick, true)
		draw_line(Vector2(-half * 0.5, half * 0.6), Vector2(half * 0.5, -half * 0.6), c, thick * 0.6, true)
	for s: Dictionary in _sparks:
		var life: float = 1.0 - _t / float(s["l"])
		if life > 0.0:
			var p: Vector2 = s["p"]
			var v: Vector2 = s["v"]
			draw_line(p, p - v * 0.025, Color(_color.r, _color.g, _color.b, life), 3.0, true)
