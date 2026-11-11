extends Node2D
## Cowl's body: the approved artwork, cut into parts and animated.
##
## Nothing here moves Cowl. Every frame the rig reads the controller (speed,
## floor, swing timing, dodge progress) and poses the parts to match, so the
## picture is always a consequence of the physics rather than a clip playing
## over it. Poses are blended with short springs: no transition ever snaps,
## and none ever lags a control input (the swing is posed directly).
##
## Parts and pivots come from assets/cowl/rig.json, written by
## tools/build_cowl_parts.py from the character mockup.

const DIR := "res://assets/cowl/"
## Height of Cowl on screen in pixels at zoom 1 (rig units are 369 tall).
const HEIGHT_PX := 124.0
const FLASH_SHADER := "
shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}"

## A pose: every channel the animations drive. Angles in radians; a positive
## angle turns clockwise, so for a hanging limb NEGATIVE swings it forward.
class Pose:
	var lean := 0.0          # whole body about the feet
	var hip_y := 0.0         # body up (-) / down (+), rig units
	var hip_x := 0.0
	var head_rot := 0.0
	var head_y := 0.0
	var head_x := 0.0
	var arm_f := 0.0
	var arm_b := 0.0
	var leg_f := 0.0
	var leg_b := 0.0
	var leg_f_y := 0.0
	var leg_b_y := 0.0
	var shorts_rot := 0.0
	var knife := -1.95       # knife angle relative to the forearm (at rest: blade up)

	const KEYS := [&"lean", &"hip_y", &"hip_x", &"head_rot", &"head_y", &"head_x", &"arm_f", &"arm_b",
		&"leg_f", &"leg_b", &"leg_f_y", &"leg_b_y", &"shorts_rot", &"knife"]

	func blend_to(other: Pose, weight: float) -> void:
		for k: StringName in KEYS:
			set(k, lerpf(get(k), other.get(k), weight))

var _cowl: Cowl
var _rig: Dictionary
var _scale := 1.0
var _body: Node2D
var _parts: Dictionary = {}       # name -> pivot Node2D
var _knife: Sprite2D
var _eye_lids: Array[Polygon2D] = []
var _eye_glow: Array[Sprite2D] = []
var _material: ShaderMaterial
var _slash: Node2D

var _pose := Pose.new()
var _t := 0.0
var _stride := 0.0                # walk/run cycle phase, advanced by distance
var _face := 1.0                  # eased facing, -1..1 (the turn squeeze)
var _squash := 0.0                # + stretch, - squash; a spring
var _squash_vel := 0.0
var _land_time := 9.0
var _turn_time := 9.0
var _blink := 0.0
var _next_blink := 2.5
var _flash := 0.0
var _slope_drop := 0.0
var _ghost_timer := 0.0
var _last_step_phase := 0.0
var _hurt_time := 9.0
var _dead_time := 0.0
var _swing_arc := Vector2.ZERO    # arm angle from/to of the active swing
var _slash_fade := 0.0
var _slash_kind: StringName = &""
var _glow_tex: Texture2D


func _ready() -> void:
	_cowl = get_parent() as Cowl
	_rig = JSON.parse_string(FileAccess.get_file_as_string(DIR + "rig.json"))
	_scale = HEIGHT_PX / float(_rig["height_px"])
	_material = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLASH_SHADER
	_material.shader = sh
	_build()
	_cowl.jumped.connect(_on_jumped)
	_cowl.landed.connect(_on_landed)
	_cowl.turned.connect(func(_f: int) -> void: _turn_time = 0.0)
	_cowl.was_hurt.connect(_on_hurt)
	_cowl.attack_started.connect(_on_attack)
	_cowl.dodge_started.connect(_on_dodge)
	_cowl.died.connect(func() -> void: _dead_time = 0.0)
	_face = float(_cowl.facing)


