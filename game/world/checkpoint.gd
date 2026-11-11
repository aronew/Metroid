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


func _draw() -> void:
	if kind == "bed":
		return
	# A floor candlestick, in the mansion's ink.
	draw_rect(Rect2(-14, -6, 28, 6), Pal.INK)
	draw_rect(Rect2(-3, -70, 6, 66), Pal.INK)
	draw_rect(Rect2(-12, -76, 24, 6), Pal.INK)
	draw_rect(Rect2(-4, -92, 8, 16), Color(0.75, 0.7, 0.85) if _glow > 0.0 else Pal.INK_SOFT)
	if _glow > 0.0:
		var f := 1.0 + sin(_t * 11.0) * 0.08 + sin(_t * 23.0) * 0.05
		for i in 5:
			var r := (150.0 - i * 26.0) * f
			draw_circle(Vector2(0, -100), r, Color(Pal.CANDLE.r, Pal.CANDLE.g, Pal.CANDLE.b, 0.035 * _glow * (i + 1)))
		draw_circle(Vector2(0, -100 - 4 * f), 7.0 * f, Color(1.0, 0.9, 0.8, _glow))
