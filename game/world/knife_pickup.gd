extends Node2D
## The butcher knife, buried in the block it fell with. Walk up and take it.

var _t := 0.0
var _taken := false


func _ready() -> void:
	z_index = 8
	add_to_group(&"interactable")


func interact_prompt(_cowl: Cowl) -> String:
	return "" if _taken else "Take the knife  [E]"


func interact(_cowl: Cowl) -> void:
	if _taken:
		return
	_taken = true
	Game.give_knife()
	Game.hitstop(0.12)
	Game.shake(0.3)
	Sfx.play(&"pickup")
	Game.say("The butcher knife. Heavier than it looks, and it has kept its edge. Roots will not stop you now.", 4.5)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Kit art (W34): the butcher's block with the knife buried in it. Once the
## knife is taken, only the block is drawn (the art cut at the block's top).
func _draw() -> void:
	var key := "props/butcher_block"
	var t := Kit.tex(key)
	if t == null:
		return
	var s := 104.0 / t.get_width()
	var size := t.get_size() * s
	var rect := Rect2(-size.x * 0.5, -size.y + 2.0, size.x, size.y)
	if _taken:
		var top: float = Kit.meta(key)["block_top"]
		draw_texture_rect_region(t, Rect2(rect.position.x, rect.position.y + top * s, size.x, size.y - top * s),
			Rect2(0, top, t.get_width(), t.get_height() - top))
		return
	draw_texture_rect(t, rect, false)
	# A slow glint on the blade so the eye finds it.
	var g := pow(maxf(sin(_t * 1.6), 0.0), 12.0)
	var c := Vector2(size.x * 0.12, -size.y * 0.86)
	draw_line(c + Vector2(-26, 0) * g, c + Vector2(26, 0) * g, Color(1, 1, 1, g), 3.0, true)
	draw_line(c + Vector2(0, -26) * g, c + Vector2(0, 26) * g, Color(1, 1, 1, g), 3.0, true)
