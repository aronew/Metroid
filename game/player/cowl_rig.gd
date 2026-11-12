extends Node2D
## Cowl's body: the hand-drawn frames from his animation sheets (H4-H20),
## chosen every frame from what the controller is doing.
##
## Nothing here moves Cowl. The rig reads the controller (state, speed, floor,
## strike timing, dodge progress) and its signals, so the picture always
## follows the physics. Strikes are posed straight from the strike clock, so
## the contact frame is on screen exactly while the hitbox is live.
##
## Clips without supplied art fall back to the closest drawn frames:
## dodge (run frames, fast, with after-images), hurt (a fall frame, flashed),
## death (the heavy landing's crouch, fading), waking (idle frames on the bed).

const FLASH_SHADER := "
shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}"
## Seconds standing still before Cowl takes a smoke break.
const BREAK_AFTER := 7.0
## Seconds in the chilled idle before the next break.
const CHILL_FOR := 14.0
## Full jumps flip, as the jump sheet is drawn; short hops do not.
const FLIP_ON_JUMP := true
const BED_FEET := Vector2(-24.0, -104.0)        # where his feet are, lying in the bed

const STRIKE_CLIP := {&"jab": "jab", &"cross": "cross", &"kick": "kick", &"air": "air_kick"}
const STRIKE_FX := {
	&"jab": ["trail_jab", "flare_jab", "flash_light"],
	&"cross": ["trail_cross", "flare_cross", "flash_heavy"],
	&"kick": ["trail_kick", "flare_kick", "flash_finisher"],
	&"air": ["trail_air", "flare_cross", "flash_heavy"],
}
const STRIKE_TINT := Color(0.78, 0.9, 1.0)
const SMOKE_TINT := Color(0.86, 0.84, 0.95, 0.85)

var _cowl: Cowl
var _body: Node2D
var _sprite: Sprite2D
var _glow: Sprite2D
var _material: ShaderMaterial

# what is showing
var clip := "idle"
var frame := 0
var _tick := 0.0                 # ticks into the current frame
var _done := false
var _looped := false            # a looping clip came round at least once
var _flip := 1.0                 # 1 = as drawn (facing right)

var _t := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _flash := 0.0
var _hurt_time := 9.0
var _dead_time := 0.0
var _ghost_timer := 0.0

# ground and air bookkeeping
var _landing := ""               # "", "land", "land_heavy"
var _turning := false
var _starting := false
var _stopping := false
var _since_strike := 9.0
var _jump_phase := ""            # "", "rise", "flip", "open"
var _jump_ticks := 0.0
var _idle_time := 0.0
var _break: Array = []           # queued break clips
var _breaking := false
var _snap := ""
var _smoke_timer := 0.0
var _strike_fx_done := false
var _last_step := -1


func _ready() -> void:
	_cowl = get_parent() as Cowl
	_material = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLASH_SHADER
	_material.shader = sh
	_body = Node2D.new()
	add_child(_body)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.material = _material
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_body.add_child(_sprite)
	_glow = Sprite2D.new()
	_glow.texture = _make_glow()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.modulate = Color(0.45, 0.85, 1.0, 0.35)
	_glow.scale = Vector2(0.55, 0.3)
	_body.add_child(_glow)

	_cowl.jumped.connect(_on_jumped)
	_cowl.landed.connect(_on_landed)
	_cowl.turned.connect(_on_turned)
	_cowl.was_hurt.connect(func(_d: int) -> void:
		_flash = 1.0
		_hurt_time = 0.0)
	_cowl.attack_started.connect(func(_k: StringName) -> void:
		_strike_fx_done = false
		_end_break())
	_cowl.attack_connected.connect(_on_connected)
	_cowl.dodge_started.connect(func(_d: int) -> void:
		_ghost_timer = 0.0
		_end_break()
		Puff.burst(_cowl, _cowl.global_position, 6, Vector2(-_cowl.facing * 120.0, -20.0), 0.8))
	_cowl.died.connect(func() -> void: _dead_time = 0.0)
	_show("idle", 0)


