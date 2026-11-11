extends Node2D
## A region that offers a control prompt while Cowl stands in it, or something
## to look at. Prompts teach by being where the move is first needed.

var w := 128.0
var h := 128.0
var prompt := ""
var text := ""
var when := ""
var interactive := false
var _t := 0.0


func configure(spec: Dictionary) -> void:
	w = float(spec.get("w", 2)) * Game.TILE
	h = float(spec.get("h", 2)) * Game.TILE
	prompt = spec.get("prompt", "")
	text = spec.get("text", "")
	when = spec.get("when", "")
	interactive = spec.get("interact", false)


func _ready() -> void:
	add_to_group(&"interactable" if interactive else &"prompt_zone")
	z_index = 7


func contains(p: Vector2) -> bool:
	return Rect2(global_position + Vector2(0, -h), Vector2(w, h + 8.0)).has_point(p)


## For prompt zones (no interaction): the text to show, or "".
func zone_prompt(cowl: Cowl) -> String:
	if not contains(cowl.global_position):
		return ""
	match when:
		"asleep":
			return prompt if cowl.state == Cowl.State.CUTSCENE and cowl.wake_progress <= 0.0 else ""
		"knife":
			return prompt if Game.has_knife and not Game.get_flag("swung") else ""
	return "" if cowl.state == Cowl.State.CUTSCENE else prompt


func interact_prompt(cowl: Cowl) -> String:
	return "Look  [E]" if contains(cowl.global_position) else ""


func interact_origin() -> Vector2:
	return global_position + Vector2(w * 0.5, -h * 0.5)


func interact(_cowl: Cowl) -> void:
	Game.say(text, 5.5)


func _process(delta: float) -> void:
	if interactive:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not interactive:
		return
	# A mote that says "there is something here".
	var c := Vector2(w * 0.5, -46.0 + sin(_t * 1.7) * 5.0)
	var a := 0.45 + sin(_t * 2.3) * 0.2
	draw_circle(c, 13.0, Color(Pal.EYES.r, Pal.EYES.g, Pal.EYES.b, 0.08 * a * 2.0))
	draw_circle(c, 4.0, Color(0.85, 0.95, 1.0, a))
