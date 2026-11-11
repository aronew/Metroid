extends Node2D
## Walks a level with Cowl's real controller and reports everywhere he can
## stand, every place he can reach but not leave, and what each gate holds back.
##
##   godot --headless --path . res://tests/explore.tscn -- --level=mansion \
##       --mode=base|knife [--cautious] --out=/path/result.json
##
## From every standing spot it tries walks, drops, dodges and a spread of jumps
## (short, medium, full; steered, released and reversed at the apex), using the
## same physics step the player gets. "base" is Cowl before the knife: vines are
## walls and root-bound levers do not work. "knife" opens them. --cautious
## handicaps the jump and removes the forgiveness, to show which routes need a
## perfect input.

const DT := 1.0 / 60.0
const T := 64.0
const QX := 32.0
const QY := 16.0
const NODES_PER_FRAME := 6

var level_name := "mansion"
var mode := "base"
var cautious := false
var out_path := "res://docs/explore.json"

var data: Dictionary
var cowl: Cowl
var inp: Cowl.InputState
var spikes: Array[Rect2] = []
var teleports: Dictionary = {}      # node key -> Array of Vector2 destinations
var lift_pairs: Array = []          # [Rect2 a, Vector2 offset]
var bookcase: StaticBody2D
var bookcase_open_zone := Rect2()

var nodes: Dictionary = {}          # key -> Vector2 position
var edges: Dictionary = {}          # key -> Dictionary(set of keys)
var queue: Array = []
var start_key: Vector2i
var _frames := 0
var _hit_spikes := false
var _steps := 0


func _ready() -> void:
	Sfx.muted = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_name = arg.trim_prefix("--level=")
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg == "--cautious":
			cautious = true
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s/%s.json" % [level_name, level_name]))
	_build_world()
	cowl = (load("res://game/player/cowl.tscn") as PackedScene).instantiate()
	cowl.config = load("res://game/player/presets/cowl_default.tres")
	add_child(cowl)
	cowl.set_physics_process(false)
	if cautious:
		cowl.config.jump_height *= 0.9
		cowl.config.run_speed *= 0.94
		cowl.config.coyote_time = 0.0
		cowl.config.corner_correction_px = 0.0
		cowl.config.ledge_snap_px = 0.0


func _static_rect(parent: StaticBody2D, r: Rect2, oneway := false) -> void:
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = oneway
	parent.add_child(cs)


func _build_world() -> void:
	var solids := StaticBody2D.new()
	solids.collision_layer = 1
	add_child(solids)
	var oneways := StaticBody2D.new()
	oneways.collision_layer = 2
	add_child(oneways)
	for r: Array in data["solids"]:
		_static_rect(solids, Rect2(r[0] * T, r[1] * T, r[2] * T, r[3] * T))
	for s: Dictionary in data["slopes"]:
		var poly := PackedVector2Array()
		for p: Array in s["pts"]:
			poly.append(Vector2(p[0], p[1]) * T)
		var shape := ConvexPolygonShape2D.new()
		shape.points = poly
		var cs := CollisionShape2D.new()
		cs.shape = shape
		solids.add_child(cs)
	for o: Dictionary in data["oneways"]:
		_static_rect(oneways, Rect2(o["x"] * T, o["y"] * T, o["w"] * T, 14.0), true)
	var levers_free: Dictionary = {}
	for e: Dictionary in data["entities"]:
		if e["type"] == "lever":
			var usable: bool = mode == "knife" or not e.get("bound", false)
			if usable:
				levers_free[e["lift"]] = true
	for e: Dictionary in data["entities"]:
		var x: float = e["x"] * T
		var y: float = e["y"] * T
		var w: float = float(e.get("w", 1)) * T
		var h: float = float(e.get("h", 1)) * T
		match e["type"]:
			"vine":
				if mode != "knife":
					_static_rect(solids, Rect2(x, y - h, w, h))
			"spikes":
				spikes.append(Rect2(x, y - h, w, h))
			"lift":
				var top: float = float(e["top"]) * T
				var bottom: float = float(e["bottom"]) * T
				# Riding the lift needs no lever: the control is on the platform.
				# A root-bound lift cannot move until the roots are cut.
				var bound := false
				for l: Dictionary in data["entities"]:
					if l["type"] == "lever" and l["lift"] == e["name"] and l.get("bound", false):
						bound = true
				var moves: bool = mode == "knife" or not bound
				var stops: Array = [top, bottom] if moves else [top if e["start"] == "top" else bottom]
				for stop: float in stops:
					_static_rect(solids, Rect2(x, stop, w, 20.0))
				if moves:
					lift_pairs.append([Rect2(x, top - 40.0, w, 48.0), Vector2(0, bottom - top)])
					lift_pairs.append([Rect2(x, bottom - 40.0, w, 48.0), Vector2(0, top - bottom)])
			"bookcase_door":
				bookcase = StaticBody2D.new()
				bookcase.collision_layer = 1
				add_child(bookcase)
				_static_rect(bookcase, Rect2(x, y - h, w, h))
				bookcase_open_zone = Rect2(x + w, y - 3.0 * T, 3.0 * T, 3.0 * T + 8.0)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 3:
		return
	if _frames == 3:
		var spawn := Vector2(data["spawn"][0], data["spawn"][1]) * T
		cowl.sim_reset(spawn + Vector2(0, -4))
		_settle(40)
		start_key = _add_node(cowl.global_position)
		return
	var n := 0
	while not queue.is_empty() and n < NODES_PER_FRAME:
		_expand(queue.pop_front())
		n += 1
	if queue.is_empty():
		if bookcase != null and _bookcase_reached():
			# Reached from behind: it swings open, and the walk goes on.
			bookcase.queue_free()
			bookcase = null
			for k: Vector2i in nodes:
				queue.append(k)
			return
		_finish()


