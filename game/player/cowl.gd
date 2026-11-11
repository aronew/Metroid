class_name Cowl
extends CharacterBody2D
## Cowl's controller: movement, dodge, knife, damage.
##
## The controller owns the physics and nothing visual. The rig (cowl_rig.gd)
## reads this node every frame and listens to its signals, so what is drawn
## always follows what the body is actually doing.
##
## Every tunable number comes from `config` (MovementConfig). The origin of the
## node is at Cowl's feet.

signal jumped
signal landed(impact_speed: float)
signal dodge_started(direction: int)
signal dodge_ended
signal attack_started(kind: StringName)
signal attack_connected(kind: StringName, at: Vector2)
signal was_hurt(from_direction: int)
signal died
signal turned(new_facing: int)
signal woke_up
signal health_changed(current: int, maximum: int)

enum State { NORMAL, DODGE, HURT, DEAD, CUTSCENE }

const TILE := 64.0
const BODY_SIZE := Vector2(40.0, 100.0)
const LAYER_WORLD := 1
const LAYER_ONEWAY := 2
const LAYER_ENEMY_HURTBOX := 32
const LAYER_HAZARD := 64

## Knife swings. Times in seconds; boxes are in pixels relative to the feet,
## facing right. `chain` is the earliest moment the next swing may start.
const ATTACKS := {
	&"slash1": {
		"startup": 0.06, "active": 0.09, "recovery": 0.17, "chain": 0.2,
		"lunge": 2.4, "damage": 1, "knock": Vector2(5.5, -2.0),
		"box": Rect2(6, -104, 132, 108), "ground": true,
	},
	&"slash2": {
		"startup": 0.09, "active": 0.1, "recovery": 0.26, "chain": 0.34,
		"lunge": 3.4, "damage": 2, "knock": Vector2(9.0, -4.5),
		"box": Rect2(0, -150, 150, 160), "ground": true,
	},
	&"up": {
		"startup": 0.06, "active": 0.1, "recovery": 0.18, "chain": 0.24,
		"lunge": 0.0, "damage": 1, "knock": Vector2(1.5, -8.0),
		"box": Rect2(-62, -214, 124, 136), "ground": false,
	},
	&"air": {
		"startup": 0.05, "active": 0.11, "recovery": 0.14, "chain": 0.22,
		"lunge": 0.0, "damage": 1, "knock": Vector2(6.0, -2.5),
		"box": Rect2(0, -122, 138, 140), "ground": false,
	},
}

@export var config: MovementConfig
@export var max_health := 5

var state: State = State.NORMAL
var facing := 1
var health := 5
var move_input := 0.0
var look_input := 0.0
var jump_held := false
var fly_mode := false
var controls_enabled := true

## Read by the rig.
var attack_kind: StringName = &""
var attack_time := -1.0
var dodge_progress := 0.0
var air_time := 0.0
var last_fall_speed := 0.0
var wake_progress := -1.0      # -1 not waking; 0 lying in bed; 0..1 getting up

var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_buffer := 0.0
var _attack_buffer := 0.0
var _jumping := false          # rising from a jump that has not been cut
var _was_on_floor := false
var _drop_through := 0.0
var _land_lock := 0.0
var _dodge_time := 0.0
var _dodge_dir := 1
var _dodge_cooldown := 0.0
var _invuln := 0.0
var _stun := 0.0
var _dead_time := 0.0
var _combo_time := 99.0        # seconds since the last swing began
var _last_attack: StringName = &""
var _hit_already: Array[Object] = []
var _last_safe := Vector2.ZERO
var _safe_timer := 0.0
var _hazard_recover := -1.0
var _waking := false

var _hit_shape := RectangleShape2D.new()

## Input for one physics step. The real device fills one of these each step;
## the level explorer and the feel tests fill their own, so the tools drive
## exactly the code the player does.
class InputState:
	var move := 0.0
	var look := 0.0
	var jump_held := false
	var jump_pressed := false
	var dodge_pressed := false
	var attack_pressed := false
	var any_pressed := false