# ====================================================================== build
func _build() -> void:
	_body = Node2D.new()
	_body.material = _material
	add_child(_body)
	# Back to front.
	for part: String in ["arm_back", "leg_back", "leg_front", "torso", "shorts", "head", "arm_front"]:
		var spec: Dictionary = _rig["parts"][part]
		var pivot := Node2D.new()
		pivot.name = part
		pivot.position = Vector2(spec["pivot"][0], spec["pivot"][1])
		pivot.set_meta(&"rest", pivot.position)
		pivot.use_parent_material = true
		var sprite := Sprite2D.new()
		sprite.texture = load(DIR + String(spec["file"]))
		sprite.centered = false
		sprite.position = Vector2(spec["offset"][0], spec["offset"][1])
		sprite.use_parent_material = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pivot.add_child(sprite)
		_body.add_child(pivot)
		_parts[part] = pivot

	# The knife rides in the front hand, behind the fist.
	var k: Dictionary = _rig["knife"]
	_knife = Sprite2D.new()
	_knife.texture = load(DIR + String(k["file"]))
	_knife.centered = false
	_knife.offset = -Vector2(k["grip"][0], k["grip"][1])
	_knife.position = Vector2(_rig["hand_front"][0], _rig["hand_front"][1])
	_knife.use_parent_material = true
	_knife.show_behind_parent = true
	_knife.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_knife.visible = false
	_knife.scale = Vector2(0.82, 0.82)
	(_parts["arm_front"] as Node2D).add_child(_knife)

	# Eyelids (charcoal, for the blink) and a soft glow on each eye.
	_glow_tex = _make_glow()
	var head: Node2D = _parts["head"]
	for e: Array in _rig["eyes_on_head"]:
		var rect := Rect2(e[0] - 3.0, e[1] - 4.0, e[2] + 6.0, e[3] + 8.0)
		var lid := Polygon2D.new()
		lid.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		lid.color = Color(0.2, 0.2, 0.22)
		lid.visible = false
		head.add_child(lid)
		_eye_lids.append(lid)
		var glow := Sprite2D.new()
		glow.texture = _glow_tex
		glow.position = rect.get_center()
		glow.scale = Vector2(rect.size.x / 64.0 * 2.6, 0.75)
		glow.modulate = Color(0.45, 0.85, 1.0, 0.55)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		head.add_child(glow)
		_eye_glow.append(glow)

	_slash = Node2D.new()
	_slash.z_index = 2
	_slash.draw.connect(_draw_slash)
	add_child(_slash)


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


# ===================================================================== events
func _on_jumped() -> void:
	_squash = 0.0
	_squash_vel = 4.2
	Puff.burst(_cowl, _cowl.global_position, 5, Vector2(0, -40), 0.55)


func _on_landed(impact: float) -> void:
	var k := clampf(impact / 1500.0, 0.15, 1.0)
	_squash_vel = -5.5 * k
	_land_time = 0.0
	if impact > 250.0:
		Puff.burst(_cowl, _cowl.global_position, 4 + int(k * 8.0), Vector2.ZERO, 0.6 + k * 0.6)


func _on_hurt(_dir: int) -> void:
	_flash = 1.0
	_hurt_time = 0.0
	_squash_vel = -3.0


func _on_attack(kind: StringName) -> void:
	_slash_kind = kind
	_slash_fade = 0.0
	match kind:
		&"slash1":
			_swing_arc = Vector2(-3.45, -0.35)
		&"slash2":
			_swing_arc = Vector2(-4.1, 0.1)
		&"up":
			_swing_arc = Vector2(-1.0, -4.3)
		_:
			_swing_arc = Vector2(-3.6, -0.2)


func _on_dodge(_dir: int) -> void:
	_squash_vel = -2.0
	_ghost_timer = 0.0
	Puff.burst(_cowl, _cowl.global_position, 6, Vector2(-_cowl.facing * 120.0, -20.0), 0.8)


