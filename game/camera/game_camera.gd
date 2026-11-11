class_name GameCamera
extends Camera2D
## Follows Cowl.
##
## Principles:
##  - Stillness when Cowl is still. Look-ahead is earned by travelling, not by
##    facing, so tapping left and right does not swing the view.
##  - Height is held, not chased. Small hops leave the camera where it is; it
##    re-seats when Cowl lands somewhere new or leaves the hold window.
##  - Falls are followed tightly and the view leads downward, so the landing
##    is always on screen.
##  - Big rooms pull the camera back (zones from the level data) so the scale
##    reads, and the pull is slow enough never to disturb a jump.
##  - Cowl can never leave a safe frame inside the screen, whatever the
##    smoothing is doing.

@export var look_ahead := 170.0
@export var look_ahead_build := 2.4
@export var smooth_time_x := 0.16
@export var smooth_time_y := 0.24
@export var smooth_time_fall := 0.09
## Camera centre relative to Cowl's feet (negative is above).
@export var height_offset := -150.0
## Cowl may rise this far above the held height before the camera follows.
@export var hold_above := 170.0
@export var fall_lead := 190.0
@export var peek_distance := 300.0
@export var peek_delay := 0.5
@export var zoom_time := 0.7
@export var base_zoom := 1.0
## Fraction of the half-screen Cowl may reach before the camera is dragged.
@export var safe_frame := Vector2(0.62, 0.6)

var target: Cowl
var world := Rect2()
var zones: Array = []

var _pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _ahead := 0.0
var _held_y := 0.0
var _zoom := 1.0
var _zoom_vel := 0.0
var _trauma := 0.0
var _peek := 0.0
var _peek_timer := 0.0
var _noise_t := 0.0
var _zone_offset := Vector2.ZERO


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	Game.camera_shake.connect(func(a: float) -> void: _trauma = minf(_trauma + a, 1.0))
	_zoom = base_zoom
	make_current()


func follow(cowl: Cowl) -> void:
	target = cowl
	snap()


## Jump straight to where the camera wants to be (spawn, respawn, teleport).
func snap() -> void:
	if target == null:
		return
	_held_y = target.global_position.y
	_ahead = 0.0
	_vel = Vector2.ZERO
	var z := _zone_for(target.global_position)
	_zoom = float(z.get("zoom", base_zoom))
	_zone_offset = Vector2(float(z.get("ox", 0.0)), float(z.get("oy", 0.0))) * Game.TILE
	_pos = _clamp_to_world(_desired(), _zoom)
	global_position = _pos
	zoom = Vector2(_zoom, _zoom)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var p := target.global_position
	var v := target.velocity
	var grounded := target.is_on_floor()

	# ---- look-ahead: built by travelling ---------------------------------
	var want_ahead := _ahead
	if absf(v.x) > 90.0:
		want_ahead = signf(v.x) * look_ahead * clampf(absf(v.x) / 420.0, 0.0, 1.0)
	_ahead = lerpf(_ahead, want_ahead, 1.0 - exp(-look_ahead_build * delta))

	# ---- held height -------------------------------------------------------
	if grounded:
		_held_y = p.y
	else:
		if p.y < _held_y - hold_above:
			_held_y = p.y + hold_above
		if p.y > _held_y:
			_held_y = p.y

	# ---- peek up / down when standing still --------------------------------
	var want_peek := 0.0
	if grounded and absf(v.x) < 5.0 and absf(target.look_input) > 0.5 and target.attack_time < 0.0:
		_peek_timer += delta
		if _peek_timer >= peek_delay:
			want_peek = signf(target.look_input) * peek_distance
	else:
		_peek_timer = 0.0
	_peek = lerpf(_peek, want_peek, 1.0 - exp(-5.0 * delta))

	# ---- zone --------------------------------------------------------------
	var z := _zone_for(p)
	var want_zoom := float(z.get("zoom", base_zoom))
	var zs := _smooth_damp(_zoom, want_zoom, _zoom_vel, zoom_time, delta)
	_zoom = zs[0]
	_zoom_vel = zs[1]
	var want_off := Vector2(float(z.get("ox", 0.0)), float(z.get("oy", 0.0))) * Game.TILE
	_zone_offset = _zone_offset.lerp(want_off, 1.0 - exp(-2.0 * delta))

	# ---- follow --------------------------------------------------------------
	var desired := _desired()
	var falling := not grounded and v.y > 500.0
	if falling:
		desired.y += fall_lead * clampf(v.y / 1400.0, 0.0, 1.0)
	desired = _clamp_to_world(desired, _zoom)
	var sx := _smooth_damp(_pos.x, desired.x, _vel.x, smooth_time_x, delta)
	var sy := _smooth_damp(_pos.y, desired.y, _vel.y, smooth_time_fall if falling else smooth_time_y, delta)
	_pos = Vector2(sx[0], sy[0])
	_vel = Vector2(sx[1], sy[1])

	# ---- never lose Cowl ----------------------------------------------------
	var half := get_viewport_rect().size * 0.5 / _zoom
	var body := p + Vector2(0.0, -60.0)
	var fx := half.x * safe_frame.x
	var fy := half.y * safe_frame.y
	if body.x > _pos.x + fx:
		_pos.x = body.x - fx
	elif body.x < _pos.x - fx:
		_pos.x = body.x + fx
	if body.y > _pos.y + fy:
		_pos.y = body.y - fy
	elif body.y < _pos.y - fy:
		_pos.y = body.y + fy
	_pos = _clamp_to_world(_pos, _zoom)

	# ---- shake -------------------------------------------------------------
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	_noise_t += delta * 38.0
	var amp := _trauma * _trauma * 20.0
	var shake := Vector2(sin(_noise_t * 1.31) + sin(_noise_t * 2.77), sin(_noise_t * 1.73 + 1.3) + sin(_noise_t * 3.11)) * 0.5 * amp

	global_position = _pos + shake
	zoom = Vector2(_zoom, _zoom)


func _desired() -> Vector2:
	var p := target.global_position
	return Vector2(p.x + _ahead, _held_y + height_offset + _peek) + _zone_offset


func _zone_for(pos: Vector2) -> Dictionary:
	var t := pos / Game.TILE
	var best: Dictionary = {}
	var best_area := INF
	for z: Dictionary in zones:
		if t.x >= z["x"] and t.x <= z["x"] + z["w"] and t.y >= z["y"] and t.y <= z["y"] + z["h"]:
			var area: float = z["w"] * z["h"]
			if area < best_area:
				best = z
				best_area = area
	return best


func _clamp_to_world(c: Vector2, z: float) -> Vector2:
	if world.size == Vector2.ZERO:
		return c
	var half := get_viewport_rect().size * 0.5 / z
	if world.size.x <= half.x * 2.0:
		c.x = world.get_center().x
	else:
		c.x = clampf(c.x, world.position.x + half.x, world.end.x - half.x)
	if world.size.y <= half.y * 2.0:
		c.y = world.get_center().y
	else:
		c.y = clampf(c.y, world.position.y + half.y, world.end.y - half.y)
	return c


## Critically damped spring (the "smooth damp" used by most follow cameras):
## no overshoot, and it settles in about `time` seconds.
func _smooth_damp(current: float, goal: float, vel: float, time: float, delta: float) -> Array:
	var omega := 2.0 / maxf(time, 0.0001)
	var x := omega * delta
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - goal
	var temp := (vel + omega * change) * delta
	var new_vel := (vel - omega * temp) * e
	var out := goal + (change + temp) * e
	return [out, new_vel]