## When set, replaces the keyboard and gamepad.
var sim_input: InputState = null
var _any_pressed := false

@onready var body_shape: CollisionShape2D = $BodyShape
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	if config == null:
		config = MovementConfig.new()
	else:
		# A private copy: live tuning never writes into the preset on disk.
		config = config.duplicate()
	health = max_health
	floor_snap_length = 12.0
	floor_max_angle = deg_to_rad(52.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = 0.08
	collision_layer = 4
	collision_mask = LAYER_WORLD | LAYER_ONEWAY
	hurtbox.area_entered.connect(_on_hurtbox_area)
	_last_safe = global_position
	add_to_group(&"player")


# =============================================================== frame update
func _physics_process(delta: float) -> void:
	_read_input()
	_tick_timers(delta)
	if fly_mode:
		_fly(delta)
		return
	match state:
		State.NORMAL:
			_state_normal(delta)
		State.DODGE:
			_state_dodge(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			_state_dead(delta)
		State.CUTSCENE:
			_state_cutscene(delta)
	_check_hazards()


func _poll_device() -> InputState:
	var i := InputState.new()
	i.move = Input.get_axis(&"move_left", &"move_right")
	i.look = Input.get_axis(&"look_up", &"look_down")
	i.jump_held = Input.is_action_pressed(&"jump")
	i.jump_pressed = Input.is_action_just_pressed(&"jump")
	i.dodge_pressed = Input.is_action_just_pressed(&"dodge")
	i.attack_pressed = Input.is_action_just_pressed(&"attack")
	i.any_pressed = i.jump_pressed or i.dodge_pressed or i.attack_pressed \
		or Input.is_action_just_pressed(&"move_left") or Input.is_action_just_pressed(&"move_right") \
		or Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"look_up")
	return i


func _read_input() -> void:
	var i := sim_input if sim_input != null else _poll_device()
	_any_pressed = i.any_pressed and controls_enabled
	if not controls_enabled or state == State.DEAD or state == State.CUTSCENE:
		move_input = 0.0
		look_input = 0.0
		jump_held = false
		return
	move_input = i.move
	look_input = i.look
	jump_held = i.jump_held
	if i.jump_pressed:
		_jump_buffer = config.jump_buffer
	if i.dodge_pressed:
		_dodge_buffer = 0.12
	if i.attack_pressed:
		_attack_buffer = 0.16


func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_dodge_buffer = maxf(_dodge_buffer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_land_lock = maxf(_land_lock - delta, 0.0)
	_combo_time += delta
	if _drop_through > 0.0:
		_drop_through -= delta
		if _drop_through <= 0.0:
			set_collision_mask_value(2, true)


# ===================================================================== states
func _state_normal(delta: float) -> void:
	var on_floor := is_on_floor()

	# ---- knife ----------------------------------------------------------
	_update_attack(delta, on_floor)

	# ---- facing ---------------------------------------------------------
	var swing_locked := _attack_phase() in [&"startup", &"active"]
	if move_input != 0.0 and not swing_locked:
		var want := 1 if move_input > 0.0 else -1
		if want != facing:
			facing = want
			turned.emit(facing)

	# ---- horizontal -----------------------------------------------------
	var target := 0.0
	var mag := absf(move_input)
	if mag > 0.0 and _land_lock <= 0.0:
		var top := config.run_px() if mag >= config.walk_threshold else config.walk_px()
		target = signf(move_input) * top
	if on_floor and swing_locked and ATTACKS[attack_kind]["ground"]:
		target *= config.attack_move_mult
	var time_to: float
	if target == 0.0:
		time_to = config.decel_time if on_floor else config.air_decel_time
	elif velocity.x != 0.0 and signf(target) != signf(velocity.x):
		time_to = config.turn_time if on_floor else config.air_turn_time
	else:
		time_to = config.accel_time if on_floor else config.air_accel_time
	var rate := config.run_px() / maxf(time_to, 0.001)
	var at_apex := not on_floor and _jumping and absf(velocity.y) < config.apex_threshold * TILE
	if at_apex:
		rate *= config.apex_accel_bonus
	velocity.x = move_toward(velocity.x, target, rate * delta)

	# ---- vertical -------------------------------------------------------
	if on_floor:
		_coyote = config.coyote_time
		_jumping = false
		air_time = 0.0
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		air_time += delta
		var g := config.gravity_up() if velocity.y < 0.0 else config.gravity_down()
		if at_apex and jump_held:
			g *= config.apex_gravity_mult
		velocity.y = minf(velocity.y + g * delta, config.max_fall_speed * TILE)
		# Variable height: letting go while rising cuts the jump, once.
		if _jumping and not jump_held and velocity.y < 0.0:
			velocity.y *= config.jump_cut_mult
			_jumping = false
		if velocity.y >= 0.0:
			_jumping = false

	if _jump_buffer > 0.0 and (on_floor or _coyote > 0.0) and _land_lock <= 0.0:
		if on_floor and look_input > 0.5 and _standing_on_oneway():
			_start_drop_through()
		else:
			_do_jump()

	# ---- dodge ----------------------------------------------------------
	if _dodge_buffer > 0.0 and on_floor and _dodge_cooldown <= 0.0 and not swing_locked:
		_start_dodge()
		return

	_move(delta)


func _state_dodge(delta: float) -> void:
	_dodge_time += delta
	dodge_progress = clampf(_dodge_time / config.dodge_time, 0.0, 1.0)
	velocity.x = _dodge_dir * config.dodge_speed() * _dodge_curve(dodge_progress)
	if is_on_floor():
		_coyote = config.coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y = minf(velocity.y + config.gravity_down() * delta, config.max_fall_speed * TILE)

	# A jump may cut the dodge short, but never carries its speed away.
	if _jump_buffer > 0.0 and dodge_progress >= config.dodge_jump_cancel \
			and (is_on_floor() or _coyote > 0.0):
		_end_dodge()
		velocity.x = clampf(velocity.x, -config.run_px(), config.run_px())
		_do_jump()
		_move(delta)
		return

	_move(delta)
	if dodge_progress >= 1.0 or is_on_wall():
		_end_dodge()


func _state_hurt(delta: float) -> void:
	_stun -= delta
	var g := config.gravity_up() if velocity.y < 0.0 else config.gravity_down()
	velocity.y = minf(velocity.y + g * delta, config.max_fall_speed * TILE)
	velocity.x = move_toward(velocity.x, 0.0, config.run_px() / 0.4 * delta)
	_move(delta)
	if _hazard_recover >= 0.0:
		_hazard_recover -= delta
		if _hazard_recover < 0.0:
			global_position = _last_safe
			reset_physics_interpolation()
			velocity = Vector2.ZERO
			state = State.NORMAL
		return
	if _stun <= 0.0:
		state = State.NORMAL


func _state_dead(delta: float) -> void:
	_dead_time += delta
	velocity.y = minf(velocity.y + config.gravity_down() * delta, config.max_fall_speed * TILE)
	velocity.x = move_toward(velocity.x, 0.0, config.run_px() / 0.5 * delta)
	_move(delta)


func _state_cutscene(delta: float) -> void:
	velocity = Vector2.ZERO
	if _waking:
		wake_progress = minf(wake_progress + delta / 1.7, 1.0)
		if wake_progress >= 1.0:
			_waking = false
			wake_progress = -1.0
			state = State.NORMAL
			woke_up.emit()
	elif wake_progress >= 0.0 and _any_pressed:
		_waking = true
		Sfx.play(&"rustle")


# =================================================================== movement
func _move(delta: float) -> void:
	var vy_before := velocity.y
	_was_on_floor = is_on_floor()
	if velocity.y < 0.0:
		_corner_correct(delta)
	elif not _was_on_floor:
		_ledge_snap(delta)
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_on_landed(vy_before)
	if is_on_floor():
		_safe_timer -= delta
		if _safe_timer <= 0.0 and state == State.NORMAL and not _standing_on_oneway() \
				and absf(get_floor_normal().x) < 0.05 and _is_wide_floor():
			_safe_timer = 0.15
			_last_safe = global_position


func _do_jump() -> void:
	velocity.y = -config.jump_velocity()
	_jump_buffer = 0.0
	_coyote = 0.0
	_jumping = true
	_land_lock = 0.0
	jumped.emit()
	Sfx.play(&"jump")


func _on_landed(fall_speed: float) -> void:
	last_fall_speed = fall_speed
	if fall_speed >= config.heavy_land_speed * TILE and state == State.NORMAL:
		_land_lock = config.heavy_land_recovery
		Game.shake(0.22)
		Sfx.play(&"land_heavy")
	elif fall_speed > 200.0:
		Sfx.play(&"land")
	landed.emit(fall_speed)


## Rising into the underside of a corner: slide round it if a small sideways
## step clears the way.
func _corner_correct(delta: float) -> void:
	var rise := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, rise):
		return
	var px := int(config.corner_correction_px)
	for step in range(2, px + 1, 2):
		for dir: int in [1, -1]:
			# Never push against the way the player is steering.
			if move_input != 0.0 and signf(move_input) != float(dir):
				continue
			var shift := Vector2(dir * step, 0.0)
			if test_move(global_transform, shift):
				continue
			if not test_move(global_transform.translated(shift), rise):
				global_position += shift
				return


## Falling a hair short of a ledge: if Cowl's feet clip the lip by a few
## pixels and the player is steering into it, lift him onto it.
func _ledge_snap(delta: float) -> void:
	if move_input == 0.0 or velocity.y < -60.0:
		return
	var dir := signf(move_input)
	var push := Vector2(dir * maxf(absf(velocity.x) * delta, 2.0), 0.0)
	if not test_move(global_transform, push):
		return
	var px := int(config.ledge_snap_px)
	for step in range(2, px + 1, 2):
		var lift := Vector2(0.0, -step)
		if test_move(global_transform, lift):
			return
		if not test_move(global_transform.translated(lift), push):
			global_position += lift + Vector2(dir * 1.0, 0.0)
			velocity.y = minf(velocity.y, 0.0)
			return


func _standing_on_oneway() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider is CollisionObject2D and (collider as CollisionObject2D).collision_layer & LAYER_ONEWAY:
			if col.get_normal().y < -0.5:
				return true
	return false


## True when there is floor under both feet and a little beyond: a fair place
## to be put back after a hazard.
func _is_wide_floor() -> bool:
	var space := get_world_2d().direct_space_state
	for dx: float in [-48.0, 48.0]:
		var q := PhysicsRayQueryParameters2D.create(
			global_position + Vector2(dx, -8.0), global_position + Vector2(dx, 24.0), LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			return false
	return true


func _start_drop_through() -> void:
	_jump_buffer = 0.0
	_drop_through = 0.24
	set_collision_mask_value(2, false)
	global_position.y += 2.0
	velocity.y = 120.0


func _fly(delta: float) -> void:
	var dir := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"look_up", &"look_down"))
	global_position += dir * 1400.0 * delta
	velocity = Vector2.ZERO