# ====================================================================== frame
func _process(delta: float) -> void:
	# A long frame must not blow the springs up.
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	_land_time += delta
	_turn_time += delta
	_hurt_time += delta
	var target := _target_pose(delta)

	# Blend. Swings and the dodge are posed at once; everything else eases.
	var direct := _cowl.attack_time >= 0.0 or _cowl.state == Cowl.State.DODGE
	_pose.blend_to(target, 1.0 if direct else 1.0 - exp(-22.0 * delta))
	if direct:
		# Legs and head still ease, so only the arm snaps.
		pass

	# Squash and stretch: a damped spring kicked by jumps and landings.
	_squash_vel += (-_squash * 260.0 - _squash_vel * 17.0) * delta
	_squash = clampf(_squash + _squash_vel * delta, -0.42, 0.34)
	var air_stretch := 0.0
	if not _cowl.is_on_floor() and _cowl.state != Cowl.State.CUTSCENE:
		air_stretch = clampf(absf(_cowl.velocity.y) / 1500.0, 0.0, 1.0) * 0.09
	var s := _squash + air_stretch
	_body.scale = Vector2(1.0 - s * 0.62, 1.0 + s)

	# Facing: a quick squeeze through the turn instead of a mirror pop.
	_face = move_toward(_face, float(_cowl.facing), delta / 0.07)
	var squeeze := maxf(absf(_face), 0.22) * (1.0 if _face >= 0.0 else -1.0)
	scale = Vector2(_scale * squeeze, _scale)

	# On a ramp the square body rides on one corner; sink the art to the tread.
	var drop := 0.0
	if _cowl.is_on_floor():
		var n := _cowl.get_floor_normal()
		if absf(n.x) > 0.05 and absf(n.y) > 0.1:
			drop = 20.0 * absf(n.x / n.y) * 0.85
	_slope_drop = lerpf(_slope_drop, drop, 1.0 - exp(-18.0 * delta))
	position = Vector2(0.0, _slope_drop)

	_apply(_pose)
	_update_face(delta)
	_update_fx(delta)


func _apply(p: Pose) -> void:
	_body.rotation = p.lean
	_body.position = Vector2(p.hip_x, p.hip_y)
	_set_part("head", p.head_rot, Vector2(p.head_x, p.head_y))
	_set_part("arm_front", p.arm_f, Vector2.ZERO)
	_set_part("arm_back", p.arm_b, Vector2.ZERO)
	_set_part("leg_front", p.leg_f, Vector2(0.0, p.leg_f_y))
	_set_part("leg_back", p.leg_b, Vector2(0.0, p.leg_b_y))
	_set_part("shorts", p.shorts_rot, Vector2.ZERO)
	_knife.rotation = p.knife
	_knife.visible = Game.has_knife


func _set_part(part: String, rot: float, offset: Vector2) -> void:
	var node: Node2D = _parts[part]
	node.rotation = rot
	node.position = (node.get_meta(&"rest") as Vector2) + offset


