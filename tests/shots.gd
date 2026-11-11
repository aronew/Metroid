extends Node
## Takes screenshots of the running game for review.
##
##   xvfb-run -a godot --path . res://tests/shots.tscn -- --level=mansion \
##       --out=/tmp/shots --shots=/path/to/shots.json
##
## shots.json: [{"name": "bedroom", "x": 30, "y": 28, "frames": 40,
##               "move": 1.0, "jump_at": 10, "knife": true, "awake": true}]
## x, y are tiles (Cowl's feet). Optional scripted input runs for `frames`.

var main: Node
var shots: Array = []
var out_dir := "/tmp"
var _i := -1
var _left := 0
var _frame := 0
var _cur: Dictionary = {}
var _inp: Cowl.InputState
var _busy := false


func _ready() -> void:
	var spec := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			spec = arg.trim_prefix("--shots=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	shots = JSON.parse_string(FileAccess.get_file_as_string(spec))
	main = (load("res://game/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Sfx.muted = true


func _physics_process(_delta: float) -> void:
	var cowl: Cowl = main.get("cowl")
	if cowl == null or _busy:
		return
	if _left > 0:
		_left -= 1
		_frame += 1
		if _inp != null:
			_inp.jump_pressed = _frame == int(_cur.get("jump_at", -1))
			_inp.attack_pressed = _frame == int(_cur.get("attack_at", -1)) or _frame == int(_cur.get("attack2_at", -1))
			_inp.dodge_pressed = _frame == int(_cur.get("dodge_at", -1))
			_inp.any_pressed = _frame == int(_cur.get("wake_at", -1))
			if _frame == int(_cur.get("stop_at", -1)):
				_inp.move = 0.0
		if _left == 0:
			_busy = true
			var shot_name: String = _cur["name"]
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s.png" % [out_dir, shot_name])
			print("shot ", shot_name)
			_busy = false
		return
	_i += 1
	if _i >= shots.size():
		get_tree().quit()
		return
	_cur = shots[_i]
	_frame = 0
	_left = int(_cur.get("frames", 30))
	if _cur.get("knife", false):
		Game.give_knife()
	if _cur.has("x"):
		if _cur.get("awake", true) and cowl.state == Cowl.State.CUTSCENE:
			cowl.state = Cowl.State.NORMAL
			cowl.wake_progress = -1.0
		cowl.sim_reset(Vector2(_cur["x"], _cur["y"]) * 64.0)
		cowl.reset_physics_interpolation()
		if _cur.has("facing"):
			cowl.facing = int(_cur["facing"])
		main.get("camera").call(&"snap")
	_inp = Cowl.InputState.new()
	_inp.move = float(_cur.get("move", 0.0))
	_inp.look = float(_cur.get("look", 0.0))
	_inp.jump_held = bool(_cur.get("jump_held", true))
	cowl.sim_input = _inp
	if _cur.has("zoom"):
		main.get("camera").set("base_zoom", float(_cur["zoom"]))