# ====================================================================== dodge
## Speed over the dodge, as a multiple of its mean speed. It starts above the
## mean and eases down to running speed, so a dodge held forward flows straight
## into a run. The curve integrates to 1, so `dodge_distance` is honoured.
func _dodge_curve(p: float) -> float:
	var tail := clampf(config.run_px() / config.dodge_speed(), 0.0, 0.95)
	var k := 1.5 * (1.0 - tail)
	return tail + k * (1.0 - p * p)


func _start_dodge() -> void:
	_dodge_buffer = 0.0
	_cancel_attack()
	state = State.DODGE
	_dodge_time = 0.0
	dodge_progress = 0.0
	_dodge_dir = facing if move_input == 0.0 else (1 if move_input > 0.0 else -1)
	if _dodge_dir != facing:
		facing = _dodge_dir
		turned.emit(facing)
	dodge_started.emit(_dodge_dir)
	Sfx.play(&"dodge")


func _end_dodge() -> void:
	state = State.NORMAL
	_dodge_cooldown = config.dodge_cooldown
	dodge_progress = 0.0
	dodge_ended.emit()


func is_invulnerable() -> bool:
	if state == State.DEAD or state == State.CUTSCENE or _invuln > 0.0 or fly_mode:
		return true
	if state == State.DODGE:
		return _dodge_time >= config.dodge_iframe_start and _dodge_time <= config.dodge_iframe_end
	return false