func _bookcase_reached() -> bool:
	for k: Vector2i in nodes:
		if bookcase_open_zone.has_point(nodes[k]):
			return true
	return false


# --------------------------------------------------------------------- nodes
func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / QX), roundi(p.y / QY))


func _add_node(p: Vector2) -> Vector2i:
	var k := _key(p)
	if not nodes.has(k):
		nodes[k] = p
		edges[k] = {}
		queue.append(k)
	return k


func _begin(k: Vector2i) -> void:
	cowl.sim_reset(nodes[k])
	inp = Cowl.InputState.new()
	cowl.sim_input = inp
	_hit_spikes = false


func _step() -> void:
	cowl._physics_process(DT)
	_steps += 1
	inp.jump_pressed = false
	inp.dodge_pressed = false
	if not spikes.is_empty():
		var body := Rect2(cowl.global_position + Vector2(-20, -100), Vector2(40, 100))
		for s in spikes:
			if s.intersects(body):
				_hit_spikes = true


func _settle(max_frames: int) -> bool:
	## Let go and wait until Cowl stands still. False if he never does.
	inp = Cowl.InputState.new() if inp == null else inp
	inp.move = 0.0
	inp.jump_held = false
	inp.look = 0.0
	cowl.sim_input = inp
	var still := 0
	for i in max_frames:
		_step()
		if _hit_spikes:
			return false
		if cowl.is_on_floor() and cowl.velocity.length() < 2.0:
			still += 1
			if still >= 3:
				return true
		else:
			still = 0
	return false


func _land(from: Vector2i) -> void:
	if _settle(420):
		var k := _add_node(cowl.global_position)
		if k != from:
			edges[from][k] = true


func _expand(k: Vector2i) -> void:
	# Lift rides.
	for pair: Array in lift_pairs:
		if (pair[0] as Rect2).has_point(nodes[k]):
			var dest: Vector2 = nodes[k] + (pair[1] as Vector2)
			cowl.sim_reset(dest + Vector2(0, -6))
			inp = Cowl.InputState.new()
			cowl.sim_input = inp
			_hit_spikes = false
			_land(k)
	for dir: float in [-1.0, 1.0]:
		# Walk a little, walk more, and creep off an edge.
		for frames: int in [3, 9]:
			_begin(k)
			inp.move = dir
			for i in frames:
				_step()
			_land(k)
		# Dodge (carries off ledges).
		_begin(k)
		inp.move = dir
		inp.dodge_pressed = true
		for i in 16:
			_step()
		_land(k)
	# Drop through a one-way ledge.
	_begin(k)
	inp.look = 1.0
	inp.jump_pressed = true
	for i in 4:
		_step()
	_land(k)
	# Jumps.
	for move: float in [-1.0, 0.0, 1.0]:
		for run_up: int in [0, 6]:
			if move == 0.0 and run_up > 0:
				continue
			for hold: int in [2, 9, 60]:
				for steer: int in [0, 1, 2]:      # keep / let go at the apex / reverse at the apex
					if move == 0.0 and steer > 0:
						continue
					_begin(k)
					inp.move = move
					for i in run_up:
						_step()
					if run_up > 0 and not cowl.is_on_floor():
						continue
					inp.jump_pressed = true
					inp.jump_held = true
					var f := 0
					var steered := false
					while f < 90:
						_step()
						f += 1
						if f >= hold:
							inp.jump_held = false
						if not steered and cowl.velocity.y >= 0.0 and f > 1:
							steered = true
							if steer == 1:
								inp.move = 0.0
							elif steer == 2:
								inp.move = -move
						if _hit_spikes or (f > 2 and cowl.is_on_floor()):
							break
					_land(k)


# -------------------------------------------------------------------- report
func _finish() -> void:
	# Which standing spots can get back to the start?
	var back: Dictionary = {}
	for a: Vector2i in edges:
		for b: Vector2i in edges[a]:
			if not back.has(b):
				back[b] = []
			back[b].append(a)
	var ok: Dictionary = {start_key: true}
	var q: Array = [start_key]
	while not q.is_empty():
		var n: Vector2i = q.pop_front()
		for m: Vector2i in back.get(n, []):
			if not ok.has(m):
				ok[m] = true
				q.append(m)
	var all: Array = []
	var traps: Array = []
	for k: Vector2i in nodes:
		var p: Vector2 = nodes[k] / T
		all.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		if not ok.has(k):
			traps.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	var result := {"level": level_name, "mode": mode, "cautious": cautious,
		"nodes": all, "traps": traps, "steps": _steps}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	print("explore %s/%s%s: %d standing spots, %d cannot return, %d physics steps" % [
		level_name, mode, " cautious" if cautious else "", all.size(), traps.size(), _steps])
	get_tree().quit()