func _make_glow() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


# ===================================================================== clips
func _play(name: String, restart := false) -> void:
	if name == clip and not restart:
		return
	clip = name
	frame = 0
	_tick = 0.0
	_done = false
	_looped = false


## Advance the current clip by `delta` seconds at `rate`.
func _advance(delta: float, rate := 1.0) -> void:
	var c := CowlAnim.clip(clip)
	var ticks: Array = c["ticks"]
	_tick += delta * 60.0 * rate
	while _tick >= float(ticks[frame]):
		_tick -= float(ticks[frame])
		if frame + 1 < ticks.size():
			frame += 1
		elif c.get("loop", false):
			frame = 0
			_looped = true
		else:
			_done = true
			_tick = 0.0
			break


func _show(name: String, i: int) -> void:
	var c := CowlAnim.clip(name)
	var fr: Dictionary = c["frames"][clampi(i, 0, c["frames"].size() - 1)]
	_sprite.texture = CowlAnim.tex("frames", fr["file"])
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.offset = Vector2(fr["ox"], fr["oy"]) * 2.0
	var eyes: Variant = fr.get("eyes")
	_glow.visible = eyes != null
	if eyes != null:
		_glow.position = Vector2(eyes[0], eyes[1])


# ===================================================================== events
func _on_jumped() -> void:
	_squash_vel = 3.0
	_end_break()
	_landing = ""
	_jump_phase = "rise"
	_jump_ticks = 0.0
	_play("jump", true)
	frame = 1
	Puff.burst(_cowl, _cowl.global_position, 5, Vector2(0, -40), 0.55)


func _on_landed(impact: float) -> void:
	var k := clampf(impact / 1500.0, 0.15, 1.0)
	_squash_vel = -4.0 * k
	_jump_phase = ""
	if impact >= _cowl.config.heavy_land_speed * Game.TILE:
		_landing = "land_heavy"
	elif impact > 420.0:
		_landing = "land"
	else:
		_landing = ""
	if _landing != "":
		_play(_landing, true)
	if impact > 250.0:
		Puff.burst(_cowl, _cowl.global_position, 4 + int(k * 8.0), Vector2.ZERO, 0.6 + k * 0.6)


func _on_turned(_f: int) -> void:
	if _cowl.is_on_floor() and absf(_cowl.velocity.x) > _cowl.config.run_px() * 0.45 and _cowl.attack_time < 0.0:
		_turning = true
		_play("turn", true)


func _on_connected(kind: StringName, at: Vector2) -> void:
	var fx: Array = STRIKE_FX.get(kind, [])
	if fx.is_empty():
		return
	var f := _cowl.facing
	FxPlay.play(_cowl, fx[1], at, f, STRIKE_TINT)
	if kind != &"jab":
		FxPlay.play(_cowl, fx[2], at, f, STRIKE_TINT, true, 0.85)
	FxPlay.play(_cowl, "soot", at + Vector2(f * 6.0, 0), f, Color(0.7, 0.72, 0.85, 0.8), false, 1.0, Vector2(f * 40.0, 10.0), 29)


