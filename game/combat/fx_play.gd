class_name FxPlay
extends Sprite2D
## Plays one of Cowl's effect sequences (H12 smoke and flame, H21 trails,
## H22 flashes, H23 flares and soot) once, at a point, then frees itself.
## The sheets are white and pale grey so the game tints them.

var _name := ""
var _frames: Array = []
var _ticks: Array = []
var _t := 0.0
var _facing := 1
var _drift := Vector2.ZERO
var _cur := -1
var _size := 1.0


static func play(near: Node, fx_name: String, at: Vector2, facing: int = 1, tint: Color = Color.WHITE,
		additive: bool = true, size: float = 1.0, drift: Vector2 = Vector2.ZERO, z: int = 30) -> FxPlay:
	if not near.is_inside_tree():
		return null
	var spec := CowlAnim.fx(fx_name)
	if spec.is_empty():
		return null
	var f := FxPlay.new()
	f._name = fx_name
	f._frames = spec["frames"]
	f._ticks = spec["ticks"]
	f._facing = facing
	f._drift = drift
	f.modulate = tint
	f.z_index = z
	f.centered = false
	f.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		f.material = m
	near.get_tree().current_scene.add_child(f)
	f.global_position = at
	f._size = size
	f._show(0)
	return f


func _show(i: int) -> void:
	if i == _cur:
		return
	_cur = i
	var fr: Dictionary = _frames[i]
	texture = CowlAnim.tex("fx", fr["file"])
	# Stored at 2x: draw at half scale; a negative x scale mirrors about the origin.
	scale = Vector2(0.5 * _facing, 0.5) * _size
	offset = Vector2(fr["ox"], fr["oy"]) * 2.0


func _process(delta: float) -> void:
	_t += delta * 60.0
	position += _drift * delta
	if _t >= float(CowlAnim.length(_ticks)):
		queue_free()
		return
	_show(CowlAnim.frame_at(_ticks, _t))
