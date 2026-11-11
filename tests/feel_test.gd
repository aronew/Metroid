extends Node2D
## Measures the controller in the movement laboratory with scripted input.
##
##   godot --headless --path . res://tests/feel_test.tscn [-- --preset=snappy]
##
## The test drives Cowl's own _physics_process with an injected InputState, so
## what it measures is exactly what the player gets. Results are printed and
## written to docs/feel-report.txt.

const DT := 1.0 / 60.0
const T := 64.0
const F := 40.0 * T          # the lab's floor line

var level: Level
var cowl: Cowl
var inp := Cowl.InputState.new()
var lines: PackedStringArray = []
var failures := 0
var _frames := 0


func _ready() -> void:
	Sfx.muted = true
	level = Level.new()
	add_child(level)
	level.build("res://levels/lab/lab.json")
	cowl = (load("res://game/player/cowl.tscn") as PackedScene).instantiate()
	var preset := "cowl_default"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			preset = arg.trim_prefix("--preset=")
	cowl.config = load("res://game/player/presets/%s.tres" % preset)
	add_child(cowl)
	cowl.set_physics_process(false)
	cowl.sim_input = inp
	lines.append("FEEL REPORT  preset=%s" % preset)
	lines.append(cowl.config.describe())


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 3:
		_run_all()
		var out := "\n".join(lines)
		print(out)
		var f := FileAccess.open("res://docs/feel-report.txt", FileAccess.WRITE)
		f.store_string(out + "\n")
		f.close()
		get_tree().quit(1 if failures > 0 else 0)


# ------------------------------------------------------------------- helpers
func place(x_tiles: float, y_px: float = F) -> void:
	cowl.global_position = Vector2(x_tiles * T, y_px)
	cowl.velocity = Vector2.ZERO
	cowl.state = Cowl.State.NORMAL
	cowl.facing = 1
	inp = Cowl.InputState.new()
	cowl.sim_input = inp
	for i in 6:      # settle on the floor
		step()


func step() -> void:
	cowl._physics_process(DT)
	inp.jump_pressed = false
	inp.dodge_pressed = false
	inp.attack_pressed = false


func note(text: String) -> void:
	lines.append(text)


func check(ok: bool, text: String) -> void:
	lines.append(("  ok    " if ok else "  FAIL  ") + text)
	if not ok:
		failures += 1


func jump_arc(move: float, hold_frames: int, run_up_frames: int = 0) -> Dictionary:
	## Returns rise (tiles), travel (tiles), frames in the air.
	inp.move = move
	for i in run_up_frames:
		step()
	var from := cowl.global_position
	inp.jump_pressed = true
	inp.jump_held = true
	var top := from.y
	var frames := 0
	var left := false
	while frames < 400:
		step()
		frames += 1
		if frames >= hold_frames:
			inp.jump_held = false
		top = minf(top, cowl.global_position.y)
		if not cowl.is_on_floor():
			left = true
		elif left:
			break
	return {
		"rise": (from.y - top) / T, "travel": absf(cowl.global_position.x - from.x) / T,
		"frames": frames, "land_y": cowl.global_position.y,
	}


# --------------------------------------------------------------------- tests
func _run_all() -> void:
	_test_ground()
	_test_jump()
	_test_coyote_and_buffer()
	_test_gaps()
	_test_rises()
	_test_ramps()
	_test_corner()
	_test_walls()
	_test_dodge()
	_test_oneway()


