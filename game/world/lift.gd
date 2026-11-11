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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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


## Kit art (W31): the dumbwaiter's frame, the iron cage, the chandelier ring.
## Each is scaled to the platform's width with its standing line on the deck.
func _draw() -> void:
	var key := {"dumbwaiter": "machines/dumbwaiter", "chandelier": "machines/chandelier_lift"}.get(kind, "machines/cage") as String
	var t := Kit.tex(key)
	if t == null:
		return
	var s := w / t.get_width()
	var deck: float = Kit.meta(key)["deck"]
	var sway := sin(_t * 0.9) * 0.006 if kind == "chandelier" else 0.0
	draw_set_transform(Vector2(w * 0.5, 0), sway, Vector2.ONE)
	draw_texture_rect(t, Rect2(-w * 0.5, -deck * s, w, t.get_height() * s), false)
	# Cables (or the chandelier's chain) up into the dark.
	var chain := Kit.tex("machines/chain")
	var cs := 0.6
	var cw := chain.get_width() * cs
	var tops: Array = [0.0] if kind == "chandelier" else [-w * 0.36, w * 0.36]
	for cx: float in tops:
		var y0 := -deck * s - 1800.0
		var y1 := -deck * s + (6.0 if kind != "chandelier" else 4.0)
		draw_texture_rect_region(chain, Rect2(cx - cw * 0.5, y0, cw, y1 - y0), Rect2(0, 0, chain.get_width(), (y1 - y0) / cs))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