# ====================================================================== poses
func _target_pose(delta: float) -> Pose:
	var p := Pose.new()
	var c := _cowl
	var speed := absf(c.velocity.x)
	var run := c.config.run_px()
	var frac := clampf(speed / run, 0.0, 1.3)
	var forward := signf(c.velocity.x) * float(c.facing)      # +1 moving the way he faces

	match c.state:
		Cowl.State.CUTSCENE:
			return _pose_wake(p)
		Cowl.State.DEAD:
			return _pose_dead(p, delta)
		Cowl.State.HURT:
			p.lean = -0.38
			p.head_rot = -0.25
			p.arm_f = -2.3
			p.arm_b = 2.1
			p.leg_f = -0.6
			p.leg_b = 0.5
			p.hip_y = -6.0
			return p
		Cowl.State.DODGE:
			return _pose_dodge(p)

	if c.is_on_floor():
		if speed > 18.0:
			# Walk and run share one cycle; the stride lengthens with speed.
			var stride_len := lerpf(92.0, 168.0, clampf(frac, 0.0, 1.0))
			_stride += speed * delta / stride_len * TAU
			var sw := sin(_stride)
			var amp := lerpf(0.42, 0.95, clampf(frac, 0.0, 1.0))
			p.leg_f = sw * amp
			p.leg_b = -sw * amp
			p.leg_f_y = -maxf(0.0, cos(_stride)) * 16.0 * frac
			p.leg_b_y = -maxf(0.0, -cos(_stride)) * 16.0 * frac
			p.arm_f = -sw * amp * 0.85 + 0.12
			p.arm_b = sw * amp * 0.85
			p.hip_y = -absf(sin(_stride)) * 9.0 * frac + 3.0 * frac
			p.lean = 0.17 * frac * forward
			p.head_rot = -0.07 * frac * forward + sin(_stride * 2.0 + 0.6) * 0.035 * frac
			p.head_y = sin(_stride * 2.0 + 0.9) * 3.5 * frac
			p.shorts_rot = sw * 0.07
			# Braking hard or just reversed: dig the heels in.
			if forward < 0.0 or (c.move_input == 0.0 and frac > 0.25):
				p.lean = -0.2 * frac
				p.leg_f = -0.55
				p.leg_b = -0.25
				p.arm_f = -0.9
				p.arm_b = -0.5
			# Footfalls.
			var ph := fmod(_stride, PI)
			if ph < _last_step_phase and frac > 0.3:
				Sfx.play(&"step", -9.0, 0.14)
				if frac > 0.8:
					Puff.burst(c, c.global_position, 1, Vector2(-c.facing * 60.0, -10.0), 0.35)
			_last_step_phase = ph
		else:
			# Idle: breath, and the weight settling.
			var b := sin(_t * 2.1)
			p.hip_y = b * 1.6
			p.head_y = sin(_t * 2.1 - 0.5) * 2.2
			p.head_rot = sin(_t * 0.7) * 0.02
			p.arm_f = 0.03 + b * 0.025
			p.arm_b = -0.03 - b * 0.025
			_stride = 0.0
			if c.look_input < -0.5:
				p.head_rot -= 0.16
			elif c.look_input > 0.5:
				p.head_rot += 0.14
				p.hip_y += 5.0
		if _land_time < 0.16:
			# Knees give on touchdown.
			var k := 1.0 - _land_time / 0.16
			p.leg_f -= 0.35 * k
			p.leg_b += 0.35 * k
			p.arm_f -= 0.5 * k
			p.arm_b += 0.5 * k
			p.head_y += 8.0 * k
	else:
		# In the air the pose follows vertical speed: tucked on the way up,
		# opening at the top, arms thrown up and legs trailing on the way down.
		var vy := c.velocity.y
		var up := clampf(-vy / 900.0, 0.0, 1.0)
		var down := clampf(vy / 1100.0, 0.0, 1.0)
		var flutter := sin(_t * 17.0) * 0.07 * down
		p.arm_f = lerpf(-0.5, -2.5, down) + up * 0.9 + flutter
		p.arm_b = lerpf(0.45, 2.3, down) - up * 0.3 - flutter
		p.leg_f = lerpf(-0.75, -0.15, down) * (0.4 + 0.6 * maxf(up, down))
		p.leg_b = lerpf(0.55, 0.35, down) * (0.4 + 0.6 * maxf(up, down))
		p.leg_f_y = -10.0 * up
		p.head_rot = -0.1 * up + 0.12 * down
		p.head_y = 5.0 * down - 3.0 * up
		p.lean = clampf(c.velocity.x / run, -1.0, 1.0) * float(c.facing) * 0.13
		p.shorts_rot = -0.05 * down

	if c.attack_time >= 0.0:
		_pose_attack(p)
	return p