# ====================================================================== frame
## Runs on the physics tick, the controller's clock: clip ticks are 1/60 s,
## so the strike frames line up exactly with the live hitbox at any frame rate.
func _physics_process(delta: float) -> void:
	_t += delta
	_hurt_time += delta
	_since_strike += delta
	var c := _cowl
	var facing := float(c.facing)
	_flip = facing

	match c.state:
		Cowl.State.CUTSCENE:
			_pose_wake()
		Cowl.State.DEAD:
			_pose_dead(delta)
		Cowl.State.HURT:
			_pose_hurt()
		Cowl.State.DODGE:
			_pose_dodge(delta)
		_:
			if c.attack_time >= 0.0:
				_pose_strike()
			elif not c.is_on_floor():
				_pose_air(delta)
			else:
				_pose_ground(delta)

	# Squash and stretch: a small spring on top of the drawn frames.
	_squash_vel += (-_squash * 260.0 - _squash_vel * 17.0) * delta
	_squash = clampf(_squash + _squash_vel * delta, -0.2, 0.16)
	_body.scale = Vector2(_flip * (1.0 - _squash * 0.5), 1.0 + _squash)

	# Hit flash and the flicker of invulnerability.
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_material.set_shader_parameter(&"flash", _flash)
	var a := 1.0
	if c.is_flashing() and _hurt_time > 0.15:
		a = 0.45 if fmod(_t, 0.12) < 0.06 else 1.0
	if c.state == Cowl.State.DEAD:
		a = clampf(1.6 - _dead_time, 0.0, 1.0)
	_body.modulate.a = a
	_glow.modulate.a = 0.3 + sin(_t * 2.3) * 0.06


# ===================================================================== strikes
func _pose_strike() -> void:
	var c := _cowl
	_end_break()
	_landing = ""
	_turning = false
	_stopping = false
	_starting = false
	_since_strike = 0.0
	var name: String = STRIKE_CLIP.get(c.attack_kind, "jab")
	var cl := CowlAnim.clip(name)
	var i := CowlAnim.frame_at(cl["ticks"], c.attack_time * 60.0)
	clip = name
	frame = i
	_body.rotation = 0.0
	_body.position = Vector2.ZERO
	_show(name, i)
	# The trail appears with the strike's smear, a frame before contact.
	var a: Dictionary = Cowl.ATTACKS[c.attack_kind]
	if not _strike_fx_done and c.attack_time >= float(a["startup"]) - 1.0 / 60.0:
		_strike_fx_done = true
		var trail: String = STRIKE_FX[c.attack_kind][0]
		FxPlay.play(c, trail, c.global_position, c.facing, STRIKE_TINT)


# ========================================================================= air
func _pose_air(delta: float) -> void:
	var c := _cowl
	_end_break()
	_landing = ""
	_turning = false
	_stopping = false
	_body.rotation = 0.0
	_body.position = Vector2.ZERO
	var vy := c.velocity.y
	if _jump_phase == "":
		# Off a ledge, or knocked up: the fall loop, or the apex if still rising.
		if vy < -200.0:
			_play("jump")
			frame = 12
			_show("jump", 12)
			return
		_play("fall")
		_advance(delta)
		_show("fall", frame)
		return
	_play("jump")
	_jump_ticks += delta * 60.0
	var ticks: Array = CowlAnim.clip("jump")["ticks"]
	match _jump_phase:
		"rise":
			_advance(delta)
			if frame >= 4:
				var full := c.jump_held and vy < -c.config.jump_velocity() * 0.45
				if FLIP_ON_JUMP and full:
					_jump_phase = "flip"
				else:
					_jump_phase = "open"
					frame = 11
					_tick = 0.0
		"flip":
			_advance(delta, 1.15)
			if frame >= 11:
				_jump_phase = "open"
		"open":
			# Opening out, then the apex holds until he starts to fall.
			if frame < 12:
				_advance(delta)
			elif frame == 12 and vy < 60.0:
				pass
			else:
				_advance(delta)
			if _done or frame >= 15:
				if vy > 0.0:
					_jump_phase = ""
					_play("fall", true)
	_show(clip, frame)


