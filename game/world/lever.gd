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
	if not Game.has_knife:
		Sfx.play(&"locked")
		return true
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


## Kit art (W30, W31): a lever wrapped in roots until it is cut free; then
## the iron lever, thrown when pulled. The chandelier's lever is its winch.
func _draw() -> void:
	var key: String
	var height := 100.0
	if bound:
		key = "roots/lever_bound_crop"
		height = 118.0
	elif _lift != null and _lift.kind == "chandelier":
		key = "machines/winch"
		height = 112.0
	else:
		key = "machines/lever_down" if _thrown > 0.5 or (_lift != null and _at_lift()) else "machines/lever_up"
	var t := Kit.tex(key)
	if t == null:
		return
	var s := height / t.get_height()
	var size := t.get_size() * s
	draw_texture_rect(t, Rect2(-size.x * 0.5, -size.y + 2.0, size.x, size.y), false)
	if _cut_fx > 0.0:
		draw_circle(Vector2(0, -50), 60.0 * (1.0 - _cut_fx) + 10.0, Color(0.6, 0.95, 0.75, 0.25 * _cut_fx))


func _at_lift() -> bool:
	var here_is_top := absf(global_position.y - _lift.top_y) < absf(global_position.y - _lift.bottom_y)
	return _lift.at_top == here_is_top and not _lift.moving