func _pose_attack(p: Pose) -> void:
	var c := _cowl
	var a: Dictionary = Cowl.ATTACKS[c.attack_kind]
	var t := c.attack_time
	var su: float = a["startup"]
	var ac: float = a["active"]
	var rc: float = a["recovery"]
	var arm: float
	var body := 0.0
	if t < su:
		# Anticipation: the knife goes back as the body coils.
		var k := ease(t / su, 0.5)
		arm = lerpf(0.0, _swing_arc.x, k)
		body = -0.13 * k
		p.knife = lerpf(-1.95, -1.3, k)
	elif t < su + ac:
		# The cut. Fast at the start: the edge leads.
		var k := ease((t - su) / ac, 0.45)
		arm = lerpf(_swing_arc.x, _swing_arc.y, k)
		body = lerpf(-0.13, 0.24, k)
		p.knife = lerpf(-1.3, 0.2, k)
	else:
		# Follow-through, then the weight of the blade brings the arm home.
		var k := clampf((t - su - ac) / rc, 0.0, 1.0)
		var over := sin(k * PI) * 0.22
		arm = lerpf(_swing_arc.y, 0.0, ease(k, 2.4)) + over * signf(_swing_arc.y - _swing_arc.x)
		body = lerpf(0.24, 0.0, ease(k, 0.6))
		p.knife = lerpf(0.2, -1.95, ease(k, 2.0))
	var heavy := 1.35 if c.attack_kind == &"slash2" else 1.0
	p.arm_f = arm
	p.arm_b = lerpf(p.arm_b, 0.9 + body * 2.0, 0.8)
	if c.attack_kind == &"up":
		p.lean += body * -0.5
		p.head_rot -= 0.14
	else:
		p.lean += body * heavy
		p.head_rot += body * 0.5
	if c.is_on_floor():
		# Plant the feet for the cut.
		p.leg_f = lerpf(p.leg_f, -0.45 * heavy, 0.75)
		p.leg_b = lerpf(p.leg_b, 0.4 * heavy, 0.75)
		p.hip_y += 5.0 * heavy
	else:
		p.leg_f = lerpf(p.leg_f, -0.9, 0.6)
		p.leg_b = lerpf(p.leg_b, 0.7, 0.6)


func _pose_dodge(p: Pose) -> Pose:
	# A low, fast slip: head down, limbs swept back, uncurling at the end.
	var k := _cowl.dodge_progress
	var tuck := sin(clampf(k * 1.15, 0.0, 1.0) * PI)
	p.lean = 0.2 + 0.75 * tuck
	p.hip_y = 26.0 * tuck
	p.head_rot = -0.35 * tuck
	p.head_y = 10.0 * tuck
	p.arm_f = 1.5 * tuck
	p.arm_b = 1.9 * tuck
	p.leg_f = 1.05 * tuck - 0.3 * (1.0 - tuck)
	p.leg_b = 1.35 * tuck
	p.knife = -1.95 + 1.2 * tuck
	return p


func _pose_wake(p: Pose) -> Pose:
	# 0: asleep on the bed. Then: eyes open, sit up, swing off, land.
	var w := _cowl.wake_progress
	var bed := -285.0                   # the mattress in the bedroom plate, rig units
	if w <= 0.0:
		p.lean = -PI * 0.5
		p.hip_y = bed
		p.hip_x = 60.0
		p.arm_f = 0.25
		p.arm_b = -0.2
		p.head_rot = 0.12
		p.hip_y += sin(_t * 1.3) * 1.5
		return p
	var sit := smoothstep(0.22, 0.6, w)
	var off := smoothstep(0.62, 0.95, w)
	p.lean = lerpf(-PI * 0.5, -0.18, sit) * (1.0 - off)
	p.hip_y = bed * (1.0 - off) - sin(off * PI) * 46.0
	p.hip_x = lerpf(60.0, 0.0, off)
	p.head_rot = lerpf(0.12, 0.3, sit) * (1.0 - off)
	p.arm_f = lerpf(0.25, -0.9, sit) * (1.0 - off) - 1.2 * sin(off * PI)
	p.arm_b = lerpf(-0.2, 0.7, sit) * (1.0 - off) + 1.0 * sin(off * PI)
	p.leg_f = -1.25 * sit * (1.0 - off)
	p.leg_b = -1.05 * sit * (1.0 - off)
	return p


