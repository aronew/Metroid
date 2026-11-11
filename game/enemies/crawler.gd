extends CharacterBody2D
## A cellar creature: low, many-legged, changed by whatever the sphere did.
## It patrols its floor, turns at walls and edges, and rushes Cowl when he
## comes level with it. Placeholder art: a plain ink silhouette with lit eyes,
## in the manner of the family's design, until creature art exists.

const SPEED := 95.0
const CHARGE := 330.0
const GRAVITY := 3000.0

var health := 2
var _dir := -1
var _stun := 0.0
var _flash := 0.0
var _telegraph := 0.0
var _charging := 0.0
var _cooldown := 0.0
var _walk := 0.0
var _dead := false
var _contact: Area2D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 3
	floor_snap_length = 10.0
	z_index = 9
	var shape := RectangleShape2D.new()
	shape.size = Vector2(70, 38)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -19)
	add_child(cs)
	var hurt := Hurtbox.new()
	hurt.owner_node = self
	var hs := RectangleShape2D.new()
	hs.size = Vector2(84, 56)
	var hcs := CollisionShape2D.new()
	hcs.shape = hs
	hcs.position = Vector2(0, -28)
	hurt.add_child(hcs)
	add_child(hurt)
	_contact = ContactDamage.new()
	var ks := RectangleShape2D.new()
	ks.size = Vector2(60, 34)
	var kcs := CollisionShape2D.new()
	kcs.shape = ks
	kcs.position = Vector2(0, -19)
	_contact.add_child(kcs)
	add_child(_contact)
	_dir = -1 if (int(global_position.x) / 64) % 2 == 0 else 1


func take_hit(info: Dictionary) -> bool:
	if _dead:
		return false
	health -= int(info["damage"])
	_flash = 1.0
	_stun = 0.28
	_telegraph = 0.0
	_charging = 0.0
	var kb: Vector2 = info["knockback"]
	velocity = Vector2(kb.x, minf(kb.y, -180.0))
	HitFx.spawn(self, info["at"], info["direction"], Color(0.95, 0.8, 1.0))
	Sfx.play(&"hit")
	if health <= 0:
		_die(info["direction"])
	return true


func _die(dir: int) -> void:
	_dead = true
	collision_layer = 0
	_contact.collision_layer = 0
	Sfx.play(&"creature_die")
	Puff.burst(self, global_position + Vector2(0, -20), 9, Vector2(dir * 140.0, -60.0), 1.3)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_cooldown = maxf(_cooldown - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, 1500.0)
	if _dead or _stun > 0.0:
		_stun -= delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	var cowl := get_tree().get_first_node_in_group(&"player") as Cowl
	var sees := false
	if cowl != null and cowl.state != Cowl.State.DEAD and is_on_floor():
		var d := cowl.global_position - global_position
		sees = absf(d.x) < 380.0 and absf(d.y) < 90.0
		if sees and _telegraph <= 0.0 and _charging <= 0.0 and _cooldown <= 0.0:
			_dir = 1 if d.x > 0.0 else -1
			_telegraph = 0.42
			Sfx.play(&"creature_alert", -6.0)
	if _telegraph > 0.0:
		# Rears back before it rushes: the tell Cowl dodges on.
		_telegraph -= delta
		velocity.x = move_toward(velocity.x, -_dir * 30.0, 600.0 * delta)
		if _telegraph <= 0.0:
			_charging = 0.55
	elif _charging > 0.0:
		_charging -= delta
		velocity.x = _dir * CHARGE
		if _charging <= 0.0:
			_cooldown = 1.1
	else:
		velocity.x = _dir * SPEED
	if is_on_floor() and (_at_wall() or _at_edge()):
		_dir = -_dir
		velocity.x = _dir * SPEED
		if _charging > 0.0:
			_charging = 0.0
			_cooldown = 1.1
	move_and_slide()
	_walk += absf(velocity.x) * delta * 0.06
	queue_redraw()


func _at_wall() -> bool:
	return test_move(global_transform, Vector2(_dir * 6.0, -2.0))


func _at_edge() -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(_dir * 46.0, -6.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 40.0), 3)
	return space.intersect_ray(q).is_empty()


func _draw() -> void:
	var body := Pal.INK.lerp(Color.WHITE, _flash)
	var rear := -0.25 * _dir if _telegraph > 0.0 else 0.0
	draw_set_transform(Vector2(0, 0), rear, Vector2(1.0, 1.0))
	for i in 4:
		var lx := -30.0 + i * 20.0
		var sw := sin(_walk * TAU + i * 1.6) * 9.0
		draw_line(Vector2(lx, -16), Vector2(lx + sw - 6.0, -30), body, 5.0, true)
		draw_line(Vector2(lx + sw - 6.0, -30), Vector2(lx + sw * 1.6, 0), body, 4.0, true)
	var shell := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		shell.append(Vector2(-38.0 + 76.0 * f, -12.0 - sin(f * PI) * 30.0))
	shell.append(Vector2(38, -8))
	shell.append(Vector2(-38, -8))
	draw_colored_polygon(shell, body)
	for i in 3:
		var sx := -18.0 + i * 16.0 - _dir * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 7, -36), Vector2(sx, -58 - i % 2 * 8), Vector2(sx + 7, -36)]), body)
	var ex := _dir * 20.0
	var hot := 1.0 if (_telegraph > 0.0 or _charging > 0.0) else 0.6
	draw_circle(Vector2(ex, -22), 12.0, Color(Pal.CREATURE.r, Pal.CREATURE.g, Pal.CREATURE.b, 0.16 * hot))
	draw_circle(Vector2(ex, -22), 4.5, Color(Pal.CREATURE.r, Pal.CREATURE.g, Pal.CREATURE.b, hot))
	draw_circle(Vector2(ex + _dir * 11.0, -19), 3.0, Color(Pal.CREATURE.r, Pal.CREATURE.g, Pal.CREATURE.b, hot))
