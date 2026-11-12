class_name Ghost
extends Sprite2D
## An after-image of Cowl's current frame, left behind by the dodge.

var _t := 0.0


static func spawn(cowl: Cowl, from: Sprite2D) -> void:
	if Sfx.muted or from.texture == null:
		return
	var g := Ghost.new()
	g.texture = from.texture
	g.centered = false
	g.offset = from.offset
	g.z_index = cowl.z_index - 1
	g.modulate = Color(0.55, 0.8, 1.0, 0.42)
	cowl.get_tree().current_scene.add_child(g)
	g.global_transform = from.global_transform


func _process(delta: float) -> void:
	_t += delta
	modulate.a = 0.42 * (1.0 - _t / 0.22)
	if _t >= 0.22:
		queue_free()
