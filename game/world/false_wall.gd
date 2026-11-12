extends Node2D
## Something in front of the play that hides a way through (here, the bank of
## pipes behind the boiler). It never collides. It thins out when Cowl is
## behind it, so finding the gap is a discovery, not a guess.

var w := 256.0
var h := 640.0
var _a := 1.0


func configure(spec: Dictionary) -> void:
	w = float(spec.get("w", 4)) * Game.TILE
	h = float(spec.get("h", 10)) * Game.TILE


func _ready() -> void:
	z_index = 40


func _process(delta: float) -> void:
	var cowl := get_tree().get_first_node_in_group(&"player") as Cowl
	var inside := false
	if cowl != null:
		inside = Rect2(global_position + Vector2(-20, -h - 40), Vector2(w + 40, h + 400)).has_point(cowl.global_position)
		if inside and not Game.get_flag("found_gap"):
			Game.set_flag("found_gap")
			Sfx.play(&"secret")
	_a = move_toward(_a, 0.18 if inside else 1.0, delta * 2.5)
	modulate.a = _a


## Kit art (W33): the bank of pipes behind the boiler, in front of the play.
func _draw() -> void:
	var t := Kit.tex("doors/pipe_wall")
	if t == null:
		return
	draw_texture_rect(t, Rect2(0, -h, w, h), false, Color(0.75, 0.75, 0.85))
	# A breath of cold light through the gaps: the tell.
	for i in 5:
		var y := -h * (0.15 + 0.17 * i)
		draw_circle(Vector2(w * 0.5, y), 60.0, Color(Pal.WATER.r, Pal.WATER.g, Pal.WATER.b, 0.05))