# ====================================================================== knife
func _attack_phase() -> StringName:
	if attack_time < 0.0:
		return &""
	var a: Dictionary = ATTACKS[attack_kind]
	if attack_time < a["startup"]:
		return &"startup"
	if attack_time < a["startup"] + a["active"]:
		return &"active"
	return &"recovery"


func _update_attack(delta: float, on_floor: bool) -> void:
	if attack_time >= 0.0:
		attack_time += delta
		var a: Dictionary = ATTACKS[attack_kind]
		if _attack_phase() == &"active":
			_swing_hits(a)
		if attack_time >= a["startup"] + a["active"] + a["recovery"]:
			attack_time = -1.0
			attack_kind = &""
	if _attack_buffer <= 0.0 or not Game.has_knife:
		return
	if attack_time >= 0.0 and attack_time < ATTACKS[attack_kind]["chain"]:
		return
	var kind: StringName
	if look_input < -0.5:
		kind = &"up"
	elif not on_floor:
		kind = &"air"
	elif _last_attack == &"slash1" and _combo_time < 0.55:
		kind = &"slash2"
	else:
		kind = &"slash1"
	_start_attack(kind, on_floor)


func _start_attack(kind: StringName, on_floor: bool) -> void:
	_attack_buffer = 0.0
	attack_kind = kind
	attack_time = 0.0
	_last_attack = kind
	_combo_time = 0.0
	_hit_already.clear()
	# A swing commits to the direction held when it starts.
	if move_input != 0.0:
		var want := 1 if move_input > 0.0 else -1
		if want != facing:
			facing = want
			turned.emit(facing)
	var lunge: float = ATTACKS[kind]["lunge"]
	if on_floor and lunge > 0.0:
		velocity.x = facing * maxf(absf(velocity.x) * 0.5, lunge * TILE)
	attack_started.emit(kind)
	Sfx.play(&"swing_heavy" if kind == &"slash2" else &"swing")