func _test_ground() -> void:
	note("\nGROUND")
	place(8)
	var cfg := cowl.config
	inp.move = 1.0
	var frames := 0
	while absf(cowl.velocity.x) < cfg.run_px() - 0.5 and frames < 120:
		step()
		frames += 1
	note("  rest to top speed: %d frames (%.3f s), covering %.2f tiles" % [frames, frames * DT, cowl.global_position.x / T - 8.0])
	check(frames <= 8, "top speed inside 8 frames")
	for i in 30:
		step()
	check(is_equal_approx(cowl.velocity.x, cfg.run_px()), "holds top speed exactly (%.1f px/s)" % cowl.velocity.x)
	var x0 := cowl.global_position.x
	inp.move = 0.0
	frames = 0
	while absf(cowl.velocity.x) > 0.5 and frames < 120:
		step()
		frames += 1
	note("  top speed to rest: %d frames, sliding %.2f tiles" % [frames, (cowl.global_position.x - x0) / T])
	check(frames <= 6 and (cowl.global_position.x - x0) / T < 0.6, "stops inside 6 frames and 0.6 tiles")
	inp.move = 1.0
	for i in 30:
		step()
	x0 = cowl.global_position.x
	inp.move = -1.0
	frames = 0
	var overshoot := 0.0
	while cowl.velocity.x > -cfg.run_px() + 0.5 and frames < 120:
		step()
		frames += 1
		overshoot = maxf(overshoot, cowl.global_position.x - x0)
	note("  full reverse: %d frames, carried %.2f tiles past the turn" % [frames, overshoot / T])
	check(frames <= 12, "full reverse inside 12 frames")
	# Analog walk.
	place(8)
	inp.move = 0.4
	for i in 40:
		step()
	check(is_equal_approx(cowl.velocity.x, cfg.walk_px()), "half stick walks at %.1f t/s" % (cowl.velocity.x / T))


func _test_jump() -> void:
	note("\nJUMP")
	var cfg := cowl.config
	place(12)
	var full := jump_arc(0.0, 999)
	note("  full jump: rise %.2f tiles, %d frames in the air (%.2f s)" % [full["rise"], full["frames"], full["frames"] * DT])
	check(absf(full["rise"] - cfg.jump_height) < 0.35, "full jump rises about jump_height (%.2f, hang adds a little)" % cfg.jump_height)
	place(12)
	var tap := jump_arc(0.0, 1)
	note("  one-frame tap: rise %.2f tiles, %d frames" % [tap["rise"], tap["frames"]])
	check(tap["rise"] < full["rise"] * 0.45 and tap["rise"] > 0.5, "tap is a short hop, under half the full jump")
	place(12)
	var mid := jump_arc(0.0, 8)
	note("  eight-frame press: rise %.2f tiles" % mid["rise"])
	check(mid["rise"] > tap["rise"] + 0.4 and mid["rise"] < full["rise"] - 0.4, "height follows how long the button is held")
	place(8)
	var run := jump_arc(1.0, 999, 20)
	note("  running full jump on the flat: travels %.2f tiles" % run["travel"])
	place(8)
	var runtap := jump_arc(1.0, 1, 20)
	note("  running tap: travels %.2f tiles" % runtap["travel"])
	# Air control: reverse at the apex and see how far back Cowl gets.
	place(12)
	inp.move = 1.0
	for i in 20:
		step()
	var x0 := cowl.global_position.x
	inp.jump_pressed = true
	inp.jump_held = true
	var frames := 0
	var apex_x := 0.0
	var seen_air := false
	while frames < 300:
		step()
		frames += 1
		if not cowl.is_on_floor():
			seen_air = true
		if cowl.velocity.y >= 0.0 and apex_x == 0.0:
			apex_x = cowl.global_position.x
			inp.move = -1.0
		if seen_air and cowl.is_on_floor():
			break
	note("  jump right, reverse at the apex: out %.2f tiles, lands %.2f tiles from take-off" % [(apex_x - x0) / T, (cowl.global_position.x - x0) / T])
	check(cowl.global_position.x < apex_x, "air steering can bring Cowl back from the apex")


