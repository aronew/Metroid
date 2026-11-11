class_name Ghost
extends Sprite2D
## An after-image left behind by the dodge.

const TEX := preload("res://assets/cowl/cowl_whole.png")
var _t := 0.0


static func spawn(cowl: Cowl, rig: Node2D) -> void:
	if Sfx.muted:
		return
	var rig_data: Dictionary = rig.get(&"_rig")
	var g := Ghost.new()
	g.texture = TEX
	g.centered = false
	g.offset = Vector2(rig_data["whole_offset"][0], rig_data["whole_offset"][1])
	g.z_index = cowl.z_index - 1
	g.modulate = Color(0.55, 0.8, 1.0, 0.42)
	cowl.get_tree().current_scene.add_child(g)
	var body: Node2D = rig.get(&"_body")
	g.global_transform = body.global_transform


func _process(delta: float) -> void:
	_t += delta
	modulate.a = 0.42 * (1.0 - _t / 0.22)
	if _t >= 0.22:
		queue_free()
