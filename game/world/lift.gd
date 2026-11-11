class_name Lift
extends AnimatableBody2D
## A platform that travels between two stops. Its control is on it: stand on
## it and pull. Call levers at either stop bring it to you. A lift whose
## mechanism is bound in roots will not move until one of its levers is cut free.
##
## kinds: "dumbwaiter" (kitchen), "cage" (father's private lift), "chandelier".

signal arrived(at_top: bool)

const SPEED := 5.5 * 64.0

var w := 256.0
var top_y := 0.0
var bottom_y := 0.0
var kind := "cage"
var lift_name := ""
var locked := false
var at_top := true
var moving := false
var _goal := 0.0
var _vel := 0.0
var _t := 0.0


func configure(spec: Dictionary) -> void:
	w = float(spec.get("w", 4)) * Game.TILE
	top_y = float(spec["top"]) * Game.TILE
	bottom_y = float(spec["bottom"]) * Game.TILE
	kind = spec.get("kind", "cage")
	lift_name = spec.get("name", "")
	at_top = spec.get("start", "top") == "top"


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	position.y = top_y if at_top else bottom_y
	_goal = position.y
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 20.0)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(w * 0.5, 10.0)
	add_child(cs)
	add_to_group(&"interactable")
	add_to_group(&"lift")
	z_index = 5


func rider_on(cowl: Cowl) -> bool:
	var p := cowl.global_position
	return cowl.is_on_floor() and p.x > global_position.x + 6.0 and p.x < global_position.x + w - 6.0 \
		and absf(p.y - global_position.y) < 10.0


func interact_prompt(cowl: Cowl) -> String:
	if moving or not rider_on(cowl):
		return ""
	return "Held fast by roots" if locked else "Pull the lever  [E]"


func interact_origin() -> Vector2:
	return global_position + Vector2(w * 0.5, 0.0)


func interact(_cowl: Cowl) -> void:
	if locked:
		Sfx.play(&"locked")
		return
	send(not at_top)


## Send the platform to a stop. Returns false if it cannot go.
func send(to_top: bool) -> bool:
	if locked or moving or to_top == at_top:
		return false
	moving = true
	at_top = to_top
	_goal = top_y if to_top else bottom_y
	Sfx.play(&"lift_start")
	return true


func _physics_process(delta: float) -> void:
	_t += delta
	if not moving:
		return
	var dist := _goal - position.y
	# Ease away from a stop and into the next one.
	var want := signf(dist) * minf(SPEED, absf(dist) * 4.0 + 50.0)
	_vel = move_toward(_vel, want, SPEED * 3.0 * delta)
	var step := _vel * delta
	if absf(step) >= absf(dist):
		position.y = _goal
		_vel = 0.0
		moving = false
		Sfx.play(&"lift_stop")
		Game.shake(0.1)
		arrived.emit(at_top)
	else:
		position.y += step
	queue_redraw()


func _process(_delta: float) -> void:
	if kind == "chandelier":
		queue_redraw()


func _draw() -> void:
	match kind:
		"chandelier":
			_draw_chandelier()
		_:
			_draw_cage()


func _draw_cage() -> void:
	# Deck, a low rail, and the lever.
	draw_rect(Rect2(0, 0, w, 20), Pal.INK)
	draw_line(Vector2(0, 1), Vector2(w, 1), Pal.EDGE, 3.0)
	for x: float in [6.0, w - 6.0]:
		draw_line(Vector2(x, 0), Vector2(x, -150), Pal.INK, 7.0)
	draw_line(Vector2(6, -150), Vector2(w - 6, -150), Pal.INK, 7.0)
	var lx := w - 30.0
	draw_line(Vector2(lx, 0), Vector2(lx + (10.0 if at_top else -10.0), -44), Pal.INK_SOFT, 6.0)
	draw_circle(Vector2(lx + (10.0 if at_top else -10.0), -46), 7.0, Pal.LAVENDER)
	# Cables up into the dark.
	for x: float in [18.0, w - 18.0]:
		draw_line(Vector2(x, -150), Vector2(x, -1400), Color(Pal.INK.r, Pal.INK.g, Pal.INK.b, 0.9), 3.0)


func _draw_chandelier() -> void:
	# An iron ring of candles on a chain. You ride the ring.
	var sway := sin(_t * 0.9) * 3.0
	draw_line(Vector2(w * 0.5, -6), Vector2(w * 0.5 + sway * 0.2, -1700), Pal.INK, 5.0)
	for i in 3:
		var x := w * (0.2 + 0.3 * i)
		draw_line(Vector2(w * 0.5, -150), Vector2(x, 0), Pal.INK, 4.0)
	draw_rect(Rect2(0, 0, w, 16), Pal.INK)
	draw_line(Vector2(0, 1), Vector2(w, 1), Pal.EDGE, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(20, 16), Vector2(w - 20, 16), Vector2(w * 0.5, 70)]), Pal.INK)
	for i in 6:
		var x := 14.0 + (w - 28.0) * i / 5.0
		draw_rect(Rect2(x - 4, -26, 8, 26), Color(0.72, 0.68, 0.84))
		var f := 1.0 + sin(_t * 12.0 + i * 1.7) * 0.12
		for k in 3:
			draw_circle(Vector2(x, -34), (46.0 - k * 14.0) * f, Color(Pal.CANDLE.r, Pal.CANDLE.g, Pal.CANDLE.b, 0.05 * (k + 1)))
		draw_circle(Vector2(x, -34 - 2 * f), 5.5 * f, Color(1.0, 0.92, 0.82))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 0), Vector2(x + 8, 0), Vector2(x, 14)]), Pal.INK)