func _test_coyote_and_buffer() -> void:
	note("\nCOYOTE TIME AND JUMP BUFFER")
	var cfg := cowl.config
	# The block of rise 4 at x 123..127: walk off its east edge.
	var allowed := int(round(cfg.coyote_time / DT))
	for late: int in [allowed - 1, allowed + 2]:
		place(125.0, F - 4.0 * T)
		inp.move = 1.0
		var frames := 0
		while cowl.is_on_floor() and frames < 200:
			step()
			frames += 1
		for i in late - 1:
			step()
		var y_before := cowl.global_position.y
		inp.jump_pressed = true
		inp.jump_held = true
		step()
		step()
		var jumped := cowl.velocity.y < -200.0
		if late <= allowed:
			check(jumped, "jump %d frames after leaving a ledge still fires" % late)
		else:
			check(not jumped, "jump %d frames after leaving a ledge does not fire" % late)
		inp.jump_held = false
	var buf := int(round(cfg.jump_buffer / DT))
	for early: int in [buf - 1, buf + 3]:
		place(20.0)
		# Drop from five tiles up and press `early` frames before touching down.
		cowl.global_position.y = F - 5.0 * T
		cowl.move_and_slide()
		cowl._coyote = 0.0
		var fall_frames := 0
		var probe := cowl.global_position
		while not cowl.is_on_floor() and fall_frames < 200:
			step()
			fall_frames += 1
		cowl.global_position = probe
		cowl.velocity = Vector2.ZERO
		cowl.move_and_slide()
		cowl._coyote = 0.0
		for i in fall_frames - early:
			step()
		inp.jump_pressed = true
		inp.jump_held = true
		var fired := false
		for i in early + 3:
			step()
			if cowl.velocity.y < -200.0:
				fired = true
		if early <= buf:
			check(fired, "jump pressed %d frames before landing fires on landing" % early)
		else:
			check(not fired, "jump pressed %d frames before landing is forgotten" % early)
		inp.jump_held = false


func _test_gaps() -> void:
	note("\nGAPS (running full jump from the lip)")
	var x := 42.0
	var widest := 0
	for gap: int in [3, 4, 5, 6, 7]:
		# Find the latest take-off: run from 6 tiles back, jump when the lip is under the trailing foot.
		var best := false
		for lip_px: int in [0, 6, 12, 18]:
			place(x - 6.0)
			inp.move = 1.0
			var frames := 0
			while cowl.global_position.x < x * T - lip_px - 6.0 and frames < 300:
				step()
				frames += 1
			inp.jump_pressed = true
			inp.jump_held = true
			var left := false
			frames = 0
			while frames < 300:
				step()
				frames += 1
				if not cowl.is_on_floor():
					left = true
				elif left:
					break
			if absf(cowl.global_position.y - F) < 2.0 and cowl.global_position.x > (x + gap) * T:
				best = true
				break
		note("  gap %d: %s" % [gap, "cleared" if best else "not cleared"])
		if best:
			widest = gap
		x += gap + 7
	note("  widest gap cleared on the flat: %d tiles" % widest)
	check(widest == 6, "flat-ground reach tops out at 6 tiles with a perfect take-off; 7 is a wall")


func _test_rises() -> void:
	note("\nRISES (standing start beside the block, jump and steer on)")
	var x := 96.0
	var tallest := 0
	for rise: int in [1, 2, 3, 4]:
		place(x - 1.2)
		inp.move = 1.0
		inp.jump_pressed = true
		inp.jump_held = true
		var frames := 0
		var left := false
		while frames < 300:
			step()
			frames += 1
			if not cowl.is_on_floor():
				left = true
			elif left:
				break
		var on_top := absf(cowl.global_position.y - (F - rise * T)) < 2.0
		note("  rise %d: %s" % [rise, "reached" if on_top else "not reached"])
		if on_top:
			tallest = rise
		x += 9
	check(tallest == 3, "a 3-tile block is reachable and a 4-tile block is not (got %d)" % tallest)


func _test_ramps() -> void:
	note("\nRAMPS")
	var cfg := cowl.config
	for dir: int in [1, -1]:
		place(130.0 if dir > 0 else 152.0)
		inp.move = float(dir)
		var airborne := 0
		var min_speed := INF
		var frames := 0
		var seen := 0
		while frames < 400:
			step()
			frames += 1
			var x := cowl.global_position.x / T
			if x > 134.5 and x < 149.5:
				seen += 1
				if not cowl.is_on_floor():
					airborne += 1
				min_speed = minf(min_speed, cowl.get_real_velocity().length())
			if (dir > 0 and x > 151.0) or (dir < 0 and x < 133.0):
				break
		check(airborne == 0, "%s over both ramps: never leaves the ground (%d airborne frames of %d)" % ["east" if dir > 0 else "west", airborne, seen])
		check(min_speed > cfg.run_px() * 0.82, "%s over both ramps: speed holds (slowest %.1f t/s)" % ["east" if dir > 0 else "west", min_speed / T])
	# Stand still on the steep ramp: no sliding.
	place(148.0, F - 2.0 * T)
	for i in 30:
		step()
	var at := cowl.global_position
	for i in 60:
		step()
	check(cowl.global_position.distance_to(at) < 0.5, "standing on the 1:1 ramp does not slide")


