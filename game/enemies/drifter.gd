extends CharacterBody2D
## A drifting spore-thing. It hangs in the air and floats toward Cowl when he
## is near. One cut bursts it. Placeholder art, like the crawler.

var health := 1
var _home := Vector2.ZERO
var _t := 0.0
var _flash := 0.0
var _dead := false
var _stun := 0.0
var _contact: Area2D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 9
	_home = global_position
	_t = fmod(global_position.x, 7.0)
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	var hurt := Hurtbox.new()
	hurt.owner_node = self
	var hs := CircleShape2D.new()
	hs.radius = 36.0
	var hcs := CollisionShape2D.new()
	hcs.shape = hs
	hurt.add_child(hcs)
	add_child(hurt)
	_contact = ContactDamage.new()
	var ks := CircleShape2D.new()
	ks.radius = 24.0
	var kcs := CollisionShape2D.new()
	kcs.shape = ks
	_contact.add_child(kcs)
	add_child(_contact)


func take_hit(info: Dictionary) -> bool:
	if _dead:
		return false
	health -= int(info["damage"])
	_flash = 1.0
	_stun = 0.3
	velocity = (info["knockback"] as Vector2) * 0.8
	HitFx.spawn(self, info["at"], info["direction"], Color(0.95, 0.8, 1.0))
	Sfx.play(&"hit")
	if health <= 0:
		_dead = true
		collision_layer = 0
		_contact.collision_layer = 0
		Sfx.play(&"creature_die")
		Puff.burst(self, global_position, 12, Vector2(0, -30), 1.5)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.7, 1.7), 0.18)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
		tw.tween_callback(queue_free)
	return true


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	if _dead:
		return
	if _stun > 0.0:
		_stun -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	var goal := _home + Vector2(sin(_t * 0.6) * 70.0, sin(_t * 1.1) * 26.0)
	var cowl := get_tree().get_first_node_in_group(&"player") as Cowl
	if cowl != null and cowl.state != Cowl.State.DEAD:
		var target := cowl.global_position + Vector2(0, -60)
		if target.distance_to(global_position) < 460.0 and target.distance_to(_home) < 760.0:
			goal = target
	var want := (goal - global_position).limit_length(1.0) * 125.0
	velocity = velocity.move_toward(want, 260.0 * delta)
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	var c := Pal.INK.lerp(Color.WHITE, _flash)
	var puls := 1.0 + sin(_t * 3.0) * 0.07
	for i in 5:
		var a := -0.5 + i * 0.25 + sin(_t * 2.0 + i) * 0.12
		var tip := Vector2(sin(a) * 40.0, 34.0 + cos(a) * 30.0 + sin(_t * 3.0 + i) * 5.0)
		draw_line(Vector2((i - 2) * 9.0, 12), tip, c, 4.0, true)
	draw_circle(Vector2.ZERO, 26.0 * puls, c)
	draw_circle(Vector2.ZERO, 44.0, Color(Pal.CREATURE.r, Pal.CREATURE.g, Pal.CREATURE.b, 0.07))
	draw_circle(Vector2(-8, -3), 4.5, Pal.CREATURE)
	draw_circle(Vector2(9, -3), 4.5, Pal.CREATURE)
