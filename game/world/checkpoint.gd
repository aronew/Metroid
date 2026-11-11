extends Area2D
## A place to come back to. Cowl's own bed is the first; the others are candles
## that take light as he passes. Passing one mends him and sets the return point.

var kind := "rest"
var _lit := false
var _glow := 0.0
var _t := 0.0


func configure(spec: Dictionary) -> void:
	kind = spec.get("kind", "rest")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var shape := RectangleShape2D.new()
	shape.size = Vector2(150, 150)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -75)
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = 7
	_lit = kind == "bed"


func _on_body(body: Node) -> void:
	if not body is Cowl:
		return
	var cowl := body as Cowl
	if cowl.state == Cowl.State.CUTSCENE:
		return
	Game.set_checkpoint(global_position)
	cowl.heal_full()
	if not _lit and kind != "bed":
		_lit = true
		Sfx.play(&"candle")
		Puff.burst(self, global_position + Vector2(0, -92), 4, Vector2(0, -30), 0.5)


func _process(delta: float) -> void:
	_t += delta
	_glow = move_toward(_glow, 1.0 if _lit else 0.0, delta * 2.0)
	if kind != "bed":
		queue_redraw()


## Kit art (W34): a candle on an iron stand, unlit until Cowl passes; then
## the flame loop (W36) and its light.
func _draw() -> void:
	if kind == "bed":
		return
	var key := "props/candle_lit" if _glow > 0.0 else "props/candle_unlit"
	var t := Kit.tex(key)
	if t == null:
		return
	var s := 112.0 / t.get_height()
	var size := t.get_size() * s
	var rect := Rect2(-size.x * 0.5, -size.y + 2.0, size.x, size.y)
	draw_texture_rect(t, rect, false)
	if _glow > 0.0:
		var wicks: Array = Kit.meta("props/candle_lit").get("wicks", [])
		var base := rect.position + (Vector2(wicks[0][0], wicks[0][1]) * s if not wicks.is_empty() else Vector2(size.x * 0.5, size.y * 0.12))
		var f := 1.0 + sin(_t * 11.0) * 0.08 + sin(_t * 23.0) * 0.05
		for i in 5:
			var r := (150.0 - i * 26.0) * f
			draw_circle(base + Vector2(0, -8), r, Color(Pal.CANDLE.r, Pal.CANDLE.g, Pal.CANDLE.b, 0.03 * _glow * (i + 1)))
		Kit.draw_flame(self, base, 18.0, int(_t * 60.0), _glow)