func _test_corner() -> void:
	note("\nCORNER CORRECTION (block at x 168..171, underside 4 tiles up)")
	var cfg := cowl.config
	var passed := 0
	var tried := 0
	for overlap: int in [4, 8, 12, 20]:
		# Cowl's right edge overlaps the block's left edge by `overlap` px.
		place(168.0 - (20.0 - overlap) / T)
		var x0 := cowl.global_position.x
		var r := jump_arc(0.0, 999)
		var ok: bool = r["rise"] > 3.0
		tried += 1
		if overlap <= int(cfg.corner_correction_px):
			check(ok, "head clips the corner by %d px: slides round (rise %.2f)" % [overlap, r["rise"]])
		else:
			check(not ok, "head overlaps by %d px: stopped by the block (rise %.2f)" % [overlap, r["rise"]])
		if ok:
			passed += 1


func _test_walls() -> void:
	note("\nWALLS (press into the tall shelf at x 188 while falling and rising)")
	place(186.0)
	inp.move = 1.0
	for i in 20:
		step()
	inp.jump_pressed = true
	inp.jump_held = true
	var snag := 0
	var frames := 0
	var left := false
	var last_vy := -INF
	while frames < 300:
		step()
		frames += 1
		if not cowl.is_on_floor():
			left = true
			# While falling against the wall the speed must only ever grow.
			if cowl.velocity.y > 0.0 and cowl.velocity.y < last_vy - 1.0:
				snag += 1
			last_vy = cowl.velocity.y
		elif left:
			break
	check(snag == 0, "sliding down a wall never snags")
	check(absf(cowl.global_position.x - (188.0 * T - 20.0)) < 1.0, "body rests flush against the wall")


func _test_dodge() -> void:
	note("\nDODGE")
	var cfg := cowl.config
	place(10)
	var x0 := cowl.global_position.x
	inp.dodge_pressed = true
	var frames := 0
	step()
	var invuln_frames := 0
	while cowl.state == Cowl.State.DODGE and frames < 100:
		if cowl.is_invulnerable():
			invuln_frames += 1
		step()
		frames += 1
	var dist := (cowl.global_position.x - x0) / T
	note("  standing dodge: %.2f tiles in %d frames, %d of them untouchable" % [dist, frames, invuln_frames])
	check(absf(dist - cfg.dodge_distance) < 0.35, "dodge covers its set distance (%.1f)" % cfg.dodge_distance)
	inp.dodge_pressed = true
	step()
	check(cowl.state != Cowl.State.DODGE, "cannot dodge again inside the cooldown")
	# In the air the dodge is not available.
	place(12)
	inp.jump_pressed = true
	inp.jump_held = true
	for i in 6:
		step()
	inp.dodge_pressed = true
	step()
	step()
	check(cowl.state != Cowl.State.DODGE, "no dodge in the air (kept for a later ability)")


func _test_oneway() -> void:
	note("\nONE-WAY LEDGES (ledge at x 174..179, 3 tiles up)")
	place(176.0)
	var r := jump_arc(0.0, 999)
	check(absf(cowl.global_position.y - (F - 3.0 * T)) < 2.0, "jumps up through a ledge and lands on it")
	inp = Cowl.InputState.new()
	cowl.sim_input = inp
	inp.look = 1.0
	inp.jump_pressed = true
	for i in 40:
		step()
	check(absf(cowl.global_position.y - F) < 2.0, "down + jump drops through it")
