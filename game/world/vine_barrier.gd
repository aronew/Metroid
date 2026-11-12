extends StaticBody2D
## Overgrowth across a way through. It stops Cowl until he has something to
## cut with; one good swing of the butcher knife parts it.

var w := 64.0
var h := 256.0
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


func take_hit(info: Dictionary) -> bool:
	if _cut:
		return false
	if not Game.has_knife:
		# Fists and feet only shake them. The knife is what cuts.
		_shake = 1.0
		Sfx.play(&"locked")
		if not Game.get_flag("roots_hint"):
			Game.set_flag("roots_hint")
			Game.say("The roots give, and spring back. They need cutting.", 3.5)
		return true
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
	_shake = maxf(_shake - delta * 3.0, 0.0)
	if _cut:
		_fall += delta
	queue_redraw()


## The kit's root barrier (W30): a woven barrier, then on the cut the sliced
## frame, the halves falling, and the stubs that stay. The cell is scaled so
## its doorway is this opening: four tiles high, its floor on ours.
func _draw() -> void:
	var key := _variant()
	if _cut:
		key = "roots/cut_0" if _fall < 0.1 else ("roots/cut_1" if _fall < 0.42 else "roots/cut_2")
	var t := Kit.tex(key)
	if t == null:
		return
	var floor_px: float = Kit.meta("roots/barrier_a")["floor"]
	var s := h / (floor_px * 0.53)
	var size := t.get_size() * s
	var sway := 0.0 if _cut else sin(_sway * 0.8 + global_position.x) * 0.012 + sin(_sway * 40.0) * 0.03 * _shake
	draw_set_transform(Vector2(w * 0.5, 0), sway, Vector2.ONE)
	draw_texture_rect(t, Rect2(-size.x * 0.5, -floor_px * s, size.x, size.y), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _variant() -> String:
	var k := int(absf(global_position.x / 64.0)) % 3
	return ["roots/barrier_a", "roots/barrier_b", "roots/barrier_c"][k]
