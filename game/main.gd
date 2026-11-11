extends Node2D
## Boots the slice: loads a level, spawns Cowl, attaches camera, HUD and art.
##
##   F2 switches between the mansion and the movement laboratory.
##   Command line:  -- --level=lab   (or mansion)   --blockout

const LEVELS := {
	"mansion": "res://levels/mansion/mansion.json",
	"lab": "res://levels/lab/lab.json",
}
const COWL_SCENE := preload("res://game/player/cowl.tscn")

var level_name := "mansion"
var force_blockout := false
var level: Level
var art: Node2D
var cowl: Cowl
var camera: GameCamera
var hud: Hud

var _respawning := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_name = arg.trim_prefix("--level=")
		elif arg == "--blockout":
			force_blockout = true
	hud = Hud.new()
	add_child(hud)
	load_level(level_name)


func load_level(which: String) -> void:
	level_name = which
	for n in [level, art, cowl, camera]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	Game.reset_session()

	level = Level.new()
	level.name = "Level"
	level.blockout_view = force_blockout or which == "lab"
	add_child(level)
	level.build(LEVELS[which])

	if not level.blockout_view and ResourceLoader.exists("res://game/level/level_art.gd"):
		art = (load("res://game/level/level_art.gd") as GDScript).new()
		art.name = "LevelArt"
		add_child(art)
		art.call(&"dress", level)

	cowl = COWL_SCENE.instantiate()
	cowl.z_index = 10
	add_child(cowl)
	cowl.global_position = level.spawn_px
	cowl.reset_physics_interpolation()

	camera = GameCamera.new()
	camera.world = level.world_rect()
	camera.zones = level.zones()
	add_child(camera)
	camera.follow(cowl)

	hud.bind(cowl, self)
	cowl.attack_started.connect(func(_k: StringName) -> void: Game.set_flag("swung"))
	if not Game.player_died.is_connected(_on_player_died):
		Game.player_died.connect(_on_player_died)

	if which == "lab":
		Game.give_knife()
	else:
		var bed := level.entities_by_type.get("checkpoint", []) as Array
		if not bed.is_empty() and not force_blockout:
			cowl.begin_asleep(level.spawn_px)
		Game.set_checkpoint(level.spawn_px)
		camera.snap()
		Sfx.loop(&"ambience", -14.0)


## Offer the nearest thing Cowl can act on, and show any control prompt for
## the ground he is standing on.
func _process(_delta: float) -> void:
	if cowl == null or not is_instance_valid(cowl):
		return
	var best: Node = null
	var best_d := INF
	var text := ""
	if cowl.state == Cowl.State.NORMAL:
		for n in get_tree().get_nodes_in_group(&"interactable"):
			var p: String = n.call(&"interact_prompt", cowl)
			if p == "":
				continue
			var origin: Vector2 = n.call(&"interact_origin") if n.has_method(&"interact_origin") else (n as Node2D).global_position
			var d := origin.distance_to(cowl.global_position)
			if d < best_d and d < 420.0:
				best = n
				best_d = d
				text = p
	if best == null:
		for n in get_tree().get_nodes_in_group(&"prompt_zone"):
			var p: String = n.call(&"zone_prompt", cowl)
			if p != "":
				text = p
				break
	elif Input.is_action_just_pressed(&"interact") and cowl.controls_enabled:
		best.call(&"interact", cowl)
	hud.set_prompt(text)
	if Game.get_flag("lab_door_seen") and not Game.get_flag("slice_end_shown"):
		Game.set_flag("slice_end_shown")
		_show_end_card()


func _show_end_card() -> void:
	await get_tree().create_timer(7.0).timeout
	Game.say("END OF THE VERTICAL SLICE\nThe house is yours to keep exploring.", 9.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_level"):
		load_level("lab" if level_name == "mansion" else "mansion")
	elif event.is_action_pressed(&"debug_collision"):
		Game.debug_collision = not Game.debug_collision
		level.queue_redraw()
	elif event.is_action_pressed(&"debug_fly"):
		cowl.fly_mode = not cowl.fly_mode
	elif event.is_action_pressed(&"debug_knife"):
		Game.give_knife()


func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	await get_tree().create_timer(1.5, true, false, true).timeout
	await hud.fade(1.0, 0.5)
	var at := Game.checkpoint_position if Game.has_checkpoint else level.spawn_px
	cowl.revive(at)
	camera.snap()
	await hud.fade(0.0, 0.6)
	_respawning = false