func _pose_dead(p: Pose, delta: float) -> Pose:
	_dead_time += delta
	var k := clampf(_dead_time / 0.55, 0.0, 1.0)
	var down := ease(k, 0.5)
	p.lean = -1.5 * down if _cowl.is_on_floor() else -0.7 * down
	p.hip_y = 26.0 * down if _cowl.is_on_floor() else 0.0
	p.head_rot = -0.3 * down
	p.arm_f = -2.4 * down
	p.arm_b = 2.2 * down
	p.leg_f = -0.5 * down
	p.leg_b = 0.3 * down
	return p


# ======================================================================= face
func _update_face(delta: float) -> void:
	var closed := false
	if _cowl.state == Cowl.State.CUTSCENE:
		var w := _cowl.wake_progress
		# Asleep, then two slow blinks as he comes round.
		closed = w <= 0.02 or (w > 0.08 and w < 0.13) or (w > 0.17 and w < 0.2)
	elif _cowl.state == Cowl.State.DEAD:
		closed = _dead_time > 0.35
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink = 0.11
			_next_blink = randf_range(2.2, 5.5)
		_blink -= delta
		closed = _blink > 0.0 or _hurt_time < 0.2
	for lid in _eye_lids:
		lid.visible = closed
	var pulse := 0.5 + sin(_t * 2.3) * 0.08
	for glow in _eye_glow:
		glow.visible = not closed
		glow.modulate.a = pulse

	# Hit flash, and the flicker of invulnerability.
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_material.set_shader_parameter(&"flash", _flash)
	var a := 1.0
	if _cowl.is_flashing() and _hurt_time > 0.15:
		a = 0.45 if fmod(_t, 0.12) < 0.06 else 1.0
	if _cowl.state == Cowl.State.DEAD:
		a = clampf(1.6 - _dead_time, 0.0, 1.0)
	_body.modulate.a = a


# ========================================================================= fx
func _update_fx(delta: float) -> void:
	if _cowl.state == Cowl.State.DODGE:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = 0.045
			Ghost.spawn(_cowl, self)
	if _cowl.attack_time >= 0.0:
		var a: Dictionary = Cowl.ATTACKS[_cowl.attack_kind]
		if _cowl.attack_time >= float(a["startup"]):
			_slash_fade += delta
	else:
		_slash_fade += delta
	_slash.queue_redraw()


## The crescent the edge leaves in the air. Drawn in rig space, in front.
func _draw_slash() -> void:
	if _slash_kind == &"" or _slash_fade > 0.2:
		return
	var a: Dictionary = Cowl.ATTACKS[_slash_kind]
	var t := _cowl.attack_time
	if _cowl.attack_time < 0.0:
		t = 99.0
	if t < float(a["startup"]):
		return
	var k := clampf((t - float(a["startup"])) / float(a["active"]), 0.0, 1.0)
	var shoulder: Vector2 = (_parts["arm_front"] as Node2D).get_meta(&"rest")
	var reach := 330.0 if _slash_kind == &"slash2" else 290.0
	var from := _swing_arc.x
	var to := lerpf(_swing_arc.x, _swing_arc.y, ease(k, 0.45))
	var alpha := clampf(1.0 - _slash_fade / 0.2, 0.0, 1.0)
	var steps := 18
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in steps + 1:
		var f := float(i) / steps
		var ang := lerpf(from, to, f) + PI * 0.5      # limb angle -> direction
		var dir := Vector2(cos(ang), sin(ang))
		var width := sin(f * PI) * (86.0 if _slash_kind == &"slash2" else 62.0) * (0.4 + 0.6 * f)
		outer.append(shoulder + dir * reach)
		inner.append(shoulder + dir * (reach - width))
	inner.reverse()
	var poly := outer + inner
	if Geometry2D.triangulate_polygon(poly).is_empty():
		return
	_slash.draw_colored_polygon(poly, Color(0.86, 0.84, 1.0, 0.6 * alpha))
	_slash.draw_polyline(outer, Color(1, 1, 1, 0.95 * alpha), 7.0, true)
