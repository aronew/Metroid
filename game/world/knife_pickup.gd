extends Node2D
## The butcher knife, buried in the block it fell with. Walk up and take it.

const KNIFE := preload("res://assets/cowl/knife.png")
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
	Game.say("The butcher knife. Heavier than it looks, and it has kept its edge.", 4.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# The knife stands in the block it fell with, blade sunk a third deep.
	if not _taken:
		draw_set_transform(Vector2(4, -40), 0.2, Vector2(0.4, 0.4))
		draw_texture(KNIFE, -Vector2(50, 290))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-46, -58, 92, 58), Pal.INK)
	draw_rect(Rect2(-52, -66, 104, 12), Pal.INK_SOFT)
	draw_line(Vector2(-52, -66), Vector2(52, -66), Pal.EDGE, 3.0)
	if _taken:
		return
	# A slow glint so the eye finds it.
	var g := pow(maxf(sin(_t * 1.6), 0.0), 12.0)
	var c := Vector2(-8, -132)
	draw_line(c + Vector2(-26, 0) * g, c + Vector2(26, 0) * g, Color(1, 1, 1, g), 3.0, true)
	draw_line(c + Vector2(0, -26) * g, c + Vector2(0, 26) * g, Color(1, 1, 1, g), 3.0, true)