func _cancel_attack() -> void:
	attack_time = -1.0
	attack_kind = &""


func attack_box_global() -> Rect2:
	if attack_kind == &"":
		return Rect2()
	var box: Rect2 = ATTACKS[attack_kind]["box"]
	if facing < 0:
		box.position.x = -box.position.x - box.size.x
	box.position += global_position
	return box


func _swing_hits(a: Dictionary) -> void:
	var box := attack_box_global()
	_hit_shape.size = box.size
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _hit_shape
	q.transform = Transform2D(0.0, box.get_center())
	q.collision_mask = LAYER_ENEMY_HURTBOX
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var connected := false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var target: Object = hit["collider"]
		if target in _hit_already or not target.has_method(&"take_hit"):
			continue
		_hit_already.append(target)
		var at: Vector2 = (target as Node2D).global_position
		at = Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
		var knock: Vector2 = a["knock"]
		var info := {
			"damage": a["damage"],
			"knockback": Vector2(knock.x * facing, knock.y) * TILE,
			"direction": facing,
			"source": self,
			"at": at,
			"kind": attack_kind,
		}
		if target.call(&"take_hit", info):
			connected = true
			attack_connected.emit(attack_kind, at)
	if connected:
		var heavy := attack_kind == &"slash2"
		Game.hitstop(0.085 if heavy else 0.06)
		Game.shake(0.3 if heavy else 0.18)
		# The blow pushes back on the hand that made it.
		if attack_kind != &"up":
			velocity.x -= facing * (2.6 if is_on_floor() else 1.6) * TILE


