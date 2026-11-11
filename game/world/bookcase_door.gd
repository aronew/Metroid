extends StaticBody2D
## The bookcase in father's study. It is a door, and it opens only from behind:
## the first time Cowl comes up to it from the lift side, it swings away.

var w := 64.0
var h := 640.0
var _open := 0.0
var _opening := false


func configure(spec: Dictionary) -> void:
	w = float(spec.get("w", 1)) * Game.TILE
	h = float(spec.get("h", 10)) * Game.TILE


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 11
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(w * 0.5, -h * 0.5)
	cs.name = "Shape"
	add_child(cs)


func _physics_process(delta: float) -> void:
	if not _opening:
		var cowl := get_tree().get_first_node_in_group(&"player") as Cowl
		if cowl != null:
			var zone := Rect2(global_position + Vector2(w, -3.0 * Game.TILE), Vector2(3.2 * Game.TILE, 3.0 * Game.TILE + 12.0))
			if zone.has_point(cowl.global_position):
				_opening = true
				Sfx.play(&"door_heavy")
				Game.shake(0.25)
				Game.say("The bookcase swings in. A way through, from his study to whatever is under it.", 4.5)
				Game.set_flag("bookcase_open")
	elif _open < 1.0:
		_open = minf(_open + delta / 1.1, 1.0)
		if _open > 0.35:
			($Shape as CollisionShape2D).disabled = true
		queue_redraw()


## Kit art (W33): the narrow bookcase. Opening, it slides up into the wall.
func _draw() -> void:
	var lift := ease(_open, 0.4) * (h - 20.0)
	var t := Kit.tex("doors/bookcase_door")
	if t == null:
		return
	draw_texture_rect(t, Rect2(-6.0, -h - lift, w + 12.0, h), false)
