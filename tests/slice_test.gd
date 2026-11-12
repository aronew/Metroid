extends Node
## Plays the slice's mechanics end to end with scripted input, in the real
## game scene: waking, the vine lock, taking the knife, cutting through, riding
## the lifts, creatures, spikes, the bookcase and dying.
##
##   godot --headless --path . res://tests/slice_test.tscn

const T := 64.0
var main: Node
var cowl: Cowl
var inp := Cowl.InputState.new()
var failures := 0
var lines: PackedStringArray = []


func _ready() -> void:
	Sfx.muted = true
	main = (load("res://game/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		inp.jump_pressed = false
		inp.attack_pressed = false
		inp.dodge_pressed = false
		inp.any_pressed = false


func check(ok: bool, text: String) -> void:
	lines.append(("  ok    " if ok else "  FAIL  ") + text)
	if not ok:
		failures += 1


func put(x: float, y: float, facing := 1) -> void:
	inp = Cowl.InputState.new()
	cowl.sim_input = inp
	cowl.sim_reset(Vector2(x, y) * T)
	cowl.facing = facing
	cowl.reset_physics_interpolation()
	await frames(4)


func entity(kind: String, index := 0) -> Node:
	return (main.get("level") as Level).entities_by_type[kind][index]


func named(kind: String, part: String) -> Node:
	for n: Node in (main.get("level") as Level).entities_by_type[kind]:
		if String((n.get_meta(&"spec") as Dictionary).get("name", "")).contains(part):
			return n
	return null


func swing() -> void:
	inp.attack_pressed = true
	await frames(1)
	await frames(24)


func _run() -> void:
	await frames(5)
	cowl = main.get("cowl")
	cowl.sim_input = inp
	lines.append("SLICE MECHANICS TEST")

	# --- waking ---------------------------------------------------------
	check(cowl.state == Cowl.State.CUTSCENE and cowl.wake_progress == 0.0, "starts asleep in bed")
	await frames(30)
	check(cowl.state == Cowl.State.CUTSCENE, "stays asleep until a key is pressed")
	inp.any_pressed = true
	await frames(1)
	await frames(130)
	check(cowl.state == Cowl.State.NORMAL, "wakes and stands under the player's control")

	# --- the vine lock, before the knife ---------------------------------
	await put(22.0, 28.0, -1)
	inp.move = -1.0
	await frames(60)
	check(cowl.global_position.x > 19.5 * T, "roots across the bedroom's west door stop him (x %.1f)" % (cowl.global_position.x / T))
	await put(20.6, 28.0, -1)
	var v1 := named("vine", "V1")
	await swing()
	Engine.time_scale = 1.0
	check(is_instance_valid(v1) and not v1.get(&"_cut"), "bare-handed strikes do not cut the roots")
	await put(22.0, 28.0, -1)
	inp.move = -1.0
	await frames(40)
	inp.move = 0.0
	check(cowl.global_position.x > 19.5 * T, "and the roots still hold the door")

	# --- the knife ---------------------------------------------------------
	await put(41.0, 54.0)
	var knife := entity("knife")
	check(knife.call(&"interact_prompt", cowl) != "", "the knife in the pantry offers itself")
	knife.call(&"interact", cowl)
	Engine.time_scale = 1.0
	check(Game.has_knife, "taking it gives Cowl the knife")

	check((named("lift", "dumbwaiter") as Lift).locked, "the dumbwaiter is held by roots")

	# --- cutting through ---------------------------------------------------
	await put(59.6, 54.0, 1)
	var vine := named("vine", "V5")
	await swing()
	Engine.time_scale = 1.0
	await frames(50)
	check(not is_instance_valid(vine) or vine.get(&"_cut"), "with the knife, one strike cuts the roots on the pantry door")
	inp.move = 1.0
	await frames(50)
	inp.move = 0.0
	check(cowl.global_position.x > 61.0 * T, "and he walks through the doorway toward storage (x %.1f)" % (cowl.global_position.x / T))

	# --- a creature --------------------------------------------------------
	var crawler := entity("crawler") as Node2D
	await put(crawler.global_position.x / T - 1.6, 54.0, 1)
	var hp_before := cowl.health
	await swing()
	Engine.time_scale = 1.0
	check(crawler.get(&"health") < 2, "a strike wounds a crawler")
	for i in 4:
		if is_instance_valid(crawler) and not crawler.get(&"_dead"):
			await put(crawler.global_position.x / T - 1.4, crawler.global_position.y / T, 1)
			await swing()
			Engine.time_scale = 1.0
	check(not is_instance_valid(crawler) or crawler.get(&"_dead"), "and a second blow kills it")
	var other := entity("crawler", 2) as Node2D
	await put(other.global_position.x / T, other.global_position.y / T)
	await frames(20)
	check(cowl.health < hp_before or cowl.health < cowl.max_health, "touching a crawler hurts (health %d)" % cowl.health)
	Engine.time_scale = 1.0

	# --- the dumbwaiter ----------------------------------------------------
	# (The storage creatures would wander in and interrupt; clear them for this part.)
	var crawlers: Array = (main.get("level") as Level).entities_by_type["crawler"]
	for i in 2:
		if is_instance_valid(crawlers[i]):
			crawlers[i].queue_free()
	cowl.heal_full()
	var lift := named("lift", "dumbwaiter") as Lift
	await put(56.6, 54.0, 1)
	var lever := named("lever", "V2b")
	await swing()
	Engine.time_scale = 1.0
	await frames(20)
	check(not lift.locked, "cutting the lever's roots frees the mechanism")
	lever.call(&"interact", cowl)
	await frames(200)
	check(not lift.at_top and not lift.moving, "the pantry lever calls it down")
	await put(54.0, 54.0)
	check(lift.rider_on(cowl), "Cowl can stand on it")
	lift.interact(cowl)
	var worst := 0.0
	for i in 200:
		await frames(1)
		worst = maxf(worst, absf(cowl.global_position.y - lift.global_position.y))
		if not lift.moving:
			break
	await frames(10)
	check(absf(cowl.global_position.y - 41.0 * T) < 4.0, "and rides it up to the kitchen (y %.2f)" % (cowl.global_position.y / T))
	check(worst < 14.0, "staying on the deck the whole way (worst gap %.1f px)" % worst)

	# --- spikes ------------------------------------------------------------
	for i in crawlers.size():
		if is_instance_valid(crawlers[i]):
			crawlers[i].queue_free()
	await frames(3)
	cowl.heal_full()
	cowl._invuln = 0.0
	await put(113.0, 54.0, 1)
	await frames(20)
	inp.move = 1.0
	await frames(40)
	inp.move = 0.0
	Engine.time_scale = 1.0
	await frames(90)
	check(cowl.health == cowl.max_health - 1, "the stalagmites cost one health (health %d)" % cowl.health)
	check(cowl.global_position.x < 116.0 * T and cowl.is_on_floor(), "and put him back on the edge he left (x %.1f)" % (cowl.global_position.x / T))

	# --- father's lift and the bookcase -------------------------------------
	var cage := named("lift", "study") as Lift
	var bookcase := entity("bookcase_door")
	await put(231.0, 66.0)
	check(cage.rider_on(cowl), "the lift waits at the laboratory level")
	cage.interact(cowl)
	for i in 400:
		await frames(1)
		if not cage.moving:
			break
	await frames(100)
	check(absf(cowl.global_position.y - 41.0 * T) < 4.0, "it carries him up to the study (y %.2f)" % (cowl.global_position.y / T))
	check(bookcase.get(&"_opening"), "and the bookcase opens from behind")
	inp.move = -1.0
	await frames(70)
	inp.move = 0.0
	check(cowl.global_position.x < 227.0 * T, "he walks out into the study (x %.1f)" % (cowl.global_position.x / T))

	# --- the vault ---------------------------------------------------------
	await put(193.5, 66.0, -1)
	var vault := entity("lab_door")
	check(vault.call(&"interact_prompt", cowl) != "", "the sealed laboratory door can be examined")

	# --- dying -------------------------------------------------------------
	Game.set_checkpoint(Vector2(153.0, 54.0) * T)
	await put(160.0, 54.0)
	for i in 6:
		cowl._invuln = 0.0
		cowl.take_damage(1, cowl.global_position + Vector2(40, 0))
		Engine.time_scale = 1.0
		await frames(3)
	check(cowl.state == Cowl.State.DEAD, "five blows kill")
	Engine.time_scale = 1.0
	await get_tree().create_timer(4.0).timeout
	check(cowl.state == Cowl.State.NORMAL and cowl.health == cowl.max_health, "he comes back whole")
	check(cowl.global_position.distance_to(Vector2(153.0, 54.0) * T) < 40.0, "at the last candle he passed")

	var out := "\n".join(lines)
	print(out)
	var f := FileAccess.open("res://docs/slice-test-report.txt", FileAccess.WRITE)
	f.store_string(out + "\n")
	f.close()
	get_tree().quit(1 if failures > 0 else 0)