# ====================================================================== ground
func _pose_ground(delta: float) -> void:
	var c := _cowl
	_body.rotation = 0.0
	_body.position = Vector2.ZERO
	_jump_phase = ""
	var speed := absf(c.velocity.x)
	var run := c.config.run_px()
	var moving := c.move_input != 0.0 and speed > 20.0
	var input := moving or c.look_input != 0.0

	if input or speed > 20.0:
		_idle_time = 0.0
	if _breaking or _snap != "":
		if _pose_break(delta, input, moving):
			return

	# Landing plays out unless he moves.
	if _landing != "":
		if moving:
			_landing = ""
		else:
			_play(_landing)
			_advance(delta)
			_show(clip, frame)
			if _done:
				_landing = ""
			return

	if _turning:
		_flip = -_flip
		_advance(delta)
		_show("turn", frame)
		if _done or not moving:
			_turning = false
			_play("run", true)
			frame = 4
		return

	if moving:
		_stopping = false
		if clip != "run" and clip != "start" and clip != "fight_to_run":
			if _since_strike < 0.5:
				_play("fight_to_run", true)
			elif speed < run * 0.7:
				_play("start", true)
			else:
				_play("run", true)
		if clip == "start" or clip == "fight_to_run":
			_advance(delta, 1.2)
			_show(clip, frame)
			if _done:
				_play("run", true)
			return
		var rate := clampf(speed / run, 0.45, 1.15)
		_advance(delta, rate)
		_show("run", frame)
		if (frame == 0 or frame == 6) and frame != _last_step:
			Sfx.play(&"step", -9.0, 0.14)
			if speed > run * 0.8:
				Puff.burst(c, c.global_position, 1, Vector2(-c.facing * 60.0, -10.0), 0.35)
		_last_step = frame
		return
	_last_step = -1

	# Skid to a stop after a run.
	if clip == "run" and speed > run * 0.4:
		_stopping = true
		_play("stop", true)
	if _stopping:
		_advance(delta)
		_show("stop", frame)
		if _done:
			_stopping = false
			_play("idle", true)
		return

	# After a strike: hold the guard, then drop it.
	if _since_strike < 0.55:
		_play("jab")
		_show("jab", 7)
		return
	if _since_strike < 0.55 + 0.4 and clip in ["jab", "cross", "kick", "fight_to_idle"]:
		_play("fight_to_idle")
		_advance(delta)
		_show(clip, frame)
		return

	# Idle, and after a while a smoke break.
	_idle_time += delta
	if _idle_time > BREAK_AFTER and not _breaking:
		_begin_break()
		return
	_play("idle")
	_advance(delta)
	_show("idle", frame)


# ====================================================================== breaks
var _break_count := 0


func _begin_break() -> void:
	_breaking = true
	_break_count += 1
	if _break_count % 2 == 1:
		_break = ["light", "smoke", "smoke", "finish", "chill"]
	else:
		_break = ["bong", "after_bong", "chill"]
	_play(_break.pop_front(), true)
	_idle_time = 0.0


func _end_break() -> void:
	_breaking = false
	_break.clear()
	_snap = ""


## True while a break or a snap owns the pose.
func _pose_break(delta: float, input: bool, moving: bool) -> bool:
	if _snap != "":
		_advance(delta)
		_show(_snap, frame)
		# Moving: only the alert and the flick-away play before the run takes over.
		if _done or (moving and frame >= 3):
			_snap = ""
			_play("idle", true)
			return false
		return true
	if input:
		var holding := (clip == "light" and frame >= 7) or clip == "smoke" or (clip == "finish" and frame < 6)
		var bong := (clip == "bong" and frame >= 3) or (clip == "after_bong" and frame < 11)
		_breaking = false
		_break.clear()
		if holding or bong:
			_snap = "snap_blunt" if holding else "snap_bong"
			_play(_snap, true)
			_show(_snap, 0)
			Sfx.play(&"rustle")
			return true
		return false
	_advance(delta)
	_show(clip, frame)
	_smoke_fx(delta)
	if _done or (_looped and clip != "chill"):
		if _break.is_empty():
			if clip == "chill":
				pass
			_breaking = clip == "chill"
			if clip != "chill":
				_play("chill", true)
		else:
			_play(_break.pop_front(), true)
	if clip == "chill":
		_idle_time += delta
		if _idle_time > CHILL_FOR:
			_breaking = false
			_idle_time = BREAK_AFTER   # straight into the next break
	return true


