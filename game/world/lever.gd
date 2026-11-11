extends Node2D
## A wall lever that calls a lift to this stop. Some are bound in roots: the
## knife frees them, and with them the lift's mechanism.

var lift_name := ""
var bound := false
var _lift: Lift
var _thrown := 0.0
var _hurt: Hurtbox
var _t := 0.0
var _cut_fx := 0.0


func configure(spec: Dictionary) -> void:
	lift_name = spec.get("lift", "")
	bound = spec.get("bound", false)


func _ready() -> void:
	add_to_group(&"interactable")
	z_index = 6
	if bound:
		_hurt = Hurtbox.new()
		_hurt.owner_node = self
		var shape := RectangleShape2D.new()
		shape.size = Vector2(90, 130)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = Vector2(0, -65)
		_hurt.add_child(cs)
		add_child(_hurt)
	_find_lift.call_deferred()


func _find_lift() -> void:
	for l in get_tree().get_nodes_in_group(&"lift"):
		if (l as Lift).lift_name == lift_name:
			_lift = l
			if bound:
				_lift.locked = true


func take_hit(info: Dictionary) -> bool:
	if not bound:
		return false
	bound = false
	_cut_fx = 1.0
	_hurt.collision_layer = 0
	if _lift != null:
		_lift.locked = false
	Sfx.play(&"vine_cut")
	HitFx.spawn(self, info["at"], info["direction"], Color(0.6, 0.95, 0.75))
	Puff.burst(self, global_position + Vector2(0, -60), 7, Vector2(float(info["direction"]) * 120.0, -40.0), 1.0)
	return true


func interact_prompt(cowl: Cowl) -> String:
	if cowl.global_position.distance_to(global_position) > 110.0:
		return ""
	if bound:
		return "Bound in roots. They will not tear by hand." if not Game.has_knife else "Bound in roots  —  cut them"
	return "Pull the lever  [E]"


func interact_origin() -> Vector2:
	return global_position


func interact(_cowl: Cowl) -> void:
	if bound or _lift == null:
		Sfx.play(&"locked")
		return
	# Bring the lift to whichever stop this lever stands at.
	var here_is_top := absf(global_position.y - _lift.top_y) < absf(global_position.y - _lift.bottom_y)
	_thrown = 1.0
	if not _lift.send(here_is_top):
		Sfx.play(&"locked")


func _process(delta: float) -> void:
	_t += delta
	_thrown = maxf(_thrown - delta * 1.5, 0.0)
	_cut_fx = maxf(_cut_fx - delta * 2.0, 0.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-16, -8, 32, 8), Pal.INK)
	draw_rect(Rect2(-10, -40, 20, 34), Pal.INK)
	var ang := lerpf(-0.6, 0.6, _thrown)
	var tip := Vector2(0, -34) + Vector2(0, -52).rotated(ang)
	draw_line(Vector2(0, -34), tip, Pal.INK_SOFT, 7.0, true)
	draw_circle(tip, 9.0, Pal.LAVENDER if not bound else Pal.HAZE)
	if bound:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(global_position.x)
		for i in 6:
			var pts := PackedVector2Array()
			var x0 := rng.randf_range(-40.0, 40.0)
			for k in 9:
				var f := k / 8.0
				pts.append(Vector2(x0 + sin(f * 5.0 + i + _t * 0.6) * 22.0, -118.0 + f * 122.0))
			draw_polyline(pts, Pal.INK_SOFT, rng.randf_range(6.0, 13.0), true)
			draw_polyline(pts, Pal.LEAF, 1.5, true)