# ===================================================================== damage
func take_damage(amount: int, from: Vector2) -> bool:
	if is_invulnerable():
		return false
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	Game.player_health_changed.emit(health, max_health)
	var dir := 1 if global_position.x >= from.x else -1
	_cancel_attack()
	if state == State.DODGE:
		_end_dodge()
	Game.hitstop(0.11)
	Game.shake(0.45)
	Sfx.play(&"hurt")
	was_hurt.emit(dir)
	if health <= 0:
		_die(dir)
		return true
	state = State.HURT
	_stun = config.hurt_stun
	_invuln = config.hurt_invuln
	_hazard_recover = -1.0
	velocity = Vector2(dir * config.hurt_knockback.x, -config.hurt_knockback.y) * TILE
	_jumping = false
	return true


## Spikes and pits: hurt, then put Cowl back on the last sound footing.
func hazard_hit(from: Vector2) -> void:
	if state == State.DEAD or state == State.CUTSCENE or fly_mode:
		return
	_invuln = 0.0
	if take_damage(1, from) and state == State.HURT:
		_hazard_recover = 0.38
		_stun = 0.5
		_invuln = 1.4


func _die(dir: int) -> void:
	state = State.DEAD
	_dead_time = 0.0
	velocity = Vector2(dir * 3.0, -6.0) * TILE
	died.emit()
	Game.player_died.emit()


func revive(at: Vector2) -> void:
	global_position = at
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	health = max_health
	state = State.NORMAL
	_invuln = 1.0
	_last_safe = at
	health_changed.emit(health, max_health)
	Game.player_health_changed.emit(health, max_health)


func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	Game.player_health_changed.emit(health, max_health)


func is_flashing() -> bool:
	return _invuln > 0.0 and state != State.DEAD


func _on_hurtbox_area(area: Area2D) -> void:
	if area.has_method(&"get_contact_damage"):
		take_damage(area.call(&"get_contact_damage"), area.global_position)


func _check_hazards() -> void:
	# Contact damage keeps applying while Cowl stands in something.
	if is_invulnerable() or state == State.HURT:
		return
	for area in hurtbox.get_overlapping_areas():
		if area.collision_layer & LAYER_HAZARD:
			if area.has_method(&"is_spikes") and area.call(&"is_spikes"):
				hazard_hit(area.global_position)
			elif area.has_method(&"get_contact_damage"):
				take_damage(area.call(&"get_contact_damage"), area.global_position)
			return


# =================================================================== cutscene
## Put Cowl in bed, asleep, waiting for the first input.
func begin_asleep(at: Vector2) -> void:
	global_position = at
	reset_physics_interpolation()
	state = State.CUTSCENE
	wake_progress = 0.0
	_waking = false
	facing = 1


## Put the body somewhere at rest with every timer cleared. Used by the tools
## that drive the controller directly (tests/feel_test, tests/explore).
func sim_reset(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	state = State.NORMAL
	facing = 1
	attack_time = -1.0
	attack_kind = &""
	_coyote = 0.0
	_jump_buffer = 0.0
	_dodge_buffer = 0.0
	_attack_buffer = 0.0
	_dodge_cooldown = 0.0
	_jumping = false
	_land_lock = 0.0
	_invuln = 0.0
	if _drop_through > 0.0:
		_drop_through = 0.0
		set_collision_mask_value(2, true)
	# Refresh the floor state at the new place.
	velocity = Vector2(0.0, 60.0)
	move_and_slide()
	velocity = Vector2.ZERO


func teleport(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	reset_physics_interpolation()
	_last_safe = at