## Smoke and flame from the break clips, at the face (eyes, a little lower
## and forward) or the hand. Positions come from the frame's own eyes.
func _smoke_fx(delta: float) -> void:
	var fr: Dictionary = CowlAnim.clip(clip)["frames"][frame]
	var eyes: Variant = fr.get("eyes")
	if eyes == null:
		return
	var f := _cowl.facing
	var face := _cowl.global_position + Vector2((eyes[0] + 9.0) * f, eyes[1] + 12.0)
	var key := "%s:%d" % [clip, frame]
	if key == get_meta(&"last_fx", ""):
		return
	set_meta(&"last_fx", key)
	match key:
		"light:7", "bong:8":
			FxPlay.play(_cowl, "lighter", face + Vector2(4.0 * f, 18.0), f, Color(1, 0.95, 0.85, 0.8), true, 0.55)
		"light:13":
			FxPlay.play(_cowl, "smoke_exhale", face, f, SMOKE_TINT, false, 1.0, Vector2(f * 14.0, -18.0))
		"smoke:5":
			var ring := randf() < 0.35
			FxPlay.play(_cowl, "smoke_ring" if ring else "smoke_exhale", face + (Vector2(10.0 * f, -4.0) if ring else Vector2.ZERO),
				f, SMOKE_TINT, false, 0.8 if ring else 1.0, Vector2(f * 14.0, -22.0))
		"smoke:0", "smoke:8":
			FxPlay.play(_cowl, "smoke_wisp", _cowl.global_position + Vector2(20.0 * f, -50.0), f, Color(0.86, 0.84, 0.95, 0.6),
				false, 0.7, Vector2(0, -16.0))
		"after_bong:0":
			FxPlay.play(_cowl, "smoke_plume", face, f, SMOKE_TINT, false, 1.0, Vector2(f * 10.0, -24.0))


# ============================================================ without own art
func _pose_dodge(delta: float) -> void:
	# A low slip: the run's float frames, fast, leaning in, with after-images.
	_end_break()
	_landing = ""
	var k := _cowl.dodge_progress
	var i := 2 + int(k * 4.0) % 4
	_show("run", i)
	_body.rotation = 0.12 * sin(k * PI)
	_body.position = Vector2(0, 4.0 * sin(k * PI))
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.045
		Ghost.spawn(_cowl, _sprite)


func _pose_hurt() -> void:
	_end_break()
	_landing = ""
	_show("fall", 1)
	_body.rotation = -0.3
	_body.position = Vector2.ZERO


func _pose_dead(delta: float) -> void:
	_dead_time += delta
	var k := clampf(_dead_time / 0.55, 0.0, 1.0)
	_show("land_heavy", 0)
	_body.rotation = -1.2 * ease(k, 0.5) if _cowl.is_on_floor() else -0.5 * k
	_body.position = Vector2(0, 0)


func _pose_wake() -> void:
	# Asleep on his back in the bed; then sitting up, then off the bed.
	var w := _cowl.wake_progress
	var lying := Vector2(BED_FEET.x, BED_FEET.y)
	if w <= 0.0:
		_show("idle", 11)              # the idle's blink: eyes closed
		_body.rotation = -PI * 0.5
		_body.position = lying + Vector2(0, sin(_t * 1.3) * 1.5)
		_glow.visible = false
		return
	var sit := smoothstep(0.22, 0.6, w)
	var off := smoothstep(0.62, 0.95, w)
	if w < 0.22:
		_show("idle", 11 if (w > 0.08 and w < 0.13) else 12)
	elif off <= 0.0:
		_show("chill", 0)
	elif off < 0.85:
		_show("jump", 12)
	else:
		_show("land", 1)
	_body.rotation = lerpf(-PI * 0.5, -0.15, sit) * (1.0 - off)
	_body.position = lying.lerp(Vector2.ZERO, off) + Vector2(0, -sin(off * PI) * 40.0)
